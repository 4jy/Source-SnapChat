//
//  SCAudioCaptureSession.m
//  Snapchat
//
//  Created by Liu Liu on 3/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCAudioCaptureSession.h"

#import <SCAudio/SCAudioSession.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>

#import <mach/mach.h>
#import <mach/mach_time.h>

@import AVFoundation;

double const kSCAudioCaptureSessionDefaultSampleRate = 44100;
NSString *const SCAudioCaptureSessionErrorDomain = @"SCAudioCaptureSessionErrorDomain";

static NSInteger const kNumberOfAudioBuffersInQueue = 15;
static float const kAudioBufferDurationInSeconds = 0.2;

static char *const kSCAudioCaptureSessionQueueLabel = "com.snapchat.audio-capture-session";

@implementation SCAudioCaptureSession {
    SCQueuePerformer *_performer;

    AudioQueueRef _audioQueue;
    AudioQueueBufferRef _audioQueueBuffers[kNumberOfAudioBuffersInQueue];
    CMAudioFormatDescriptionRef _audioFormatDescription;
}

@synthesize delegate = _delegate;

- (instancetype)init
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCAudioCaptureSessionQueueLabel
                                            qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCamera];
    }
    return self;
}

- (void)dealloc
{
    [self disposeAudioRecordingSynchronouslyWithCompletionHandler:NULL];
}

static AudioStreamBasicDescription setupAudioFormat(UInt32 inFormatID, Float64 sampleRate)
{
    SCTraceStart();
    AudioStreamBasicDescription recordFormat = {0};

    recordFormat.mSampleRate = sampleRate;
    recordFormat.mChannelsPerFrame = (UInt32)[SCAudioSession sharedInstance].inputNumberOfChannels;

    recordFormat.mFormatID = inFormatID;
    if (inFormatID == kAudioFormatLinearPCM) {
        // if we want pcm, default to signed 16-bit little-endian
        recordFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
        recordFormat.mBitsPerChannel = 16;
        recordFormat.mBytesPerPacket = recordFormat.mBytesPerFrame =
            (recordFormat.mBitsPerChannel / 8) * recordFormat.mChannelsPerFrame;
        recordFormat.mFramesPerPacket = 1;
    }
    return recordFormat;
}

static int computeRecordBufferSize(const AudioStreamBasicDescription *format, const AudioQueueRef audioQueue,
                                   float seconds)
{
    SCTraceStart();
    int packets, frames, bytes = 0;
    frames = (int)ceil(seconds * format->mSampleRate);

    if (format->mBytesPerFrame > 0) {
        bytes = frames * format->mBytesPerFrame;
    } else {
        UInt32 maxPacketSize;
        if (format->mBytesPerPacket > 0)
            maxPacketSize = format->mBytesPerPacket; // constant packet size
        else {
            UInt32 propertySize = sizeof(maxPacketSize);
            AudioQueueGetProperty(audioQueue, kAudioQueueProperty_MaximumOutputPacketSize, &maxPacketSize,
                                  &propertySize);
        }
        if (format->mFramesPerPacket > 0)
            packets = frames / format->mFramesPerPacket;
        else
            packets = frames; // worst-case scenario: 1 frame in a packet
        if (packets == 0)     // sanity check
            packets = 1;
        bytes = packets * maxPacketSize;
    }
    return bytes;
}

static NSTimeInterval machHostTimeToSeconds(UInt64 mHostTime)
{
    static dispatch_once_t onceToken;
    static mach_timebase_info_data_t timebase_info;
    dispatch_once(&onceToken, ^{
        (void)mach_timebase_info(&timebase_info);
    });
    return (double)mHostTime * timebase_info.numer / timebase_info.denom / NSEC_PER_SEC;
}

