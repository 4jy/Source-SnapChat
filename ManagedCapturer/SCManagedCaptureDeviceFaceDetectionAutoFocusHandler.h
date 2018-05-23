//
//  SCManagedCaptureDeviceFaceDetectionAutoFocusHandler.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/7/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class is used to
//  1. adjust focus related parameters of camera, including focus mode and focus point.
//  2. receive detected face bounds, and focus to a preferred face if needed.

#import "SCManagedCaptureDeviceFocusHandler.h"

#import <SCBase/SCMacros.h>

#import <AVFoundation/AVFoundation.h>

@protocol SCCapturer;

@interface SCManagedCaptureDeviceFaceDetectionAutoFocusHandler : NSObject <SCManagedCaptureDeviceFocusHandler>

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
               managedCapturer:(id<SCCapturer>)managedCapturer;

@end
