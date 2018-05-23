//
//  SCManagedVideoStreamer.m
//  Snapchat
//
//  Created by Liu Liu on 4/30/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedVideoStreamer.h"

#import "ARConfiguration+SCConfiguration.h"
#import "SCCameraTweaks.h"
#import "SCCapturerDefines.h"
#import "SCLogger+Camera.h"
#import "SCManagedCapturePreviewLayerController.h"
#import "SCMetalUtils.h"
#import "SCProcessingPipeline.h"
#import "SCProcessingPipelineBuilder.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListenerAnnouncer.h>
#import <SCFoundation/NSString+SCFormat.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCLogger/SCCameraMetrics.h>

#import <Looksery/Looksery.h>

#import <libkern/OSAtomic.h>
#import <stdatomic.h>

@import ARKit;
@import AVFoundation;

#define SCLogVideoStreamerInfo(fmt, ...) SCLogCoreCameraInfo(@"[SCManagedVideoStreamer] " fmt, ##__VA_ARGS__)
#define SCLogVideoStreamerWarning(fmt, ...) SCLogCoreCameraWarning(@"[SCManagedVideoStreamer] " fmt, ##__VA_ARGS__)
#define SCLogVideoStreamerError(fmt, ...) SCLogCoreCameraError(@"[SCManagedVideoStreamer] " fmt, ##__VA_ARGS__)

static NSInteger const kSCCaptureFrameRate = 30;
static CGFloat const kSCLogInterval = 3.0;
static char *const kSCManagedVideoStreamerQueueLabel = "com.snapchat.managed-video-streamer";
static char *const kSCManagedVideoStreamerCallbackQueueLabel = "com.snapchat.managed-video-streamer.dequeue";
static NSTimeInterval const kSCManagedVideoStreamerMaxAllowedLatency = 1; // Drop the frame if it is 1 second late.

static NSTimeInterval const kSCManagedVideoStreamerStalledDisplay =
    5; // If the frame is not updated for 5 seconds, it is considered to be stalled.

static NSTimeInterval const kSCManagedVideoStreamerARSessionFramerateCap =
    1.0 / (kSCCaptureFrameRate + 1); // Restrict ARSession to 30fps
static int32_t const kSCManagedVideoStreamerMaxProcessingBuffers = 15;

@interface SCManagedVideoStreamer () <AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate,
                                      AVCaptureDataOutputSynchronizerDelegate, ARSessionDelegate>

@property (nonatomic, strong) AVCaptureSession *captureSession;

@end

@implementation SCManagedVideoStreamer {
    AVCaptureVideoDataOutput *_videoDataOutput;
    AVCaptureDepthDataOutput *_depthDataOutput NS_AVAILABLE_IOS(11_0);
    AVCaptureDataOutputSynchronizer *_dataOutputSynchronizer NS_AVAILABLE_IOS(11_0);
    BOOL _performingConfigurations;
    SCManagedCaptureDevicePosition _devicePosition;
    BOOL _videoStabilizationEnabledIfSupported;
    SCManagedVideoDataSourceListenerAnnouncer *_announcer;

    BOOL _sampleBufferDisplayEnabled;
    id<SCManagedSampleBufferDisplayController> _sampleBufferDisplayController;
    dispatch_block_t _flushOutdatedPreviewBlock;
    NSMutableArray<NSArray *> *_waitUntilSampleBufferDisplayedBlocks;
    SCProcessingPipeline *_processingPipeline;

    NSTimeInterval _lastDisplayedFrameTimestamp;
#ifdef SC_USE_ARKIT_FACE
    NSTimeInterval _lastDisplayedDepthFrameTimestamp;
#endif

    BOOL _depthCaptureEnabled;
    CGPoint _portraitModePointOfInterest;

    // For sticky video tweaks
    BOOL _keepLateFrames;
    SCQueuePerformer *_callbackPerformer;
    atomic_int _processingBuffersCount;
}

@synthesize isStreaming = _isStreaming;
@synthesize performer = _performer;
@synthesize currentFrame = _currentFrame;
@synthesize fieldOfView = _fieldOfView;
#ifdef SC_USE_ARKIT_FACE
@synthesize lastDepthData = _lastDepthData;
#endif
@synthesize videoOrientation = _videoOrientation;

