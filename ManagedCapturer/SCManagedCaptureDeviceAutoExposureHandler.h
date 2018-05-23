//
//  SCManagedCaptureDeviceAutoExposureHandler.h
//  Snapchat
//
//  Created by Derek Peirce on 3/21/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceExposureHandler.h"

#import <AVFoundation/AVFoundation.h>

@interface SCManagedCaptureDeviceAutoExposureHandler : NSObject <SCManagedCaptureDeviceExposureHandler>

- (instancetype)initWithDevice:(AVCaptureDevice *)device pointOfInterest:(CGPoint)pointOfInterest;

@end
