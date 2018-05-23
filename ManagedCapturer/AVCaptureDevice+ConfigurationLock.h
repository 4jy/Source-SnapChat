//
//  AVCaptureDevice+ConfigurationLock.h
//  Snapchat
//
//  Created by Derek Peirce on 4/19/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface AVCaptureDevice (ConfigurationLock)

/*
 The following method will lock this AVCaptureDevice, run the task, then unlock the device.
 The task is usually related to set AVCaptureDevice.
 It will return a boolean telling you whether or not your task ran successfully. You can use the boolean to adjust your
 strategy to handle this failure. For some cases, we don't have a good mechanism to handle the failure. E.g. if we want
 to re-focus, but failed to do so. What is next step? Pop up a alert view to user? If yes, it is intrusive, if not, user
 will get confused. Just because the error handling is difficulty, we would like to notify you if the task fails.
 If the task does not run successfully. We will log an event using SCLogger for better visibility.
 */
- (BOOL)runTask:(NSString *)taskName withLockedConfiguration:(void (^)(void))task;

/*
 The following method has the same function as the above one.
 The difference is that it retries the operation for certain times. Please give a number below or equal 2.
 When retry equals 0, we will only try to lock for once.
 When retry equals 1, we will retry once if the 1st try fails.
 ....
 */
- (BOOL)runTask:(NSString *)taskName withLockedConfiguration:(void (^)(void))task retry:(NSUInteger)retryTimes;

@end
