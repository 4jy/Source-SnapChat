//
//  SCManagedCapturerV1_Private.h
//  Snapchat
//
//  Created by Jingtian Yang on 20/12/2017.
//

#import "SCManagedCapturerV1.h"

@interface SCManagedCapturerV1 ()

- (SCCaptureResource *)captureResource;

- (void)setupWithDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
              completionHandler:(dispatch_block_t)completionHandler;

- (BOOL)stopRunningWithCaptureToken:(SCCapturerToken *)token
                  completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                            context:(NSString *)context;
@end
