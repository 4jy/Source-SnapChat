//#!announcer.rb
//  SCManagedDeviceCapacityAnalyzerListener.h
//  Snapchat
//
//  Created by Liu Liu on 5/4/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCCapturerDefines.h"

#import <Foundation/Foundation.h>

@class SCManagedDeviceCapacityAnalyzer;

@protocol SCManagedDeviceCapacityAnalyzerListener <NSObject>

@optional

// These callbacks happen on a internal queue
- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeLowLightCondition:(BOOL)lowLightCondition;

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeAdjustingExposure:(BOOL)adjustingExposure;

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
              didChangeAdjustingFocus:(BOOL)adjustingFocus;

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
                  didChangeBrightness:(float)adjustingBrightness;

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeLightingCondition:(SCCapturerLightingConditionType)lightingCondition;

@end
