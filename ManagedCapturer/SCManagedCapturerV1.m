//
//  SCManagedCapturer.m
//  Snapchat
//
//  Created by Liu Liu on 4/20/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedCapturerV1.h"
#import "SCManagedCapturerV1_Private.h"

#import "ARConfiguration+SCConfiguration.h"
#import "NSURL+Asset.h"
#import "SCBlackCameraDetector.h"
#import "SCBlackCameraNoOutputDetector.h"
#import "SCCameraTweaks.h"
#import "SCCaptureResource.h"
#import "SCCaptureSessionFixer.h"
#import "SCCaptureUninitializedState.h"
#import "SCCaptureWorker.h"
#import "SCCapturerToken.h"
#import "SCManagedAudioStreamer.h"
#import "SCManagedCaptureDevice+SCManagedCapturer.h"
#import "SCManagedCaptureDeviceDefaultZoomHandler.h"
#import "SCManagedCaptureDeviceHandler.h"
#import "SCManagedCaptureDeviceSubjectAreaHandler.h"
#import "SCManagedCapturePreviewLayerController.h"
#import "SCManagedCaptureSession.h"
#import "SCManagedCapturerARImageCaptureProvider.h"
#import "SCManagedCapturerGLViewManagerAPI.h"
#import "SCManagedCapturerLSAComponentTrackerAPI.h"
#import "SCManagedCapturerLensAPI.h"
#import "SCManagedCapturerListenerAnnouncer.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerSampleMetadata.h"
#import "SCManagedCapturerState.h"
#import "SCManagedCapturerStateBuilder.h"
#import "SCManagedDeviceCapacityAnalyzer.h"
#import "SCManagedDroppedFramesReporter.h"
#import "SCManagedFrameHealthChecker.h"
#import "SCManagedFrontFlashController.h"
#import "SCManagedStillImageCapturer.h"
#import "SCManagedStillImageCapturerHandler.h"
#import "SCManagedVideoARDataSource.h"
#import "SCManagedVideoCapturer.h"
#import "SCManagedVideoFileStreamer.h"
#import "SCManagedVideoFrameSampler.h"
#import "SCManagedVideoScanner.h"
#import "SCManagedVideoStreamReporter.h"
#import "SCManagedVideoStreamer.h"
#import "SCMetalUtils.h"
#import "SCProcessingPipeline.h"
#import "SCProcessingPipelineBuilder.h"
#import "SCScanConfiguration.h"
#import "SCSingleFrameStreamCapturer.h"
#import "SCSnapCreationTriggers.h"
#import "SCTimedTask.h"

#import <SCBase/SCAssignment.h>
#import <SCBase/SCLazyLoadingProxy.h>
#import <SCBatteryLogger/SCBatteryLogger.h>
#import <SCFoundation/NSData+Random.h>
#import <SCFoundation/NSError+Helpers.h>
#import <SCFoundation/NSString+SCFormat.h>
#import <SCFoundation/SCAppEnvironment.h>
#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>
#import <SCGhostToSnappable/SCGhostToSnappableSignal.h>
#import <SCImageProcess/SCImageProcessVideoPlaybackSession.h>
#import <SCLenses/SCLens.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger+Performance.h>
#import <SCUserTraceLogger/SCUserTraceLogger.h>

#import <Looksery/Looksery.h>

@import ARKit;

static NSUInteger const kSCManagedCapturerFixInconsistencyMaxRetriesWithCurrentSession = 22;
static CGFloat const kSCManagedCapturerFixInconsistencyARSessionDelayThreshold = 2;
static CGFloat const kSCManagedCapturerFixInconsistencyARSessionHungInitThreshold = 5;

static NSTimeInterval const kMinFixAVSessionRunningInterval = 1; // Interval to run _fixAVSessionIfNecessary
static NSTimeInterval const kMinFixSessionRuntimeErrorInterval =
    1; // Min interval that RuntimeError calls _startNewSession

static NSString *const kSCManagedCapturerErrorDomain = @"kSCManagedCapturerErrorDomain";

NSString *const kSCLensesTweaksDidChangeFileInput = @"kSCLensesTweaksDidChangeFileInput";

@implementation SCManagedCapturerV1 {
    // No ivars for CapturerV1 please, they should be in resource.
    SCCaptureResource *_captureResource;
}

+ (SCManagedCapturerV1 *)sharedInstance
{
    static dispatch_once_t onceToken;
    static SCManagedCapturerV1 *managedCapturerV1;
    dispatch_once(&onceToken, ^{
        managedCapturerV1 = [[SCManagedCapturerV1 alloc] init];
    });
    return managedCapturerV1;
}

- (instancetype)init
{
    SCTraceStart();
    SCAssertMainThread();
    SCCaptureResource *resource = [SCCaptureWorker generateCaptureResource];
    return [self initWithResource:resource];
}

- (instancetype)initWithResource:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    self = [super init];
    if (self) {
        // Assuming I am not in background. I can be more defensive here and fetch the app state.
        // But to avoid potential problems, won't do that until later.
        SCLogCapturerInfo(@"======================= cool startup =======================");
        // Initialization of capture resource should be done in worker to be shared between V1 and V2.
        _captureResource = resource;
        _captureResource.handleAVSessionStatusChange = @selector(_handleAVSessionStatusChange:);
        _captureResource.sessionRuntimeError = @selector(_sessionRuntimeError:);
        _captureResource.livenessConsistency = @selector(_livenessConsistency:);
        _captureResource.deviceSubjectAreaHandler =
            [[SCManagedCaptureDeviceSubjectAreaHandler alloc] initWithCaptureResource:_captureResource];
        _captureResource.snapCreationTriggers = [SCSnapCreationTriggers new];
        if (SCIsMasterBuild()) {
            // We call _sessionRuntimeError to reset _captureResource.videoDataSource if input changes
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(_sessionRuntimeError:)
                                                         name:kSCLensesTweaksDidChangeFileInput
                                                       object:nil];
        }
    }
    return self;
}

- (SCBlackCameraDetector *)blackCameraDetector
{
    return _captureResource.blackCameraDetector;
}

- (void)recreateAVCaptureSession
{
    SCTraceODPCompatibleStart(2);
    [self _startRunningWithNewCaptureSessionIfNecessary];
}

- (void)_handleAVSessionStatusChange:(NSDictionary *)change
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(!_captureResource.state.arSessionActive);
    SC_GUARD_ELSE_RETURN(!_captureResource.appInBackground);
    BOOL wasRunning = [change[NSKeyValueChangeOldKey] boolValue];
    BOOL isRunning = [change[NSKeyValueChangeNewKey] boolValue];
    SCLogCapturerInfo(@"avSession running status changed: %@ -> %@", wasRunning ? @"running" : @"stopped",
                      isRunning ? @"running" : @"stopped");

    [_captureResource.blackCameraDetector sessionDidChangeIsRunning:isRunning];

    if (_captureResource.isRecreateSessionFixScheduled) {
        SCLogCapturerInfo(@"Scheduled AVCaptureSession recreation, return");
        return;
    }

    if (wasRunning != isRunning) {
        runOnMainThreadAsynchronously(^{
            if (isRunning) {
                [_captureResource.announcer managedCapturer:self didStartRunning:_captureResource.state];
            } else {
                [_captureResource.announcer managedCapturer:self didStopRunning:_captureResource.state];
            }
        });
    }

    if (!isRunning) {
        [_captureResource.queuePerformer perform:^{
            [self _fixAVSessionIfNecessary];
        }];
    } else {
        if (!SCDeviceSupportsMetal()) {
            [self _fixNonMetalSessionPreviewInconsistency];
        }
    }
}

- (void)_fixAVSessionIfNecessary
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    SC_GUARD_ELSE_RETURN(!_captureResource.appInBackground);
    SC_GUARD_ELSE_RETURN(_captureResource.status == SCManagedCapturerStatusRunning);
    [[SCLogger sharedInstance] logStepToEvent:kSCCameraFixAVCaptureSession
                                     uniqueId:@""
                                     stepName:@"startConsistencyCheckAndFix"];

    NSTimeInterval timeNow = [NSDate timeIntervalSinceReferenceDate];
    if (timeNow - _captureResource.lastFixSessionTimestamp < kMinFixAVSessionRunningInterval) {
        SCLogCoreCameraInfo(@"Fixing session in less than %f, skip", kMinFixAVSessionRunningInterval);
        return;
    }
    _captureResource.lastFixSessionTimestamp = timeNow;

    if (!_captureResource.managedSession.isRunning) {
        SCTraceStartSection("Fix AVSession")
        {
            _captureResource.numRetriesFixAVCaptureSessionWithCurrentSession++;
            SCGhostToSnappableSignalCameraFixInconsistency();
            if (_captureResource.numRetriesFixAVCaptureSessionWithCurrentSession <=
                kSCManagedCapturerFixInconsistencyARSessionDelayThreshold) {
                SCLogCapturerInfo(@"Fixing AVSession");
                [_captureResource.managedSession startRunning];
                SCLogCapturerInfo(@"Fixed AVSession, success : %@", @(_captureResource.managedSession.isRunning));
                [[SCLogger sharedInstance] logStepToEvent:kSCCameraFixAVCaptureSession
                                                 uniqueId:@""
                                                 stepName:@"finishCaptureSessionFix"];
            } else {
                // start running with new capture session if the inconsistency fixing not succeeds
                SCLogCapturerInfo(@"*** Recreate and run new capture session to fix the inconsistency ***");
                [self _startRunningWithNewCaptureSessionIfNecessary];
                [[SCLogger sharedInstance] logStepToEvent:kSCCameraFixAVCaptureSession
                                                 uniqueId:@""
                                                 stepName:@"finishNewCaptureSessionCreation"];
            }
        }
        SCTraceEndSection();
        [[SCLogger sharedInstance]
            logTimedEventEnd:kSCCameraFixAVCaptureSession
                    uniqueId:@""
                  parameters:@{
                      @"success" : @(_captureResource.managedSession.isRunning),
                      @"count" : @(_captureResource.numRetriesFixAVCaptureSessionWithCurrentSession)
                  }];
    } else {
        _captureResource.numRetriesFixAVCaptureSessionWithCurrentSession = 0;
        [[SCLogger sharedInstance] cancelLogTimedEvent:kSCCameraFixAVCaptureSession uniqueId:@""];
    }
    if (_captureResource.managedSession.isRunning) {
        // If it is fixed, we signal received the first frame.
        SCGhostToSnappableSignalDidReceiveFirstPreviewFrame();

        // For non-metal preview render, we need to make sure preview is not hidden
        if (!SCDeviceSupportsMetal()) {
            [self _fixNonMetalSessionPreviewInconsistency];
        }
        runOnMainThreadAsynchronously(^{
            [_captureResource.announcer managedCapturer:self didStartRunning:_captureResource.state];
            // To approximate this did render timer, it is not accurate.
            SCGhostToSnappableSignalDidRenderFirstPreviewFrame(CACurrentMediaTime());
        });
    } else {
        [_captureResource.queuePerformer perform:^{
            [self _fixAVSessionIfNecessary];
        }
                                           after:1];
    }

    [_captureResource.blackCameraDetector sessionDidChangeIsRunning:_captureResource.managedSession.isRunning];
}

