//
//  SCCaptureImageWhileRecordingState.h
//  Snapchat
//
//  Created by Sun Lei on 22/02/2018.
//

#import "SCCaptureBaseState.h"

#import <Foundation/Foundation.h>

@class SCQueuePerformer;

@interface SCCaptureImageWhileRecordingState : SCCaptureBaseState

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;

@end
