//
//  SCManagedAudioStreamer.m
//  Snapchat
//
//  Created by Ricardo Sánchez-Sáez on 7/28/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCManagedAudioStreamer.h"

#import "SCAudioCaptureSession.h"

#import <SCAudio/SCAudioSession.h>
#import <SCCameraFoundation/SCManagedAudioDataSourceListenerAnnouncer.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>

#import <SCAudioScope/SCAudioScope.h>
#import <SCAudioScope/SCAudioSessionExperimentAdapter.h>

static char *const kSCManagedAudioStreamerQueueLabel = "com.snapchat.audioStreamerQueue";

@interface SCManagedAudioStreamer () <SCAudioCaptureSessionDelegate>

@end

@implementation SCManagedAudioStreamer {
    SCAudioCaptureSession *_captureSession;
    SCAudioConfigurationToken *_audioConfiguration;
    SCManagedAudioDataSourceListenerAnnouncer *_announcer;
    SCScopedAccess<SCMutableAudioSession *> *_scopedMutableAudioSession;
}

@synthesize performer = _performer;

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static SCManagedAudioStreamer *managedAudioStreamer;
    dispatch_once(&onceToken, ^{
        managedAudioStreamer = [[SCManagedAudioStreamer alloc] initSharedInstance];
    });
    return managedAudioStreamer;
}

- (instancetype)initSharedInstance
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCManagedAudioStreamerQueueLabel
                                            qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCamera];
        _announcer = [[SCManagedAudioDataSourceListenerAnnouncer alloc] init];
        _captureSession = [[SCAudioCaptureSession alloc] init];
        _captureSession.delegate = self;
    }
    return self;
}

- (BOOL)isStreaming
{
    return _audioConfiguration != nil;
}

- (void)startStreamingWithAudioConfiguration:(SCAudioConfiguration *)configuration
{
    SCTraceStart();
    [_performer perform:^{
        if (!self.isStreaming) {
            // Begin audio recording asynchronously. First we need to have the proper audio session category.
            _audioConfiguration = [SCAudioSessionExperimentAdapter
                configureWith:configuration
                    performer:_performer
                   completion:^(NSError *error) {
                       [_captureSession
                           beginAudioRecordingAsynchronouslyWithSampleRate:kSCAudioCaptureSessionDefaultSampleRate
                                                         completionHandler:NULL];

                   }];
        }
    }];
}

- (void)stopStreaming
{
    [_performer perform:^{
        if (self.isStreaming) {
            [_captureSession disposeAudioRecordingSynchronouslyWithCompletionHandler:NULL];
            [SCAudioSessionExperimentAdapter relinquishConfiguration:_audioConfiguration performer:nil completion:nil];
            _audioConfiguration = nil;
        }
    }];
}

- (void)addListener:(id<SCManagedAudioDataSourceListener>)listener
{
    SCTraceStart();
    [_announcer addListener:listener];
}

- (void)removeListener:(id<SCManagedAudioDataSourceListener>)listener
{
    SCTraceStart();
    [_announcer removeListener:listener];
}

- (void)audioCaptureSession:(SCAudioCaptureSession *)audioCaptureSession
      didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [_announcer managedAudioDataSource:self didOutputSampleBuffer:sampleBuffer];
}

@end
