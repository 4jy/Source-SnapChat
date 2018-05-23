//
//  SCManagedCaptureDeviceAutoExposureHandler.m
//  Snapchat
//
//  Created by Derek Peirce on 3/21/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceAutoExposureHandler.h"

#import "AVCaptureDevice+ConfigurationLock.h"
#import "SCManagedCaptureDeviceExposureHandler.h"

#import <SCFoundation/SCTrace.h>

@import AVFoundation;

@implementation SCManagedCaptureDeviceAutoExposureHandler {
    CGPoint _exposurePointOfInterest;
    AVCaptureDevice *_device;
}

- (instancetype)initWithDevice:(AVCaptureDevice *)device pointOfInterest:(CGPoint)pointOfInterest
{
    if (self = [super init]) {
        _device = device;
        _exposurePointOfInterest = pointOfInterest;
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
    if (!CGPointEqualToPoint(pointOfInterest, _exposurePointOfInterest)) {
        if ([_device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] &&
            [_device isExposurePointOfInterestSupported]) {
            [_device runTask:@"set exposure"
                withLockedConfiguration:^() {
                    // Set exposure point before changing focus mode
                    // Be noticed that order does matter
                    _device.exposurePointOfInterest = pointOfInterest;
                    _device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
                }];
        }
        _exposurePointOfInterest = pointOfInterest;
    }
}

- (void)setStableExposure:(BOOL)stableExposure
{
}

- (void)setVisible:(BOOL)visible
{
}

@end
