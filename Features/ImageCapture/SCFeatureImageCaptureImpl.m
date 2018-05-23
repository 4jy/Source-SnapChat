//
//  SCFeatureImageCaptureImpl.m
//  SCCamera
//
//  Created by Kristian Bauer on 4/18/18.
//

#import "SCFeatureImageCaptureImpl.h"

#import "SCLogger+Camera.h"
#import "SCManagedCapturePreviewLayerController.h"
#import "SCManagedCapturerLensAPI.h"
#import "SCManagedCapturerListener.h"
#import "SCManagedCapturerUtils.h"
#import "SCManagedStillImageCapturer.h"

#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCGhostToSnappable/SCGhostToSnappableSignal.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger+Performance.h>

@interface SCFeatureImageCaptureImpl ()
@property (nonatomic, strong, readwrite) id<SCCapturer> capturer;
@property (nonatomic, strong, readwrite) SCLogger *logger;
@property (nonatomic, assign) AVCameraViewType cameraViewType;
@property (nonatomic, strong, readwrite) SCManagedCapturerState *managedCapturerState;

/**
 * Whether user has attempted image capture in current session. Reset on foreground of app.
 */
@property (nonatomic, assign) BOOL hasTriedCapturing;
@end

@interface SCFeatureImageCaptureImpl (SCManagedCapturerListener) <SCManagedCapturerListener>
@end

@implementation SCFeatureImageCaptureImpl
@synthesize delegate = _delegate;
@synthesize imagePromise = _imagePromise;

- (instancetype)initWithCapturer:(id<SCCapturer>)capturer
                          logger:(SCLogger *)logger
                  cameraViewType:(AVCameraViewType)cameraViewType
{
    SCTraceODPCompatibleStart(2);
    self = [super init];
    if (self) {
        _capturer = capturer;
        [_capturer addListener:self];
        _logger = logger;
        _cameraViewType = cameraViewType;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_viewWillEnterForeground)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
    }
    return self;
}

- (void)dealloc
{
    [_capturer removeListener:self];
}

#pragma mark - SCFeatureImageCapture

- (void)captureImage:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    [_logger logTimedEventStart:kSCCameraMetricsRecordingDelay uniqueId:@"IMAGE" isUniqueEvent:NO];
    BOOL asyncCaptureEnabled = [self _asynchronousCaptureEnabled:_managedCapturerState];
    SCLogCameraFeatureInfo(@"[%@] takeImage begin async: %@", NSStringFromClass([self class]),
                           asyncCaptureEnabled ? @"YES" : @"NO");

    if (asyncCaptureEnabled) {
        SCQueuePerformer *performer = [[SCQueuePerformer alloc] initWithLabel:"com.snapchat.image-capture-promise"
                                                             qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                                    queueType:DISPATCH_QUEUE_SERIAL
                                                                      context:SCQueuePerformerContextCoreCamera];
        _imagePromise = [[SCPromise alloc] initWithPerformer:performer];
    }

    @weakify(self);
    [_capturer captureStillImageAsynchronouslyWithAspectRatio:SCManagedCapturedImageAndVideoAspectRatio()
                                             captureSessionID:captureSessionID
                                            completionHandler:^(UIImage *fullScreenImage, NSDictionary *metadata,
                                                                NSError *error, SCManagedCapturerState *state) {
                                                @strongify(self);
                                                SC_GUARD_ELSE_RETURN(self);
                                                [self _takeImageCallback:fullScreenImage
                                                                metadata:metadata
                                                                   error:error
                                                                   state:state];
                                            }
                                                      context:SCCapturerContext];
    [_logger logCameraCaptureFinishedWithDuration:0];
}

#pragma mark - Private

- (void)_viewWillEnterForeground
{
    SCTraceODPCompatibleStart(2);
    _hasTriedCapturing = NO;
}

- (void)_takeImageCallback:(UIImage *)image
                  metadata:(NSDictionary *)metadata
                     error:(NSError *)error
                     state:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    [self _logCaptureComplete:state];

    if (image) {
        [_delegate featureImageCapture:self willCompleteWithImage:image];
        if (_imagePromise) {
            [_imagePromise completeWithValue:image];
        }
    } else {
        if (_imagePromise) {
            [_imagePromise completeWithError:[NSError errorWithDomain:@"" code:-1 userInfo:nil]];
        }
        [_delegate featureImageCapture:self didCompleteWithError:error];
    }
    _imagePromise = nil;
    [_delegate featureImageCapturedDidComplete:self];
}

- (BOOL)_asynchronousCaptureEnabled:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    BOOL shouldCaptureImageFromVideoBuffer =
        [SCDeviceName isSimilarToIphone5orNewer] && ![SCDeviceName isSimilarToIphone6orNewer];
    // Fast image capture is disabled in following cases
    // (1) flash is on;
    // (2) lenses are active;
    // (3) SCPhotoCapturer is not supported;
    // (4) not main camera for iPhoneX;
    return !state.flashActive && !state.lensesActive && !_capturer.lensProcessingCore.appliedLens &&
           (SCPhotoCapturerIsEnabled() || shouldCaptureImageFromVideoBuffer) &&
           (![SCDeviceName isIphoneX] || (_cameraViewType == AVCameraViewNoReply));
}

- (void)_logCaptureComplete:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    NSDictionary *params = @{
        @"type" : @"image",
        @"lenses_active" : @(state.lensesActive),
        @"is_back_camera" : @(state.devicePosition != SCManagedCaptureDevicePositionFront),
        @"is_main_camera" : @(_cameraViewType == AVCameraViewNoReply),
        @"is_first_attempt_after_app_startup" : @(!_hasTriedCapturing),
        @"app_startup_type" : SCLaunchType(),
        @"app_startup_time" : @(SCAppStartupTimeMicros() / 1000.0),
        @"time_elapse_after_app_startup" : @(SCTimeElapseAfterAppStartupMicros() / 1000.0),
    };
    [_logger logTimedEventEnd:kSCCameraMetricsRecordingDelay uniqueId:@"IMAGE" parameters:params];
    _hasTriedCapturing = YES;
}

@end

@implementation SCFeatureImageCaptureImpl (SCManagedCapturerListener)

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeState:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    _managedCapturerState = [state copy];
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didCapturePhoto:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    if (_imagePromise) {
        [[SCManagedCapturePreviewLayerController sharedInstance] pause];
    }
}

@end
