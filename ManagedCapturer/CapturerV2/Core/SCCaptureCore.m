//
//  SCCaptureCore.m
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//
//

#import "SCCaptureCore.h"

#import "SCCaptureDeviceAuthorizationChecker.h"
#import "SCCaptureResource.h"
#import "SCCaptureWorker.h"
#import "SCManagedCapturePreviewLayerController.h"
#import "SCManagedCapturerGLViewManagerAPI.h"
#import "SCManagedCapturerLSAComponentTrackerAPI.h"
#import "SCManagedCapturerV1_Private.h"

#import <SCAudio/SCAudioConfiguration.h>
#import <SCFoundation/SCAssertWrapper.h>

static const char *kSCCaptureDeviceAuthorizationManagerQueueLabel =
    "com.snapchat.capture_device_authorization_checker_queue";

@implementation SCCaptureCore {
    SCManagedCapturerV1 *_managedCapturerV1;
    SCQueuePerformer *_queuePerformer;
    SCCaptureDeviceAuthorizationChecker *_authorizationChecker;
}
@synthesize blackCameraDetector = _blackCameraDetector;

- (instancetype)init
{
    SCTraceStart();
    SCAssertMainThread();
    self = [super init];
    if (self) {
        _managedCapturerV1 = [SCManagedCapturerV1 sharedInstance];
        SCCaptureResource *resource = _managedCapturerV1.captureResource;
        _queuePerformer = resource.queuePerformer;
        _stateMachine = [[SCCaptureStateMachineContext alloc] initWithResource:resource];
        SCQueuePerformer *authorizationCheckPerformer =
            [[SCQueuePerformer alloc] initWithLabel:kSCCaptureDeviceAuthorizationManagerQueueLabel
                                   qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                          queueType:DISPATCH_QUEUE_SERIAL
                                            context:SCQueuePerformerContextCamera];
        _authorizationChecker =
            [[SCCaptureDeviceAuthorizationChecker alloc] initWithPerformer:authorizationCheckPerformer];
    }
    return self;
}

- (id<SCManagedCapturerLensAPI>)lensProcessingCore
{
    return _managedCapturerV1.lensProcessingCore;
}

// For APIs inside protocol SCCapture, if they are related to capture state machine, we delegate to state machine.
- (void)setupWithDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                            completionHandler:(dispatch_block_t)completionHandler
                                      context:(NSString *)context
{
    [_stateMachine initializeCaptureWithDevicePositionAsynchronously:devicePosition
                                                   completionHandler:completionHandler
                                                             context:context];
}

- (SCCapturerToken *)startRunningAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                             context:(NSString *)context
{
    return [_stateMachine startRunningWithContext:context completionHandler:completionHandler];
}

#pragma mark - Recording / Capture

