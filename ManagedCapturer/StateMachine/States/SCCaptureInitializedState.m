//
//  SCCaptureInitializedState.m
//  Snapchat
//
//  Created by Jingtian Yang on 20/12/2017.
//

#import "SCCaptureInitializedState.h"

#import "SCCapturerToken.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerV1_Private.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>

@interface SCCaptureInitializedState () {
    __weak id<SCCaptureStateDelegate> _delegate;
    SCQueuePerformer *_performer;
}

@end

@implementation SCCaptureInitializedState

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
    // No op.
}

- (SCCaptureStateMachineStateId)stateId
{
    return SCCaptureInitializedStateId;
}

- (void)startRunningWithCapturerToken:(SCCapturerToken *)token
                             resource:(SCCaptureResource *)resource
                    completionHandler:(dispatch_block_t)completionHandler
                              context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"startRunningAsynchronouslyWithCompletionHandler called. token: %@", token);

    [SCCaptureWorker startRunningWithCaptureResource:resource token:token completionHandler:completionHandler];

    [_delegate currentState:self requestToTransferToNewState:SCCaptureRunningStateId payload:nil context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

@end
