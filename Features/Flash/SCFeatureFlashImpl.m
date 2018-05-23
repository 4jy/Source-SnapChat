//
//  SCFeatureFlashImpl.m
//  SCCamera
//
//  Created by Kristian Bauer on 3/27/18.
//

#import "SCFeatureFlashImpl.h"

#import "SCCapturer.h"
#import "SCFlashButton.h"
#import "SCManagedCapturerListener.h"
#import "SCManagedCapturerState.h"

#import <SCFoundation/SCLocale.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCLogger/SCLogger.h>
#import <SCUIKit/SCNavigationBarButtonItem.h>

static CGFloat const kSCFlashButtonInsets = -2.f;
static CGRect const kSCFlashButtonFrame = {0, 0, 36, 44};

static NSString *const kSCFlashEventName = @"TOGGLE_CAMERA_FLASH_BUTTON";
static NSString *const kSCFlashEventParameterFlashName = @"flash_on";
static NSString *const kSCFlashEventParameterCameraName = @"front_facing_camera_on";

@interface SCFeatureFlashImpl ()
@property (nonatomic, strong, readwrite) id<SCCapturer> capturer;
@property (nonatomic, strong, readwrite) SCLogger *logger;
@property (nonatomic, strong, readwrite) SCFlashButton *flashButton;
@property (nonatomic, weak, readwrite) UIView<SCFeatureContainerView> *containerView;
@property (nonatomic, strong, readwrite) SCManagedCapturerState *managedCapturerState;
@property (nonatomic, assign, readwrite) BOOL canEnable;
@end

@interface SCFeatureFlashImpl (SCManagedCapturerListener) <SCManagedCapturerListener>
@end

@implementation SCFeatureFlashImpl
@synthesize navigationBarButtonItem = _navigationBarButtonItem;

- (instancetype)initWithCapturer:(id<SCCapturer>)capturer logger:(SCLogger *)logger
{
    SCTraceODPCompatibleStart(2);
    self = [super init];
    if (self) {
        _capturer = capturer;
        [_capturer addListener:self];
        _logger = logger;
    }
    return self;
}

- (void)dealloc
{
    SCTraceODPCompatibleStart(2);
    [_capturer removeListener:self];
}

#pragma mark - SCFeature

- (void)configureWithView:(UIView<SCFeatureContainerView> *)view
{
    SCTraceODPCompatibleStart(2);
    _containerView = view;
}

- (BOOL)shouldBlockTouchAtPoint:(CGPoint)point
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN_VALUE(_flashButton.userInteractionEnabled && !_flashButton.hidden, NO);
    CGPoint convertedPoint = [_flashButton convertPoint:point fromView:_containerView];
    return [_flashButton pointInside:convertedPoint withEvent:nil];
}

#pragma mark - SCFeatureFlash

- (void)interruptGestures
{
    SCTraceODPCompatibleStart(2);
    [_flashButton interruptGestures];
}

- (SCNavigationBarButtonItem *)navigationBarButtonItem
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN_VALUE(!_navigationBarButtonItem, _navigationBarButtonItem);
    _navigationBarButtonItem = [[SCNavigationBarButtonItem alloc] initWithCustomView:self.flashButton];
    return _navigationBarButtonItem;
}

#pragma mark - Getters

- (SCFlashButton *)flashButton
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN_VALUE(!_flashButton, _flashButton);
    _flashButton = [[SCFlashButton alloc] initWithFrame:kSCFlashButtonFrame];
    _flashButton.layer.sublayerTransform = CATransform3DMakeTranslation(kSCFlashButtonInsets, 0, 0);
    _flashButton.buttonState = SCFlashButtonStateOff;
    _flashButton.maximumScale = 1.1111f;
    [_flashButton addTarget:self action:@selector(_flashTapped)];

    _flashButton.accessibilityIdentifier = @"flash";
    _flashButton.accessibilityLabel = SCLocalizedString(@"flash", 0);
    return _flashButton;
}

#pragma mark - Setters

- (void)setCanEnable:(BOOL)canEnable
{
    SCTraceODPCompatibleStart(2);
    SCLogCameraFeatureInfo(@"[%@] setCanEnable new: %@ old: %@", NSStringFromClass([self class]),
                           canEnable ? @"YES" : @"NO", _canEnable ? @"YES" : @"NO");
    self.flashButton.userInteractionEnabled = canEnable;
}

#pragma mark - Internal Helpers

- (void)_flashTapped
{
    SCTraceODPCompatibleStart(2);
    BOOL flashActive = !_managedCapturerState.flashActive;

    SCLogCameraFeatureInfo(@"[%@] _flashTapped flashActive new: %@ old: %@", NSStringFromClass([self class]),
                           flashActive ? @"YES" : @"NO", !flashActive ? @"YES" : @"NO");
    _containerView.userInteractionEnabled = NO;
    @weakify(self);
    [_capturer setFlashActive:flashActive
            completionHandler:^{
                @strongify(self);
                SCLogCameraFeatureInfo(@"[%@] _flashTapped setFlashActive completion", NSStringFromClass([self class]));
                self.containerView.userInteractionEnabled = YES;
            }
                      context:SCCapturerContext];

    NSDictionary *loggingParameters = @{
        kSCFlashEventParameterFlashName : @(flashActive),
        kSCFlashEventParameterCameraName :
            @(_managedCapturerState.devicePosition == SCManagedCaptureDevicePositionFront)
    };
    [_logger logEvent:kSCFlashEventName parameters:loggingParameters];
}

- (BOOL)_shouldHideForState:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    return (!state.flashSupported && !state.torchSupported &&
            state.devicePosition != SCManagedCaptureDevicePositionFront) ||
           state.arSessionActive;
}

@end

@implementation SCFeatureFlashImpl (SCManagedCapturerListener)

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeFlashActive:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    SCLogCameraFeatureInfo(@"[%@] didChangeFlashActive flashActive: %@", NSStringFromClass([self class]),
                           state.flashActive ? @"YES" : @"NO");
    self.flashButton.buttonState = state.flashActive ? SCFlashButtonStateOn : SCFlashButtonStateOff;
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didChangeFlashSupportedAndTorchSupported:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    SCLogCameraFeatureInfo(
        @"[%@] didChangeFlashSupportedAndTorchSupported flashSupported: %@ torchSupported: %@ devicePosition: %@",
        NSStringFromClass([self class]), state.flashSupported ? @"YES" : @"NO", state.torchSupported ? @"YES" : @"NO",
        state.devicePosition == SCManagedCaptureDevicePositionFront ? @"front" : @"back");
    self.flashButton.hidden = [self _shouldHideForState:state];
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeState:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    _managedCapturerState = [state copy];
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeARSessionActive:(SCManagedCapturerState *)state
{
    SCTraceODPCompatibleStart(2);
    SCLogCameraFeatureInfo(@"[%@] didChangeARSessionActive: %@", NSStringFromClass([self class]),
                           state.arSessionActive ? @"YES" : @"NO");
    self.flashButton.hidden = [self _shouldHideForState:state];
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
 didBeginVideoRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session
{
    SCTraceODPCompatibleStart(2);
    self.canEnable = NO;
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
     didFinishRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session
          recordedVideo:(SCManagedRecordedVideo *)recordedVideo
{
    SCTraceODPCompatibleStart(2);
    self.canEnable = YES;
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
       didFailRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session
                  error:(NSError *)error
{
    SCTraceODPCompatibleStart(2);
    self.canEnable = YES;
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
     didCancelRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session
{
    SCTraceODPCompatibleStart(2);
    self.canEnable = YES;
}

@end
