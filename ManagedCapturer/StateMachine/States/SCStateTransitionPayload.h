//
//  SCStateTransitionPayload.h
//  Snapchat
//
//  Created by Lin Jia on 1/8/18.
//

#import "SCCaptureStateUtil.h"

#import <Foundation/Foundation.h>

@interface SCStateTransitionPayload : NSObject

@property (nonatomic, readonly, assign) SCCaptureStateMachineStateId fromState;

@property (nonatomic, readonly, assign) SCCaptureStateMachineStateId toState;

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithFromState:(SCCaptureStateMachineStateId)fromState toState:(SCCaptureStateMachineStateId)toState;

@end
