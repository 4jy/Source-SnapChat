//
//  SCCaptureStateTransitionBookKeeper.m
//  Snapchat
//
//  Created by Lin Jia on 10/27/17.
//
//

#import "SCCaptureStateMachineBookKeeper.h"

#import "SCCaptureStateUtil.h"
#import "SCLogger+Camera.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCLogger/SCCameraMetrics.h>

@interface SCCaptureStateMachineBookKeeper () {
    NSDate *_lastStateStartTime;
}
@end

@implementation SCCaptureStateMachineBookKeeper

- (void)stateTransitionFrom:(SCCaptureStateMachineStateId)fromId
                         to:(SCCaptureStateMachineStateId)toId
                    context:(NSString *)context
{
    NSDate *date = [NSDate date];
    SCLogCaptureStateMachineInfo(@"State %@ life span: %f seconds, transition to: %@, in context:%@, at: %@ \n",
                                 SCCaptureStateName(fromId), [date timeIntervalSinceDate:_lastStateStartTime],
                                 SCCaptureStateName(toId), context, date);
    _lastStateStartTime = date;
}

- (void)state:(SCCaptureStateMachineStateId)captureState
    illegalAPIcalled:(NSString *)illegalAPIName
           callStack:(NSArray<NSString *> *)callStack
             context:(NSString *)context

{
    SCAssert(callStack, @"call stack empty");
    SCAssert(illegalAPIName, @"");
    SCAssert(context, @"Context is empty");
    SCLogCaptureStateMachineError(@"State: %@, illegal API invoke: %@, at: %@, callstack: %@ \n",
                                  SCCaptureStateName(captureState), illegalAPIName, [NSDate date], callStack);
    NSArray<NSString *> *reportedArray =
        [callStack count] > 15 ? [callStack subarrayWithRange:NSMakeRange(0, 15)] : callStack;
    [[SCLogger sharedInstance] logEvent:kSCCameraStateMachineIllegalAPICall
                             parameters:@{
                                 @"state" : SCCaptureStateName(captureState),
                                 @"API" : illegalAPIName,
                                 @"call_stack" : reportedArray,
                                 @"context" : context
                             }];
}

- (void)logAPICalled:(NSString *)apiName context:(NSString *)context
{
    SCAssert(apiName, @"API name is empty");
    SCAssert(context, @"Context is empty");
    SCLogCaptureStateMachineInfo(@"api: %@ context: %@", apiName, context);
}
@end
