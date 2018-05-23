//
//  SCCaptureImageWhileRecordingStateTransitionPayload.m
//  Snapchat
//
//  Created by Sun Lei on 22/02/2018.
//

#import "SCCaptureImageWhileRecordingStateTransitionPayload.h"

@implementation SCCaptureImageWhileRecordingStateTransitionPayload

- (instancetype)initWithFromState:(SCCaptureStateMachineStateId)fromState
                          toState:(SCCaptureStateMachineStateId)toState
                 captureSessionId:(NSString *)captureSessionID
                      aspectRatio:(CGFloat)aspectRatio
                completionHandler:(sc_managed_capturer_capture_still_image_completion_handler_t)block
{
    self = [super initWithFromState:fromState toState:toState];
    if (self) {
        _captureSessionID = captureSessionID;
        _aspectRatio = aspectRatio;
        _block = block;
    }
    return self;
}

@end
