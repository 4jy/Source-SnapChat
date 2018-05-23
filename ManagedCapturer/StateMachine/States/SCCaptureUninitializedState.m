//
//  SCCaptureUninitializedState.m
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCCaptureUninitializedState.h"

#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerV1_Private.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCCaptureUninitializedState () {
    __weak id<SCCaptureStateDelegate> _delegate;
    SCQueuePerformer *_performer;
}

@end

@implementation SCCaptureUninitializedState

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
    return SCCaptureUninitializedStateId;
}

- (void)initializeCaptureWithDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
                                   resource:(SCCaptureResource *)resource
                          completionHandler:(dispatch_block_t)completionHandler
                                    context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Setting up with devicePosition:%lu", (unsigned long)devicePosition);

    // TODO: we need to push completionHandler to a payload and let intializedState handle.
    [[SCManagedCapturerV1 sharedInstance] setupWithDevicePosition:devicePosition completionHandler:completionHandler];

    [_delegate currentState:self requestToTransferToNewState:SCCaptureInitializedStateId payload:nil context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

@end
