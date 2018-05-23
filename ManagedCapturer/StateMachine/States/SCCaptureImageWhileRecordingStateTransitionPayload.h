//
//  SCCaptureImageWhileRecordingStateTransitionPayload.h
//  Snapchat
//
//  Created by Sun Lei on 22/02/2018.
//

#import "SCCaptureCommon.h"
#import "SCStateTransitionPayload.h"

#import <Foundation/Foundation.h>

@interface SCCaptureImageWhileRecordingStateTransitionPayload : SCStateTransitionPayload

@property (nonatomic, readonly, strong) NSString *captureSessionID;

@property (nonatomic, readonly, copy) sc_managed_capturer_capture_still_image_completion_handler_t block;

@property (nonatomic, readonly, assign) CGFloat aspectRatio;

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithFromState:(SCCaptureStateMachineStateId)fromState
                          toState:(SCCaptureStateMachineStateId)toState
                 captureSessionId:(NSString *)captureSessionID
                      aspectRatio:(CGFloat)aspectRatio
                completionHandler:(sc_managed_capturer_capture_still_image_completion_handler_t)block;

@end
