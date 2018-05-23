//
//  SCCaptureRunningState.h
//  Snapchat
//
//  Created by Jingtian Yang on 08/01/2018.
//

#import "SCCaptureBaseState.h"

#import <Foundation/Foundation.h>

@class SCQueuePerformer;

@interface SCCaptureRunningState : SCCaptureBaseState

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;

@end