- (instancetype)initWithSession:(AVCaptureSession *)session
                 devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _sampleBufferDisplayEnabled = YES;
        _announcer = [[SCManagedVideoDataSourceListenerAnnouncer alloc] init];
        // We discard frames to support lenses in real time
        _keepLateFrames = NO;
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCManagedVideoStreamerQueueLabel
                                            qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCamera];

        _videoOrientation = AVCaptureVideoOrientationLandscapeRight;

        [self setupWithSession:session devicePosition:devicePosition];
        SCLogVideoStreamerInfo(@"init with position:%lu", (unsigned long)devicePosition);
    }
    return self;
}

- (instancetype)initWithSession:(AVCaptureSession *)session
                      arSession:(ARSession *)arSession
                 devicePosition:(SCManagedCaptureDevicePosition)devicePosition NS_AVAILABLE_IOS(11_0)
{
    self = [self initWithSession:session devicePosition:devicePosition];
    if (self) {
        [self setupWithARSession:arSession];
        self.currentFrame = nil;
#ifdef SC_USE_ARKIT_FACE
        self.lastDepthData = nil;
#endif
    }
    return self;
}

- (AVCaptureVideoDataOutput *)_newVideoDataOutput
{
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    // All inbound frames are going to be the native format of the camera avoid
    // any need for transcoding.
    output.videoSettings =
        @{(NSString *) kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) };
    return output;
}

- (void)setupWithSession:(AVCaptureSession *)session devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    [self stopStreaming];
    self.captureSession = session;
    _devicePosition = devicePosition;

    _videoDataOutput = [self _newVideoDataOutput];
    if (SCDeviceSupportsMetal()) {
        // We default to start the streaming if the Metal is supported at startup time.
        _isStreaming = YES;
        // Set the sample buffer delegate before starting it.
        [_videoDataOutput setSampleBufferDelegate:self queue:[self callbackPerformer].queue];
    }

    if ([session canAddOutput:_videoDataOutput]) {
        [session addOutput:_videoDataOutput];
        [self _enableVideoMirrorForDevicePosition:devicePosition];
    }

    if (SCCameraTweaksEnablePortraitModeButton()) {
        if (@available(iOS 11.0, *)) {
            _depthDataOutput = [[AVCaptureDepthDataOutput alloc] init];
            [[_depthDataOutput connectionWithMediaType:AVMediaTypeDepthData] setEnabled:NO];
            if ([session canAddOutput:_depthDataOutput]) {
                [session addOutput:_depthDataOutput];
                [_depthDataOutput setDelegate:self callbackQueue:_performer.queue];
            }
            _depthCaptureEnabled = NO;
        }
        _portraitModePointOfInterest = CGPointMake(0.5, 0.5);
    }

    [self setVideoStabilizationEnabledIfSupported:YES];
}

- (void)setupWithARSession:(ARSession *)arSession NS_AVAILABLE_IOS(11_0)
{
    arSession.delegateQueue = _performer.queue;
    arSession.delegate = self;
}

- (void)addSampleBufferDisplayController:(id<SCManagedSampleBufferDisplayController>)sampleBufferDisplayController
{
    [_performer perform:^{
        _sampleBufferDisplayController = sampleBufferDisplayController;
        SCLogVideoStreamerInfo(@"add sampleBufferDisplayController:%@", _sampleBufferDisplayController);
    }];
}

- (void)setSampleBufferDisplayEnabled:(BOOL)sampleBufferDisplayEnabled
{
    [_performer perform:^{
        _sampleBufferDisplayEnabled = sampleBufferDisplayEnabled;
        SCLogVideoStreamerInfo(@"sampleBufferDisplayEnabled set to:%d", _sampleBufferDisplayEnabled);
    }];
}

