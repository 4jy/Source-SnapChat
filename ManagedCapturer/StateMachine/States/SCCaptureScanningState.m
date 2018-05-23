//
//  SCCaptureScanningState.m
//  Snapchat
//
//  Created by Xiaokang Liu on 09/01/2018.
//

#import "SCCaptureScanningState.h"

#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerV1_Private.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCCaptureScanningState () {
    __weak id<SCCaptureStateDelegate> _delegate;
    SCQueuePerformer *_performer;
}

@end

@implementation SCCaptureScanningState
- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate
{
    self = [super initWithPerformer:performer bookKeeper:bookKeeper delegate:delegate];
    if (self) {
        SCAssert(delegate, @"");
        SCAssert(performer, @"");
        SCAssert(bookKeeper, @"");
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
    return SCCaptureScanningStateId;
}

- (void)stopScanWithCompletionHandler:(dispatch_block_t)completionHandler
                             resource:(SCCaptureResource *)resource
                              context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"stop scan asynchronously.");
    [SCCaptureWorker stopScanWithCompletionHandler:completionHandler resource:resource];
    [_delegate currentState:self requestToTransferToNewState:SCCaptureRunningStateId payload:nil context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (void)cancelRecordingWithResource:(SCCaptureResource *)resource context:(NSString *)context
{
    // Intentionally No Op, this will be removed once CCAM-13851 gets resolved.
    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

@end
