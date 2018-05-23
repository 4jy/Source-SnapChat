//
//  SCCaptureWorker.m
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCCaptureWorker.h"

#import "ARConfiguration+SCConfiguration.h"
#import "SCBlackCameraDetector.h"
#import "SCBlackCameraNoOutputDetector.h"
#import "SCCameraTweaks.h"
#import "SCCaptureCoreImageFaceDetector.h"
#import "SCCaptureFaceDetector.h"
#import "SCCaptureMetadataOutputDetector.h"
#import "SCCaptureSessionFixer.h"
#import "SCManagedCaptureDevice+SCManagedCapturer.h"
#import "SCManagedCaptureDeviceDefaultZoomHandler.h"
#import "SCManagedCaptureDeviceHandler.h"
#import "SCManagedCaptureDeviceLinearInterpolationZoomHandler.h"
#import "SCManagedCaptureDeviceSavitzkyGolayZoomHandler.h"
#import "SCManagedCaptureDeviceSubjectAreaHandler.h"
#import "SCManagedCapturePreviewLayerController.h"
#import "SCManagedCaptureSession.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerARImageCaptureProvider.h"
#import "SCManagedCapturerARSessionHandler.h"
#import "SCManagedCapturerGLViewManagerAPI.h"
#import "SCManagedCapturerLensAPIProvider.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerState.h"
#import "SCManagedCapturerStateBuilder.h"
#import "SCManagedCapturerV1.h"
#import "SCManagedDeviceCapacityAnalyzer.h"
#import "SCManagedDeviceCapacityAnalyzerHandler.h"
#import "SCManagedDroppedFramesReporter.h"
#import "SCManagedFrontFlashController.h"
#import "SCManagedStillImageCapturerHandler.h"
#import "SCManagedVideoARDataSource.h"
#import "SCManagedVideoCapturer.h"
#import "SCManagedVideoCapturerHandler.h"
#import "SCManagedVideoFileStreamer.h"
#import "SCManagedVideoScanner.h"
#import "SCManagedVideoStreamReporter.h"
#import "SCManagedVideoStreamer.h"
#import "SCMetalUtils.h"
#import "SCProcessingPipelineBuilder.h"
#import "SCVideoCaptureSessionInfo.h"

#import <SCBatteryLogger/SCBatteryLogger.h>
#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>
#import <SCGhostToSnappable/SCGhostToSnappableSignal.h>
#import <SCImageProcess/SCImageProcessVideoPlaybackSession.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger+Performance.h>

@import ARKit;

static const char *kSCManagedCapturerQueueLabel = "com.snapchat.managed_capturer";
static NSTimeInterval const kMaxDefaultScanFrameDuration = 1. / 15; // Restrict scanning to max 15 frames per second
static NSTimeInterval const kMaxPassiveScanFrameDuration = 1.;      // Restrict scanning to max 1 frame per second
static float const kScanTargetCPUUtilization = 0.5;                 // 50% utilization

static NSString *const kSCManagedCapturerErrorDomain = @"kSCManagedCapturerErrorDomain";
static NSInteger const kSCManagedCapturerRecordVideoBusy = 3001;
static NSInteger const kSCManagedCapturerCaptureStillImageBusy = 3002;

static UIImageOrientation SCMirroredImageOrientation(UIImageOrientation orientation)
{
    switch (orientation) {
    case UIImageOrientationRight:
        return UIImageOrientationLeftMirrored;
    case UIImageOrientationLeftMirrored:
        return UIImageOrientationRight;
    case UIImageOrientationUp:
        return UIImageOrientationUpMirrored;
    case UIImageOrientationUpMirrored:
        return UIImageOrientationUp;
    case UIImageOrientationDown:
        return UIImageOrientationDownMirrored;
    case UIImageOrientationDownMirrored:
        return UIImageOrientationDown;
    case UIImageOrientationLeft:
        return UIImageOrientationRightMirrored;
    case UIImageOrientationRightMirrored:
        return UIImageOrientationLeft;
    }
}

@implementation SCCaptureWorker

+ (SCCaptureResource *)generateCaptureResource
{
    SCCaptureResource *captureResource = [[SCCaptureResource alloc] init];

    captureResource.queuePerformer = [[SCQueuePerformer alloc] initWithLabel:kSCManagedCapturerQueueLabel
                                                            qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                                     context:SCQueuePerformerContextCamera];

    captureResource.announcer = [[SCManagedCapturerListenerAnnouncer alloc] init];
    captureResource.videoCapturerHandler =
        [[SCManagedVideoCapturerHandler alloc] initWithCaptureResource:captureResource];
    captureResource.stillImageCapturerHandler =
        [[SCManagedStillImageCapturerHandler alloc] initWithCaptureResource:captureResource];
    captureResource.deviceCapacityAnalyzerHandler =
        [[SCManagedDeviceCapacityAnalyzerHandler alloc] initWithCaptureResource:captureResource];
    captureResource.deviceZoomHandler = ({
        SCManagedCaptureDeviceDefaultZoomHandler *handler = nil;
        switch (SCCameraTweaksDeviceZoomHandlerStrategy()) {
        case SCManagedCaptureDeviceDefaultZoom:
            handler = [[SCManagedCaptureDeviceDefaultZoomHandler alloc] initWithCaptureResource:captureResource];
            break;
        case SCManagedCaptureDeviceSavitzkyGolayFilter:
            handler = [[SCManagedCaptureDeviceSavitzkyGolayZoomHandler alloc] initWithCaptureResource:captureResource];
            break;
        case SCManagedCaptureDeviceLinearInterpolation:
            handler =
                [[SCManagedCaptureDeviceLinearInterpolationZoomHandler alloc] initWithCaptureResource:captureResource];
            break;
        }
        handler;
    });
    captureResource.captureDeviceHandler =
        [[SCManagedCaptureDeviceHandler alloc] initWithCaptureResource:captureResource];
    captureResource.arSessionHandler =
        [[SCManagedCapturerARSessionHandler alloc] initWithCaptureResource:captureResource];

    captureResource.tokenSet = [NSMutableSet new];
    captureResource.allowsZoom = YES;
    captureResource.debugInfoDict = [[NSMutableDictionary alloc] init];
    captureResource.notificationRegistered = NO;
    return captureResource;
}

