//
//  SCManagedCaptureDeviceAutoFocusHandler.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/7/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceAutoFocusHandler.h"

#import "AVCaptureDevice+ConfigurationLock.h"

#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@import CoreGraphics;

@interface SCManagedCaptureDeviceAutoFocusHandler ()

@property (nonatomic, assign) CGPoint focusPointOfInterest;
@property (nonatomic, strong) AVCaptureDevice *device;

@property (nonatomic, assign) BOOL isContinuousAutofocus;
@property (nonatomic, assign) BOOL isFocusLock;

@end

@implementation SCManagedCaptureDeviceAutoFocusHandler

- (instancetype)initWithDevice:(AVCaptureDevice *)device pointOfInterest:(CGPoint)pointOfInterest
{
    if (self = [super init]) {
        _device = device;
        _focusPointOfInterest = pointOfInterest;
        _isContinuousAutofocus = YES;
        _isFocusLock = NO;
    }
    return self;
}

- (CGPoint)getFocusPointOfInterest
{
    return self.focusPointOfInterest;
}

// called when user taps on a point on screen, to re-adjust camera focus onto that tapped spot.
// this re-adjustment is always necessary, regardless of scenarios (recording video, taking photo, etc),
// therefore we don't have to check self.isFocusLock in this method.
- (void)setAutofocusPointOfInterest:(CGPoint)pointOfInterest
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(!CGPointEqualToPoint(pointOfInterest, self.focusPointOfInterest) || self.isContinuousAutofocus)
    // Do the setup immediately if the focus lock is off.
    if ([self.device isFocusModeSupported:AVCaptureFocusModeAutoFocus] &&
        [self.device isFocusPointOfInterestSupported]) {
        [self.device runTask:@"set autofocus"
            withLockedConfiguration:^() {
                // Set focus point before changing focus mode
                // Be noticed that order does matter
                self.device.focusPointOfInterest = pointOfInterest;
                self.device.focusMode = AVCaptureFocusModeAutoFocus;
            }];
    }
    self.focusPointOfInterest = pointOfInterest;
    self.isContinuousAutofocus = NO;
}

- (void)continuousAutofocus
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(!self.isContinuousAutofocus);
    if (!self.isFocusLock) {
        // Do the setup immediately if the focus lock is off.
        if ([self.device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus] &&
            [self.device isFocusPointOfInterestSupported]) {
            [self.device runTask:@"set continuous autofocus"
                withLockedConfiguration:^() {
                    // Set focus point before changing focus mode
                    // Be noticed that order does matter
                    self.device.focusPointOfInterest = CGPointMake(0.5, 0.5);
                    self.device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
                }];
        }
    }
    self.focusPointOfInterest = CGPointMake(0.5, 0.5);
    self.isContinuousAutofocus = YES;
}

- (void)setFocusLock:(BOOL)focusLock
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(self.isFocusLock != focusLock);
    // This is the old lock, we only do focus lock on back camera
    if (focusLock) {
        if ([self.device isFocusModeSupported:AVCaptureFocusModeLocked]) {
            [self.device runTask:@"set focus lock on"
                withLockedConfiguration:^() {
                    self.device.focusMode = AVCaptureFocusModeLocked;
                }];
        }
    } else {
        // Restore to previous autofocus configurations
        if ([self.device isFocusModeSupported:(self.isContinuousAutofocus ? AVCaptureFocusModeContinuousAutoFocus
                                                                          : AVCaptureFocusModeAutoFocus)] &&
            [self.device isFocusPointOfInterestSupported]) {
            [self.device runTask:@"set focus lock on"
                withLockedConfiguration:^() {
                    self.device.focusPointOfInterest = self.focusPointOfInterest;
                    self.device.focusMode = self.isContinuousAutofocus ? AVCaptureFocusModeContinuousAutoFocus
                                                                       : AVCaptureFocusModeAutoFocus;
                }];
        }
    }
    self.isFocusLock = focusLock;
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
}

@end
