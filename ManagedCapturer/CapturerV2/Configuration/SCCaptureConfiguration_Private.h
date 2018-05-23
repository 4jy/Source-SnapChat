//
//  SCCaptureConfiguration_Private.h
//  Snapchat
//
//  Created by Lin Jia on 10/3/17.
//
//

#import "SCCaptureConfiguration_Private.h"

typedef NSNumber SCCaptureConfigurationDirtyKey;

/*
 The key values to identify dirty keys in SCCaptureConfiguration.
 Dirty key is defined as the key customer changes.

 e.g. if customer toggle device position. Dirty keys will have SCCaptureConfigurationKeyDevicePosition.

 It is not complete, and it is only a draft now. It
 will be gradually tuned while we work on the APIs.
 */

typedef NS_ENUM(NSUInteger, SCCaptureConfigurationKey) {
    SCCaptureConfigurationKeyIsRunning,
    SCCaptureConfigurationKeyIsNightModeActive,
    SCCaptureConfigurationKeyLowLightCondition,
    SCCaptureConfigurationKeyDevicePosition,
    SCCaptureConfigurationKeyZoomFactor,
    SCCaptureConfigurationKeyFlashActive,
    SCCaptureConfigurationKeyTorchActive,
    SCCaptureConfigurationKeyARSessionActive,
    SCCaptureConfigurationKeyLensesActive,
    SCCaptureConfigurationKeyVideoRecording,
};

@interface SCCaptureConfiguration (internalMethods)

// Return dirtyKeys, which identify the parameters customer want to set.
- (NSArray *)dirtyKeys;

// Called by SCCaptureConfigurator to seal a configuration, so future changes are ignored.
- (void)seal;

- (BOOL)_configurationSealed;

@end