+ (void)setupWithCaptureResource:(SCCaptureResource *)captureResource
                  devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceODPCompatibleStart(2);
    SCAssert(captureResource.status == SCManagedCapturerStatusUnknown, @"The status should be unknown");
    captureResource.device = [SCManagedCaptureDevice deviceWithPosition:devicePosition];
    if (!captureResource.device) {
        // Always prefer front camera over back camera
        if ([SCManagedCaptureDevice front]) {
            captureResource.device = [SCManagedCaptureDevice front];
            devicePosition = SCManagedCaptureDevicePositionFront;
        } else {
            captureResource.device = [SCManagedCaptureDevice back];
            devicePosition = SCManagedCaptureDevicePositionBack;
        }
    }
    // Initial state
    SCLogCapturerInfo(@"Init state with devicePosition:%lu, zoomFactor:%f, flashSupported:%d, "
                      @"torchSupported:%d, flashActive:%d, torchActive:%d",
                      (unsigned long)devicePosition, captureResource.device.zoomFactor,
                      captureResource.device.isFlashSupported, captureResource.device.isTorchSupported,
                      captureResource.device.flashActive, captureResource.device.torchActive);
    captureResource.state = [[SCManagedCapturerState alloc] initWithIsRunning:NO
                                                            isNightModeActive:NO
                                                         isPortraitModeActive:NO
                                                            lowLightCondition:NO
                                                            adjustingExposure:NO
                                                               devicePosition:devicePosition
                                                                   zoomFactor:captureResource.device.zoomFactor
                                                               flashSupported:captureResource.device.isFlashSupported
                                                               torchSupported:captureResource.device.isTorchSupported
                                                                  flashActive:captureResource.device.flashActive
                                                                  torchActive:captureResource.device.torchActive
                                                                 lensesActive:NO
                                                              arSessionActive:NO
                                                           liveVideoStreaming:NO
                                                           lensProcessorReady:NO];

    [self configLensesProcessorWithCaptureResource:captureResource];
    [self configARSessionWithCaptureResource:captureResource];
    [self configCaptureDeviceHandlerWithCaptureResource:captureResource];
    [self configAVCaptureSessionWithCaptureResource:captureResource];
    [self configImageCapturerWithCaptureResource:captureResource];
    [self configDeviceCapacityAnalyzerWithCaptureResource:captureResource];
    [self configVideoDataSourceWithCaptureResource:captureResource devicePosition:devicePosition];
    [self configVideoScannerWithCaptureResource:captureResource];
    [self configVideoCapturerWithCaptureResource:captureResource];

    if (!SCIsSimulator()) {
        // We don't want it enabled for simulator
        [self configBlackCameraDetectorWithCaptureResource:captureResource];
    }

    if (SCCameraTweaksEnableFaceDetectionFocus(captureResource.state.devicePosition)) {
        [self configureCaptureFaceDetectorWithCaptureResource:captureResource];
    }
}

+ (void)setupCapturePreviewLayerController
{
    SCAssert([[SCQueuePerformer mainQueuePerformer] isCurrentPerformer], @"");
    [[SCManagedCapturePreviewLayerController sharedInstance] setupPreviewLayer];
}

+ (void)configLensesProcessorWithCaptureResource:(SCCaptureResource *)captureResource
{
    SCManagedCapturerStateBuilder *stateBuilder =
        [SCManagedCapturerStateBuilder withManagedCapturerState:captureResource.state];
    [stateBuilder setLensProcessorReady:YES];
    captureResource.state = [stateBuilder build];

    captureResource.lensProcessingCore = [captureResource.lensAPIProvider lensAPIForCaptureResource:captureResource];
}

+ (void)configARSessionWithCaptureResource:(SCCaptureResource *)captureResource
{
    if (@available(iOS 11.0, *)) {
        captureResource.arSession = [[ARSession alloc] init];

        captureResource.arImageCapturer =
            [captureResource.arImageCaptureProvider arImageCapturerWith:captureResource.queuePerformer
                                                     lensProcessingCore:captureResource.lensProcessingCore];
    }
}

+ (void)configAVCaptureSessionWithCaptureResource:(SCCaptureResource *)captureResource
{
#if !TARGET_IPHONE_SIMULATOR
    captureResource.numRetriesFixAVCaptureSessionWithCurrentSession = 0;
    // lazily initialize _captureResource.kvoController on background thread
    if (!captureResource.kvoController) {
        captureResource.kvoController = [[FBKVOController alloc] initWithObserver:[SCManagedCapturerV1 sharedInstance]];
    }
    [captureResource.kvoController unobserve:captureResource.managedSession.avSession];
    captureResource.managedSession =
        [[SCManagedCaptureSession alloc] initWithBlackCameraDetector:captureResource.blackCameraDetector];
    [captureResource.kvoController observe:captureResource.managedSession.avSession
                                   keyPath:@keypath(captureResource.managedSession.avSession, running)
                                   options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                                    action:captureResource.handleAVSessionStatusChange];
#endif

    [captureResource.managedSession.avSession setAutomaticallyConfiguresApplicationAudioSession:NO];
    [captureResource.device setDeviceAsInput:captureResource.managedSession.avSession];
}

+ (void)configDeviceCapacityAnalyzerWithCaptureResource:(SCCaptureResource *)captureResource
{
    captureResource.deviceCapacityAnalyzer =
        [[SCManagedDeviceCapacityAnalyzer alloc] initWithPerformer:captureResource.videoDataSource.performer];
    [captureResource.deviceCapacityAnalyzer addListener:captureResource.deviceCapacityAnalyzerHandler];
    [captureResource.deviceCapacityAnalyzer setLowLightConditionEnabled:[SCManagedCaptureDevice isNightModeSupported]];
    [captureResource.deviceCapacityAnalyzer addListener:captureResource.stillImageCapturer];
    [captureResource.deviceCapacityAnalyzer setAsFocusListenerForDevice:captureResource.device];
}

