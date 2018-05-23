//
//  SCCaptureStateTransitionBookKeeper.h
//  Snapchat
//
//  Created by Lin Jia on 10/27/17.
//
//

#import "SCCaptureStateUtil.h"

#import <Foundation/Foundation.h>

/*
 Book keeper is used to record every state transition, and every illegal API call.
 */

@interface SCCaptureStateMachineBookKeeper : NSObject

- (void)stateTransitionFrom:(SCCaptureStateMachineStateId)fromId
                         to:(SCCaptureStateMachineStateId)toId
                    context:(NSString *)context;

- (void)state:(SCCaptureStateMachineStateId)captureState
    illegalAPIcalled:(NSString *)illegalAPIName
           callStack:(NSArray<NSString *> *)callStack
             context:(NSString *)context;

- (void)logAPICalled:(NSString *)apiName context:(NSString *)context;
@end