- (void)_fixNonMetalSessionPreviewInconsistency
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(_captureResource.status == SCManagedCapturerStatusRunning);
    if ((!_captureResource.videoPreviewLayer.hidden) != _captureResource.managedSession.isRunning) {
        SCTraceStartSection("Fix non-Metal VideoPreviewLayer");
        {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            [SCCaptureWorker setupVideoPreviewLayer:_captureResource];
            [CATransaction commit];
        }
        SCTraceEndSection();
    }
}

- (SCCaptureResource *)captureResource
{
    SCTraceODPCompatibleStart(2);
    return _captureResource;
}

- (id<SCManagedCapturerLensAPI>)lensProcessingCore
{
    SCTraceODPCompatibleStart(2);
    @weakify(self);
    return (id<SCManagedCapturerLensAPI>)[[SCLazyLoadingProxy alloc] initWithInitializationBlock:^id {
        @strongify(self);
        SCReportErrorIf(self.captureResource.state.lensProcessorReady, @"[Lenses] Lens processing core is not ready");
        return self.captureResource.lensProcessingCore;
    }];
}

- (SCVideoCaptureSessionInfo)activeSession
{
    SCTraceODPCompatibleStart(2);
    return [SCCaptureWorker activeSession:_captureResource];
}

- (BOOL)isLensApplied
{
    SCTraceODPCompatibleStart(2);
    return [SCCaptureWorker isLensApplied:_captureResource];
}

- (BOOL)isVideoMirrored
{
    SCTraceODPCompatibleStart(2);
    return [SCCaptureWorker isVideoMirrored:_captureResource];
}

#pragma mark - Setup, Start & Stop

- (void)_updateHRSIEnabled
{
    SCTraceODPCompatibleStart(2);
    // Since night mode is low-res, we set high resolution still image output when night mode is enabled
    // SoftwareZoom requires higher resolution image to get better zooming result too.
    // We also want a higher resolution on newer devices
    BOOL is1080pSupported = [SCManagedCaptureDevice is1080pSupported];
    BOOL shouldHRSIEnabled =
        (_captureResource.device.isNightModeActive || _captureResource.device.softwareZoom || is1080pSupported);
    SCLogCapturerInfo(@"Setting HRSIEnabled to: %d. isNightModeActive:%d softwareZoom:%d is1080pSupported:%d",
                      shouldHRSIEnabled, _captureResource.device.isNightModeActive,
                      _captureResource.device.softwareZoom, is1080pSupported);
    [_captureResource.stillImageCapturer setHighResolutionStillImageOutputEnabled:shouldHRSIEnabled];
}

- (void)_updateStillImageStabilizationEnabled
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Enabling still image stabilization");
    [_captureResource.stillImageCapturer enableStillImageStabilization];
}

- (void)setupWithDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                            completionHandler:(dispatch_block_t)completionHandler
                                      context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Setting up with devicePosition:%lu", (unsigned long)devicePosition);
    SCTraceResumeToken token = SCTraceCapture();
    [[SCManagedCapturePreviewLayerController sharedInstance] setupPreviewLayer];
    [_captureResource.queuePerformer perform:^{
        SCTraceResume(token);
        [self setupWithDevicePosition:devicePosition completionHandler:completionHandler];
    }];
}

- (void)setupWithDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
              completionHandler:(dispatch_block_t)completionHandler
{
    SCTraceODPCompatibleStart(2);
    SCAssertPerformer(_captureResource.queuePerformer);
    [SCCaptureWorker setupWithCaptureResource:_captureResource devicePosition:devicePosition];

    [self addListener:_captureResource.stillImageCapturer];
    [self addListener:_captureResource.blackCameraDetector.blackCameraNoOutputDetector];
    [self addListener:_captureResource.lensProcessingCore];

    [self _updateHRSIEnabled];
    [self _updateStillImageStabilizationEnabled];

    [SCCaptureWorker updateLensesFieldOfViewTracking:_captureResource];

    if (!SCDeviceSupportsMetal()) {
        [SCCaptureWorker makeVideoPreviewLayer:_captureResource];
    }

    // I need to do this setup now. Thus, it is off the main thread. This also means my preview layer controller is
    // entangled with the capturer.
    [[SCManagedCapturePreviewLayerController sharedInstance] setupRenderPipeline];
    [[SCManagedCapturePreviewLayerController sharedInstance] setManagedCapturer:self];
    _captureResource.status = SCManagedCapturerStatusReady;

    SCManagedCapturerState *state = [_captureResource.state copy];
    AVCaptureVideoPreviewLayer *videoPreviewLayer = _captureResource.videoPreviewLayer;
    runOnMainThreadAsynchronously(^{
        SCLogCapturerInfo(@"Did setup with devicePosition:%lu", (unsigned long)devicePosition);
        [_captureResource.announcer managedCapturer:self didChangeState:state];
        [_captureResource.announcer managedCapturer:self didChangeCaptureDevicePosition:state];
        if (!SCDeviceSupportsMetal()) {
            [_captureResource.announcer managedCapturer:self didChangeVideoPreviewLayer:videoPreviewLayer];
        }
        if (completionHandler) {
            completionHandler();
        }
    });
}

- (void)addSampleBufferDisplayController:(id<SCManagedSampleBufferDisplayController>)sampleBufferDisplayController
                                 context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        _captureResource.sampleBufferDisplayController = sampleBufferDisplayController;
        [_captureResource.videoDataSource addSampleBufferDisplayController:sampleBufferDisplayController];
    }];
}

- (SCCapturerToken *)startRunningAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                             context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [[SCLogger sharedInstance] updateLogTimedEventStart:kSCCameraMetricsOpen uniqueId:@""];
    SCCapturerToken *token = [[SCCapturerToken alloc] initWithIdentifier:context];
    SCLogCapturerInfo(@"startRunningAsynchronouslyWithCompletionHandler called. token: %@", token);
    [_captureResource.queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [SCCaptureWorker startRunningWithCaptureResource:_captureResource
                                                   token:token
                                       completionHandler:completionHandler];
        // After startRunning, we need to make sure _fixAVSessionIfNecessary start running.
        // The problem: with the new KVO fix strategy, it may happen that AVCaptureSession is in stopped state, thus no
        // KVO callback is triggered.
        // And calling startRunningAsynchronouslyWithCompletionHandler has no effect because SCManagedCapturerStatus is
        // in SCManagedCapturerStatusRunning state
        [self _fixAVSessionIfNecessary];
    }];
    return token;
}

- (BOOL)stopRunningWithCaptureToken:(SCCapturerToken *)token
                  completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                            context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertPerformer(_captureResource.queuePerformer);
    SCLogCapturerInfo(@"Stop running. token:%@ context:%@", token, context);
    return [SCCaptureWorker stopRunningWithCaptureResource:_captureResource
                                                     token:token
                                         completionHandler:completionHandler];
}

- (void)stopRunningAsynchronously:(SCCapturerToken *)token
                completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                          context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Stop running asynchronously. token:%@ context:%@", token, context);
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_captureResource.queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [SCCaptureWorker stopRunningWithCaptureResource:_captureResource
                                                  token:token
                                      completionHandler:completionHandler];
    }];
}

- (void)stopRunningAsynchronously:(SCCapturerToken *)token
                completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                            after:(NSTimeInterval)delay
                          context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Stop running asynchronously. token:%@ delay:%f", token, delay);
    NSTimeInterval startTime = CACurrentMediaTime();
    [_captureResource.queuePerformer perform:^{
        NSTimeInterval elapsedTime = CACurrentMediaTime() - startTime;
        [_captureResource.queuePerformer perform:^{
            SCTraceStart();
            // If we haven't started a new running sequence yet, stop running now
            [SCCaptureWorker stopRunningWithCaptureResource:_captureResource
                                                      token:token
                                          completionHandler:completionHandler];
        }
                                           after:MAX(delay - elapsedTime, 0)];
    }];
}

- (void)startStreamingAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                  context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Start streaming asynchronously");
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        [SCCaptureWorker startStreaming:_captureResource];
        if (completionHandler) {
            runOnMainThreadAsynchronously(completionHandler);
        }
    }];
}

#pragma mark - Recording / Capture

- (void)captureStillImageAsynchronouslyWithAspectRatio:(CGFloat)aspectRatio
                                      captureSessionID:(NSString *)captureSessionID
                                     completionHandler:
                                         (sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                                               context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        [SCCaptureWorker captureStillImageWithCaptureResource:_captureResource
                                                  aspectRatio:aspectRatio
                                             captureSessionID:captureSessionID
                                       shouldCaptureFromVideo:[self _shouldCaptureImageFromVideo]
                                            completionHandler:completionHandler
                                                      context:context];
    }];
}

- (void)captureSingleVideoFrameAsynchronouslyWithCompletionHandler:
            (sc_managed_capturer_capture_video_frame_completion_handler_t)completionHandler
                                                           context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        SCLogCapturerInfo(@"Start capturing single video frame");
        _captureResource.frameCap = [[SCSingleFrameStreamCapturer alloc] initWithCompletion:^void(UIImage *image) {
            [_captureResource.queuePerformer perform:^{
                [_captureResource.videoDataSource removeListener:_captureResource.frameCap];
                _captureResource.frameCap = nil;
            }];
            runOnMainThreadAsynchronously(^{
                [_captureResource.device setTorchActive:NO];
                SCLogCapturerInfo(@"End capturing single video frame");
                completionHandler(image);
            });
        }];

        BOOL waitForTorch = NO;
        if (!_captureResource.state.torchActive) {
            if (_captureResource.state.flashActive) {
                waitForTorch = YES;
                [_captureResource.device setTorchActive:YES];
            }
        }
        [_captureResource.queuePerformer perform:^{
            [_captureResource.videoDataSource addListener:_captureResource.frameCap];
            [SCCaptureWorker startStreaming:_captureResource];
        }
                                           after:(waitForTorch ? 0.5 : 0)];

    }];
}

- (void)prepareForRecordingAsynchronouslyWithContext:(NSString *)context
                                  audioConfiguration:(SCAudioConfiguration *)configuration
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCLogCapturerInfo(@"prepare for recording");
        [_captureResource.videoCapturer prepareForRecordingWithAudioConfiguration:configuration];
    }];
}

