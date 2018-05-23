//
//  SCManagedVideoScanner.h
//  Snapchat
//
//  Created by Liu Liu on 5/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturer.h"
#import "SCManagedDeviceCapacityAnalyzerListener.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>

#import <Foundation/Foundation.h>

@class SCScanConfiguration;

@interface SCManagedVideoScanner : NSObject <SCManagedVideoDataSourceListener, SCManagedDeviceCapacityAnalyzerListener>

/**
 * Calling this method to start scan, scan will automatically stop when a snapcode detected
 */
- (void)startScanAsynchronouslyWithScanConfiguration:(SCScanConfiguration *)configuration;

/**
 * Calling this method to stop scan immediately (it is still possible that a successful scan can happen after this is
 * called)
 */
- (void)stopScanAsynchronously;

- (instancetype)initWithMaxFrameDefaultDuration:(NSTimeInterval)maxFrameDefaultDuration
                        maxFramePassiveDuration:(NSTimeInterval)maxFramePassiveDuration
                                      restCycle:(float)restCycle;

@end
