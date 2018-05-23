//
//  SCManagedCaptureDeviceAutoFocusHandler.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/7/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class is used to adjust focus related parameters of camera, including focus mode and focus point.

#import "SCManagedCaptureDeviceFocusHandler.h"

#import <AVFoundation/AVFoundation.h>

@interface SCManagedCaptureDeviceAutoFocusHandler : NSObject <SCManagedCaptureDeviceFocusHandler>

- (instancetype)initWithDevice:(AVCaptureDevice *)device pointOfInterest:(CGPoint)pointOfInterest;

@end
