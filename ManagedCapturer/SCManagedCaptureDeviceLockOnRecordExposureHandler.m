//
//  SCManagedCaptureDeviceLockOnRecordExposureHandler.m
//  Snapchat
//
//  Created by Derek Peirce on 3/24/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceLockOnRecordExposureHandler.h"

#import "AVCaptureDevice+ConfigurationLock.h"
#import "SCExposureState.h"
#import "SCManagedCaptureDeviceExposureHandler.h"

#import <SCFoundation/SCTrace.h>

@import AVFoundation;

@implementation SCManagedCaptureDeviceLockOnRecordExposureHandler {
    CGPoint _exposurePointOfInterest;
    AVCaptureDevice *_device;
    // allows the exposure to change when the user taps to refocus
    BOOL _allowTap;
    SCExposureState *_exposureState;
}

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
                      allowTap:(BOOL)allowTap
{
    if (self = [super init]) {
        _device = device;
        _exposurePointOfInterest = pointOfInterest;
        _allowTap = allowTap;
    }
    return self;
}

- (CGPoint)getExposurePointOfInterest
{
    return _exposurePointOfInterest;
}

- (void)setExposurePointOfInterest:(CGPoint)pointOfInterest fromUser:(BOOL)fromUser
{
    SCTraceStart();
    BOOL locked = _device.exposureMode == AVCaptureExposureModeLocked ||
                  _device.exposureMode == AVCaptureExposureModeCustom ||
                  _device.exposureMode == AVCaptureExposureModeAutoExpose;
    if (!locked || (fromUser && _allowTap)) {
        AVCaptureExposureMode exposureMode =
            (locked ? AVCaptureExposureModeAutoExpose : AVCaptureExposureModeContinuousAutoExposure);
        if ([_device isExposureModeSupported:exposureMode] && [_device isExposurePointOfInterestSupported]) {
            [_device runTask:@"set exposure point"
                withLockedConfiguration:^() {
                    // Set exposure point before changing focus mode
                    // Be noticed that order does matter
                    _device.exposurePointOfInterest = pointOfInterest;
                    _device.exposureMode = exposureMode;
                }];
        }
        _exposurePointOfInterest = pointOfInterest;
    }
}

- (void)setStableExposure:(BOOL)stableExposure
{
    AVCaptureExposureMode exposureMode =
        stableExposure ? AVCaptureExposureModeLocked : AVCaptureExposureModeContinuousAutoExposure;
    if ([_device isExposureModeSupported:exposureMode]) {
        [_device runTask:@"set stable exposure"
            withLockedConfiguration:^() {
                _device.exposureMode = exposureMode;
            }];
    }
}

- (void)setVisible:(BOOL)visible
{
    if (visible) {
        if (_device.exposureMode == AVCaptureExposureModeLocked ||
            _device.exposureMode == AVCaptureExposureModeCustom) {
            [_exposureState applyISOAndExposureDurationToDevice:_device];
        }
    } else {
        _exposureState = [[SCExposureState alloc] initWithDevice:_device];
    }
}

@end