- (void)captureStillImageAsynchronouslyWithAspectRatio:(CGFloat)aspectRatio
                                      captureSessionID:(NSString *)captureSessionID
                                     completionHandler:
                                         (sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                                               context:(NSString *)context
{
    [_stateMachine captureStillImageAsynchronouslyWithAspectRatio:aspectRatio
                                                 captureSessionID:captureSessionID
                                                completionHandler:completionHandler
                                                          context:context];
}

- (void)stopRunningAsynchronously:(SCCapturerToken *)token
                completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                          context:(NSString *)context
{
    [_stateMachine stopRunningWithCapturerToken:token completionHandler:completionHandler context:context];
}

- (void)stopRunningAsynchronously:(SCCapturerToken *)token
                completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                            after:(NSTimeInterval)delay
                          context:(NSString *)context
{
    [_stateMachine stopRunningWithCapturerToken:token after:delay completionHandler:completionHandler context:context];
}

#pragma mark - Scanning

- (void)startScanAsynchronouslyWithScanConfiguration:(SCScanConfiguration *)configuration context:(NSString *)context
{
    [_stateMachine startScanAsynchronouslyWithScanConfiguration:configuration context:context];
}

- (void)stopScanAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler context:(NSString *)context
{
    [_stateMachine stopScanAsynchronouslyWithCompletionHandler:completionHandler context:context];
}

- (void)prepareForRecordingAsynchronouslyWithContext:(NSString *)context
                                  audioConfiguration:(SCAudioConfiguration *)configuration
{
    [_stateMachine prepareForRecordingAsynchronouslyWithAudioConfiguration:configuration context:context];
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
    [_stateMachine startRecordingWithOutputSettings:outputSettings
                                 audioConfiguration:configuration
                                        maxDuration:maxDuration
                                            fileURL:fileURL
                                   captureSessionID:captureSessionID
                                  completionHandler:completionHandler
                                            context:context];
}

- (void)stopRecordingAsynchronouslyWithContext:(NSString *)context
{
    [_stateMachine stopRecordingWithContext:context];
}

- (void)cancelRecordingAsynchronouslyWithContext:(NSString *)context
{
    [_stateMachine cancelRecordingWithContext:context];
    [[self snapCreationTriggers] markSnapCreationEndWithContext:context];
}

#pragma mark -

- (void)startStreamingAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                  context:(NSString *)context
{
    [_managedCapturerV1 startStreamingAsynchronouslyWithCompletionHandler:completionHandler context:context];
}
- (void)addSampleBufferDisplayController:(id<SCManagedSampleBufferDisplayController>)sampleBufferDisplayController
                                 context:(NSString *)context
{
    [_managedCapturerV1 addSampleBufferDisplayController:sampleBufferDisplayController context:context];
}

#pragma mark - Utilities

- (void)convertViewCoordinates:(CGPoint)viewCoordinates
             completionHandler:(sc_managed_capturer_convert_view_coordniates_completion_handler_t)completionHandler
                       context:(NSString *)context
{
    [_managedCapturerV1 convertViewCoordinates:viewCoordinates completionHandler:completionHandler context:context];
}

- (void)detectLensCategoryOnNextFrame:(CGPoint)point
                               lenses:(NSArray<SCLens *> *)lenses
                           completion:(sc_managed_lenses_processor_category_point_completion_handler_t)completion
                              context:(NSString *)context
{
    [_managedCapturerV1 detectLensCategoryOnNextFrame:point lenses:lenses completion:completion context:context];
}

#pragma mark - Configurations

- (void)setDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                      completionHandler:(dispatch_block_t)completionHandler
                                context:(NSString *)context
{
    [_managedCapturerV1 setDevicePositionAsynchronously:devicePosition
                                      completionHandler:completionHandler
                                                context:context];
}

- (void)setFlashActive:(BOOL)flashActive
     completionHandler:(dispatch_block_t)completionHandler
               context:(NSString *)context
{
    [_managedCapturerV1 setFlashActive:flashActive completionHandler:completionHandler context:context];
}

- (void)setLensesActive:(BOOL)lensesActive
      completionHandler:(dispatch_block_t)completionHandler
                context:(NSString *)context
{
    [_managedCapturerV1 setLensesActive:lensesActive completionHandler:completionHandler context:context];
}

- (void)setLensesActive:(BOOL)lensesActive
          filterFactory:(SCLookseryFilterFactory *)filterFactory
      completionHandler:(dispatch_block_t)completionHandler
                context:(NSString *)context
{
    [_managedCapturerV1 setLensesActive:lensesActive
                          filterFactory:filterFactory
                      completionHandler:completionHandler
                                context:context];
}

- (void)setLensesInTalkActive:(BOOL)lensesActive
            completionHandler:(dispatch_block_t)completionHandler
                      context:(NSString *)context
{
    [_managedCapturerV1 setLensesInTalkActive:lensesActive completionHandler:completionHandler context:context];
}

- (void)setTorchActiveAsynchronously:(BOOL)torchActive
                   completionHandler:(dispatch_block_t)completionHandler
                             context:(NSString *)context
{
    [_managedCapturerV1 setTorchActiveAsynchronously:torchActive completionHandler:completionHandler context:context];
}

- (void)setNightModeActiveAsynchronously:(BOOL)active
                       completionHandler:(dispatch_block_t)completionHandler
                                 context:(NSString *)context
{
    [_managedCapturerV1 setNightModeActiveAsynchronously:active completionHandler:completionHandler context:context];
}

- (void)lockZoomWithContext:(NSString *)context
{
    [_managedCapturerV1 lockZoomWithContext:context];
}

- (void)unlockZoomWithContext:(NSString *)context
{
    [_managedCapturerV1 unlockZoomWithContext:context];
}

- (void)setZoomFactorAsynchronously:(CGFloat)zoomFactor context:(NSString *)context
{
    [_managedCapturerV1 setZoomFactorAsynchronously:zoomFactor context:context];
}

- (void)resetZoomFactorAsynchronously:(CGFloat)zoomFactor
                       devicePosition:(SCManagedCaptureDevicePosition)devicePosition
                              context:(NSString *)context
{
    [_managedCapturerV1 resetZoomFactorAsynchronously:zoomFactor devicePosition:devicePosition context:context];
}

- (void)setExposurePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                        fromUser:(BOOL)fromUser
                               completionHandler:(dispatch_block_t)completionHandler
                                         context:(NSString *)context
{
    [_managedCapturerV1 setExposurePointOfInterestAsynchronously:pointOfInterest
                                                        fromUser:fromUser
                                               completionHandler:completionHandler
                                                         context:context];
}

- (void)setAutofocusPointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                completionHandler:(dispatch_block_t)completionHandler
                                          context:(NSString *)context
{
    [_managedCapturerV1 setAutofocusPointOfInterestAsynchronously:pointOfInterest
                                                completionHandler:completionHandler
                                                          context:context];
}

- (void)setPortraitModePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                   completionHandler:(dispatch_block_t)completionHandler
                                             context:(NSString *)context
{
    [_managedCapturerV1 setPortraitModePointOfInterestAsynchronously:pointOfInterest
                                                   completionHandler:completionHandler
                                                             context:context];
}

- (void)continuousAutofocusAndExposureAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                                  context:(NSString *)context
{
    [_managedCapturerV1 continuousAutofocusAndExposureAsynchronouslyWithCompletionHandler:completionHandler
                                                                                  context:context];
}

// I need to call these three methods from SCAppDelegate explicitly so that I get the latest information.
- (void)applicationDidEnterBackground
{
    [_managedCapturerV1 applicationDidEnterBackground];
}

- (void)applicationWillEnterForeground
{
    [_managedCapturerV1 applicationWillEnterForeground];
}

- (void)applicationDidBecomeActive
{
    [_managedCapturerV1 applicationDidBecomeActive];
}
- (void)applicationWillResignActive
{
    [_managedCapturerV1 applicationWillResignActive];
}

- (void)mediaServicesWereReset
{
    [_managedCapturerV1 mediaServicesWereReset];
}

- (void)mediaServicesWereLost
{
    [_managedCapturerV1 mediaServicesWereLost];
}

#pragma mark - Add / Remove Listener

- (void)addListener:(id<SCManagedCapturerListener>)listener
{
    [_managedCapturerV1 addListener:listener];
}

- (void)removeListener:(id<SCManagedCapturerListener>)listener
{
    [_managedCapturerV1 removeListener:listener];
}

- (void)addVideoDataSourceListener:(id<SCManagedVideoDataSourceListener>)listener
{
    [_managedCapturerV1 addVideoDataSourceListener:listener];
}

- (void)removeVideoDataSourceListener:(id<SCManagedVideoDataSourceListener>)listener
{
    [_managedCapturerV1 removeVideoDataSourceListener:listener];
}

- (void)addDeviceCapacityAnalyzerListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener
{
    [_managedCapturerV1 addDeviceCapacityAnalyzerListener:listener];
}

- (void)removeDeviceCapacityAnalyzerListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener
{
    [_managedCapturerV1 removeDeviceCapacityAnalyzerListener:listener];
}

- (NSString *)debugInfo
{
    return [_managedCapturerV1 debugInfo];
}

- (id<SCManagedVideoDataSource>)currentVideoDataSource
{
    return [_managedCapturerV1 currentVideoDataSource];
}

// For APIs inside protocol SCCapture, if they are not related to capture state machine, we directly delegate to V1.
- (void)checkRestrictedCamera:(void (^)(BOOL, BOOL, AVAuthorizationStatus))callback
{
    [_managedCapturerV1 checkRestrictedCamera:callback];
}

- (void)recreateAVCaptureSession
{
    [_managedCapturerV1 recreateAVCaptureSession];
}

#pragma mark -
- (CMTime)firstWrittenAudioBufferDelay
{
    return [SCCaptureWorker firstWrittenAudioBufferDelay:_managedCapturerV1.captureResource];
}

- (BOOL)audioQueueStarted
{
    return [SCCaptureWorker audioQueueStarted:_managedCapturerV1.captureResource];
}

- (BOOL)isLensApplied
{
    return [SCCaptureWorker isLensApplied:_managedCapturerV1.captureResource];
}

- (BOOL)isVideoMirrored
{
    return [SCCaptureWorker isVideoMirrored:_managedCapturerV1.captureResource];
}

- (SCVideoCaptureSessionInfo)activeSession
{
    return _managedCapturerV1.activeSession;
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
    _managedCapturerV1.captureResource.blackCameraDetector = blackCameraDetector;
    _managedCapturerV1.captureResource.deviceMotionProvider = deviceMotionProvider;
    _managedCapturerV1.captureResource.fileInputDecider = fileInputDecider;
    _managedCapturerV1.captureResource.arImageCaptureProvider = arImageCaptureProvider;
    _managedCapturerV1.captureResource.videoPreviewGLViewManager = glViewManager;
    [_managedCapturerV1.captureResource.videoPreviewGLViewManager
        configureWithCaptureResource:_managedCapturerV1.captureResource];
    _managedCapturerV1.captureResource.lensAPIProvider = lensAPIProvider;
    _managedCapturerV1.captureResource.lsaTrackingComponentHandler = lsaComponentTracker;
    [_managedCapturerV1.captureResource.lsaTrackingComponentHandler
        configureWithCaptureResource:_managedCapturerV1.captureResource];
    _managedCapturerV1.captureResource.previewLayerControllerDelegate = previewLayerControllerDelegate;
    [SCManagedCapturePreviewLayerController sharedInstance].delegate =
        _managedCapturerV1.captureResource.previewLayerControllerDelegate;
}

- (SCBlackCameraDetector *)blackCameraDetector
{
    return _managedCapturerV1.captureResource.blackCameraDetector;
}

- (void)captureSingleVideoFrameAsynchronouslyWithCompletionHandler:
            (sc_managed_capturer_capture_video_frame_completion_handler_t)completionHandler
                                                           context:(NSString *)context
{
    [_managedCapturerV1 captureSingleVideoFrameAsynchronouslyWithCompletionHandler:completionHandler context:context];
}

- (void)sampleFrameWithCompletionHandler:(void (^)(UIImage *frame, CMTime presentationTime))completionHandler
                                 context:(NSString *)context
{
    [_managedCapturerV1 sampleFrameWithCompletionHandler:completionHandler context:context];
}

- (void)addTimedTask:(SCTimedTask *)task context:(NSString *)context
{
    [_managedCapturerV1 addTimedTask:task context:context];
}

- (void)clearTimedTasksWithContext:(NSString *)context
{
    [_managedCapturerV1 clearTimedTasksWithContext:context];
}

- (BOOL)authorizedForVideoCapture
{
    return [_authorizationChecker authorizedForVideoCapture];
}

- (void)preloadVideoCaptureAuthorization
{
    [_authorizationChecker preloadVideoCaptureAuthorization];
}

#pragma mark - Snap Creation triggers

- (SCSnapCreationTriggers *)snapCreationTriggers
{
    return [_managedCapturerV1 snapCreationTriggers];
}

@end
