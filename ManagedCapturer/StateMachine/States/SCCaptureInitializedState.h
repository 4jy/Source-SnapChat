//
//  SCCaptureInitializedState.h
//  Snapchat
//
//  Created by Jingtian Yang on 20/12/2017.
//

#import "SCCaptureBaseState.h"

#import <Foundation/Foundation.h>

@class SCQueuePerformer;

@interface SCCaptureInitializedState : SCCaptureBaseState

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;

@end
