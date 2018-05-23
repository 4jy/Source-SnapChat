//
//  SCManagedVideoFileStreamer.m
//  Snapchat
//
//  Created by Alexander Grytsiuk on 3/4/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCManagedVideoFileStreamer.h"

#import "SCManagedCapturePreviewLayerController.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListenerAnnouncer.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCPlayer.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>

@import AVFoundation;
@import CoreMedia;

static char *const kSCManagedVideoFileStreamerQueueLabel = "com.snapchat.managed-video-file-streamer";

@interface SCManagedVideoFileStreamer () <AVPlayerItemOutputPullDelegate>
@end

@implementation SCManagedVideoFileStreamer {
    SCManagedVideoDataSourceListenerAnnouncer *_announcer;
    SCManagedCaptureDevicePosition _devicePosition;
    sc_managed_video_file_streamer_pixel_buffer_completion_handler_t _nextPixelBufferHandler;

    id _notificationToken;
    id<SCPerforming> _performer;
    dispatch_semaphore_t _semaphore;

    CADisplayLink *_displayLink;
    AVPlayerItemVideoOutput *_videoOutput;
    AVPlayer *_player;

    BOOL _sampleBufferDisplayEnabled;
    id<SCManagedSampleBufferDisplayController> _sampleBufferDisplayController;
}

@synthesize isStreaming = _isStreaming;
@synthesize performer = _performer;
@synthesize videoOrientation = _videoOrientation;

- (instancetype)initWithPlaybackForURL:(NSURL *)URL
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        _announcer = [[SCManagedVideoDataSourceListenerAnnouncer alloc] init];
        _semaphore = dispatch_semaphore_create(1);
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCManagedVideoFileStreamerQueueLabel
                                            qualityOfService:QOS_CLASS_UNSPECIFIED
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextStories];

        // Setup CADisplayLink which will callback displayPixelBuffer: at every vsync.
        _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(displayLinkCallback:)];
        [_displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
        [_displayLink setPaused:YES];

        // Prepare player
        _player = [[SCPlayer alloc] initWithPlayerDomain:SCPlayerDomainCameraFileStreamer URL:URL];
#if TARGET_IPHONE_SIMULATOR
        _player.volume = 0.0;
#endif
        // Configure output
        [self configureOutput];
    }
    return self;
}

- (void)addSampleBufferDisplayController:(id<SCManagedSampleBufferDisplayController>)sampleBufferDisplayController
{
    _sampleBufferDisplayController = sampleBufferDisplayController;
}

- (void)setSampleBufferDisplayEnabled:(BOOL)sampleBufferDisplayEnabled
{
    _sampleBufferDisplayEnabled = sampleBufferDisplayEnabled;
    SCLogGeneralInfo(@"[SCManagedVideoFileStreamer] sampleBufferDisplayEnabled set to:%d", _sampleBufferDisplayEnabled);
}

- (void)setKeepLateFrames:(BOOL)keepLateFrames
{
    // Do nothing
}

- (BOOL)getKeepLateFrames
{
    // return default NO value
    return NO;
}

- (void)waitUntilSampleBufferDisplayed:(dispatch_queue_t)queue completionHandler:(dispatch_block_t)completionHandler
{
    SCAssert(queue, @"callback queue must be provided");
    SCAssert(completionHandler, @"completion handler must be provided");
    dispatch_async(queue, completionHandler);
}

- (void)startStreaming
{
    SCTraceStart();
    if (!_isStreaming) {
        _isStreaming = YES;
        [self addDidPlayToEndTimeNotificationForPlayerItem:_player.currentItem];
        [_player play];
    }
}

- (void)stopStreaming
{
    SCTraceStart();
    if (_isStreaming) {
        _isStreaming = NO;
        [_player pause];
        [self removePlayerObservers];
    }
}

- (void)pauseStreaming
{
    [self stopStreaming];
}

- (void)addListener:(id<SCManagedVideoDataSourceListener>)listener
{
    SCTraceStart();
    [_announcer addListener:listener];
}

- (void)removeListener:(id<SCManagedVideoDataSourceListener>)listener
{
    SCTraceStart();
    [_announcer removeListener:listener];
}

- (void)setAsOutput:(AVCaptureSession *)session devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    _devicePosition = devicePosition;
}

- (void)setDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    _devicePosition = devicePosition;
}

- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    _videoOrientation = videoOrientation;
}

- (void)removeAsOutput:(AVCaptureSession *)session
{
    // Ignored
}

