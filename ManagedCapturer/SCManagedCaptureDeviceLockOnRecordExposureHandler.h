//
//  SCManagedCaptureDeviceLockOnRecordExposureHandler.h
//  Snapchat
//
//  Created by Derek Peirce on 3/24/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceExposureHandler.h"

#import <AVFoundation/AVFoundation.h>

// An exposure handler that prevents any changes in exposure as soon as recording begins
@interface SCManagedCaptureDeviceLockOnRecordExposureHandler : NSObject <SCManagedCaptureDeviceExposureHandler>

- (instancetype)initWithDevice:(AVCaptureDevice *)device
               pointOfInterest:(CGPoint)pointOfInterest
                      allowTap:(BOOL)allowTap;

@end