- (void)waitUntilSampleBufferDisplayed:(dispatch_queue_t)queue completionHandler:(dispatch_block_t)completionHandler
{
    SCAssert(queue, @"callback queue must be provided");
    SCAssert(completionHandler, @"completion handler must be provided");
    SCLogVideoStreamerInfo(@"waitUntilSampleBufferDisplayed queue:%@ completionHandler:%p isStreaming:%d", queue,
                           completionHandler, _isStreaming);
    if (_isStreaming) {
        [_performer perform:^{
            if (!_waitUntilSampleBufferDisplayedBlocks) {
                _waitUntilSampleBufferDisplayedBlocks = [NSMutableArray array];
            }
            [_waitUntilSampleBufferDisplayedBlocks addObject:@[ queue, completionHandler ]];
            SCLogVideoStreamerInfo(@"waitUntilSampleBufferDisplayed add block:%p", completionHandler);
        }];
    } else {
        dispatch_async(queue, completionHandler);
    }
}

- (void)startStreaming
{
    SCTraceStart();
    SCLogVideoStreamerInfo(@"start streaming. _isStreaming:%d", _isStreaming);
    if (!_isStreaming) {
        _isStreaming = YES;
        [self _cancelFlushOutdatedPreview];
        if (@available(ios 11.0, *)) {
            if (_depthCaptureEnabled) {
                [[_depthDataOutput connectionWithMediaType:AVMediaTypeDepthData] setEnabled:YES];
            }
        }
        [_videoDataOutput setSampleBufferDelegate:self queue:[self callbackPerformer].queue];
    }
}

- (void)setAsOutput:(AVCaptureSession *)session devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceStart();
    if ([session canAddOutput:_videoDataOutput]) {
        SCLogVideoStreamerError(@"add videoDataOutput:%@", _videoDataOutput);
        [session addOutput:_videoDataOutput];
        [self _enableVideoMirrorForDevicePosition:devicePosition];
    } else {
        SCLogVideoStreamerError(@"cannot add videoDataOutput:%@ to session:%@", _videoDataOutput, session);
    }
    [self _enableVideoStabilizationIfSupported];
}

- (void)removeAsOutput:(AVCaptureSession *)session
{
    SCTraceStart();
    SCLogVideoStreamerInfo(@"remove videoDataOutput:%@ from session:%@", _videoDataOutput, session);
    [session removeOutput:_videoDataOutput];
}

- (void)_cancelFlushOutdatedPreview
{
    SCLogVideoStreamerInfo(@"cancel flush outdated preview:%p", _flushOutdatedPreviewBlock);
    if (_flushOutdatedPreviewBlock) {
        dispatch_block_cancel(_flushOutdatedPreviewBlock);
        _flushOutdatedPreviewBlock = nil;
    }
}

- (SCQueuePerformer *)callbackPerformer
{
    // If sticky video tweak is on, use a separated performer queue
    if (_keepLateFrames) {
        if (!_callbackPerformer) {
            _callbackPerformer = [[SCQueuePerformer alloc] initWithLabel:kSCManagedVideoStreamerCallbackQueueLabel
                                                        qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                               queueType:DISPATCH_QUEUE_SERIAL
                                                                 context:SCQueuePerformerContextCamera];
        }
        return _callbackPerformer;
    }
    return _performer;
}

- (void)pauseStreaming
{
    SCTraceStart();
    SCLogVideoStreamerInfo(@"pauseStreaming isStreaming:%d", _isStreaming);
    if (_isStreaming) {
        _isStreaming = NO;
        [_videoDataOutput setSampleBufferDelegate:nil queue:NULL];
        if (@available(ios 11.0, *)) {
            if (_depthCaptureEnabled) {
                [[_depthDataOutput connectionWithMediaType:AVMediaTypeDepthData] setEnabled:NO];
            }
        }
        @weakify(self);
        _flushOutdatedPreviewBlock = dispatch_block_create(0, ^{
            SCLogVideoStreamerInfo(@"execute flushOutdatedPreviewBlock");
            @strongify(self);
            SC_GUARD_ELSE_RETURN(self);
            [self->_sampleBufferDisplayController flushOutdatedPreview];
        });
        [_performer perform:_flushOutdatedPreviewBlock
                      after:SCCameraTweaksEnableKeepLastFrameOnCamera() ? kSCManagedVideoStreamerStalledDisplay : 0];
        [_performer perform:^{
            [self _performCompletionHandlersForWaitUntilSampleBufferDisplayed];
        }];
    }
}

