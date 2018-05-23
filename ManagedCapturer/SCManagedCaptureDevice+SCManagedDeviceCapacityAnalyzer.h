//
//  SCManagedCaptureDevice+SCManagedDeviceCapacityAnalyzer.h
//  Snapchat
//
//  Created by Kam Sheffield on 10/29/15.
//  Copyright © 2015 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDevice.h"

#import <AVFoundation/AVFoundation.h>

@interface SCManagedCaptureDevice (SCManagedDeviceCapacityAnalyzer)

@property (nonatomic, strong, readonly) AVCaptureDevice *device;

@end
