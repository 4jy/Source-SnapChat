//
//  ARConfiguration+SCConfiguration.m
//  Snapchat
//
//  Created by Max Goedjen on 11/7/17.
//

#import "ARConfiguration+SCConfiguration.h"

#import "SCCapturerDefines.h"

@implementation ARConfiguration (SCConfiguration)

+ (BOOL)sc_supportedForDevicePosition:(SCManagedCaptureDevicePosition)position
{
    return [[[self sc_configurationForDevicePosition:position] class] isSupported];
}

+ (ARConfiguration *)sc_configurationForDevicePosition:(SCManagedCaptureDevicePosition)position
{
    if (@available(iOS 11.0, *)) {
        if (position == SCManagedCaptureDevicePositionBack) {
            ARWorldTrackingConfiguration *config = [[ARWorldTrackingConfiguration alloc] init];
            config.planeDetection = ARPlaneDetectionHorizontal;
            config.lightEstimationEnabled = NO;
            return config;
        } else {
#ifdef SC_USE_ARKIT_FACE
            return [[ARFaceTrackingConfiguration alloc] init];
#endif
        }
    }
    return nil;
}

@end