- (void)startRecordingAsynchronouslyWithOutputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                                    audioConfiguration:(SCAudioConfiguration *)configuration
                                           maxDuration:(NSTimeInterval)maxDuration
                                               fileURL:(NSURL *)fileURL
                                      captureSessionID:(NSString *)captureSessionID
                                     completionHandler:
                                         (sc_managed_capturer_start_recording_completion_handler_t)completionHandler
                                               context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        [SCCaptureWorker startRecordingWithCaptureResource:_captureResource
                                            outputSettings:outputSettings
                                        audioConfiguration:configuration
                                               maxDuration:maxDuration
                                                   fileURL:fileURL
                                          captureSessionID:captureSessionID
                                         completionHandler:completionHandler];
    }];
}

- (void)stopRecordingAsynchronouslyWithContext:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        [SCCaptureWorker stopRecordingWithCaptureResource:_captureResource];
    }];
}

- (void)cancelRecordingAsynchronouslyWithContext:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        [SCCaptureWorker cancelRecordingWithCaptureResource:_captureResource];
    }];
}

- (void)startScanAsynchronouslyWithScanConfiguration:(SCScanConfiguration *)configuration context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        [SCCaptureWorker startScanWithScanConfiguration:configuration resource:_captureResource];
    }];
}

- (void)stopScanAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        [SCCaptureWorker stopScanWithCompletionHandler:completionHandler resource:_captureResource];
    }];
}

- (void)sampleFrameWithCompletionHandler:(void (^)(UIImage *frame, CMTime presentationTime))completionHandler
                                 context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    // Previously _captureResource.videoFrameSampler was conditionally created when setting up, but if this method is
    // called it is a
    // safe assumption the client wants it to run instead of failing silently, so always create
    // _captureResource.videoFrameSampler
    if (!_captureResource.videoFrameSampler) {
        _captureResource.videoFrameSampler = [SCManagedVideoFrameSampler new];
        [_captureResource.announcer addListener:_captureResource.videoFrameSampler];
    }
    SCLogCapturerInfo(@"Sampling next frame");
    [_captureResource.videoFrameSampler sampleNextFrame:completionHandler];
}

- (void)addTimedTask:(SCTimedTask *)task context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Adding timed task:%@", task);
    [_captureResource.queuePerformer perform:^{
        [_captureResource.videoCapturer addTimedTask:task];
    }];
}

- (void)clearTimedTasksWithContext:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        [_captureResource.videoCapturer clearTimedTasks];
    }];
}

#pragma mark - Utilities

- (void)convertViewCoordinates:(CGPoint)viewCoordinates
             completionHandler:(sc_managed_capturer_convert_view_coordniates_completion_handler_t)completionHandler
                       context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssert(completionHandler, @"completionHandler shouldn't be nil");
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (SCDeviceSupportsMetal()) {
            CGSize viewSize = [UIScreen mainScreen].fixedCoordinateSpace.bounds.size;
            CGPoint pointOfInterest =
                [_captureResource.device convertViewCoordinates:viewCoordinates
                                                       viewSize:viewSize
                                                   videoGravity:AVLayerVideoGravityResizeAspectFill];
            runOnMainThreadAsynchronously(^{
                completionHandler(pointOfInterest);
            });
        } else {
            CGSize viewSize = _captureResource.videoPreviewLayer.bounds.size;
            CGPoint pointOfInterest =
                [_captureResource.device convertViewCoordinates:viewCoordinates
                                                       viewSize:viewSize
                                                   videoGravity:_captureResource.videoPreviewLayer.videoGravity];
            runOnMainThreadAsynchronously(^{
                completionHandler(pointOfInterest);
            });
        }
    }];
}

- (void)detectLensCategoryOnNextFrame:(CGPoint)point
                               lenses:(NSArray<SCLens *> *)lenses
                           completion:(sc_managed_lenses_processor_category_point_completion_handler_t)completion
                              context:(NSString *)context

{
    SCTraceODPCompatibleStart(2);
    SCAssert(completion, @"completionHandler shouldn't be nil");
    SCAssertMainThread();
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        SCLogCapturerInfo(@"Detecting lens category on next frame. point:%@, lenses:%@", NSStringFromCGPoint(point),
                          [lenses valueForKey:NSStringFromSelector(@selector(lensId))]);
        [_captureResource.lensProcessingCore
            detectLensCategoryOnNextFrame:point
                         videoOrientation:_captureResource.videoDataSource.videoOrientation
                                   lenses:lenses
                               completion:^(SCLensCategory *_Nullable category, NSInteger categoriesCount) {
                                   runOnMainThreadAsynchronously(^{
                                       if (completion) {
                                           completion(category, categoriesCount);
                                       }
                                   });
                               }];
    }];
}

#pragma mark - Configurations

- (void)setDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                      completionHandler:(dispatch_block_t)completionHandler
                                context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Setting device position asynchronously to: %lu", (unsigned long)devicePosition);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        BOOL devicePositionChanged = NO;
        BOOL nightModeChanged = NO;
        BOOL portraitModeChanged = NO;
        BOOL zoomFactorChanged = NO;
        BOOL flashSupportedOrTorchSupportedChanged = NO;
        SCManagedCapturerState *state = [_captureResource.state copy];
        if (_captureResource.state.devicePosition != devicePosition) {
            SCManagedCaptureDevice *device = [SCManagedCaptureDevice deviceWithPosition:devicePosition];
            if (device) {
                if (!device.delegate) {
                    device.delegate = _captureResource.captureDeviceHandler;
                }

                SCManagedCaptureDevice *prevDevice = _captureResource.device;
                [SCCaptureWorker turnARSessionOff:_captureResource];
                BOOL isStreaming = _captureResource.videoDataSource.isStreaming;
                if (!SCDeviceSupportsMetal()) {
                    if (isStreaming) {
                        [_captureResource.videoDataSource stopStreaming];
                    }
                }
                SCLogCapturerInfo(@"Set device position beginConfiguration");
                [_captureResource.videoDataSource beginConfiguration];
                [_captureResource.managedSession beginConfiguration];
                // Turn off flash for the current device in case it is active
                [_captureResource.device setTorchActive:NO];
                if (_captureResource.state.devicePosition == SCManagedCaptureDevicePositionFront) {
                    _captureResource.frontFlashController.torchActive = NO;
                }
                [_captureResource.deviceCapacityAnalyzer removeFocusListener];
                [_captureResource.device removeDeviceAsInput:_captureResource.managedSession.avSession];
                _captureResource.device = device;
                BOOL deviceSet = [_captureResource.device setDeviceAsInput:_captureResource.managedSession.avSession];
                // If we are toggling while recording, set the night mode back to not
                // active
                if (_captureResource.videoRecording) {
                    [self _setNightModeActive:NO];
                }
                // Sync night mode, torch and flash state with the current device
                devicePositionChanged = (_captureResource.state.devicePosition != devicePosition);
                nightModeChanged =
                    (_captureResource.state.isNightModeActive != _captureResource.device.isNightModeActive);
                portraitModeChanged =
                    devicePositionChanged &&
                    (devicePosition == SCManagedCaptureDevicePositionBackDualCamera ||
                     _captureResource.state.devicePosition == SCManagedCaptureDevicePositionBackDualCamera);
                zoomFactorChanged = (_captureResource.state.zoomFactor != _captureResource.device.zoomFactor);
                if (zoomFactorChanged && _captureResource.device.softwareZoom) {
                    [SCCaptureWorker softwareZoomWithDevice:_captureResource.device resource:_captureResource];
                }
                if (_captureResource.state.flashActive != _captureResource.device.flashActive) {
                    // preserve flashActive across devices
                    _captureResource.device.flashActive = _captureResource.state.flashActive;
                }
                if (_captureResource.state.liveVideoStreaming != device.liveVideoStreamingActive) {
                    // preserve liveVideoStreaming state across devices
                    [_captureResource.device setLiveVideoStreaming:_captureResource.state.liveVideoStreaming
                                                           session:_captureResource.managedSession.avSession];
                }
                if (devicePosition == SCManagedCaptureDevicePositionBackDualCamera &&
                    _captureResource.state.isNightModeActive != _captureResource.device.isNightModeActive) {
                    // preserve nightMode when switching from back camera to back dual camera
                    [self _setNightModeActive:_captureResource.state.isNightModeActive];
                }

                flashSupportedOrTorchSupportedChanged =
                    (_captureResource.state.flashSupported != _captureResource.device.isFlashSupported ||
                     _captureResource.state.torchSupported != _captureResource.device.isTorchSupported);
                SCLogCapturerInfo(@"Set device position: %lu -> %lu, night mode: %d -> %d, zoom "
                                  @"factor: %f -> %f, flash supported: %d -> %d, torch supported: %d -> %d",
                                  (unsigned long)_captureResource.state.devicePosition, (unsigned long)devicePosition,
                                  _captureResource.state.isNightModeActive, _captureResource.device.isNightModeActive,
                                  _captureResource.state.zoomFactor, _captureResource.device.zoomFactor,
                                  _captureResource.state.flashSupported, _captureResource.device.isFlashSupported,
                                  _captureResource.state.torchSupported, _captureResource.device.isTorchSupported);
                _captureResource.state = [[[[[[[[SCManagedCapturerStateBuilder
                    withManagedCapturerState:_captureResource.state] setDevicePosition:devicePosition]
                    setIsNightModeActive:_captureResource.device.isNightModeActive]
                    setZoomFactor:_captureResource.device.zoomFactor]
                    setFlashSupported:_captureResource.device.isFlashSupported]
                    setTorchSupported:_captureResource.device.isTorchSupported]
                    setIsPortraitModeActive:devicePosition == SCManagedCaptureDevicePositionBackDualCamera] build];
                [self _updateHRSIEnabled];
                [self _updateStillImageStabilizationEnabled];
                // This needs to be done after we have finished configure everything
                // for session otherwise we
                // may set it up without hooking up the video input yet, and will set
                // wrong parameter for the
                // output.
                [_captureResource.videoDataSource setDevicePosition:devicePosition];
                if (@available(ios 11.0, *)) {
                    if (portraitModeChanged) {
                        [_captureResource.videoDataSource
                            setDepthCaptureEnabled:_captureResource.state.isPortraitModeActive];
                        [_captureResource.device setCaptureDepthData:_captureResource.state.isPortraitModeActive
                                                             session:_captureResource.managedSession.avSession];
                        [_captureResource.stillImageCapturer
                            setPortraitModeCaptureEnabled:_captureResource.state.isPortraitModeActive];
                        if (_captureResource.state.isPortraitModeActive) {
                            SCProcessingPipelineBuilder *processingPipelineBuilder =
                                [[SCProcessingPipelineBuilder alloc] init];
                            processingPipelineBuilder.portraitModeEnabled = YES;
                            SCProcessingPipeline *pipeline = [processingPipelineBuilder build];
                            SCLogCapturerInfo(@"Adding processing pipeline:%@", pipeline);
                            [_captureResource.videoDataSource addProcessingPipeline:pipeline];
                        } else {
                            [_captureResource.videoDataSource removeProcessingPipeline];
                        }
                    }
                }
                [_captureResource.deviceCapacityAnalyzer setAsFocusListenerForDevice:_captureResource.device];

                [SCCaptureWorker updateLensesFieldOfViewTracking:_captureResource];
                [_captureResource.managedSession commitConfiguration];
                [_captureResource.videoDataSource commitConfiguration];

                // Checks if the flash is activated and if so switches the flash along
                // with the camera view. Setting device's torch mode has to be called after -[AVCaptureSession
                // commitConfiguration], otherwise flash may be not working, especially for iPhone 8/8 Plus.
                if (_captureResource.state.torchActive ||
                    (_captureResource.state.flashActive && _captureResource.videoRecording)) {
                    [_captureResource.device setTorchActive:YES];
                    if (devicePosition == SCManagedCaptureDevicePositionFront) {
                        _captureResource.frontFlashController.torchActive = YES;
                    }
                }

                SCLogCapturerInfo(@"Set device position commitConfiguration");
                [_captureResource.droppedFramesReporter didChangeCaptureDevicePosition];
                if (!SCDeviceSupportsMetal()) {
                    if (isStreaming) {
                        [SCCaptureWorker startStreaming:_captureResource];
                    }
                }
                NSArray *inputs = _captureResource.managedSession.avSession.inputs;
                if (!deviceSet) {
                    [self _logFailureSetDevicePositionFrom:_captureResource.state.devicePosition
                                                        to:devicePosition
                                                    reason:@"setDeviceForInput failed"];
                } else if (inputs.count == 0) {
                    [self _logFailureSetDevicePositionFrom:_captureResource.state.devicePosition
                                                        to:devicePosition
                                                    reason:@"no input"];
                } else if (inputs.count > 1) {
                    [self
                        _logFailureSetDevicePositionFrom:_captureResource.state.devicePosition
                                                      to:devicePosition
                                                  reason:[NSString sc_stringWithFormat:@"multiple inputs: %@", inputs]];
                } else {
                    AVCaptureDeviceInput *input = [inputs firstObject];
                    AVCaptureDevice *resultDevice = input.device;
                    if (resultDevice == prevDevice.device) {
                        [self _logFailureSetDevicePositionFrom:_captureResource.state.devicePosition
                                                            to:devicePosition
                                                        reason:@"stayed on previous device"];
                    } else if (resultDevice != _captureResource.device.device) {
                        [self
                            _logFailureSetDevicePositionFrom:_captureResource.state.devicePosition
                                                          to:devicePosition
                                                      reason:[NSString sc_stringWithFormat:@"unknown input device: %@",
                                                                                           resultDevice]];
                    }
                }
            } else {
                [self _logFailureSetDevicePositionFrom:_captureResource.state.devicePosition
                                                    to:devicePosition
                                                reason:@"no device"];
            }
        } else {
            SCLogCapturerInfo(@"Device position did not change");
            if (_captureResource.device.position != _captureResource.state.devicePosition) {
                [self _logFailureSetDevicePositionFrom:state.devicePosition
                                                    to:devicePosition
                                                reason:@"state position set incorrectly"];
            }
        }
        BOOL stateChanged = ![_captureResource.state isEqual:state];
        state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            if (stateChanged) {
                [_captureResource.announcer managedCapturer:self didChangeState:state];
            }
            if (devicePositionChanged) {
                [_captureResource.announcer managedCapturer:self didChangeCaptureDevicePosition:state];
            }
            if (nightModeChanged) {
                [_captureResource.announcer managedCapturer:self didChangeNightModeActive:state];
            }
            if (portraitModeChanged) {
                [_captureResource.announcer managedCapturer:self didChangePortraitModeActive:state];
            }
            if (zoomFactorChanged) {
                [_captureResource.announcer managedCapturer:self didChangeZoomFactor:state];
            }
            if (flashSupportedOrTorchSupportedChanged) {
                [_captureResource.announcer managedCapturer:self didChangeFlashSupportedAndTorchSupported:state];
            }
            if (completionHandler) {
                completionHandler();
            }
        });
    }];
}

