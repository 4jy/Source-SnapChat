//
//  SCFeatureTapToFocusImpl.m
//  SCCamera
//
//  Created by Michel Loenngren on 4/5/18.
//

#import "SCFeatureTapToFocusAndExposureImpl.h"

#import "SCCameraTweaks.h"
#import "SCCapturer.h"
#import "SCFeatureContainerView.h"
#import "SCTapAnimationView.h"

#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCFeatureTapToFocusAndExposureImpl ()
@property (nonatomic, weak) id<SCCapturer> capturer;
@property (nonatomic, weak) UIView<SCFeatureContainerView> *containerView;
@property (nonatomic) BOOL userTappedToFocusAndExposure;
@property (nonatomic) NSArray<id<SCFeatureCameraTapCommand>> *commands;
@end

@implementation SCFeatureTapToFocusAndExposureImpl

- (instancetype)initWithCapturer:(id<SCCapturer>)capturer commands:(NSArray<id<SCFeatureCameraTapCommand>> *)commands
{
    if (self = [super init]) {
        _capturer = capturer;
        _commands = commands;
    }
    return self;
}

- (void)reset
{
    SC_GUARD_ELSE_RETURN(_userTappedToFocusAndExposure);
    _userTappedToFocusAndExposure = NO;
    [_capturer continuousAutofocusAndExposureAsynchronouslyWithCompletionHandler:nil context:SCCapturerContext];
}

#pragma mark - SCFeature

- (void)configureWithView:(UIView<SCFeatureContainerView> *)view
{
    SCTraceODPCompatibleStart(2);
    _containerView = view;
}

- (void)forwardCameraOverlayTapGesture:(UIGestureRecognizer *)gestureRecognizer
{
    SCTraceODPCompatibleStart(2);
    CGPoint point = [gestureRecognizer locationInView:gestureRecognizer.view];
    @weakify(self);
    [_capturer convertViewCoordinates:[gestureRecognizer locationInView:_containerView]
                    completionHandler:^(CGPoint pointOfInterest) {
                        @strongify(self);
                        SC_GUARD_ELSE_RETURN(self);
                        SCLogCameraFeatureInfo(@"Tapped to focus: %@", NSStringFromCGPoint(pointOfInterest));
                        [self _applyTapCommands:pointOfInterest];
                        [self _showTapAnimationAtPoint:point forGesture:gestureRecognizer];
                    }
                              context:SCCapturerContext];
}

#pragma mark - Private helpers

- (void)_applyTapCommands:(CGPoint)pointOfInterest
{
    SCTraceODPCompatibleStart(2);
    for (id<SCFeatureCameraTapCommand> command in _commands) {
        [command execute:pointOfInterest capturer:_capturer];
    }
    self.userTappedToFocusAndExposure = YES;
}

- (void)_showTapAnimationAtPoint:(CGPoint)point forGesture:(UIGestureRecognizer *)gestureRecognizer
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN([self.containerView isTapGestureRecognizer:gestureRecognizer])
    SCTapAnimationView *tapAnimationView = [SCTapAnimationView tapAnimationView];
    [_containerView addSubview:tapAnimationView];
    tapAnimationView.center = point;
    [tapAnimationView showWithCompletion:^(SCTapAnimationView *view) {
        [view removeFromSuperview];
    }];
}

@end

@implementation SCFeatureCameraFocusTapCommand
- (void)execute:(CGPoint)pointOfInterest capturer:(id<SCCapturer>)capturer
{
    [capturer setAutofocusPointOfInterestAsynchronously:pointOfInterest
                                      completionHandler:nil
                                                context:SCCapturerContext];
}
@end

@implementation SCFeatureCameraExposureTapCommand
- (void)execute:(CGPoint)pointOfInterest capturer:(id<SCCapturer>)capturer
{
    [capturer setExposurePointOfInterestAsynchronously:pointOfInterest
                                              fromUser:YES
                                     completionHandler:nil
                                               context:SCCapturerContext];
}
@end

@implementation SCFeatureCameraPortraitTapCommand
- (void)execute:(CGPoint)pointOfInterest capturer:(id<SCCapturer>)capturer
{
    [capturer setPortraitModePointOfInterestAsynchronously:pointOfInterest
                                         completionHandler:nil
                                                   context:SCCapturerContext];
}
@end
