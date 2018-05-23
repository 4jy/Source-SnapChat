//
//  SCManagedDeviceCapacityAnalyzer.h
//  Snapchat
//
//  Created by Liu Liu on 5/1/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedDeviceCapacityAnalyzerListener.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>

#import <Foundation/Foundation.h>

@class SCManagedCaptureDevice;
@protocol SCPerforming;

extern NSInteger const kSCManagedDeviceCapacityAnalyzerMaxISOPresetHigh;

@interface SCManagedDeviceCapacityAnalyzer : NSObject <SCManagedVideoDataSourceListener>

@property (nonatomic, assign) BOOL lowLightConditionEnabled;

- (instancetype)initWithPerformer:(id<SCPerforming>)performer;

- (void)addListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener;
- (void)removeListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener;

- (void)setAsFocusListenerForDevice:(SCManagedCaptureDevice *)captureDevice;
- (void)removeFocusListener;

@end
