//
//  SCCaptureImageState.m
//  Snapchat
//
//  Created by Lin Jia on 1/8/18.
//

#import "SCCaptureImageState.h"

#import "SCCaptureImageStateTransitionPayload.h"
#import "SCManagedCapturerV1_Private.h"
#import "SCStateTransitionPayload.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>

@interface SCCaptureImageState () {
    __weak id<SCCaptureStateDelegate> _delegate;
    SCQueuePerformer *_performer;
}
@end

@implementation SCCaptureImageState

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate
{
    self = [super initWithPerformer:performer bookKeeper:bookKeeper delegate:delegate];
    if (self) {
        _delegate = delegate;
        _performer = performer;
    }
    return self;
}

- (void)didBecomeCurrentState:(SCStateTransitionPayload *)payload
                     resource:(SCCaptureResource *)resource
                      context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCAssert(payload.toState == [self stateId], @"");
    if (![payload isKindOfClass:[SCCaptureImageStateTransitionPayload class]]) {
        SCAssertFail(@"wrong payload pass in");
        [_delegate currentState:self requestToTransferToNewState:payload.fromState payload:nil context:context];
        return;
    }
    SCCaptureImageStateTransitionPayload *captureImagePayload = (SCCaptureImageStateTransitionPayload *)payload;

    [SCCaptureWorker
        captureStillImageWithCaptureResource:resource
                                 aspectRatio:captureImagePayload.aspectRatio
                            captureSessionID:captureImagePayload.captureSessionID
                      shouldCaptureFromVideo:[SCCaptureWorker shouldCaptureImageFromVideoWithResource:resource]
                           completionHandler:captureImagePayload.block
                                     context:context];

    [_delegate currentState:self requestToTransferToNewState:SCCaptureRunningStateId payload:nil context:context];
}

- (SCCaptureStateMachineStateId)stateId
{
    return SCCaptureImageStateId;
}
@end