+ (void)configVideoDataSourceWithCaptureResource:(SCCaptureResource *)captureResource
                                  devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    if (captureResource.fileInputDecider.shouldProcessFileInput) {
        captureResource.videoDataSource =
            [[SCManagedVideoFileStreamer alloc] initWithPlaybackForURL:captureResource.fileInputDecider.fileURL];
        [captureResource.lensProcessingCore setLensesActive:YES
                                           videoOrientation:captureResource.videoDataSource.videoOrientation
                                              filterFactory:nil];

        runOnMainThreadAsynchronously(^{
            [captureResource.videoPreviewGLViewManager prepareViewIfNecessary];
        });
    } else {
        if (@available(iOS 11.0, *)) {
            captureResource.videoDataSource =
                [[SCManagedVideoStreamer alloc] initWithSession:captureResource.managedSession.avSession
                                                      arSession:captureResource.arSession
                                                 devicePosition:devicePosition];
            [captureResource.videoDataSource addListener:captureResource.arImageCapturer];
            if (captureResource.state.isPortraitModeActive) {
                [captureResource.videoDataSource setDepthCaptureEnabled:YES];

                SCProcessingPipelineBuilder *processingPipelineBuilder = [[SCProcessingPipelineBuilder alloc] init];
                processingPipelineBuilder.portraitModeEnabled = YES;
                SCProcessingPipeline *pipeline = [processingPipelineBuilder build];
                [captureResource.videoDataSource addProcessingPipeline:pipeline];
            }
        } else {
            captureResource.videoDataSource =
                [[SCManagedVideoStreamer alloc] initWithSession:captureResource.managedSession.avSession
                                                 devicePosition:devicePosition];
        }
    }

    [captureResource.videoDataSource addListener:captureResource.lensProcessingCore.capturerListener];
    [captureResource.videoDataSource addListener:captureResource.deviceCapacityAnalyzer];
    [captureResource.videoDataSource addListener:captureResource.stillImageCapturer];

    if (SCIsMasterBuild()) {
        captureResource.videoStreamReporter = [[SCManagedVideoStreamReporter alloc] init];
        [captureResource.videoDataSource addListener:captureResource.videoStreamReporter];
    }
}

+ (void)configVideoScannerWithCaptureResource:(SCCaptureResource *)captureResource
{
    // When initializing video scanner:
    // Restrict default scanning to max 15 frames per second.
    // Restrict passive scanning to max 1 frame per second.
    // Give CPU time to rest.
    captureResource.videoScanner =
        [[SCManagedVideoScanner alloc] initWithMaxFrameDefaultDuration:kMaxDefaultScanFrameDuration
                                               maxFramePassiveDuration:kMaxPassiveScanFrameDuration
                                                             restCycle:1 - kScanTargetCPUUtilization];
    [captureResource.videoDataSource addListener:captureResource.videoScanner];
    [captureResource.deviceCapacityAnalyzer addListener:captureResource.videoScanner];
}

+ (void)configVideoCapturerWithCaptureResource:(SCCaptureResource *)captureResource
{
    if (SCCameraTweaksEnableCaptureSharePerformer()) {
        captureResource.videoCapturer =
            [[SCManagedVideoCapturer alloc] initWithQueuePerformer:captureResource.queuePerformer];
    } else {
        captureResource.videoCapturer = [[SCManagedVideoCapturer alloc] init];
    }

    [captureResource.videoCapturer addListener:captureResource.lensProcessingCore.capturerListener];
    captureResource.videoCapturer.delegate = captureResource.videoCapturerHandler;
}

+ (void)configImageCapturerWithCaptureResource:(SCCaptureResource *)captureResource
{
    captureResource.stillImageCapturer = [SCManagedStillImageCapturer capturerWithCaptureResource:captureResource];
}

+ (void)startRunningWithCaptureResource:(SCCaptureResource *)captureResource
                                  token:(SCCapturerToken *)token
                      completionHandler:(dispatch_block_t)completionHandler
{
    [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsOpen
                                     uniqueId:@""
                                     stepName:@"startOpenCameraOnManagedCaptureQueue"];
    SCTraceSignal(@"Add token %@ to set %@", token, captureResource.tokenSet);
    [captureResource.tokenSet addObject:token];
    if (captureResource.appInBackground) {
        SCTraceSignal(@"Will skip startRunning on AVCaptureSession because we are in background");
    }
    SCTraceStartSection("start session")
    {
        if (!SCDeviceSupportsMetal()) {
            SCCAssert(captureResource.videoPreviewLayer, @"videoPreviewLayer should be created already");
            if (captureResource.status == SCManagedCapturerStatusReady) {
                // Need to wrap this into a CATransaction because startRunning will change
                // AVCaptureVideoPreviewLayer,
                // therefore,
                // without atomic update, will cause layer inconsistency.
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                captureResource.videoPreviewLayer.session = captureResource.managedSession.avSession;
                if (!captureResource.appInBackground) {
                    SCGhostToSnappableSignalCameraStart();
                    [captureResource.managedSession startRunning];
                }
                [self setupVideoPreviewLayer:captureResource];
                [CATransaction commit];
                SCLogCapturerInfo(@"[_captureResource.avSession startRunning] finished. token: %@", token);
            }
            // In case we don't use sample buffer, then we need to fake that we know when the first frame receieved.
            SCGhostToSnappableSignalDidReceiveFirstPreviewFrame();
        } else {
            if (captureResource.status == SCManagedCapturerStatusReady) {
                if (!captureResource.appInBackground) {
                    SCGhostToSnappableSignalCameraStart();
                    [captureResource.managedSession startRunning];
                    SCLogCapturerInfo(
                        @"[_captureResource.avSession startRunning] finished using sample buffer. token: %@", token);
                }
            }
        }
    }
    SCTraceEndSection();
    SCTraceStartSection("start streaming")
    {
        // Do the start streaming after start running, but make sure we start it
        // regardless if the status is ready or
        // not.
        [self startStreaming:captureResource];
    }
    SCTraceEndSection();

    if (!captureResource.notificationRegistered) {
        captureResource.notificationRegistered = YES;

        [captureResource.deviceSubjectAreaHandler startObserving];

        [[NSNotificationCenter defaultCenter] addObserver:[SCManagedCapturerV1 sharedInstance]
                                                 selector:captureResource.sessionRuntimeError
                                                     name:AVCaptureSessionRuntimeErrorNotification
                                                   object:nil];
    }

    if (captureResource.status == SCManagedCapturerStatusReady) {
        // Schedule a timer to check the running state and fix any inconsistency.
        runOnMainThreadAsynchronously(^{
            [self setupLivenessConsistencyTimerIfForeground:captureResource];
        });
        SCLogCapturerInfo(@"Setting isRunning to YES. token: %@", token);
        captureResource.state =
            [[[SCManagedCapturerStateBuilder withManagedCapturerState:captureResource.state] setIsRunning:YES] build];
        captureResource.status = SCManagedCapturerStatusRunning;
    }
    [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsOpen
                                     uniqueId:@""
                                     stepName:@"endOpenCameraOnManagedCaptureQueue"];
    [[SCLogger sharedInstance] logTimedEventEnd:kSCCameraMetricsOpen uniqueId:@"" parameters:nil];

    SCManagedCapturerState *state = [captureResource.state copy];
    SCTraceResumeToken resumeToken = SCTraceCapture();
    runOnMainThreadAsynchronously(^{
        SCTraceResume(resumeToken);
        [captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didChangeState:state];
        [captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didStartRunning:state];
        [[SCBatteryLogger shared] logManagedCapturerDidStartRunning];
        if (completionHandler) {
            completionHandler();
        }
        if (!SCDeviceSupportsMetal()) {
            // To approximate this did render timer, it is not accurate.
            SCGhostToSnappableSignalDidRenderFirstPreviewFrame(CACurrentMediaTime());
        }
    });
}

