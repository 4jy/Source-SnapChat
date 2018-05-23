//
//  SCManagedCaptureDeviceFaceDetectionAutoFocusHandler.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/7/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceFaceDetectionAutoFocusHandler.h"

#import "AVCaptureDevice+ConfigurationLock.h"
#import "SCCameraTweaks.h"
#import "SCManagedCaptureFaceDetectionAdjustingPOIResource.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerListener.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCManagedCaptureDeviceFaceDetectionAutoFocusHandler () <SCManagedCapturerListener>

@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, weak) id<SCCapturer> managedCapturer;
@property (nonatomic, assign) CGPoint focusPointOfInterest;

@property (nonatomic, assign) BOOL isVisible;
@property (nonatomic, assign) BOOL isContinuousAutofocus;
@property (nonatomic, assign) BOOL focusLock;

@property (nonatomic, copy) NSDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID;
@property (nonatomic, strong) SCManagedCaptureFaceDetectionAdjustingPOIResource *resource;

@end

@implementation SCManagedCaptureDeviceFaceDetectionAutoFocusHandler

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
               managedCapturer:(id<SCCapturer>)managedCapturer
{
    if (self = [super init]) {
        SCAssert(device, @"AVCaptureDevice should not be nil.");
        SCAssert(managedCapturer, @"id<SCCapturer> should not be nil.");
        _device = device;
        _focusPointOfInterest = pointOfInterest;
        SCManagedCaptureDevicePosition position =
            (device.position == AVCaptureDevicePositionFront ? SCManagedCaptureDevicePositionFront
                                                             : SCManagedCaptureDevicePositionBack);
        _resource = [[SCManagedCaptureFaceDetectionAdjustingPOIResource alloc]
             initWithDefaultPointOfInterest:pointOfInterest
            shouldTargetOnFaceAutomatically:SCCameraTweaksTurnOnFaceDetectionFocusByDefault(position)];
        _managedCapturer = managedCapturer;
    }
    return self;
}

- (CGPoint)getFocusPointOfInterest
{
    return self.focusPointOfInterest;
}

// called when user taps on a point on screen, to re-adjust camera focus onto that tapped spot.
// this re-adjustment is always necessary, regardless of scenarios (recording video, taking photo, etc),
// therefore we don't have to check self.focusLock in this method.
- (void)setAutofocusPointOfInterest:(CGPoint)pointOfInterest
{
    SCTraceODPCompatibleStart(2);
    pointOfInterest = [self.resource updateWithNewProposedPointOfInterest:pointOfInterest fromUser:YES];
    SC_GUARD_ELSE_RETURN(!CGPointEqualToPoint(pointOfInterest, self.focusPointOfInterest) ||
                         self.isContinuousAutofocus);
    [self _actuallySetFocusPointOfInterestIfNeeded:pointOfInterest
                                     withFocusMode:AVCaptureFocusModeAutoFocus
                                          taskName:@"set autofocus"];
}

- (void)continuousAutofocus
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(!self.isContinuousAutofocus);
    CGPoint pointOfInterest = [self.resource updateWithNewProposedPointOfInterest:CGPointMake(0.5, 0.5) fromUser:NO];
    [self _actuallySetFocusPointOfInterestIfNeeded:pointOfInterest
                                     withFocusMode:AVCaptureFocusModeContinuousAutoFocus
                                          taskName:@"set continuous autofocus"];
}

- (void)setFocusLock:(BOOL)focusLock
{
    // Disabled focus lock for face detection and focus handler.
}

- (void)setSmoothFocus:(BOOL)smoothFocus
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(smoothFocus != self.device.smoothAutoFocusEnabled);
    [self.device runTask:@"set smooth autofocus"
        withLockedConfiguration:^() {
            [self.device setSmoothAutoFocusEnabled:smoothFocus];
        }];
}

- (void)setVisible:(BOOL)visible
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(_isVisible != visible);
    self.isVisible = visible;
    if (visible) {
        [[SCManagedCapturer sharedInstance] addListener:self];
    } else {
        [[SCManagedCapturer sharedInstance] removeListener:self];
        [self.resource reset];
    }
}

- (void)_actuallySetFocusPointOfInterestIfNeeded:(CGPoint)pointOfInterest
                                   withFocusMode:(AVCaptureFocusMode)focusMode
                                        taskName:(NSString *)taskName
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(!CGPointEqualToPoint(pointOfInterest, self.focusPointOfInterest) &&
                         [self.device isFocusModeSupported:focusMode] && [self.device isFocusPointOfInterestSupported]);
    [self.device runTask:taskName
        withLockedConfiguration:^() {
            // Set focus point before changing focus mode
            // Be noticed that order does matter
            self.device.focusPointOfInterest = pointOfInterest;
            self.device.focusMode = focusMode;
        }];

    self.focusPointOfInterest = pointOfInterest;
    self.isContinuousAutofocus = (focusMode == AVCaptureFocusModeContinuousAutoFocus);
}

#pragma mark - SCManagedCapturerListener
- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didDetectFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(self.isVisible);
    CGPoint pointOfInterest = [self.resource updateWithNewDetectedFaceBounds:faceBoundsByFaceID];
    // If pointOfInterest is equal to CGPointMake(0.5, 0.5), it means no valid face is found, so that we should reset to
    // AVCaptureFocusModeContinuousAutoFocus. Otherwise, focus on the point and set the mode as
    // AVCaptureFocusModeAutoFocus.
    // TODO(Jiyang): Refactor SCManagedCaptureFaceDetectionAdjustingPOIResource to include focusMode and exposureMode.
    AVCaptureFocusMode focusMode = CGPointEqualToPoint(pointOfInterest, CGPointMake(0.5, 0.5))
                                       ? AVCaptureFocusModeContinuousAutoFocus
                                       : AVCaptureFocusModeAutoFocus;
    [self _actuallySetFocusPointOfInterestIfNeeded:pointOfInterest
                                     withFocusMode:focusMode
                                          taskName:@"set autofocus from face detection"];
}

@end
