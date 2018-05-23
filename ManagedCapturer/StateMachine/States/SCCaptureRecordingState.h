//
//  SCCaptureRecordingState.h
//  Snapchat
//
//  Created by Jingtian Yang on 12/01/2018.
//

#import "SCCaptureBaseState.h"

#import <Foundation/Foundation.h>

@class SCQueuePerformer;

@interface SCCaptureRecordingState : SCCaptureBaseState

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;

@end