+ (BOOL)stopRunningWithCaptureResource:(SCCaptureResource *)captureResource
                                 token:(SCCapturerToken *)token
                     completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
{
    SCTraceODPCompatibleStart(2);
    SCAssert([captureResource.queuePerformer isCurrentPerformer], @"");
    BOOL videoPreviewLayerChanged = NO;
    SCAssert([captureResource.tokenSet containsObject:token],
             @"It should be a valid token that is issued by startRunning method.");
    SCTraceSignal(@"Remove token %@, from set %@", token, captureResource.tokenSet);
    SCLogCapturerInfo(@"Stop running. token:%@ tokenSet:%@", token, captureResource.tokenSet);
    [captureResource.tokenSet removeObject:token];
    BOOL succeed = (captureResource.tokenSet.count == 0);
    if (succeed && captureResource.status == SCManagedCapturerStatusRunning) {
        captureResource.status = SCManagedCapturerStatusReady;
        if (@available(iOS 11.0, *)) {
            [captureResource.arSession pause];
        }
        [captureResource.managedSession stopRunning];
        if (!SCDeviceSupportsMetal()) {
            [captureResource.videoDataSource stopStreaming];
            [self redoVideoPreviewLayer:captureResource];
            videoPreviewLayerChanged = YES;
        } else {
            [captureResource.videoDataSource pauseStreaming];
        }

        if (captureResource.state.devicePosition == SCManagedCaptureDevicePositionBackDualCamera) {
            [[SCManagedCapturerV1 sharedInstance] setDevicePositionAsynchronously:SCManagedCaptureDevicePositionBack
                                                                completionHandler:nil
                                                                          context:SCCapturerContext];
        }

        // We always disable lenses and hide _captureResource.videoPreviewGLView when app goes into
        // the background
        // thus there is no need to clean up anything.
        // _captureResource.videoPreviewGLView will be shown again to the user only when the frame
        // will be processed by the lenses
        // processor

        // Remove the liveness timer which checks the health of the running state
        runOnMainThreadAsynchronously(^{
            [self destroyLivenessConsistencyTimer:captureResource];
        });
        SCLogCapturerInfo(@"Setting isRunning to NO. removed token: %@", token);
        captureResource.state =
            [[[SCManagedCapturerStateBuilder withManagedCapturerState:captureResource.state] setIsRunning:NO] build];

        captureResource.notificationRegistered = NO;

        [captureResource.deviceSubjectAreaHandler stopObserving];

        [[NSNotificationCenter defaultCenter] removeObserver:[SCManagedCapturerV1 sharedInstance]
                                                        name:AVCaptureSessionRuntimeErrorNotification
                                                      object:nil];

        [captureResource.arSessionHandler stopObserving];
    }

    SCManagedCapturerState *state = [captureResource.state copy];
    AVCaptureVideoPreviewLayer *videoPreviewLayer = videoPreviewLayerChanged ? captureResource.videoPreviewLayer : nil;
    runOnMainThreadAsynchronously(^{
        if (succeed) {
            [captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didChangeState:state];
            [captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didStopRunning:state];
            [[SCBatteryLogger shared] logManagedCapturerDidStopRunning];
            if (videoPreviewLayerChanged) {
                [captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                didChangeVideoPreviewLayer:videoPreviewLayer];
            }
        }
        if (completionHandler) {
            completionHandler(succeed);
        }
    });

    return succeed;
}

+ (void)setupVideoPreviewLayer:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCAssert([resource.queuePerformer isCurrentPerformer] || [[SCQueuePerformer mainQueuePerformer] isCurrentPerformer],
             @"");
    if ([resource.videoPreviewLayer.connection isVideoOrientationSupported]) {
        resource.videoPreviewLayer.connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    resource.videoPreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    resource.videoPreviewLayer.hidden = !resource.managedSession.isRunning;

    SCLogCapturerInfo(@"Setup video preview layer with connect.enabled:%d, hidden:%d",
                      resource.videoPreviewLayer.connection.enabled, resource.videoPreviewLayer.hidden);
}