- (void)_logFailureSetDevicePositionFrom:(SCManagedCaptureDevicePosition)start
                                      to:(SCManagedCaptureDevicePosition)end
                                  reason:(NSString *)reason
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Device position change failed: %@", reason);
    [[SCLogger sharedInstance] logEvent:kSCCameraMetricsCameraFlipFailure
                             parameters:@{
                                 @"start" : @(start),
                                 @"end" : @(end),
                                 @"reason" : reason,
                             }];
}

- (void)setFlashActive:(BOOL)flashActive
     completionHandler:(dispatch_block_t)completionHandler
               context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        BOOL flashActiveOrFrontFlashEnabledChanged = NO;
        if (_captureResource.state.flashActive != flashActive) {
            [_captureResource.device setFlashActive:flashActive];
            SCLogCapturerInfo(@"Set flash active: %d -> %d", _captureResource.state.flashActive, flashActive);
            _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
                setFlashActive:flashActive] build];
            flashActiveOrFrontFlashEnabledChanged = YES;
        }
        SCManagedCapturerState *state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            if (flashActiveOrFrontFlashEnabledChanged) {
                [_captureResource.announcer managedCapturer:self didChangeState:state];
                [_captureResource.announcer managedCapturer:self didChangeFlashActive:state];
            }
            if (completionHandler) {
                completionHandler();
            }
        });
    }];
}

- (void)setLensesActive:(BOOL)lensesActive
      completionHandler:(dispatch_block_t)completionHandler
                context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [self _setLensesActive:lensesActive
        liveVideoStreaming:NO
             filterFactory:nil
         completionHandler:completionHandler
                   context:context];
}

- (void)setLensesActive:(BOOL)lensesActive
          filterFactory:(SCLookseryFilterFactory *)filterFactory
      completionHandler:(dispatch_block_t)completionHandler
                context:(NSString *)context
{
    [self _setLensesActive:lensesActive
        liveVideoStreaming:NO
             filterFactory:filterFactory
         completionHandler:completionHandler
                   context:context];
}

- (void)setLensesInTalkActive:(BOOL)lensesActive
            completionHandler:(dispatch_block_t)completionHandler
                      context:(NSString *)context
{
    // Talk requires liveVideoStreaming to be turned on
    BOOL liveVideoStreaming = lensesActive;

    dispatch_block_t activationBlock = ^{
        [self _setLensesActive:lensesActive
            liveVideoStreaming:liveVideoStreaming
                 filterFactory:nil
             completionHandler:completionHandler
                       context:context];
    };

    @weakify(self);
    [_captureResource.queuePerformer perform:^{
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        // If lenses are enabled in TV3 and it was enabled not from TV3. We have to turn off lenses off at first.
        BOOL shouldTurnOffBeforeActivation = liveVideoStreaming && !self->_captureResource.state.liveVideoStreaming &&
                                             self->_captureResource.state.lensesActive;
        if (shouldTurnOffBeforeActivation) {
            [self _setLensesActive:NO
                liveVideoStreaming:NO
                     filterFactory:nil
                 completionHandler:activationBlock
                           context:context];
        } else {
            activationBlock();
        }
    }];
}

- (void)_setLensesActive:(BOOL)lensesActive
      liveVideoStreaming:(BOOL)liveVideoStreaming
           filterFactory:(SCLookseryFilterFactory *)filterFactory
       completionHandler:(dispatch_block_t)completionHandler
                 context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Setting lenses active to: %d", lensesActive);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        BOOL lensesActiveChanged = NO;
        if (_captureResource.state.lensesActive != lensesActive) {
            SCLogCapturerInfo(@"Set lenses active: %d -> %d", _captureResource.state.lensesActive, lensesActive);
            _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
                setLensesActive:lensesActive] build];

            // Update capturer settings(orientation and resolution) after changing state, because
            // _setLiveVideoStreaming logic is depends on it
            [self _setLiveVideoStreaming:liveVideoStreaming];

            [SCCaptureWorker turnARSessionOff:_captureResource];

            // Only enable sample buffer display when lenses is not active.
            [_captureResource.videoDataSource setSampleBufferDisplayEnabled:!lensesActive];
            [_captureResource.debugInfoDict setObject:!lensesActive ? @"True" : @"False"
                                               forKey:@"sampleBufferDisplayEnabled"];

            lensesActiveChanged = YES;
            [_captureResource.lensProcessingCore setAspectRatio:_captureResource.state.liveVideoStreaming];
            [_captureResource.lensProcessingCore setLensesActive:_captureResource.state.lensesActive
                                                videoOrientation:_captureResource.videoDataSource.videoOrientation
                                                   filterFactory:filterFactory];
            BOOL modifySource = _captureResource.state.liveVideoStreaming || _captureResource.videoRecording;
            [_captureResource.lensProcessingCore setModifySource:modifySource];
            [_captureResource.lensProcessingCore setShouldMuteAllSounds:_captureResource.state.liveVideoStreaming];
            if (_captureResource.fileInputDecider.shouldProcessFileInput) {
                [_captureResource.lensProcessingCore setLensesActive:YES
                                                    videoOrientation:_captureResource.videoDataSource.videoOrientation
                                                       filterFactory:filterFactory];
            }
            [_captureResource.videoDataSource
                setVideoStabilizationEnabledIfSupported:!_captureResource.state.lensesActive];

            if (SCIsMasterBuild()) {
                // Check that connection configuration is correct
                if (_captureResource.state.lensesActive &&
                    _captureResource.state.devicePosition == SCManagedCaptureDevicePositionFront) {
                    for (AVCaptureOutput *output in _captureResource.managedSession.avSession.outputs) {
                        if ([output isKindOfClass:[AVCaptureVideoDataOutput class]]) {
                            AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
                            SCAssert(connection.videoMirrored &&
                                             connection.videoOrientation == !_captureResource.state.liveVideoStreaming
                                         ? AVCaptureVideoOrientationLandscapeRight
                                         : AVCaptureVideoOrientationPortrait,
                                     @"Connection configuration is not correct");
                        }
                    }
                }
            }
        }
        dispatch_block_t viewChangeHandler = ^{
            SCManagedCapturerState *state = [_captureResource.state copy]; // update to latest state always
            runOnMainThreadAsynchronously(^{
                [_captureResource.announcer managedCapturer:self didChangeState:state];
                [_captureResource.announcer managedCapturer:self didChangeLensesActive:state];
                [_captureResource.videoPreviewGLViewManager setLensesActive:state.lensesActive];
                if (completionHandler) {
                    completionHandler();
                }
            });
        };
        if (lensesActiveChanged && !lensesActive && SCDeviceSupportsMetal()) {
            // If we are turning off lenses and have sample buffer display on.
            // We need to wait until new frame presented in sample buffer before
            // dismiss the Lenses' OpenGL view.
            [_captureResource.videoDataSource waitUntilSampleBufferDisplayed:_captureResource.queuePerformer.queue
                                                           completionHandler:viewChangeHandler];
        } else {
            viewChangeHandler();
        }
    }];
}

