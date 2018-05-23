//
//  SCCaptureScanningState.h
//  Snapchat
//
//  Created by Xiaokang Liu on 09/01/2018.
//

#import "SCCaptureBaseState.h"

@class SCQueuePerformer;

@interface SCCaptureScanningState : SCCaptureBaseState
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;
@end