+ (void)makeVideoPreviewLayer:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    // This can be called either from current queue or from main queue.
    SCAssert([resource.queuePerformer isCurrentPerformer] || [[SCQueuePerformer mainQueuePerformer] isCurrentPerformer],
             @"");
#if !TARGET_IPHONE_SIMULATOR
    SCAssert(resource.managedSession.avSession, @"session shouldn't be nil");
#endif
    // Need to wrap this to a transcation otherwise this is happening off the main
    // thread, and the layer
    // won't be lay out correctly.
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    // Since _captureResource.avSession is always created / recreated on this private queue, and
    // videoPreviewLayer.session,
    // if not touched by anyone else, is also set on this private queue, it should
    // be safe to do this
    // If-clause check.
    resource.videoPreviewLayer = [AVCaptureVideoPreviewLayer new];
    SCAssert(resource.videoPreviewLayer, @"_captureResource.videoPreviewLayer shouldn't be nil");
    [self setupVideoPreviewLayer:resource];
    if (resource.device.softwareZoom && resource.device.zoomFactor != 1) {
        [self softwareZoomWithDevice:resource.device resource:resource];
    }
    [CATransaction commit];
    SCLogCapturerInfo(@"Created AVCaptureVideoPreviewLayer:%@", resource.videoPreviewLayer);
}

+ (void)redoVideoPreviewLayer:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"redo video preview layer");
    AVCaptureVideoPreviewLayer *videoPreviewLayer = resource.videoPreviewLayer;
    resource.videoPreviewLayer = nil;
    // This will do dispatch_sync on the main thread, since mainQueuePerformer
    // is reentrant, it should be fine
    // on iOS 7.
    [[SCQueuePerformer mainQueuePerformer] performAndWait:^{
        // Hide and remove the session when stop the video preview layer at main
        // thread.
        // It seems that when we nil out the session, it will cause some relayout
        // on iOS 9
        // and trigger an assertion.
        videoPreviewLayer.hidden = YES;
        videoPreviewLayer.session = nil;
        // We setup the video preview layer immediately after destroy it so
        // that when we start running again, we don't need to pay the setup
        // cost.
        [self makeVideoPreviewLayer:resource];
    }];
}

+ (void)startStreaming:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    ++resource.streamingSequence;
    SCLogCapturerInfo(@"Start streaming. streamingSequence:%lu", (unsigned long)resource.streamingSequence);
    [resource.videoDataSource startStreaming];
}

+ (void)setupLivenessConsistencyTimerIfForeground:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    if (resource.livenessTimer) {
        // If we have the liveness timer already, don't need to set it up.
        return;
    }
    // Check if the application state is in background now, if so, we don't need
    // to setup liveness timer
    if ([UIApplication sharedApplication].applicationState != UIApplicationStateBackground) {
        resource.livenessTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                                  target:[SCManagedCapturerV1 sharedInstance]
                                                                selector:resource.livenessConsistency
                                                                userInfo:nil
                                                                 repeats:YES];
    }
}

+ (void)destroyLivenessConsistencyTimer:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCAssertMainThread();
    [resource.livenessTimer invalidate];
    resource.livenessTimer = nil;
}

+ (void)softwareZoomWithDevice:(SCManagedCaptureDevice *)device resource:(SCCaptureResource *)resource
{
    [resource.deviceZoomHandler softwareZoomWithDevice:device];
}

+ (void)captureStillImageWithCaptureResource:(SCCaptureResource *)captureResource
                                 aspectRatio:(CGFloat)aspectRatio
                            captureSessionID:(NSString *)captureSessionID
                      shouldCaptureFromVideo:(BOOL)shouldCaptureFromVideo
                           completionHandler:
                               (sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                                     context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    if (captureResource.stillImageCapturing) {
        SCLogCapturerWarning(@"Another still image is capturing. aspectRatio:%f", aspectRatio);
        if (completionHandler) {
            SCManagedCapturerState *state = [captureResource.state copy];
            runOnMainThreadAsynchronously(^{
                completionHandler(nil, nil, [NSError errorWithDomain:kSCManagedCapturerErrorDomain
                                                                code:kSCManagedCapturerCaptureStillImageBusy
                                                            userInfo:nil],
                                  state);
            });
        }
    } else {
        captureResource.stillImageCapturing = YES;
        [SCCaptureWorker _captureStillImageAsynchronouslyWithCaptureResource:captureResource
                                                                 aspectRatio:aspectRatio
                                                            captureSessionID:captureSessionID
                                                      shouldCaptureFromVideo:shouldCaptureFromVideo
                                                           completionHandler:completionHandler];
    }
}