- (void)stopStreaming
{
    SCTraceStart();
    SCLogVideoStreamerInfo(@"stopStreaming isStreaming:%d", _isStreaming);
    if (_isStreaming) {
        _isStreaming = NO;
        [_videoDataOutput setSampleBufferDelegate:nil queue:NULL];
        if (@available(ios 11.0, *)) {
            if (_depthCaptureEnabled) {
                [[_depthDataOutput connectionWithMediaType:AVMediaTypeDepthData] setEnabled:NO];
            }
        }
    }
    [self _cancelFlushOutdatedPreview];
    [_performer perform:^{
        SCLogVideoStreamerInfo(@"stopStreaming in perfome queue");
        [_sampleBufferDisplayController flushOutdatedPreview];
        [self _performCompletionHandlersForWaitUntilSampleBufferDisplayed];
    }];
}

- (void)beginConfiguration
{
    SCLogVideoStreamerInfo(@"enter beginConfiguration");
    [_performer perform:^{
        SCLogVideoStreamerInfo(@"performingConfigurations set to YES");
        _performingConfigurations = YES;
    }];
}

- (void)setDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCLogVideoStreamerInfo(@"setDevicePosition with newPosition:%lu", (unsigned long)devicePosition);
    [self _enableVideoMirrorForDevicePosition:devicePosition];
    [self _enableVideoStabilizationIfSupported];
    [_performer perform:^{
        SCLogVideoStreamerInfo(@"setDevicePosition in perform queue oldPosition:%lu newPosition:%lu",
                               (unsigned long)_devicePosition, (unsigned long)devicePosition);
        if (_devicePosition != devicePosition) {
            _devicePosition = devicePosition;
        }
    }];
}

- (void)setVideoOrientation:(AVCaptureVideoOrientation)videoOrientation
{
    SCTraceStart();
    // It is not neccessary call these changes on private queue, because is is just only data output configuration.
    // It should be called from manged capturer queue to prevent lock capture session in two different(private and
    // managed capturer) queues that will cause the deadlock.
    SCLogVideoStreamerInfo(@"setVideoOrientation oldOrientation:%lu newOrientation:%lu",
                           (unsigned long)_videoOrientation, (unsigned long)videoOrientation);
    _videoOrientation = videoOrientation;
    AVCaptureConnection *connection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = _videoOrientation;
}

- (void)setKeepLateFrames:(BOOL)keepLateFrames
{
    SCTraceStart();
    [_performer perform:^{
        SCTraceStart();
        if (keepLateFrames != _keepLateFrames) {
            _keepLateFrames = keepLateFrames;
            // Get and set corresponding queue base on keepLateFrames.
            // We don't use AVCaptureVideoDataOutput.alwaysDiscardsLateVideo anymore, because it will potentially
            // result in lenses regression, and we could use all 15 sample buffers by adding a separated calllback
            // queue.
            [_videoDataOutput setSampleBufferDelegate:self queue:[self callbackPerformer].queue];
            SCLogVideoStreamerInfo(@"keepLateFrames was set to:%d", keepLateFrames);
        }
    }];
}

- (void)setDepthCaptureEnabled:(BOOL)enabled NS_AVAILABLE_IOS(11_0)
{
    _depthCaptureEnabled = enabled;
    [[_depthDataOutput connectionWithMediaType:AVMediaTypeDepthData] setEnabled:enabled];
    if (enabled) {
        _dataOutputSynchronizer =
            [[AVCaptureDataOutputSynchronizer alloc] initWithDataOutputs:@[ _videoDataOutput, _depthDataOutput ]];
        [_dataOutputSynchronizer setDelegate:self queue:_performer.queue];
    } else {
        _dataOutputSynchronizer = nil;
    }
}

- (void)setPortraitModePointOfInterest:(CGPoint)pointOfInterest
{
    _portraitModePointOfInterest = pointOfInterest;
}

- (BOOL)getKeepLateFrames
{
    return _keepLateFrames;
}

- (void)commitConfiguration
{
    SCLogVideoStreamerInfo(@"enter commitConfiguration");
    [_performer perform:^{
        SCLogVideoStreamerInfo(@"performingConfigurations set to NO");
        _performingConfigurations = NO;
    }];
}

- (void)addListener:(id<SCManagedVideoDataSourceListener>)listener
{
    SCTraceStart();
    SCLogVideoStreamerInfo(@"add listener:%@", listener);
    [_announcer addListener:listener];
}

