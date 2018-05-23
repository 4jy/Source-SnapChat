//
//  SCCaptureUninitializedState.h
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCCaptureBaseState.h"

#import <Foundation/Foundation.h>

/*
 State which handles capture initialialization, which should be used only once for every app life span.
*/
@class SCQueuePerformer;

@interface SCCaptureUninitializedState : SCCaptureBaseState

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;

@end
