//
//  AVCaptureDevice+ConfigurationLock.m
//  Snapchat
//
//  Created by Derek Peirce on 4/19/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "AVCaptureDevice+ConfigurationLock.h"

#import "SCLogger+Camera.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCLogger/SCLogger.h>

@implementation AVCaptureDevice (ConfigurationLock)

- (BOOL)runTask:(NSString *)taskName withLockedConfiguration:(void (^)(void))task
{
    return [self runTask:taskName withLockedConfiguration:task retry:0];
}

- (BOOL)runTask:(NSString *)taskName withLockedConfiguration:(void (^)(void))task retry:(NSUInteger)retryTimes
{
    SCAssert(taskName, @"camera logger taskString should not be empty");
    SCAssert(retryTimes <= 2 && retryTimes >= 0, @"retry times should be equal to or below 2.");
    NSError *error = nil;
    BOOL deviceLockSuccess = NO;
    NSUInteger retryCounter = 0;
    while (retryCounter <= retryTimes && !deviceLockSuccess) {
        deviceLockSuccess = [self lockForConfiguration:&error];
        retryCounter++;
    }
    if (deviceLockSuccess) {
        task();
        [self unlockForConfiguration];
        SCLogCoreCameraInfo(@"AVCapture Device setting success, task:%@ tryCount:%zu", taskName,
                            (unsigned long)retryCounter);
    } else {
        SCLogCoreCameraError(@"AVCapture Device Encountered error when %@ %@", taskName, error);
        [[SCLogger sharedInstance] logManagedCapturerSettingFailure:taskName error:error];
    }
    return deviceLockSuccess;
}

@end