- (void)_setLiveVideoStreaming:(BOOL)liveVideoStreaming
{
    SCAssertPerformer(_captureResource.queuePerformer);
    BOOL enableLiveVideoStreaming = liveVideoStreaming;
    if (!_captureResource.state.lensesActive && liveVideoStreaming) {
        SCLogLensesError(@"LiveVideoStreaming is not allowed when lenses are turned off");
        enableLiveVideoStreaming = NO;
    }
    SC_GUARD_ELSE_RETURN(enableLiveVideoStreaming != _captureResource.state.liveVideoStreaming);

    // We will disable blackCameraNoOutputDetector if in live video streaming
    // In case there is some black camera when doing video call, will consider re-enable it
    [self _setBlackCameraNoOutputDetectorEnabled:!liveVideoStreaming];

    if (!_captureResource.device.isConnected) {
        SCLogCapturerError(@"Can't perform configuration for live video streaming");
    }
    SCLogCapturerInfo(@"Set live video streaming: %d -> %d", _captureResource.state.liveVideoStreaming,
                      enableLiveVideoStreaming);
    _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
        setLiveVideoStreaming:enableLiveVideoStreaming] build];

    BOOL isStreaming = _captureResource.videoDataSource.isStreaming;
    if (isStreaming) {
        [_captureResource.videoDataSource stopStreaming];
    }

    SCLogCapturerInfo(@"Set live video streaming beginConfiguration");
    [_captureResource.managedSession performConfiguration:^{
        [_captureResource.videoDataSource beginConfiguration];

        // If video chat is active we should use portrait orientation, otherwise landscape right
        [_captureResource.videoDataSource setVideoOrientation:_captureResource.state.liveVideoStreaming
                                                                  ? AVCaptureVideoOrientationPortrait
                                                                  : AVCaptureVideoOrientationLandscapeRight];

        [_captureResource.device setLiveVideoStreaming:_captureResource.state.liveVideoStreaming
                                               session:_captureResource.managedSession.avSession];

        [_captureResource.videoDataSource commitConfiguration];
    }];

    SCLogCapturerInfo(@"Set live video streaming commitConfiguration");

    if (isStreaming) {
        [_captureResource.videoDataSource startStreaming];
    }
}

- (void)_setBlackCameraNoOutputDetectorEnabled:(BOOL)enabled
{
    if (enabled) {
        [self addListener:_captureResource.blackCameraDetector.blackCameraNoOutputDetector];
        [_captureResource.videoDataSource addListener:_captureResource.blackCameraDetector.blackCameraNoOutputDetector];
    } else {
        [self removeListener:_captureResource.blackCameraDetector.blackCameraNoOutputDetector];
        [_captureResource.videoDataSource
            removeListener:_captureResource.blackCameraDetector.blackCameraNoOutputDetector];
    }
}

- (void)setTorchActiveAsynchronously:(BOOL)torchActive
                   completionHandler:(dispatch_block_t)completionHandler
                             context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Setting torch active asynchronously to: %d", torchActive);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        BOOL torchActiveChanged = NO;
        if (_captureResource.state.torchActive != torchActive) {
            [_captureResource.device setTorchActive:torchActive];
            if (_captureResource.state.devicePosition == SCManagedCaptureDevicePositionFront) {
                _captureResource.frontFlashController.torchActive = torchActive;
            }
            SCLogCapturerInfo(@"Set torch active: %d -> %d", _captureResource.state.torchActive, torchActive);
            _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
                setTorchActive:torchActive] build];
            torchActiveChanged = YES;
        }
        SCManagedCapturerState *state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            if (torchActiveChanged) {
                [_captureResource.announcer managedCapturer:self didChangeState:state];
            }
            if (completionHandler) {
                completionHandler();
            }
        });
    }];
}

- (void)setNightModeActiveAsynchronously:(BOOL)active
                       completionHandler:(dispatch_block_t)completionHandler
                                 context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        // Only do the configuration if current device is connected
        if (_captureResource.device.isConnected) {
            SCLogCapturerInfo(@"Set night mode beginConfiguration");
            [_captureResource.managedSession performConfiguration:^{
                [self _setNightModeActive:active];
                [self _updateHRSIEnabled];
                [self _updateStillImageStabilizationEnabled];
            }];
            SCLogCapturerInfo(@"Set night mode commitConfiguration");
        }
        BOOL nightModeChanged = (_captureResource.state.isNightModeActive != active);
        if (nightModeChanged) {
            SCLogCapturerInfo(@"Set night mode active: %d -> %d", _captureResource.state.isNightModeActive, active);
            _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
                setIsNightModeActive:active] build];
        }
        SCManagedCapturerState *state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            if (nightModeChanged) {
                [_captureResource.announcer managedCapturer:self didChangeState:state];
                [_captureResource.announcer managedCapturer:self didChangeNightModeActive:state];
            }
            if (completionHandler) {
                completionHandler();
            }
        });
    }];
}

- (void)_setNightModeActive:(BOOL)active
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.device setNightModeActive:active session:_captureResource.managedSession.avSession];
    if ([SCManagedCaptureDevice isEnhancedNightModeSupported]) {
        [self _toggleSoftwareNightmode:active];
    }
}

- (void)_toggleSoftwareNightmode:(BOOL)active
{
    SCTraceODPCompatibleStart(2);
    if (active) {
        SCLogCapturerInfo(@"Set enhanced night mode active");
        SCProcessingPipelineBuilder *processingPipelineBuilder = [[SCProcessingPipelineBuilder alloc] init];
        processingPipelineBuilder.enhancedNightMode = YES;
        SCProcessingPipeline *pipeline = [processingPipelineBuilder build];
        SCLogCapturerInfo(@"Adding processing pipeline:%@", pipeline);
        [_captureResource.videoDataSource addProcessingPipeline:pipeline];
    } else {
        SCLogCapturerInfo(@"Removing processing pipeline");
        [_captureResource.videoDataSource removeProcessingPipeline];
    }
}

- (BOOL)_shouldCaptureImageFromVideo
{
    SCTraceODPCompatibleStart(2);
    BOOL isIphone5Series = [SCDeviceName isSimilarToIphone5orNewer] && ![SCDeviceName isSimilarToIphone6orNewer];
    return isIphone5Series && !_captureResource.state.flashActive && ![self isLensApplied];
}

- (void)lockZoomWithContext:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    SCLogCapturerInfo(@"Lock zoom");
    _captureResource.allowsZoom = NO;
}

- (void)unlockZoomWithContext:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    SCLogCapturerInfo(@"Unlock zoom");
    // Don't let anyone unlock the zoom while ARKit is active. When ARKit shuts down, it'll unlock it.
    SC_GUARD_ELSE_RETURN(!_captureResource.state.arSessionActive);
    _captureResource.allowsZoom = YES;
}

- (void)setZoomFactorAsynchronously:(CGFloat)zoomFactor context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    SC_GUARD_ELSE_RETURN(_captureResource.allowsZoom);
    SCLogCapturerInfo(@"Setting zoom factor to: %f", zoomFactor);
    [_captureResource.deviceZoomHandler setZoomFactor:zoomFactor forDevice:_captureResource.device immediately:NO];
}

- (void)resetZoomFactorAsynchronously:(CGFloat)zoomFactor
                       devicePosition:(SCManagedCaptureDevicePosition)devicePosition
                              context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    SC_GUARD_ELSE_RETURN(_captureResource.allowsZoom);
    SCLogCapturerInfo(@"Setting zoom factor to: %f devicePosition:%lu", zoomFactor, (unsigned long)devicePosition);
    SCManagedCaptureDevice *device = [SCManagedCaptureDevice deviceWithPosition:devicePosition];
    [_captureResource.deviceZoomHandler setZoomFactor:zoomFactor forDevice:device immediately:YES];
}

- (void)setExposurePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                        fromUser:(BOOL)fromUser
                               completionHandler:(dispatch_block_t)completionHandler
                                         context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (_captureResource.device.isConnected) {
            CGPoint exposurePoint;
            if ([self isVideoMirrored]) {
                exposurePoint = CGPointMake(pointOfInterest.x, 1 - pointOfInterest.y);
            } else {
                exposurePoint = pointOfInterest;
            }
            if (_captureResource.device.softwareZoom) {
                // Fix for the zooming factor
                [_captureResource.device
                    setExposurePointOfInterest:CGPointMake(
                                                   (exposurePoint.x - 0.5) / _captureResource.device.softwareZoom + 0.5,
                                                   (exposurePoint.y - 0.5) / _captureResource.device.softwareZoom + 0.5)
                                      fromUser:fromUser];
            } else {
                [_captureResource.device setExposurePointOfInterest:exposurePoint fromUser:fromUser];
            }
        }
        if (completionHandler) {
            runOnMainThreadAsynchronously(completionHandler);
        }
    }];
}

- (void)setAutofocusPointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                completionHandler:(dispatch_block_t)completionHandler
                                          context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (_captureResource.device.isConnected) {
            CGPoint focusPoint;
            if ([self isVideoMirrored]) {
                focusPoint = CGPointMake(pointOfInterest.x, 1 - pointOfInterest.y);
            } else {
                focusPoint = pointOfInterest;
            }
            if (_captureResource.device.softwareZoom) {
                // Fix for the zooming factor
                [_captureResource.device
                    setAutofocusPointOfInterest:CGPointMake(
                                                    (focusPoint.x - 0.5) / _captureResource.device.softwareZoom + 0.5,
                                                    (focusPoint.y - 0.5) / _captureResource.device.softwareZoom + 0.5)];
            } else {
                [_captureResource.device setAutofocusPointOfInterest:focusPoint];
            }
        }
        if (completionHandler) {
            runOnMainThreadAsynchronously(completionHandler);
        }
    }];
}

- (void)setPortraitModePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                   completionHandler:(dispatch_block_t)completionHandler
                                             context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [SCCaptureWorker setPortraitModePointOfInterestAsynchronously:pointOfInterest
                                                completionHandler:completionHandler
                                                         resource:_captureResource];
}

- (void)continuousAutofocusAndExposureAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                                  context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (_captureResource.device.isConnected) {
            [_captureResource.device continuousAutofocus];
            [_captureResource.device setExposurePointOfInterest:CGPointMake(0.5, 0.5) fromUser:NO];
            if (SCCameraTweaksEnablePortraitModeAutofocus()) {
                [self setPortraitModePointOfInterestAsynchronously:CGPointMake(0.5, 0.5)
                                                 completionHandler:nil
                                                           context:context];
            }
        }
        if (completionHandler) {
            runOnMainThreadAsynchronously(completionHandler);
        }
    }];
}

#pragma mark - Add / Remove Listener

- (void)addListener:(id<SCManagedCapturerListener>)listener
{
    SCTraceODPCompatibleStart(2);
    // Only do the make sure thing if I added it to announcer fresh.
    SC_GUARD_ELSE_RETURN([_captureResource.announcer addListener:listener]);
    // After added the listener, make sure we called all these methods with its
    // initial values
    [_captureResource.queuePerformer perform:^{
        SCManagedCapturerState *state = [_captureResource.state copy];
        AVCaptureVideoPreviewLayer *videoPreviewLayer = _captureResource.videoPreviewLayer;
        LSAGLView *videoPreviewGLView = _captureResource.videoPreviewGLViewManager.view;
        runOnMainThreadAsynchronously(^{
            SCTraceStart();
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeState:)]) {
                [listener managedCapturer:self didChangeState:state];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeCaptureDevicePosition:)]) {
                [listener managedCapturer:self didChangeCaptureDevicePosition:state];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeNightModeActive:)]) {
                [listener managedCapturer:self didChangeNightModeActive:state];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeFlashActive:)]) {
                [listener managedCapturer:self didChangeFlashActive:state];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeFlashSupportedAndTorchSupported:)]) {
                [listener managedCapturer:self didChangeFlashSupportedAndTorchSupported:state];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeZoomFactor:)]) {
                [listener managedCapturer:self didChangeZoomFactor:state];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeLowLightCondition:)]) {
                [listener managedCapturer:self didChangeLowLightCondition:state];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeAdjustingExposure:)]) {
                [listener managedCapturer:self didChangeAdjustingExposure:state];
            }
            if (!SCDeviceSupportsMetal()) {
                if ([listener respondsToSelector:@selector(managedCapturer:didChangeVideoPreviewLayer:)]) {
                    [listener managedCapturer:self didChangeVideoPreviewLayer:videoPreviewLayer];
                }
            }
            if (videoPreviewGLView &&
                [listener respondsToSelector:@selector(managedCapturer:didChangeVideoPreviewGLView:)]) {
                [listener managedCapturer:self didChangeVideoPreviewGLView:videoPreviewGLView];
            }
            if ([listener respondsToSelector:@selector(managedCapturer:didChangeLensesActive:)]) {
                [listener managedCapturer:self didChangeLensesActive:state];
            }
        });
    }];
}

- (void)removeListener:(id<SCManagedCapturerListener>)listener
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.announcer removeListener:listener];
}

- (void)addVideoDataSourceListener:(id<SCManagedVideoDataSourceListener>)listener
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.videoDataSource addListener:listener];
}

- (void)removeVideoDataSourceListener:(id<SCManagedVideoDataSourceListener>)listener
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.videoDataSource removeListener:listener];
}

- (void)addDeviceCapacityAnalyzerListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.deviceCapacityAnalyzer addListener:listener];
}

- (void)removeDeviceCapacityAnalyzerListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.deviceCapacityAnalyzer removeListener:listener];
}

#pragma mark - Debug

- (NSString *)debugInfo
{
    SCTraceODPCompatibleStart(2);
    NSMutableString *info = [NSMutableString new];
    [info appendString:@"==== SCManagedCapturer tokens ====\n"];
    [_captureResource.tokenSet enumerateObjectsUsingBlock:^(SCCapturerToken *_Nonnull token, BOOL *_Nonnull stop) {
        [info appendFormat:@"%@\n", token.debugDescription];
    }];
    return info.copy;
}

- (NSString *)description
{
    return [self debugDescription];
}

- (NSString *)debugDescription
{
    return [NSString sc_stringWithFormat:@"SCManagedCapturer state:\n%@\nVideo streamer info:\n%@",
                                         _captureResource.state.debugDescription,
                                         _captureResource.videoDataSource.description];
}

- (CMTime)firstWrittenAudioBufferDelay
{
    SCTraceODPCompatibleStart(2);
    return [SCCaptureWorker firstWrittenAudioBufferDelay:_captureResource];
}

- (BOOL)audioQueueStarted
{
    SCTraceODPCompatibleStart(2);
    return [SCCaptureWorker audioQueueStarted:_captureResource];
}

#pragma mark - SCTimeProfilable

+ (SCTimeProfilerContext)context
{
    return SCTimeProfilerContextCamera;
}

// We disable and re-enable liveness timer when enter background and foreground

- (void)applicationDidEnterBackground
{
    SCTraceODPCompatibleStart(2);
    [SCCaptureWorker destroyLivenessConsistencyTimer:_captureResource];
    // Hide the view when in background.
    if (!SCDeviceSupportsMetal()) {
        [_captureResource.queuePerformer perform:^{
            _captureResource.appInBackground = YES;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            _captureResource.videoPreviewLayer.hidden = YES;
            [CATransaction commit];
        }];
    } else {
        [_captureResource.queuePerformer perform:^{
            _captureResource.appInBackground = YES;
            // If it is running, stop the streaming.
            if (_captureResource.status == SCManagedCapturerStatusRunning) {
                [_captureResource.videoDataSource stopStreaming];
            }
        }];
    }
    [[SCManagedCapturePreviewLayerController sharedInstance] applicationDidEnterBackground];
}

- (void)applicationWillEnterForeground
{
    SCTraceODPCompatibleStart(2);
    if (!SCDeviceSupportsMetal()) {
        [_captureResource.queuePerformer perform:^{
            SCTraceStart();
            _captureResource.appInBackground = NO;

            if (!SCDeviceSupportsMetal()) {
                [self _fixNonMetalSessionPreviewInconsistency];
            }

            // Doing this right now on iOS 10. It will probably work on iOS 9 as well, but need to verify.
            if (SC_AT_LEAST_IOS_10) {
                [self _runningConsistencyCheckAndFix];
                // For OS version >= iOS 10, try to fix AVCaptureSession when app is entering foreground.
                _captureResource.numRetriesFixAVCaptureSessionWithCurrentSession = 0;
                [self _fixAVSessionIfNecessary];
            }
        }];
    } else {
        [_captureResource.queuePerformer perform:^{
            SCTraceStart();
            _captureResource.appInBackground = NO;
            if (_captureResource.status == SCManagedCapturerStatusRunning) {
                [_captureResource.videoDataSource startStreaming];
            }
            // Doing this right now on iOS 10. It will probably work on iOS 9 as well, but need to verify.
            if (SC_AT_LEAST_IOS_10) {
                [self _runningConsistencyCheckAndFix];
                // For OS version >= iOS 10, try to fix AVCaptureSession when app is entering foreground.
                _captureResource.numRetriesFixAVCaptureSessionWithCurrentSession = 0;
                [self _fixAVSessionIfNecessary];
            }
        }];
    }
    [[SCManagedCapturePreviewLayerController sharedInstance] applicationWillEnterForeground];
}

- (void)applicationWillResignActive
{
    SCTraceODPCompatibleStart(2);
    [[SCManagedCapturePreviewLayerController sharedInstance] applicationWillResignActive];
    [_captureResource.queuePerformer perform:^{
        [self _pauseCaptureSessionKVOCheck];
    }];
}

- (void)applicationDidBecomeActive
{
    SCTraceODPCompatibleStart(2);
    [[SCManagedCapturePreviewLayerController sharedInstance] applicationDidBecomeActive];
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        // Since we foreground it, do the running consistency check immediately.
        // Reset number of retries for fixing status inconsistency
        _captureResource.numRetriesFixInconsistencyWithCurrentSession = 0;
        [self _runningConsistencyCheckAndFix];
        if (!SC_AT_LEAST_IOS_10) {
            // For OS version < iOS 10, try to fix AVCaptureSession after app becomes active.
            _captureResource.numRetriesFixAVCaptureSessionWithCurrentSession = 0;
            [self _fixAVSessionIfNecessary];
        }
        [self _resumeCaptureSessionKVOCheck];
        if (_captureResource.status == SCManagedCapturerStatusRunning) {
            // Reschedule the timer if we don't have it already
            runOnMainThreadAsynchronously(^{
                SCTraceStart();
                [SCCaptureWorker setupLivenessConsistencyTimerIfForeground:_captureResource];
            });
        }
    }];
}

- (void)_runningConsistencyCheckAndFix
{
    SCTraceODPCompatibleStart(2);
    // Don't enforce consistency on simulator, as it'll constantly false-positive and restart session.
    SC_GUARD_ELSE_RETURN(![SCDeviceName isSimulator]);
    if (_captureResource.state.arSessionActive) {
        [self _runningARSessionConsistencyCheckAndFix];
    } else {
        [self _runningAVCaptureSessionConsistencyCheckAndFix];
    }
}

- (void)_runningARSessionConsistencyCheckAndFix
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    SCAssert(_captureResource.state.arSessionActive, @"");
    if (@available(iOS 11.0, *)) {
        // Occassionally the capture session will get into a weird "stuck" state.
        // If this happens, we'll see that the timestamp for the most recent frame is behind the current time.
        // Pausinging the session for a moment and restarting to attempt to jog it loose.
        NSTimeInterval timeSinceLastFrame = CACurrentMediaTime() - _captureResource.arSession.currentFrame.timestamp;
        BOOL reset = NO;
        if (_captureResource.arSession.currentFrame.camera.trackingStateReason == ARTrackingStateReasonInitializing) {
            if (timeSinceLastFrame > kSCManagedCapturerFixInconsistencyARSessionHungInitThreshold) {
                SCLogCapturerInfo(@"*** Found inconsistency for ARSession timestamp (possible hung init), fix now ***");
                reset = YES;
            }
        } else if (timeSinceLastFrame > kSCManagedCapturerFixInconsistencyARSessionDelayThreshold) {
            SCLogCapturerInfo(@"*** Found inconsistency for ARSession timestamp (init complete), fix now ***");
            reset = YES;
        }
        if (reset) {
            [SCCaptureWorker turnARSessionOff:_captureResource];
            [SCCaptureWorker turnARSessionOn:_captureResource];
        }
    }
}

