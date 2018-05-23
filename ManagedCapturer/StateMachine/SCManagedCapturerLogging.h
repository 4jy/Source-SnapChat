//
//  SCManagedCapturerLogging.h
//  Snapchat
//
//  Created by Lin Jia on 11/13/17.
//

#import <SCFoundation/SCLog.h>

#define SCLogCapturerInfo(fmt, ...) SCLogCoreCameraInfo(@"[SCManagedCapturer] " fmt, ##__VA_ARGS__)
#define SCLogCapturerWarning(fmt, ...) SCLogCoreCameraWarning(@"[SCManagedCapturer] " fmt, ##__VA_ARGS__)
#define SCLogCapturerError(fmt, ...) SCLogCoreCameraError(@"[SCManagedCapturer] " fmt, ##__VA_ARGS__)
