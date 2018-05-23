//
//  SCFileAudioCaptureSession.m
//  Snapchat
//
//  Created by Xiaomu Wu on 2/2/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCFileAudioCaptureSession.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCSentinel.h>

@import AudioToolbox;

static float const kAudioBufferDurationInSeconds = 0.2; // same as SCAudioCaptureSession

static char *const kSCFileAudioCaptureSessionQueueLabel = "com.snapchat.file-audio-capture-session";

@implementation SCFileAudioCaptureSession {
    SCQueuePerformer *_performer;
    SCSentinel *_sentinel;

    NSURL *_fileURL;

    AudioFileID _audioFile;                         // audio file
    AudioStreamBasicDescription _asbd;              // audio format (core audio)
    CMAudioFormatDescriptionRef _formatDescription; // audio format (core media)
    SInt64 _readCurPacket;                          // current packet index to read
    UInt32 _readNumPackets;                         // number of packets to read every time
    UInt32 _readNumBytes;                           // number of bytes to read every time
    void *_readBuffer;                              // data buffer to hold read packets
}

@synthesize delegate = _delegate;

#pragma mark - Public

- (instancetype)init
{
    self = [super init];
    if (self) {
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCFileAudioCaptureSessionQueueLabel
                                            qualityOfService:QOS_CLASS_UNSPECIFIED
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCamera];
        _sentinel = [[SCSentinel alloc] init];
    }
    return self;
}

- (void)dealloc
{
    if (_audioFile) {
        AudioFileClose(_audioFile);
    }
    if (_formatDescription) {
        CFRelease(_formatDescription);
    }
    if (_readBuffer) {
        free(_readBuffer);
    }
}

- (void)setFileURL:(NSURL *)fileURL
{
    [_performer perform:^{
        _fileURL = fileURL;
    }];
}

#pragma mark - SCAudioCaptureSession

- (void)beginAudioRecordingAsynchronouslyWithSampleRate:(double)sampleRate // `sampleRate` ignored
                                      completionHandler:(audio_capture_session_block)completionHandler
{
    [_performer perform:^{
        BOOL succeeded = [self _setup];
        int32_t sentinelValue = [_sentinel value];
        if (completionHandler) {
            completionHandler(nil);
        }
        if (succeeded) {
            [_performer perform:^{
                SC_GUARD_ELSE_RETURN([_sentinel value] == sentinelValue);
                [self _read];
            }
                          after:kAudioBufferDurationInSeconds];
        }
    }];
}

- (void)disposeAudioRecordingSynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
{
    [_performer performAndWait:^{
        [self _teardown];
        if (completionHandler) {
            completionHandler();
        }
    }];
}

#pragma mark - Private

- (BOOL)_setup
{
    SCAssert([_performer isCurrentPerformer], @"");

    [_sentinel increment];

    OSStatus status = noErr;

    status = AudioFileOpenURL((__bridge CFURLRef)_fileURL, kAudioFileReadPermission, 0, &_audioFile);
    if (noErr != status) {
        SCLogGeneralError(@"Cannot open file at URL %@, error code %d", _fileURL, (int)status);
        return NO;
    }

    _asbd = (AudioStreamBasicDescription){0};
    UInt32 asbdSize = sizeof(_asbd);
    status = AudioFileGetProperty(_audioFile, kAudioFilePropertyDataFormat, &asbdSize, &_asbd);
    if (noErr != status) {
        SCLogGeneralError(@"Cannot get audio data format, error code %d", (int)status);
        AudioFileClose(_audioFile);
        _audioFile = NULL;
        return NO;
    }

    if (kAudioFormatLinearPCM != _asbd.mFormatID) {
        SCLogGeneralError(@"Linear PCM is required");
        AudioFileClose(_audioFile);
        _audioFile = NULL;
        _asbd = (AudioStreamBasicDescription){0};
        return NO;
    }

    UInt32 aclSize = 0;
    AudioChannelLayout *acl = NULL;
    status = AudioFileGetPropertyInfo(_audioFile, kAudioFilePropertyChannelLayout, &aclSize, NULL);
    if (noErr == status) {
        acl = malloc(aclSize);
        status = AudioFileGetProperty(_audioFile, kAudioFilePropertyChannelLayout, &aclSize, acl);
        if (noErr != status) {
            aclSize = 0;
            free(acl);
            acl = NULL;
        }
    }

    status = CMAudioFormatDescriptionCreate(NULL, &_asbd, aclSize, acl, 0, NULL, NULL, &_formatDescription);
    if (acl) {
        free(acl);
        acl = NULL;
    }
    if (noErr != status) {
        SCLogGeneralError(@"Cannot create format description, error code %d", (int)status);
        AudioFileClose(_audioFile);
        _audioFile = NULL;
        _asbd = (AudioStreamBasicDescription){0};
        return NO;
    }

    _readCurPacket = 0;
    _readNumPackets = ceil(_asbd.mSampleRate * kAudioBufferDurationInSeconds);
    _readNumBytes = _asbd.mBytesPerPacket * _readNumPackets;
    _readBuffer = malloc(_readNumBytes);

    return YES;
}

- (void)_read
{
    SCAssert([_performer isCurrentPerformer], @"");

    OSStatus status = noErr;

    UInt32 numBytes = _readNumBytes;
    UInt32 numPackets = _readNumPackets;
    status = AudioFileReadPacketData(_audioFile, NO, &numBytes, NULL, _readCurPacket, &numPackets, _readBuffer);
    if (noErr != status) {
        SCLogGeneralError(@"Cannot read audio data, error code %d", (int)status);
        return;
    }
    if (0 == numPackets) {
        return;
    }
    CMTime PTS = CMTimeMakeWithSeconds(_readCurPacket / _asbd.mSampleRate, 600);

    _readCurPacket += numPackets;

    CMBlockBufferRef dataBuffer = NULL;
    status = CMBlockBufferCreateWithMemoryBlock(NULL, NULL, numBytes, NULL, NULL, 0, numBytes, 0, &dataBuffer);
    if (kCMBlockBufferNoErr == status) {
        if (dataBuffer) {
            CMBlockBufferReplaceDataBytes(_readBuffer, dataBuffer, 0, numBytes);
            CMSampleBufferRef sampleBuffer = NULL;
            CMAudioSampleBufferCreateWithPacketDescriptions(NULL, dataBuffer, true, NULL, NULL, _formatDescription,
                                                            numPackets, PTS, NULL, &sampleBuffer);
            if (sampleBuffer) {
                [_delegate audioCaptureSession:self didOutputSampleBuffer:sampleBuffer];
                CFRelease(sampleBuffer);
            }
            CFRelease(dataBuffer);
        }
    } else {
        SCLogGeneralError(@"Cannot create data buffer, error code %d", (int)status);
    }

    int32_t sentinelValue = [_sentinel value];
    [_performer perform:^{
        SC_GUARD_ELSE_RETURN([_sentinel value] == sentinelValue);
        [self _read];
    }
                  after:kAudioBufferDurationInSeconds];
}

- (void)_teardown
{
    SCAssert([_performer isCurrentPerformer], @"");

    [_sentinel increment];

    if (_audioFile) {
        AudioFileClose(_audioFile);
        _audioFile = NULL;
    }
    _asbd = (AudioStreamBasicDescription){0};
    if (_formatDescription) {
        CFRelease(_formatDescription);
        _formatDescription = NULL;
    }
    _readCurPacket = 0;
    _readNumPackets = 0;
    _readNumBytes = 0;
    if (_readBuffer) {
        free(_readBuffer);
        _readBuffer = NULL;
    }
}

@end
