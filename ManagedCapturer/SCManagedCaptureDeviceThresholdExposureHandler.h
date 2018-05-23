//
//  SCManagedCaptureDeviceThresholdExposureHandler.h
//  Snapchat
//
//  Created by Derek Peirce on 4/11/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceExposureHandler.h"

#import <AVFoundation/AVFoundation.h>

@interface SCManagedCaptureDeviceThresholdExposureHandler : NSObject <SCManagedCaptureDeviceExposureHandler>

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
                     threshold:(CGFloat)threshold;

@end