+ (void)_captureStillImageAsynchronouslyWithCaptureResource:(SCCaptureResource *)captureResource
                                                aspectRatio:(CGFloat)aspectRatio
                                           captureSessionID:(NSString *)captureSessionID
                                     shouldCaptureFromVideo:(BOOL)shouldCaptureFromVideo
                                          completionHandler:
                                              (sc_managed_capturer_capture_still_image_completion_handler_t)
                                                  completionHandler
{
    SCTraceODPCompatibleStart(2);
    SCAssert([captureResource.queuePerformer isCurrentPerformer], @"");
    SCAssert(completionHandler, @"completionHandler cannot be nil");

    SCManagedCapturerState *state = [captureResource.state copy];
    SCLogCapturerInfo(@"Capturing still image. aspectRatio:%f state:%@", aspectRatio, state);
    // If when we start capturing, the video streamer is not running yet, start
    // running it.
    [SCCaptureWorker startStreaming:captureResource];
    SCManagedStillImageCapturer *stillImageCapturer = captureResource.stillImageCapturer;
    if (@available(iOS 11.0, *)) {
        if (state.arSessionActive) {
            stillImageCapturer = captureResource.arImageCapturer;
        }
    }
    dispatch_block_t stillImageCaptureHandler = ^{
        SCCAssert(captureResource.stillImageCapturer, @"stillImageCapturer should be available");
        float zoomFactor = captureResource.device.softwareZoom ? captureResource.device.zoomFactor : 1;
        [stillImageCapturer
            captureStillImageWithAspectRatio:aspectRatio
                                atZoomFactor:zoomFactor
                                 fieldOfView:captureResource.device.fieldOfView
                                       state:state
                            captureSessionID:captureSessionID
                      shouldCaptureFromVideo:shouldCaptureFromVideo
                           completionHandler:^(UIImage *fullScreenImage, NSDictionary *metadata, NSError *error) {
                               SCTraceStart();
                               // We are done here, turn off front flash if needed,
                               // this is dispatched in
                               // SCManagedCapturer's private queue
                               if (captureResource.state.flashActive && !captureResource.state.flashSupported &&
                                   captureResource.state.devicePosition == SCManagedCaptureDevicePositionFront) {
                                   captureResource.frontFlashController.flashActive = NO;
                               }
                               if (state.devicePosition == SCManagedCaptureDevicePositionFront) {
                                   fullScreenImage = [UIImage
                                       imageWithCGImage:fullScreenImage.CGImage
                                                  scale:1.0
                                            orientation:SCMirroredImageOrientation(fullScreenImage.imageOrientation)];
                               }
                               captureResource.stillImageCapturing = NO;

                               runOnMainThreadAsynchronously(^{
                                   completionHandler(fullScreenImage, metadata, error, state);
                               });
                           }];
    };
    if (state.flashActive && !captureResource.state.flashSupported &&
        state.devicePosition == SCManagedCaptureDevicePositionFront) {
        captureResource.frontFlashController.flashActive = YES;
        // Do the first capture only after 0.175 seconds so that the front flash is
        // already available
        [captureResource.queuePerformer perform:stillImageCaptureHandler after:0.175];
    } else {
        stillImageCaptureHandler();
    }
}

+ (void)startRecordingWithCaptureResource:(SCCaptureResource *)captureResource
                           outputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                       audioConfiguration:(SCAudioConfiguration *)configuration
                              maxDuration:(NSTimeInterval)maxDuration
                                  fileURL:(NSURL *)fileURL
                         captureSessionID:(NSString *)captureSessionID
                        completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)completionHandler
{
    SCTraceODPCompatibleStart(2);
    if (captureResource.videoRecording) {
        if (completionHandler) {
            runOnMainThreadAsynchronously(^{
                completionHandler(SCVideoCaptureSessionInfoMake(kCMTimeInvalid, kCMTimeInvalid, 0),
                                  [NSError errorWithDomain:kSCManagedCapturerErrorDomain
                                                      code:kSCManagedCapturerRecordVideoBusy
                                                  userInfo:nil]);
            });
        }
        // Don't start recording session
        SCLogCapturerInfo(@"*** Tries to start multiple video recording session ***");
        return;
    }

    // Fix: https://jira.sc-corp.net/browse/CCAM-12322
    // Fire this notification in recording state to let PlaybackSession stop
    runOnMainThreadAsynchronously(^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kSCImageProcessVideoPlaybackStopNotification
                                                            object:[SCManagedCapturer sharedInstance]
                                                          userInfo:nil];
    });

    SCLogCapturerInfo(@"Start recording. OutputSettigns:%@, maxDuration:%f, fileURL:%@", outputSettings, maxDuration,
                      fileURL);
    // Turns on torch temporarily if we have Flash active
    if (!captureResource.state.torchActive) {
        if (captureResource.state.flashActive) {
            [captureResource.device setTorchActive:YES];

            if (captureResource.state.devicePosition == SCManagedCaptureDevicePositionFront) {
                captureResource.frontFlashController.torchActive = YES;
            }
        }
    }

    if (captureResource.device.softwareZoom) {
        captureResource.device.zoomFactor = 1;
        [SCCaptureWorker softwareZoomWithDevice:captureResource.device resource:captureResource];
    }

    // Lock focus on both front and back camera if not using ARKit
    if (!captureResource.state.arSessionActive) {
        SCManagedCaptureDevice *front = [SCManagedCaptureDevice front];
        SCManagedCaptureDevice *back = [SCManagedCaptureDevice back];
        [front setRecording:YES];
        [back setRecording:YES];
    }
    // Start streaming if we haven't already
    [self startStreaming:captureResource];
    // Remove other listeners from video streamer
    [captureResource.videoDataSource removeListener:captureResource.deviceCapacityAnalyzer];
    // If lenses is not actually applied, we should open sticky video tweak

    BOOL isLensApplied = [SCCaptureWorker isLensApplied:captureResource];
    [captureResource.videoDataSource setKeepLateFrames:!isLensApplied];
    SCLogCapturerInfo(@"Start recording. isLensApplied:%d", isLensApplied);

    [captureResource.videoDataSource addListener:captureResource.videoCapturer];
    captureResource.videoRecording = YES;
    if (captureResource.state.lensesActive) {
        BOOL modifySource = captureResource.videoRecording || captureResource.state.liveVideoStreaming;
        [captureResource.lensProcessingCore setModifySource:modifySource];
    }

    if (captureResource.fileInputDecider.shouldProcessFileInput) {
        [captureResource.videoDataSource stopStreaming];
    }
    // The max video duration, we will stop process sample buffer if the current
    // time is larger than max video duration.
    // 0.5 so that we have a bit of lean way on video recording initialization, and
    // when NSTimer stucked in normal
    // recording sessions, we don't suck too much as breaking expections on how long
    // it is recorded.
    SCVideoCaptureSessionInfo sessionInfo = [captureResource.videoCapturer
        startRecordingAsynchronouslyWithOutputSettings:outputSettings
                                    audioConfiguration:configuration
                                           maxDuration:maxDuration + 0.5
                                                 toURL:fileURL
                                          deviceFormat:captureResource.device.activeFormat
                                           orientation:AVCaptureVideoOrientationLandscapeLeft
                                      captureSessionID:captureSessionID];

    if (completionHandler) {
        runOnMainThreadAsynchronously(^{
            completionHandler(sessionInfo, nil);
        });
    }

    captureResource.droppedFramesReporter = [SCManagedDroppedFramesReporter new];
    [captureResource.videoDataSource addListener:captureResource.droppedFramesReporter];
    [[SCManagedCapturerV1 sharedInstance] addListener:captureResource.droppedFramesReporter];
}