- (void)removeListener:(id<SCManagedVideoDataSourceListener>)listener
{
    SCTraceStart();
    SCLogVideoStreamerInfo(@"remove listener:%@", listener);
    [_announcer removeListener:listener];
}

- (void)addProcessingPipeline:(SCProcessingPipeline *)processingPipeline
{
    SCLogVideoStreamerInfo(@"enter addProcessingPipeline:%@", processingPipeline);
    [_performer perform:^{
        SCLogVideoStreamerInfo(@"processingPipeline set to %@", processingPipeline);
        _processingPipeline = processingPipeline;
    }];
}

- (void)removeProcessingPipeline
{
    SCLogVideoStreamerInfo(@"enter removeProcessingPipeline");
    [_performer perform:^{
        SCLogVideoStreamerInfo(@"processingPipeline set to nil");
        _processingPipeline = nil;
    }];
}

- (BOOL)isVideoMirrored
{
    SCTraceStart();
    AVCaptureConnection *connection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    return connection.isVideoMirrored;
}

#pragma mark - Common Sample Buffer Handling

- (void)didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    return [self didOutputSampleBuffer:sampleBuffer depthData:nil];
}

- (void)didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer depthData:(CVPixelBufferRef)depthDataMap
{
    // Don't send the sample buffer if we are perform configurations
    if (_performingConfigurations) {
        SCLogVideoStreamerError(@"didOutputSampleBuffer return because performingConfigurations is YES");
        return;
    }
    SC_GUARD_ELSE_RETURN([_performer isCurrentPerformer]);

    // We can't set alwaysDiscardsLateVideoFrames to YES when lens is activated because it will cause camera freezing.
    // When alwaysDiscardsLateVideoFrames is set to NO, the late frames will not be dropped until it reach 15 frames,
    // so we should simulate the dropping behaviour as AVFoundation do.
    NSTimeInterval presentationTime = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
    _lastDisplayedFrameTimestamp = presentationTime;
    NSTimeInterval frameLatency = CACurrentMediaTime() - presentationTime;
    // Log interval definied in macro LOG_INTERVAL, now is 3.0s
    BOOL shouldLog =
        (long)(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) * kSCCaptureFrameRate) %
            ((long)(kSCCaptureFrameRate * kSCLogInterval)) ==
        0;
    if (shouldLog) {
        SCLogVideoStreamerInfo(@"didOutputSampleBuffer:%p", sampleBuffer);
    }
    if (_processingPipeline) {
        RenderData renderData = {
            .sampleBuffer = sampleBuffer,
            .depthDataMap = depthDataMap,
            .depthBlurPointOfInterest =
                SCCameraTweaksEnablePortraitModeAutofocus() || SCCameraTweaksEnablePortraitModeTapToFocus()
                    ? &_portraitModePointOfInterest
                    : nil,
        };
        // Ensure we are doing all render operations (i.e. accessing textures) on performer to prevent race condition
        SCAssertPerformer(_performer);
        sampleBuffer = [_processingPipeline render:renderData];

        if (shouldLog) {
            SCLogVideoStreamerInfo(@"rendered sampleBuffer:%p in processingPipeline:%@", sampleBuffer,
                                   _processingPipeline);
        }
    }

    if (sampleBuffer && _sampleBufferDisplayEnabled) {
        // Send the buffer only if it is valid, set it to be displayed immediately (See the enqueueSampleBuffer method
        // header, need to get attachments array and set the dictionary).
        CFArrayRef attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        if (!attachmentsArray) {
            SCLogVideoStreamerError(@"Error getting attachment array for CMSampleBuffer");
        } else if (CFArrayGetCount(attachmentsArray) > 0) {
            CFMutableDictionaryRef attachment = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachmentsArray, 0);
            CFDictionarySetValue(attachment, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        }
        // Warn if frame that went through is not most recent enough.
        if (frameLatency >= kSCManagedVideoStreamerMaxAllowedLatency) {
            SCLogVideoStreamerWarning(
                @"The sample buffer we received is too late, why? presentationTime:%lf frameLatency:%f",
                presentationTime, frameLatency);
        }
        [_sampleBufferDisplayController enqueueSampleBuffer:sampleBuffer];
        if (shouldLog) {
            SCLogVideoStreamerInfo(@"displayed sampleBuffer:%p in Metal", sampleBuffer);
        }

        [self _performCompletionHandlersForWaitUntilSampleBufferDisplayed];
    }

    if (shouldLog) {
        SCLogVideoStreamerInfo(@"begin annoucing sampleBuffer:%p of devicePosition:%lu", sampleBuffer,
                               (unsigned long)_devicePosition);
    }
    [_announcer managedVideoDataSource:self didOutputSampleBuffer:sampleBuffer devicePosition:_devicePosition];
    if (shouldLog) {
        SCLogVideoStreamerInfo(@"end annoucing sampleBuffer:%p", sampleBuffer);
    }
}