- (void)_runningAVCaptureSessionConsistencyCheckAndFix
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    SCAssert(!_captureResource.state.arSessionActive, @"");
    [[SCLogger sharedInstance] logStepToEvent:@"CAMERA_OPEN_WITH_FIX_INCONSISTENCY"
                                     uniqueId:@""
                                     stepName:@"startConsistencyCheckAndFix"];
    // If the video preview layer's hidden status is out of sync with the
    // session's running status,
    // fix that now. Also, we don't care that much if the status is not running.
    if (!SCDeviceSupportsMetal()) {
        [self _fixNonMetalSessionPreviewInconsistency];
    }
    // Skip the liveness consistency check if we are in background
    if (_captureResource.appInBackground) {
        SCLogCapturerInfo(@"*** Skipped liveness consistency check, as we are in the background ***");
        return;
    }
    if (_captureResource.status == SCManagedCapturerStatusRunning && !_captureResource.managedSession.isRunning) {
        SCGhostToSnappableSignalCameraFixInconsistency();
        SCLogCapturerInfo(@"*** Found status inconsistency for running, fix now ***");
        _captureResource.numRetriesFixInconsistencyWithCurrentSession++;
        if (_captureResource.numRetriesFixInconsistencyWithCurrentSession <=
            kSCManagedCapturerFixInconsistencyMaxRetriesWithCurrentSession) {
            SCTraceStartSection("Fix non-running session")
            {
                if (!SCDeviceSupportsMetal()) {
                    [CATransaction begin];
                    [CATransaction setDisableActions:YES];
                    [_captureResource.managedSession startRunning];
                    [SCCaptureWorker setupVideoPreviewLayer:_captureResource];
                    [CATransaction commit];
                } else {
                    [_captureResource.managedSession startRunning];
                }
            }
            SCTraceEndSection();
        } else {
            SCTraceStartSection("Create new capturer session")
            {
                // start running with new capture session if the inconsistency fixing not succeeds
                // after kSCManagedCapturerFixInconsistencyMaxRetriesWithCurrentSession retries
                SCLogCapturerInfo(@"*** Recreate and run new capture session to fix the inconsistency ***");
                [self _startRunningWithNewCaptureSession];
            }
            SCTraceEndSection();
        }
        BOOL sessionIsRunning = _captureResource.managedSession.isRunning;
        if (sessionIsRunning && !SCDeviceSupportsMetal()) {
            // If it is fixed, we signal received the first frame.
            SCGhostToSnappableSignalDidReceiveFirstPreviewFrame();
            runOnMainThreadAsynchronously(^{
                // To approximate this did render timer, it is not accurate.
                SCGhostToSnappableSignalDidRenderFirstPreviewFrame(CACurrentMediaTime());
            });
        }
        SCLogCapturerInfo(@"*** Applied inconsistency fix, running state : %@ ***", sessionIsRunning ? @"YES" : @"NO");
        if (_captureResource.managedSession.isRunning) {
            [[SCLogger sharedInstance] logStepToEvent:@"CAMERA_OPEN_WITH_FIX_INCONSISTENCY"
                                             uniqueId:@""
                                             stepName:@"finishConsistencyCheckAndFix"];
            [[SCLogger sharedInstance]
                logTimedEventEnd:@"CAMERA_OPEN_WITH_FIX_INCONSISTENCY"
                        uniqueId:@""
                      parameters:@{
                          @"count" : @(_captureResource.numRetriesFixInconsistencyWithCurrentSession)
                      }];
        }
    } else {
        [[SCLogger sharedInstance] cancelLogTimedEvent:@"CAMERA_OPEN_WITH_FIX_INCONSISTENCY" uniqueId:@""];
        // Reset number of retries for fixing status inconsistency
        _captureResource.numRetriesFixInconsistencyWithCurrentSession = 0;
    }

    [_captureResource.blackCameraDetector sessionDidChangeIsRunning:_captureResource.managedSession.isRunning];
}

- (void)mediaServicesWereReset
{
    SCTraceODPCompatibleStart(2);
    [self mediaServicesWereLost];
    [_captureResource.queuePerformer perform:^{
        /* If the current state requires the ARSession, restart it.
         Explicitly flip the arSessionActive flag so that `turnSessionOn` thinks it can reset itself.
         */
        if (_captureResource.state.arSessionActive) {
            _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
                setArSessionActive:NO] build];
            [SCCaptureWorker turnARSessionOn:_captureResource];
        }
    }];
}

- (void)mediaServicesWereLost
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        if (!_captureResource.state.arSessionActive && !_captureResource.managedSession.isRunning) {
            /*
             If the session is running we will trigger
             _sessionRuntimeError: so nothing else is
             needed here.
             */
            [_captureResource.videoCapturer.outputURL reloadAssetKeys];
        }
    }];
}

- (void)_livenessConsistency:(NSTimer *)timer
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    // We can directly check the application state because this timer is scheduled
    // on the main thread.
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        [_captureResource.queuePerformer perform:^{
            [self _runningConsistencyCheckAndFix];
        }];
    }
}

- (void)_sessionRuntimeError:(NSNotification *)notification
{
    SCTraceODPCompatibleStart(2);
    NSError *sessionError = notification.userInfo[AVCaptureSessionErrorKey];
    SCLogCapturerError(@"Encountered runtime error for capture session %@", sessionError);

    NSString *errorString =
        [sessionError.description stringByReplacingOccurrencesOfString:@" " withString:@"_"].uppercaseString
            ?: @"UNKNOWN_ERROR";
    [[SCUserTraceLogger shared]
        logUserTraceEvent:[NSString sc_stringWithFormat:@"AVCAPTURESESSION_RUNTIME_ERROR_%@", errorString]];

    if (sessionError.code == AVErrorMediaServicesWereReset) {
        // If it is a AVErrorMediaServicesWereReset error, we can just call startRunning, it is much light weighted
        [_captureResource.queuePerformer perform:^{
            if (!SCDeviceSupportsMetal()) {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                [_captureResource.managedSession startRunning];
                [SCCaptureWorker setupVideoPreviewLayer:_captureResource];
                [CATransaction commit];
            } else {
                [_captureResource.managedSession startRunning];
            }
        }];
    } else {
        if (_captureResource.isRecreateSessionFixScheduled) {
            SCLogCoreCameraInfo(@"Fixing session runtime error is scheduled, skip");
            return;
        }

        _captureResource.isRecreateSessionFixScheduled = YES;
        NSTimeInterval delay = 0;
        NSTimeInterval timeNow = [NSDate timeIntervalSinceReferenceDate];
        if (timeNow - _captureResource.lastSessionRuntimeErrorTime < kMinFixSessionRuntimeErrorInterval) {
            SCLogCoreCameraInfo(@"Fixing runtime error session in less than %f, delay",
                                kMinFixSessionRuntimeErrorInterval);
            delay = kMinFixSessionRuntimeErrorInterval;
        }
        _captureResource.lastSessionRuntimeErrorTime = timeNow;
        [_captureResource.queuePerformer perform:^{
            SCTraceStart();
            // Occasionaly _captureResource.avSession will throw out an error when shutting down. If this happens while
            // ARKit is starting up,
            // _startRunningWithNewCaptureSession will throw a wrench in ARSession startup and freeze the image.
            SC_GUARD_ELSE_RETURN(!_captureResource.state.arSessionActive);
            // Need to reset the flag before _startRunningWithNewCaptureSession
            _captureResource.isRecreateSessionFixScheduled = NO;
            [self _startRunningWithNewCaptureSession];
            [self _fixAVSessionIfNecessary];
        }
                                           after:delay];
    }

    [[SCLogger sharedInstance] logUnsampledEvent:kSCCameraMetricsRuntimeError
                                      parameters:@{
                                          @"error" : sessionError == nil ? @"Unknown error" : sessionError.description,
                                      }
                                secretParameters:nil
                                         metrics:nil];
}

- (void)_startRunningWithNewCaptureSessionIfNecessary
{
    SCTraceODPCompatibleStart(2);
    if (_captureResource.isRecreateSessionFixScheduled) {
        SCLogCapturerInfo(@"Session recreation is scheduled, return");
        return;
    }
    _captureResource.isRecreateSessionFixScheduled = YES;
    [_captureResource.queuePerformer perform:^{
        // Need to reset the flag before _startRunningWithNewCaptureSession
        _captureResource.isRecreateSessionFixScheduled = NO;
        [self _startRunningWithNewCaptureSession];
    }];
}

- (void)_startRunningWithNewCaptureSession
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    SCLogCapturerInfo(@"Start running with new capture session. isRecording:%d isStreaming:%d status:%lu",
                      _captureResource.videoRecording, _captureResource.videoDataSource.isStreaming,
                      (unsigned long)_captureResource.status);

    // Mark the start of recreating session
    [_captureResource.blackCameraDetector sessionWillRecreate];

    // Light weight fix gating
    BOOL lightWeightFix = SCCameraTweaksSessionLightWeightFixEnabled() || SCCameraTweaksBlackCameraRecoveryEnabled();

    if (!lightWeightFix) {
        [_captureResource.deviceCapacityAnalyzer removeListener:_captureResource.stillImageCapturer];
        [self removeListener:_captureResource.stillImageCapturer];
        [_captureResource.videoDataSource removeListener:_captureResource.lensProcessingCore.capturerListener];

        [_captureResource.videoDataSource removeListener:_captureResource.deviceCapacityAnalyzer];
        [_captureResource.videoDataSource removeListener:_captureResource.stillImageCapturer];

        if (SCIsMasterBuild()) {
            [_captureResource.videoDataSource removeListener:_captureResource.videoStreamReporter];
        }
        [_captureResource.videoDataSource removeListener:_captureResource.videoScanner];
        [_captureResource.videoDataSource removeListener:_captureResource.videoCapturer];
        [_captureResource.videoDataSource
            removeListener:_captureResource.blackCameraDetector.blackCameraNoOutputDetector];
    }

    [_captureResource.videoCapturer.outputURL reloadAssetKeys];

    BOOL isStreaming = _captureResource.videoDataSource.isStreaming;
    if (_captureResource.videoRecording) {
        // Stop video recording prematurely
        [self stopRecordingAsynchronouslyWithContext:SCCapturerContext];
        NSError *error = [NSError
            errorWithDomain:kSCManagedCapturerErrorDomain
                description:
                    [NSString
                        sc_stringWithFormat:@"Interrupt video recording to start new session. %@",
                                            @{
                                                @"isAVSessionRunning" : @(_captureResource.managedSession.isRunning),
                                                @"numRetriesFixInconsistency" :
                                                    @(_captureResource.numRetriesFixInconsistencyWithCurrentSession),
                                                @"numRetriesFixAVCaptureSession" :
                                                    @(_captureResource.numRetriesFixAVCaptureSessionWithCurrentSession),
                                                @"lastSessionRuntimeErrorTime" :
                                                    @(_captureResource.lastSessionRuntimeErrorTime),
                                            }]
                       code:-1];
        [[SCLogger sharedInstance] logUnsampledEvent:kSCCameraMetricsVideoRecordingInterrupted
                                          parameters:@{
                                              @"error" : error.description
                                          }
                                    secretParameters:nil
                                             metrics:nil];
    }
    @try {
        if (@available(iOS 11.0, *)) {
            [_captureResource.arSession pause];
            if (!lightWeightFix) {
                [_captureResource.videoDataSource removeListener:_captureResource.arImageCapturer];
            }
        }
        [_captureResource.managedSession stopRunning];
        [_captureResource.device removeDeviceAsInput:_captureResource.managedSession.avSession];
    } @catch (NSException *exception) {
        SCLogCapturerError(@"Encountered Exception %@", exception);
    } @finally {
        // Nil out device inputs from both devices
        [[SCManagedCaptureDevice front] resetDeviceAsInput];
        [[SCManagedCaptureDevice back] resetDeviceAsInput];
    }

    if (!SCDeviceSupportsMetal()) {
        // Redo the video preview to mitigate https://ph.sc-corp.net/T42584
        [SCCaptureWorker redoVideoPreviewLayer:_captureResource];
    }

