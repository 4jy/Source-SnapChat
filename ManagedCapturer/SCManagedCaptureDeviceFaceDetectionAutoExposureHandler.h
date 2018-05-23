//
//  SCManagedCaptureDeviceFaceDetectionAutoExposureHandler.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/6/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class is used to
//  1. adjust exposure related parameters of camera, including exposure mode and exposure point.
//  2. receive detected face bounds, and set exposure point to a preferred face if needed.

#import "SCManagedCaptureDeviceExposureHandler.h"

#import <SCBase/SCMacros.h>

#import <AVFoundation/AVFoundation.h>

@protocol SCCapturer;

@interface SCManagedCaptureDeviceFaceDetectionAutoExposureHandler : NSObject <SCManagedCaptureDeviceExposureHandler>

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
               managedCapturer:(id<SCCapturer>)managedCapturer;

@end
