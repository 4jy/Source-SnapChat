//
//  SCCaptureStateDelegate.h
//  Snapchat
//
//  Created by Lin Jia on 10/27/17.
//
//

#import "SCCaptureStateUtil.h"

#import <Foundation/Foundation.h>

@class SCCaptureBaseState;
@class SCStateTransitionPayload;
/*
 The state machine state delegate is used by state machine states to hint to the system that "I am done, now transfer
 to other state".

 Currently, SCCaptureStateMachineContext is the central piece that glues all states together, and it is the delegate for
 those states.
 */

@protocol SCCaptureStateDelegate <NSObject>

- (void)currentState:(SCCaptureBaseState *)state
    requestToTransferToNewState:(SCCaptureStateMachineStateId)newState
                        payload:(SCStateTransitionPayload *)payload
                        context:(NSString *)context;

@end
