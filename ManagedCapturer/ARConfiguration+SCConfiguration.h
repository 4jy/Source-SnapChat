//
//  ARConfiguration+SCConfiguration.h
//  Snapchat
//
//  Created by Max Goedjen on 11/7/17.
//

#import "SCManagedCaptureDevice.h"

#import <ARKit/ARKit.h>

@interface ARConfiguration (SCConfiguration)

+ (BOOL)sc_supportedForDevicePosition:(SCManagedCaptureDevicePosition)position;
+ (ARConfiguration *_Nullable)sc_configurationForDevicePosition:(SCManagedCaptureDevicePosition)position;

@end
