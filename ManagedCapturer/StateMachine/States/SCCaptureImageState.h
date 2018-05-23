//
//  SCCaptureImageState.h
//  Snapchat
//
//  Created by Lin Jia on 1/8/18.
//

#import "SCCaptureBaseState.h"

#import <Foundation/Foundation.h>

@class SCQueuePerformer;

@interface SCCaptureImageState : SCCaptureBaseState

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;

@end