#if !TARGET_IPHONE_SIMULATOR
    if (@available(iOS 11.0, *)) {
        _captureResource.arSession = [[ARSession alloc] init];
        _captureResource.arImageCapturer =
            [_captureResource.arImageCaptureProvider arImageCapturerWith:_captureResource.queuePerformer
                                                      lensProcessingCore:_captureResource.lensProcessingCore];
    }
    [self _resetAVCaptureSession];
#endif
    [_captureResource.managedSession.avSession setAutomaticallyConfiguresApplicationAudioSession:NO];
    [_captureResource.device setDeviceAsInput:_captureResource.managedSession.avSession];

    if (_captureResource.fileInputDecider.shouldProcessFileInput) {
        // Keep the same logic, always create new VideoDataSource
        [self _setupNewVideoFileDataSource];
    } else {
        if (!lightWeightFix) {
            [self _setupNewVideoDataSource];
        } else {
            [self _setupVideoDataSourceWithNewSession];
        }
    }

    if (_captureResource.status == SCManagedCapturerStatusRunning) {
        if (!SCDeviceSupportsMetal()) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            // Set the session to be the new session before start running.
            _captureResource.videoPreviewLayer.session = _captureResource.managedSession.avSession;
            if (!_captureResource.appInBackground) {
                [_captureResource.managedSession startRunning];
            }
            [SCCaptureWorker setupVideoPreviewLayer:_captureResource];
            [CATransaction commit];
        } else {
            if (!_captureResource.appInBackground) {
                [_captureResource.managedSession startRunning];
            }
        }
    }
    // Since this start and stop happens in one block, we don't have to worry
    // about streamingSequence issues
    if (isStreaming) {
        [_captureResource.videoDataSource startStreaming];
    }
    SCManagedCapturerState *state = [_captureResource.state copy];
    AVCaptureVideoPreviewLayer *videoPreviewLayer = _captureResource.videoPreviewLayer;
    runOnMainThreadAsynchronously(^{
        [_captureResource.announcer managedCapturer:self didResetFromRuntimeError:state];
        if (!SCDeviceSupportsMetal()) {
            [_captureResource.announcer managedCapturer:self didChangeVideoPreviewLayer:videoPreviewLayer];
        }
    });

    // Mark the end of recreating session
    [_captureResource.blackCameraDetector sessionDidRecreate];
}

/**
 * Heavy-weight session fixing approach: recreating everything
 */
- (void)_setupNewVideoDataSource
{
    if (@available(iOS 11.0, *)) {
        _captureResource.videoDataSource =
            [[SCManagedVideoStreamer alloc] initWithSession:_captureResource.managedSession.avSession
                                                  arSession:_captureResource.arSession
                                             devicePosition:_captureResource.state.devicePosition];
        [_captureResource.videoDataSource addListener:_captureResource.arImageCapturer];
        if (_captureResource.state.isPortraitModeActive) {
            [_captureResource.videoDataSource setDepthCaptureEnabled:YES];

            SCProcessingPipelineBuilder *processingPipelineBuilder = [[SCProcessingPipelineBuilder alloc] init];
            processingPipelineBuilder.portraitModeEnabled = YES;
            SCProcessingPipeline *pipeline = [processingPipelineBuilder build];
            [_captureResource.videoDataSource addProcessingPipeline:pipeline];
        }
    } else {
        _captureResource.videoDataSource =
            [[SCManagedVideoStreamer alloc] initWithSession:_captureResource.managedSession.avSession
                                             devicePosition:_captureResource.state.devicePosition];
    }

    [self _setupVideoDataSourceListeners];
}

- (void)_setupNewVideoFileDataSource
{
    _captureResource.videoDataSource =
        [[SCManagedVideoFileStreamer alloc] initWithPlaybackForURL:_captureResource.fileInputDecider.fileURL];
    [_captureResource.lensProcessingCore setLensesActive:YES
                                        videoOrientation:_captureResource.videoDataSource.videoOrientation
                                           filterFactory:nil];
    runOnMainThreadAsynchronously(^{
        [_captureResource.videoPreviewGLViewManager prepareViewIfNecessary];
    });
    [self _setupVideoDataSourceListeners];
}

/**
 * Light-weight session fixing approach: recreating AVCaptureSession / AVCaptureOutput, and bind it to the new session
 */
- (void)_setupVideoDataSourceWithNewSession
{
    if (@available(iOS 11.0, *)) {
        SCManagedVideoStreamer *streamer = (SCManagedVideoStreamer *)_captureResource.videoDataSource;
        [streamer setupWithSession:_captureResource.managedSession.avSession
                    devicePosition:_captureResource.state.devicePosition];
        [streamer setupWithARSession:_captureResource.arSession];
    } else {
        SCManagedVideoStreamer *streamer = (SCManagedVideoStreamer *)_captureResource.videoDataSource;
        [streamer setupWithSession:_captureResource.managedSession.avSession
                    devicePosition:_captureResource.state.devicePosition];
    }
    [_captureResource.stillImageCapturer setupWithSession:_captureResource.managedSession.avSession];
}

- (void)_setupVideoDataSourceListeners
{
    if (_captureResource.videoFrameSampler) {
        [_captureResource.announcer addListener:_captureResource.videoFrameSampler];
    }

    [_captureResource.videoDataSource addSampleBufferDisplayController:_captureResource.sampleBufferDisplayController];
    [_captureResource.videoDataSource addListener:_captureResource.lensProcessingCore.capturerListener];
    [_captureResource.videoDataSource addListener:_captureResource.deviceCapacityAnalyzer];
    if (SCIsMasterBuild()) {
        [_captureResource.videoDataSource addListener:_captureResource.videoStreamReporter];
    }
    [_captureResource.videoDataSource addListener:_captureResource.videoScanner];
    [_captureResource.videoDataSource addListener:_captureResource.blackCameraDetector.blackCameraNoOutputDetector];
    _captureResource.stillImageCapturer = [SCManagedStillImageCapturer capturerWithCaptureResource:_captureResource];
    [_captureResource.deviceCapacityAnalyzer addListener:_captureResource.stillImageCapturer];
    [_captureResource.videoDataSource addListener:_captureResource.stillImageCapturer];

    [self addListener:_captureResource.stillImageCapturer];
}

- (void)_resetAVCaptureSession
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    _captureResource.numRetriesFixAVCaptureSessionWithCurrentSession = 0;
    // lazily initialize _captureResource.kvoController on background thread
    if (!_captureResource.kvoController) {
        _captureResource.kvoController = [[FBKVOController alloc] initWithObserver:self];
    }
    [_captureResource.kvoController unobserve:_captureResource.managedSession.avSession];
    _captureResource.managedSession =
        [[SCManagedCaptureSession alloc] initWithBlackCameraDetector:_captureResource.blackCameraDetector];
    [_captureResource.kvoController observe:_captureResource.managedSession.avSession
                                    keyPath:@keypath(_captureResource.managedSession.avSession, running)
                                    options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                     action:_captureResource.handleAVSessionStatusChange];
}

- (void)_pauseCaptureSessionKVOCheck
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    [_captureResource.kvoController unobserve:_captureResource.managedSession.avSession];
}

- (void)_resumeCaptureSessionKVOCheck
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    [_captureResource.kvoController observe:_captureResource.managedSession.avSession
                                    keyPath:@keypath(_captureResource.managedSession.avSession, running)
                                    options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                     action:_captureResource.handleAVSessionStatusChange];
}

- (id<SCManagedVideoDataSource>)currentVideoDataSource
{
    SCTraceODPCompatibleStart(2);
    return _captureResource.videoDataSource;
}

- (void)checkRestrictedCamera:(void (^)(BOOL, BOOL, AVAuthorizationStatus))callback
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        // Front and back should be available if user has no restriction on camera.
        BOOL front = [[SCManagedCaptureDevice front] isAvailable];
        BOOL back = [[SCManagedCaptureDevice back] isAvailable];
        AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
        runOnMainThreadAsynchronously(^{
            callback(front, back, status);
        });
    }];
}

- (SCSnapCreationTriggers *)snapCreationTriggers
{
    return _captureResource.snapCreationTriggers;
}

- (void)setBlackCameraDetector:(SCBlackCameraDetector *)blackCameraDetector
                             deviceMotionProvider:(id<SCDeviceMotionProvider>)deviceMotionProvider
                                 fileInputDecider:(id<SCFileInputDecider>)fileInputDecider
                           arImageCaptureProvider:(id<SCManagedCapturerARImageCaptureProvider>)arImageCaptureProvider
                                    glviewManager:(id<SCManagedCapturerGLViewManagerAPI>)glViewManager
                                  lensAPIProvider:(id<SCManagedCapturerLensAPIProvider>)lensAPIProvider
                              lsaComponentTracker:(id<SCManagedCapturerLSAComponentTrackerAPI>)lsaComponentTracker
    managedCapturerPreviewLayerControllerDelegate:
        (id<SCManagedCapturePreviewLayerControllerDelegate>)previewLayerControllerDelegate
{
    _captureResource.blackCameraDetector = blackCameraDetector;
    _captureResource.deviceMotionProvider = deviceMotionProvider;
    _captureResource.fileInputDecider = fileInputDecider;
    _captureResource.arImageCaptureProvider = arImageCaptureProvider;
    _captureResource.videoPreviewGLViewManager = glViewManager;
    [_captureResource.videoPreviewGLViewManager configureWithCaptureResource:_captureResource];
    _captureResource.lensAPIProvider = lensAPIProvider;
    _captureResource.lsaTrackingComponentHandler = lsaComponentTracker;
    [_captureResource.lsaTrackingComponentHandler configureWithCaptureResource:_captureResource];
    _captureResource.previewLayerControllerDelegate = previewLayerControllerDelegate;
    [SCManagedCapturePreviewLayerController sharedInstance].delegate = previewLayerControllerDelegate;
}

@end