+ (void)stopRecordingWithCaptureResource:(SCCaptureResource *)captureResource
{
    SCTraceStart();
    SCLogCapturerInfo(@"Stop recording asynchronously");
    [captureResource.videoCapturer stopRecordingAsynchronously];

    [captureResource.videoDataSource removeListener:captureResource.droppedFramesReporter];
    SCManagedDroppedFramesReporter *droppedFramesReporter = captureResource.droppedFramesReporter;
    [[SCManagedCapturerV1 sharedInstance] removeListener:captureResource.droppedFramesReporter];
    captureResource.droppedFramesReporter = nil;

    [captureResource.videoDataSource.performer perform:^{
        // call on the same performer as that of managedVideoDataSource: didOutputSampleBuffer: devicePosition:
        BOOL keepLateFrames = [captureResource.videoDataSource getKeepLateFrames];
        [droppedFramesReporter reportWithKeepLateFrames:keepLateFrames
                                          lensesApplied:[SCCaptureWorker isLensApplied:captureResource]];
        // Disable keepLateFrames once stop recording to make sure the recentness of preview
        [captureResource.videoDataSource setKeepLateFrames:NO];
    }];
}

+ (void)cancelRecordingWithCaptureResource:(SCCaptureResource *)captureResource
{
    SCTraceStart();
    SCLogCapturerInfo(@"Cancel recording asynchronously");
    [captureResource.videoDataSource removeListener:captureResource.droppedFramesReporter];
    [[SCManagedCapturerV1 sharedInstance] removeListener:captureResource.droppedFramesReporter];
    captureResource.droppedFramesReporter = nil;

    [captureResource.videoDataSource removeListener:captureResource.videoCapturer];
    // Add back other listeners to video streamer
    [captureResource.videoDataSource addListener:captureResource.deviceCapacityAnalyzer];
    [captureResource.videoCapturer cancelRecordingAsynchronously];

    captureResource.droppedFramesReporter = nil;
}

+ (SCVideoCaptureSessionInfo)activeSession:(SCCaptureResource *)resource
{
    if (resource.videoCapturer == nil) {
        SCLogCapturerWarning(
            @"Trying to retrieve SCVideoCaptureSessionInfo while _captureResource.videoCapturer is nil.");
        return SCVideoCaptureSessionInfoMake(kCMTimeInvalid, kCMTimeInvalid, 0);
    } else {
        return resource.videoCapturer.activeSession;
    }
}

+ (BOOL)canRunARSession:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    if (@available(iOS 11.0, *)) {
        return resource.state.lensesActive &&
               [ARConfiguration sc_supportedForDevicePosition:resource.state.devicePosition];
    }
    return NO;
}

+ (void)turnARSessionOff:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCAssert([resource.queuePerformer isCurrentPerformer], @"");
    if (@available(iOS 11.0, *)) {
        SC_GUARD_ELSE_RETURN(resource.state.arSessionActive);
        SCLogCapturerInfo(@"Stopping ARSession");

        [resource.arSessionHandler stopARSessionRunning];
        [resource.managedSession performConfiguration:^{
            [resource.device updateActiveFormatWithSession:resource.managedSession.avSession];
        }];
        [resource.managedSession startRunning];
        resource.state =
            [[[SCManagedCapturerStateBuilder withManagedCapturerState:resource.state] setArSessionActive:NO] build];
        [resource.lensProcessingCore setShouldProcessARFrames:resource.state.arSessionActive];
        [self clearARKitData:resource];
        [self updateLensesFieldOfViewTracking:resource];
        runOnMainThreadAsynchronously(^{
            [resource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didChangeState:resource.state];
            [resource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                       didChangeARSessionActive:resource.state];
            [[SCManagedCapturerV1 sharedInstance] unlockZoomWithContext:SCCapturerContext];
        });
    };
}

+ (void)clearARKitData:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    if (@available(iOS 11.0, *)) {
        if ([resource.videoDataSource conformsToProtocol:@protocol(SCManagedVideoARDataSource)]) {
            id<SCManagedVideoARDataSource> dataSource = (id<SCManagedVideoARDataSource>)resource.videoDataSource;
            dataSource.currentFrame = nil;
#ifdef SC_USE_ARKIT_FACE
            dataSource.lastDepthData = nil;
#endif
        }
    }
}

+ (void)turnARSessionOn:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCAssert([resource.queuePerformer isCurrentPerformer], @"");
    if (@available(iOS 11.0, *)) {
        SC_GUARD_ELSE_RETURN(!resource.state.arSessionActive);
        SC_GUARD_ELSE_RETURN([self canRunARSession:resource]);
        SCLogCapturerInfo(@"Starting ARSession");
        resource.state =
            [[[SCManagedCapturerStateBuilder withManagedCapturerState:resource.state] setArSessionActive:YES] build];
        // Make sure we commit any configurations that may be in flight.
        [resource.videoDataSource commitConfiguration];

        runOnMainThreadAsynchronously(^{
            [resource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didChangeState:resource.state];
            [resource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                       didChangeARSessionActive:resource.state];
            // Zooming on an ARSession breaks stuff in super weird ways.
            [[SCManagedCapturerV1 sharedInstance] lockZoomWithContext:SCCapturerContext];
        });
        [self clearARKitData:resource];
        [resource.managedSession stopRunning];
        [resource.arSession
            runWithConfiguration:[ARConfiguration sc_configurationForDevicePosition:resource.state.devicePosition]
                         options:(ARSessionRunOptionResetTracking | ARSessionRunOptionRemoveExistingAnchors)];

        [resource.lensProcessingCore setShouldProcessARFrames:resource.state.arSessionActive];
        [self updateLensesFieldOfViewTracking:resource];
    }
}