- (void)didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (_performingConfigurations) {
        return;
    }
    SC_GUARD_ELSE_RETURN([_performer isCurrentPerformer]);
    NSTimeInterval currentProcessingTime = CACurrentMediaTime();
    NSTimeInterval currentSampleTime = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
    // Only logging it when sticky tweak is on, which means sticky time is too long, and AVFoundation have to drop the
    // sampleBuffer
    if (_keepLateFrames) {
        SCLogVideoStreamerInfo(@"didDropSampleBuffer:%p timestamp:%f latency:%f", sampleBuffer, currentProcessingTime,
                               currentSampleTime);
    }
    [_announcer managedVideoDataSource:self didDropSampleBuffer:sampleBuffer devicePosition:_devicePosition];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection NS_AVAILABLE_IOS(11_0)
{
    // Sticky video tweak is off, i.e. lenses is on,
    // we use same queue for callback and processing, and let AVFoundation decide which frame should be dropped
    if (!_keepLateFrames) {
        [self didOutputSampleBuffer:sampleBuffer];
    }
    // Sticky video tweak is on
    else {
        if ([_performer isCurrentPerformer]) {
            // Note: there might be one frame callbacked in processing queue when switching callback queue,
            // it should be fine. But if following log appears too much, it is not our design.
            SCLogVideoStreamerWarning(@"The callback queue should be a separated queue when sticky tweak is on");
        }
        // TODO: In sticky video v2, we should consider check free memory
        if (_processingBuffersCount >= kSCManagedVideoStreamerMaxProcessingBuffers - 1) {
            SCLogVideoStreamerWarning(@"processingBuffersCount reached to the max. current count:%d",
                                      _processingBuffersCount);
            [self didDropSampleBuffer:sampleBuffer];
            return;
        }
        atomic_fetch_add(&_processingBuffersCount, 1);
        CFRetain(sampleBuffer);
        // _performer should always be the processing queue
        [_performer perform:^{
            [self didOutputSampleBuffer:sampleBuffer];
            CFRelease(sampleBuffer);
            atomic_fetch_sub(&_processingBuffersCount, 1);
        }];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
  didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    [self didDropSampleBuffer:sampleBuffer];
}

#pragma mark - AVCaptureDataOutputSynchronizer (Video + Depth)

- (void)dataOutputSynchronizer:(AVCaptureDataOutputSynchronizer *)synchronizer
    didOutputSynchronizedDataCollection:(AVCaptureSynchronizedDataCollection *)synchronizedDataCollection
    NS_AVAILABLE_IOS(11_0)
{
    AVCaptureSynchronizedDepthData *syncedDepthData = (AVCaptureSynchronizedDepthData *)[synchronizedDataCollection
        synchronizedDataForCaptureOutput:_depthDataOutput];
    AVDepthData *depthData = nil;
    if (syncedDepthData && !syncedDepthData.depthDataWasDropped) {
        depthData = syncedDepthData.depthData;
    }

    AVCaptureSynchronizedSampleBufferData *syncedVideoData =
        (AVCaptureSynchronizedSampleBufferData *)[synchronizedDataCollection
            synchronizedDataForCaptureOutput:_videoDataOutput];
    if (syncedVideoData && !syncedVideoData.sampleBufferWasDropped) {
        CMSampleBufferRef videoSampleBuffer = syncedVideoData.sampleBuffer;
        [self didOutputSampleBuffer:videoSampleBuffer depthData:depthData ? depthData.depthDataMap : nil];
    }
}

#pragma mark - ARSessionDelegate

- (void)session:(ARSession *)session cameraDidChangeTrackingState:(ARCamera *)camera NS_AVAILABLE_IOS(11_0)
{
    NSString *state = nil;
    NSString *reason = nil;
    switch (camera.trackingState) {
    case ARTrackingStateNormal:
        state = @"Normal";
        break;
    case ARTrackingStateLimited:
        state = @"Limited";
        break;
    case ARTrackingStateNotAvailable:
        state = @"Not Available";
        break;
    }
    switch (camera.trackingStateReason) {
    case ARTrackingStateReasonNone:
        reason = @"None";
        break;
    case ARTrackingStateReasonInitializing:
        reason = @"Initializing";
        break;
    case ARTrackingStateReasonExcessiveMotion:
        reason = @"Excessive Motion";
        break;
    case ARTrackingStateReasonInsufficientFeatures:
        reason = @"Insufficient Features";
        break;
#if SC_AT_LEAST_SDK_11_3
    case ARTrackingStateReasonRelocalizing:
        reason = @"Relocalizing";
        break;
#endif
    }
    SCLogVideoStreamerInfo(@"ARKit changed tracking state - %@ (reason: %@)", state, reason);
}

- (void)session:(ARSession *)session didUpdateFrame:(ARFrame *)frame NS_AVAILABLE_IOS(11_0)
{
#ifdef SC_USE_ARKIT_FACE
    // This is extremely weird, but LOOK-10251 indicates that despite the class having it defined, on some specific
    // devices there are ARFrame instances that don't respond to `capturedDepthData`.
    // (note: this was discovered to be due to some people staying on iOS 11 betas).
    AVDepthData *depth = nil;
    if ([frame respondsToSelector:@selector(capturedDepthData)]) {
        depth = frame.capturedDepthData;
    }
#endif

    CGFloat timeSince = frame.timestamp - _lastDisplayedFrameTimestamp;
    // Don't deliver more than 30 frames per sec
    BOOL framerateMinimumElapsed = timeSince >= kSCManagedVideoStreamerARSessionFramerateCap;

#ifdef SC_USE_ARKIT_FACE
    if (depth) {
        CGFloat timeSince = frame.timestamp - _lastDisplayedDepthFrameTimestamp;
        framerateMinimumElapsed |= timeSince >= kSCManagedVideoStreamerARSessionFramerateCap;
    }

#endif

    SC_GUARD_ELSE_RETURN(framerateMinimumElapsed);

#ifdef SC_USE_ARKIT_FACE
    if (depth) {
        self.lastDepthData = depth;
        _lastDisplayedDepthFrameTimestamp = frame.timestamp;
    }
#endif

    // Make sure that current frame is no longer being used, otherwise drop current frame.
    SC_GUARD_ELSE_RETURN(self.currentFrame == nil);

    CVPixelBufferRef pixelBuffer = frame.capturedImage;
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CMTime time = CMTimeMakeWithSeconds(frame.timestamp, 1000000);
    CMSampleTimingInfo timing = {kCMTimeInvalid, time, kCMTimeInvalid};

    CMVideoFormatDescriptionRef videoInfo;
    CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, &videoInfo);

    CMSampleBufferRef buffer;
    CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, YES, nil, nil, videoInfo, &timing, &buffer);
    CFRelease(videoInfo);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);

    self.currentFrame = frame;
    [self didOutputSampleBuffer:buffer];
    [self _updateFieldOfViewWithARFrame:frame];

    CFRelease(buffer);
}

