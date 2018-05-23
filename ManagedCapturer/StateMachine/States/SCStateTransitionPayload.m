//
//  SCStateTransitionPayload.m
//  Snapchat
//
//  Created by Lin Jia on 1/8/18.
//

#import "SCStateTransitionPayload.h"

#import <SCFoundation/SCAssertWrapper.h>

@implementation SCStateTransitionPayload

- (instancetype)initWithFromState:(SCCaptureStateMachineStateId)fromState toState:(SCCaptureStateMachineStateId)toState
{
    self = [super init];
    if (self) {
        SCAssert(fromState != toState, @"");
        SCAssert(fromState > SCCaptureBaseStateId && fromState < SCCaptureStateMachineStateIdCount, @"");
        SCAssert(toState > SCCaptureBaseStateId && toState < SCCaptureStateMachineStateIdCount, @"");
        _fromState = fromState;
        _toState = toState;
    }
    return self;
}

@end
