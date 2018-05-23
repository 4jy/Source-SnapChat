//
//  SCManagedCaptureDeviceThresholdExposureHandler.m
//  Snapchat
//
//  Created by Derek Peirce on 4/11/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceThresholdExposureHandler.h"

#import "AVCaptureDevice+ConfigurationLock.h"
#import "SCCameraTweaks.h"
#import "SCExposureState.h"
#import "SCManagedCaptureDeviceExposureHandler.h"

#import <SCFoundation/SCTrace.h>

#import <FBKVOController/FBKVOController.h>

@import AVFoundation;

@implementation SCManagedCaptureDeviceThresholdExposureHandler {
    AVCaptureDevice *_device;
    CGPoint _exposurePointOfInterest;
    CGFloat _threshold;
    // allows the exposure to change when the user taps to refocus
    SCExposureState *_exposureState;
    FBKVOController *_kvoController;
}

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
                     threshold:(CGFloat)threshold
{
    if (self = [super init]) {
        _device = device;
        _exposurePointOfInterest = pointOfInterest;
        _threshold = threshold;
        _kvoController = [FBKVOController controllerWithObserver:self];
        @weakify(self);
        [_kvoController observe:device
                        keyPath:NSStringFromSelector(@selector(exposureMode))
                        options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                          block:^(id observer, id object, NSDictionary *change) {
                              @strongify(self);
                              AVCaptureExposureMode old =
                                  (AVCaptureExposureMode)[(NSNumber *)change[NSKeyValueChangeOldKey] intValue];
                              AVCaptureExposureMode new =
                                  (AVCaptureExposureMode)[(NSNumber *)change[NSKeyValueChangeNewKey] intValue];
                              if (old == AVCaptureExposureModeAutoExpose && new == AVCaptureExposureModeLocked) {
                                  // auto expose is done, go back to custom
                                  self->_exposureState = [[SCExposureState alloc] initWithDevice:self->_device];
                                  [self->_exposureState applyISOAndExposureDurationToDevice:self->_device];
                              }
                          }];
        [_kvoController observe:device
                        keyPath:NSStringFromSelector(@selector(exposureTargetOffset))
                        options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
                          block:^(id observer, id object, NSDictionary *change) {
                              @strongify(self);
                              if (self->_device.exposureMode == AVCaptureExposureModeCustom) {
                                  CGFloat offset = [(NSNumber *)change[NSKeyValueChangeOldKey] floatValue];
                                  if (fabs(offset) > self->_threshold) {
                                      [self->_device runTask:@"set exposure point"
                                          withLockedConfiguration:^() {
                                              // Set exposure point before changing focus mode
                                              // Be noticed that order does matter
                                              self->_device.exposurePointOfInterest = CGPointMake(0.5, 0.5);
                                              self->_device.exposureMode = AVCaptureExposureModeAutoExpose;
                                          }];
                                  }
                              }
                          }];
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
    if (!locked || fromUser) {
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
    if (stableExposure) {
        _exposureState = [[SCExposureState alloc] initWithDevice:_device];
        [_exposureState applyISOAndExposureDurationToDevice:_device];
    } else {
        AVCaptureExposureMode exposureMode = AVCaptureExposureModeContinuousAutoExposure;
        if ([_device isExposureModeSupported:exposureMode]) {
            [_device runTask:@"set exposure point"
                withLockedConfiguration:^() {
                    _device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
                }];
        }
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