- (void)session:(ARSession *)session didAddAnchors:(NSArray<ARAnchor *> *)anchors NS_AVAILABLE_IOS(11_0)
{
    for (ARAnchor *anchor in anchors) {
        if ([anchor isKindOfClass:[ARPlaneAnchor class]]) {
            SCLogVideoStreamerInfo(@"ARKit added plane anchor");
            return;
        }
    }
}

- (void)session:(ARSession *)session didFailWithError:(NSError *)error NS_AVAILABLE_IOS(11_0)
{
    SCLogVideoStreamerError(@"ARKit session failed with error: %@. Resetting", error);
    [session runWithConfiguration:[ARConfiguration sc_configurationForDevicePosition:_devicePosition]];
}

- (void)sessionWasInterrupted:(ARSession *)session NS_AVAILABLE_IOS(11_0)
{
    SCLogVideoStreamerWarning(@"ARKit session interrupted");
}

- (void)sessionInterruptionEnded:(ARSession *)session NS_AVAILABLE_IOS(11_0)
{
    SCLogVideoStreamerInfo(@"ARKit interruption ended");
}

#pragma mark - Private methods

- (void)_performCompletionHandlersForWaitUntilSampleBufferDisplayed
{
    for (NSArray *completion in _waitUntilSampleBufferDisplayedBlocks) {
        // Call the completion handlers.
        dispatch_async(completion[0], completion[1]);
    }
    [_waitUntilSampleBufferDisplayedBlocks removeAllObjects];
}

