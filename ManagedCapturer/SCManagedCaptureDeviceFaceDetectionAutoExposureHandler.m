//
//  SCManagedCaptureDeviceFaceDetectionAutoExposureHandler.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/6/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceFaceDetectionAutoExposureHandler.h"

#import "AVCaptureDevice+ConfigurationLock.h"
#import "SCCameraTweaks.h"
#import "SCManagedCaptureDeviceExposureHandler.h"
#import "SCManagedCaptureFaceDetectionAdjustingPOIResource.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerListener.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@import AVFoundation;

@interface SCManagedCaptureDeviceFaceDetectionAutoExposureHandler () <SCManagedCapturerListener>

@property (nonatomic, strong) AVCaptureDevice *device;
@property (nonatomic, weak) id<SCCapturer> managedCapturer;
@property (nonatomic, assign) CGPoint exposurePointOfInterest;
@property (nonatomic, assign) BOOL isVisible;

@property (nonatomic, copy) NSDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID;
@property (nonatomic, strong) SCManagedCaptureFaceDetectionAdjustingPOIResource *resource;

@end

@implementation SCManagedCaptureDeviceFaceDetectionAutoExposureHandler

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
               managedCapturer:(id<SCCapturer>)managedCapturer
{
    if (self = [super init]) {
        SCAssert(device, @"AVCaptureDevice should not be nil.");
        SCAssert(managedCapturer, @"id<SCCapturer> should not be nil.");
        _device = device;
        _exposurePointOfInterest = pointOfInterest;
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

- (void)dealloc
{
    [_managedCapturer removeListener:self];
}

- (CGPoint)getExposurePointOfInterest
{
    return self.exposurePointOfInterest;
}

- (void)setExposurePointOfInterest:(CGPoint)pointOfInterest fromUser:(BOOL)fromUser
{
    SCTraceODPCompatibleStart(2);

    pointOfInterest = [self.resource updateWithNewProposedPointOfInterest:pointOfInterest fromUser:fromUser];

    [self _actuallySetExposurePointOfInterestIfNeeded:pointOfInterest];
}

- (void)_actuallySetExposurePointOfInterestIfNeeded:(CGPoint)pointOfInterest
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(!CGPointEqualToPoint(pointOfInterest, self.exposurePointOfInterest));
    if ([self.device isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure] &&
        [self.device isExposurePointOfInterestSupported]) {
        [self.device runTask:@"set exposure"
            withLockedConfiguration:^() {
                // Set exposure point before changing exposure mode
                // Be noticed that order does matter
                self.device.exposurePointOfInterest = pointOfInterest;
                self.device.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
            }];
    }
    self.exposurePointOfInterest = pointOfInterest;
}

- (void)setStableExposure:(BOOL)stableExposure
{
}

- (void)setVisible:(BOOL)visible
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(_isVisible != visible);
    _isVisible = visible;
    if (visible) {
        [self.managedCapturer addListener:self];
    } else {
        [self.managedCapturer removeListener:self];
        [self.resource reset];
    }
}

#pragma mark - SCManagedCapturerListener
- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didDetectFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(self.isVisible);
    CGPoint pointOfInterest = [self.resource updateWithNewDetectedFaceBounds:faceBoundsByFaceID];
    [self _actuallySetExposurePointOfInterestIfNeeded:pointOfInterest];
}

@end