+ (void)configBlackCameraDetectorWithCaptureResource:(SCCaptureResource *)captureResource
{
    captureResource.captureSessionFixer = [[SCCaptureSessionFixer alloc] init];
    captureResource.blackCameraDetector.blackCameraNoOutputDetector.delegate = captureResource.captureSessionFixer;
    [captureResource.videoDataSource addListener:captureResource.blackCameraDetector.blackCameraNoOutputDetector];
}

+ (void)configureCaptureFaceDetectorWithCaptureResource:(SCCaptureResource *)captureResource
{
    if (SCCameraFaceFocusDetectionMethod() == SCCameraFaceFocusDetectionMethodTypeCIDetector) {
        SCCaptureCoreImageFaceDetector *detector =
            [[SCCaptureCoreImageFaceDetector alloc] initWithCaptureResource:captureResource];
        captureResource.captureFaceDetector = detector;
        [captureResource.videoDataSource addListener:detector];
    } else {
        captureResource.captureFaceDetector =
            [[SCCaptureMetadataOutputDetector alloc] initWithCaptureResource:captureResource];
    }
}

+ (void)configCaptureDeviceHandlerWithCaptureResource:(SCCaptureResource *)captureResource
{
    captureResource.device.delegate = captureResource.captureDeviceHandler;
}

+ (void)updateLensesFieldOfViewTracking:(SCCaptureResource *)captureResource
{
    // 1. reset observers
    [captureResource.lensProcessingCore removeFieldOfViewListener];

    if (@available(iOS 11.0, *)) {
        if (captureResource.state.arSessionActive &&
            [captureResource.videoDataSource conformsToProtocol:@protocol(SCManagedVideoARDataSource)]) {
            // 2. handle ARKit case
            id<SCManagedVideoARDataSource> arDataSource =
                (id<SCManagedVideoARDataSource>)captureResource.videoDataSource;
            float fieldOfView = arDataSource.fieldOfView;
            if (fieldOfView > 0) {
                // 2.5 there will be no field of view
                [captureResource.lensProcessingCore setFieldOfView:fieldOfView];
            }
            [captureResource.lensProcessingCore setAsFieldOfViewListenerForARDataSource:arDataSource];
            return;
        }
    }
    // 3. fallback to regular device field of view
    float fieldOfView = captureResource.device.fieldOfView;
    [captureResource.lensProcessingCore setFieldOfView:fieldOfView];
    [captureResource.lensProcessingCore setAsFieldOfViewListenerForDevice:captureResource.device];
}

+ (CMTime)firstWrittenAudioBufferDelay:(SCCaptureResource *)resource
{
    return resource.videoCapturer.firstWrittenAudioBufferDelay;
}

+ (BOOL)audioQueueStarted:(SCCaptureResource *)resource
{
    return resource.videoCapturer.audioQueueStarted;
}

+ (BOOL)isLensApplied:(SCCaptureResource *)resource
{
    return resource.state.lensesActive && resource.lensProcessingCore.isLensApplied;
}

+ (BOOL)isVideoMirrored:(SCCaptureResource *)resource
{
    if ([resource.videoDataSource respondsToSelector:@selector(isVideoMirrored)]) {
        return [resource.videoDataSource isVideoMirrored];
    } else {
        // Default is NO.
        return NO;
    }
}

+ (BOOL)shouldCaptureImageFromVideoWithResource:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    BOOL isIphone5Series = [SCDeviceName isSimilarToIphone5orNewer] && ![SCDeviceName isSimilarToIphone6orNewer];
    return isIphone5Series && !resource.state.flashActive && ![SCCaptureWorker isLensApplied:resource];
}

+ (void)setPortraitModePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                   completionHandler:(dispatch_block_t)completionHandler
                                            resource:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    if (resource.state.isPortraitModeActive) {
        SCTraceODPCompatibleStart(2);
        [resource.queuePerformer perform:^{
            SCTraceStart();
            if (resource.device.isConnected) {
                if (resource.device.softwareZoom) {
                    CGPoint adjustedPoint = CGPointMake((pointOfInterest.x - 0.5) / resource.device.softwareZoom + 0.5,
                                                        (pointOfInterest.y - 0.5) / resource.device.softwareZoom + 0.5);
                    // Fix for the zooming factor
                    [resource.videoDataSource setPortraitModePointOfInterest:adjustedPoint];
                    if (resource.state.arSessionActive) {
                        if (@available(ios 11.0, *)) {
                            [resource.arImageCapturer setPortraitModePointOfInterest:adjustedPoint];
                        }
                    } else {
                        [resource.stillImageCapturer setPortraitModePointOfInterest:adjustedPoint];
                    }
                } else {
                    [resource.videoDataSource setPortraitModePointOfInterest:pointOfInterest];
                    if (resource.state.arSessionActive) {
                        if (@available(ios 11.0, *)) {
                            [resource.arImageCapturer setPortraitModePointOfInterest:pointOfInterest];
                        }
                    } else {
                        [resource.stillImageCapturer setPortraitModePointOfInterest:pointOfInterest];
                    }
                }
            }
            if (completionHandler) {
                runOnMainThreadAsynchronously(completionHandler);
            }
        }];
    }
}

+ (void)prepareForRecordingWithAudioConfiguration:(SCAudioConfiguration *)configuration
                                         resource:(SCCaptureResource *)resource
{
    SCAssertPerformer(resource.queuePerformer);
    [resource.videoCapturer prepareForRecordingWithAudioConfiguration:configuration];
}

+ (void)stopScanWithCompletionHandler:(dispatch_block_t)completionHandler resource:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Stop scan");
    [resource.videoScanner stopScanAsynchronously];
    if (completionHandler) {
        runOnMainThreadAsynchronously(completionHandler);
    }
}

+ (void)startScanWithScanConfiguration:(SCScanConfiguration *)configuration resource:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Start scan. ScanConfiguration:%@", configuration);
    [SCCaptureWorker startStreaming:resource];
    [resource.videoScanner startScanAsynchronouslyWithScanConfiguration:configuration];
}
@end