- (void)setVideoStabilizationEnabledIfSupported:(BOOL)videoStabilizationIfSupported
{
    // Ignored
}

- (void)beginConfiguration
{
    // Ignored
}

- (void)commitConfiguration
{
    // Ignored
}

- (void)setPortraitModePointOfInterest:(CGPoint)pointOfInterest
{
    // Ignored
}

#pragma mark - AVPlayerItemOutputPullDelegate

- (void)outputMediaDataWillChange:(AVPlayerItemOutput *)sender
{
    if (![_videoOutput hasNewPixelBufferForItemTime:CMTimeMake(1, 10)]) {
        [self configureOutput];
    }
    [_displayLink setPaused:NO];
}

#pragma mark - Internal

- (void)displayLinkCallback:(CADisplayLink *)sender
{
    CFTimeInterval nextVSync = [sender timestamp] + [sender duration];

    CMTime time = [_videoOutput itemTimeForHostTime:nextVSync];
    if (dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_NOW) == 0) {
        [_performer perform:^{
            if ([_videoOutput hasNewPixelBufferForItemTime:time]) {
                CVPixelBufferRef pixelBuffer = [_videoOutput copyPixelBufferForItemTime:time itemTimeForDisplay:NULL];
                if (pixelBuffer != NULL) {
                    if (_nextPixelBufferHandler) {
                        _nextPixelBufferHandler(pixelBuffer);
                        _nextPixelBufferHandler = nil;
                    } else {
                        CMSampleBufferRef sampleBuffer =
                            [self createSampleBufferFromPixelBuffer:pixelBuffer
                                                   presentationTime:CMTimeMake(CACurrentMediaTime() * 1000, 1000)];
                        if (sampleBuffer) {
                            if (_sampleBufferDisplayEnabled) {
                                [_sampleBufferDisplayController enqueueSampleBuffer:sampleBuffer];
                            }
                            [_announcer managedVideoDataSource:self
                                         didOutputSampleBuffer:sampleBuffer
                                                devicePosition:_devicePosition];
                            CFRelease(sampleBuffer);
                        }
                    }
                    CVBufferRelease(pixelBuffer);
                }
            }
            dispatch_semaphore_signal(_semaphore);
        }];
    }
}

- (CMSampleBufferRef)createSampleBufferFromPixelBuffer:(CVPixelBufferRef)pixelBuffer presentationTime:(CMTime)time
{
    CMSampleBufferRef sampleBuffer = NULL;
    CMVideoFormatDescriptionRef formatDesc = NULL;

    OSStatus err = CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &formatDesc);
    if (err != noErr) {
        return NULL;
    }

    CMSampleTimingInfo sampleTimingInfo = {kCMTimeInvalid, time, kCMTimeInvalid};
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, formatDesc,
                                       &sampleTimingInfo, &sampleBuffer);

    CFRelease(formatDesc);

    return sampleBuffer;
}

- (void)configureOutput
{
    // Remove old output
    if (_videoOutput) {
        [[_player currentItem] removeOutput:_videoOutput];
    }

    // Setup AVPlayerItemVideoOutput with the required pixelbuffer attributes.
    _videoOutput = [[AVPlayerItemVideoOutput alloc] initWithPixelBufferAttributes:@{
        (id) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
    }];
    _videoOutput.suppressesPlayerRendering = YES;
    [_videoOutput setDelegate:self queue:_performer.queue];

    // Add new output
    [[_player currentItem] addOutput:_videoOutput];
    [_videoOutput requestNotificationOfMediaDataChangeWithAdvanceInterval:1.0 / 30.0];
}

- (void)getNextPixelBufferWithCompletion:(sc_managed_video_file_streamer_pixel_buffer_completion_handler_t)completion
{
    _nextPixelBufferHandler = completion;
}

- (void)addDidPlayToEndTimeNotificationForPlayerItem:(AVPlayerItem *)item
{
    if (_notificationToken) {
        _notificationToken = nil;
    }

    _player.actionAtItemEnd = AVPlayerActionAtItemEndNone;
    _notificationToken =
        [[NSNotificationCenter defaultCenter] addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                                                          object:item
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [[_player currentItem] seekToTime:kCMTimeZero];
                                                      }];
}

- (void)removePlayerObservers
{
    if (_notificationToken) {
        [[NSNotificationCenter defaultCenter] removeObserver:_notificationToken
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:_player.currentItem];
        _notificationToken = nil;
    }
}

@end