// This is the magic that ensures the VideoDataOutput will have the correct
// orientation.
- (void)_enableVideoMirrorForDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCLogVideoStreamerInfo(@"enable video mirror for device position:%lu", (unsigned long)devicePosition);
    AVCaptureConnection *connection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    connection.videoOrientation = _videoOrientation;
    if (devicePosition == SCManagedCaptureDevicePositionFront) {
        connection.videoMirrored = YES;
    }
}

- (void)_enableVideoStabilizationIfSupported
{
    SCTraceStart();
    if (!SCCameraTweaksEnableVideoStabilization()) {
        SCLogVideoStreamerWarning(@"SCCameraTweaksEnableVideoStabilization is NO, won't enable video stabilization");
        return;
    }

    AVCaptureConnection *videoConnection = [_videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    if (!videoConnection) {
        SCLogVideoStreamerError(@"cannot get videoConnection from videoDataOutput:%@", videoConnection);
        return;
    }
    // Set the video stabilization mode to auto. Default is off.
    if ([videoConnection isVideoStabilizationSupported]) {
        videoConnection.preferredVideoStabilizationMode = _videoStabilizationEnabledIfSupported
                                                              ? AVCaptureVideoStabilizationModeStandard
                                                              : AVCaptureVideoStabilizationModeOff;
        NSDictionary *params = @{ @"iOS8_Mode" : @(videoConnection.activeVideoStabilizationMode) };
        [[SCLogger sharedInstance] logEvent:@"VIDEO_STABILIZATION_MODE" parameters:params];
        SCLogVideoStreamerInfo(@"set video stabilization mode:%ld to videoConnection:%@",
                               (long)videoConnection.preferredVideoStabilizationMode, videoConnection);
    } else {
        SCLogVideoStreamerInfo(@"video stabilization isn't supported on videoConnection:%@", videoConnection);
    }
}

- (void)setVideoStabilizationEnabledIfSupported:(BOOL)videoStabilizationIfSupported
{
    SCLogVideoStreamerInfo(@"setVideoStabilizationEnabledIfSupported:%d", videoStabilizationIfSupported);
    _videoStabilizationEnabledIfSupported = videoStabilizationIfSupported;
    [self _enableVideoStabilizationIfSupported];
}

- (void)_updateFieldOfViewWithARFrame:(ARFrame *)frame NS_AVAILABLE_IOS(11_0)
{
    SC_GUARD_ELSE_RETURN(frame.camera);
    CGSize imageResolution = frame.camera.imageResolution;
    matrix_float3x3 intrinsics = frame.camera.intrinsics;
    float xFovDegrees = 2 * atan(imageResolution.width / (2 * intrinsics.columns[0][0])) * 180 / M_PI;
    if (_fieldOfView != xFovDegrees) {
        self.fieldOfView = xFovDegrees;
    }
}

- (NSString *)description
{
    return [self debugDescription];
}

- (NSString *)debugDescription
{
    NSDictionary *debugDict = @{
        @"_sampleBufferDisplayEnabled" : _sampleBufferDisplayEnabled ? @"Yes" : @"No",
        @"_videoStabilizationEnabledIfSupported" : _videoStabilizationEnabledIfSupported ? @"Yes" : @"No",
        @"_performingConfigurations" : _performingConfigurations ? @"Yes" : @"No",
        @"alwaysDiscardLateVideoFrames" : _videoDataOutput.alwaysDiscardsLateVideoFrames ? @"Yes" : @"No"
    };
    return [NSString sc_stringWithFormat:@"%@", debugDict];
}

@end
