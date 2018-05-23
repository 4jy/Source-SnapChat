//
//  SCManagedDroppedFramesReporter.h
//  Snapchat
//
//  Created by Michel Loenngren on 3/21/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturerListener.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>

#import <Foundation/Foundation.h>

/*
 Conforms to SCManagedVideoDataSourceListener and records frame rate statistics
 during recording.
 */
@interface SCManagedDroppedFramesReporter : NSObject <SCManagedVideoDataSourceListener, SCManagedCapturerListener>

- (void)reportWithKeepLateFrames:(BOOL)keepLateFrames lensesApplied:(BOOL)lensesApplied;

- (void)didChangeCaptureDevicePosition;

@end