static void audioQueueBufferHandler(void *inUserData, AudioQueueRef inAQ, AudioQueueBufferRef inBuffer,
                                    const AudioTimeStamp *nStartTime, UInt32 inNumPackets,
                                    const AudioStreamPacketDescription *inPacketDesc)
{
    SCTraceStart();
    SCAudioCaptureSession *audioCaptureSession = (__bridge SCAudioCaptureSession *)inUserData;
    if (inNumPackets > 0) {
        CMTime PTS = CMTimeMakeWithSeconds(machHostTimeToSeconds(nStartTime->mHostTime), 600);
        [audioCaptureSession appendAudioQueueBuffer:inBuffer
                                         numPackets:inNumPackets
                                                PTS:PTS
                                 packetDescriptions:inPacketDesc];
    }

    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

- (void)appendAudioQueueBuffer:(AudioQueueBufferRef)audioQueueBuffer
                    numPackets:(UInt32)numPackets
                           PTS:(CMTime)PTS
            packetDescriptions:(const AudioStreamPacketDescription *)packetDescriptions
{
    SCTraceStart();
    CMBlockBufferRef dataBuffer = NULL;
    CMBlockBufferCreateWithMemoryBlock(NULL, NULL, audioQueueBuffer->mAudioDataByteSize, NULL, NULL, 0,
                                       audioQueueBuffer->mAudioDataByteSize, 0, &dataBuffer);
    if (dataBuffer) {
        CMBlockBufferReplaceDataBytes(audioQueueBuffer->mAudioData, dataBuffer, 0,
                                      audioQueueBuffer->mAudioDataByteSize);
        CMSampleBufferRef sampleBuffer = NULL;
        CMAudioSampleBufferCreateWithPacketDescriptions(NULL, dataBuffer, true, NULL, NULL, _audioFormatDescription,
                                                        numPackets, PTS, packetDescriptions, &sampleBuffer);
        if (sampleBuffer) {
            [self processAudioSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
        }
        CFRelease(dataBuffer);
    }
}

- (void)processAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    SCTraceStart();
    [_delegate audioCaptureSession:self didOutputSampleBuffer:sampleBuffer];
}

- (NSError *)_generateErrorForType:(NSString *)errorType
                         errorCode:(int)errorCode
                            format:(AudioStreamBasicDescription)format
{
    NSDictionary *errorInfo = @{
        @"error_type" : errorType,
        @"error_code" : @(errorCode),
        @"record_format" : @{
            @"format_id" : @(format.mFormatID),
            @"format_flags" : @(format.mFormatFlags),
            @"sample_rate" : @(format.mSampleRate),
            @"bytes_per_packet" : @(format.mBytesPerPacket),
            @"frames_per_packet" : @(format.mFramesPerPacket),
            @"bytes_per_frame" : @(format.mBytesPerFrame),
            @"channels_per_frame" : @(format.mChannelsPerFrame),
            @"bits_per_channel" : @(format.mBitsPerChannel)
        }
    };
    SCLogGeneralInfo(@"Audio queue error occured. ErrorInfo: %@", errorInfo);
    return [NSError errorWithDomain:SCAudioCaptureSessionErrorDomain code:errorCode userInfo:errorInfo];
}

- (NSError *)beginAudioRecordingWithSampleRate:(Float64)sampleRate
{
    SCTraceStart();
    if ([SCAudioSession sharedInstance].inputAvailable) {
        // SCAudioSession should be activated already
        SCTraceSignal(@"Set audio session to be active");
        AudioStreamBasicDescription recordFormat = setupAudioFormat(kAudioFormatLinearPCM, sampleRate);
        OSStatus audioQueueCreationStatus = AudioQueueNewInput(&recordFormat, audioQueueBufferHandler,
                                                               (__bridge void *)self, NULL, NULL, 0, &_audioQueue);
        if (audioQueueCreationStatus != 0) {
            NSError *error = [self _generateErrorForType:@"audio_queue_create_error"
                                               errorCode:audioQueueCreationStatus
                                                  format:recordFormat];
            return error;
        }
        SCTraceSignal(@"Initialize audio queue with new input");
        UInt32 bufferByteSize = computeRecordBufferSize(
            &recordFormat, _audioQueue, kAudioBufferDurationInSeconds); // Enough bytes for half a second
        for (int i = 0; i < kNumberOfAudioBuffersInQueue; i++) {
            AudioQueueAllocateBuffer(_audioQueue, bufferByteSize, &_audioQueueBuffers[i]);
            AudioQueueEnqueueBuffer(_audioQueue, _audioQueueBuffers[i], 0, NULL);
        }
        SCTraceSignal(@"Allocate audio buffer");
        UInt32 size = sizeof(recordFormat);
        audioQueueCreationStatus =
            AudioQueueGetProperty(_audioQueue, kAudioQueueProperty_StreamDescription, &recordFormat, &size);
        if (0 != audioQueueCreationStatus) {
            NSError *error = [self _generateErrorForType:@"audio_queue_get_property_error"
                                               errorCode:audioQueueCreationStatus
                                                  format:recordFormat];
            [self disposeAudioRecording];
            return error;
        }
        SCTraceSignal(@"Audio queue sample rate %lf", recordFormat.mSampleRate);
        AudioChannelLayout acl;
        bzero(&acl, sizeof(acl));
        acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
        audioQueueCreationStatus = CMAudioFormatDescriptionCreate(NULL, &recordFormat, sizeof(acl), &acl, 0, NULL, NULL,
                                                                  &_audioFormatDescription);
        if (0 != audioQueueCreationStatus) {
            NSError *error = [self _generateErrorForType:@"audio_queue_audio_format_error"
                                               errorCode:audioQueueCreationStatus
                                                  format:recordFormat];
            [self disposeAudioRecording];
            return error;
        }
        SCTraceSignal(@"Start audio queue");
        audioQueueCreationStatus = AudioQueueStart(_audioQueue, NULL);
        if (0 != audioQueueCreationStatus) {
            NSError *error = [self _generateErrorForType:@"audio_queue_start_error"
                                               errorCode:audioQueueCreationStatus
                                                  format:recordFormat];
            [self disposeAudioRecording];
            return error;
        }
    }
    return nil;
}

- (void)disposeAudioRecording
{
    SCTraceStart();
    SCLogGeneralInfo(@"dispose audio recording");
    if (_audioQueue) {
        AudioQueueStop(_audioQueue, true);
        AudioQueueDispose(_audioQueue, true);
        for (int i = 0; i < kNumberOfAudioBuffersInQueue; i++) {
            _audioQueueBuffers[i] = NULL;
        }
        _audioQueue = NULL;
    }
    if (_audioFormatDescription) {
        CFRelease(_audioFormatDescription);
        _audioFormatDescription = NULL;
    }
}

#pragma mark - Public methods

- (void)beginAudioRecordingAsynchronouslyWithSampleRate:(double)sampleRate
                                      completionHandler:(audio_capture_session_block)completionHandler
{
    SCTraceStart();
    // Request audio session change for recording mode.
    [_performer perform:^{
        SCTraceStart();
        NSError *error = [self beginAudioRecordingWithSampleRate:sampleRate];
        if (completionHandler) {
            completionHandler(error);
        }
    }];
}

- (void)disposeAudioRecordingSynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
{
    SCTraceStart();
    [_performer performAndWait:^{
        SCTraceStart();
        [self disposeAudioRecording];
        if (completionHandler) {
            completionHandler();
        }
    }];
}

@end
