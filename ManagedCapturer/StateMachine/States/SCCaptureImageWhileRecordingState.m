//
//  SCCaptureImageWhileRecordingState.m
//  Snapchat
//
//  Created by Sun Lei on 22/02/2018.
//

#import "SCCaptureImageWhileRecordingState.h"

#import "SCCaptureImageWhileRecordingStateTransitionPayload.h"
#import "SCManagedCapturerV1_Private.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>

@interface SCCaptureImageWhileRecordingState () {
    __weak id<SCCaptureStateDelegate> _delegate;
    SCQueuePerformer *_performer;
}
@end

@implementation SCCaptureImageWhileRecordingState

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

- (SCCaptureStateMachineStateId)stateId
{
    return SCCaptureImageWhileRecordingStateId;
}

- (void)didBecomeCurrentState:(SCStateTransitionPayload *)payload
                     resource:(SCCaptureResource *)resource
                      context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCAssert(payload.fromState == SCCaptureRecordingStateId, @"");
    SCAssert(payload.toState == [self stateId], @"");
    SCAssert([payload isKindOfClass:[SCCaptureImageWhileRecordingStateTransitionPayload class]], @"");
    ;
    SCCaptureImageWhileRecordingStateTransitionPayload *captureImagePayload =
        (SCCaptureImageWhileRecordingStateTransitionPayload *)payload;

    @weakify(self);
    sc_managed_capturer_capture_still_image_completion_handler_t block =
        ^(UIImage *fullScreenImage, NSDictionary *metadata, NSError *error, SCManagedCapturerState *state) {
            captureImagePayload.block(fullScreenImage, metadata, error, state);
            [_performer perform:^{
                @strongify(self);
                [self _cancelRecordingWithContext:context resource:resource];
            }];
        };

    [SCCaptureWorker
        captureStillImageWithCaptureResource:resource
                                 aspectRatio:captureImagePayload.aspectRatio
                            captureSessionID:captureImagePayload.captureSessionID
                      shouldCaptureFromVideo:[SCCaptureWorker shouldCaptureImageFromVideoWithResource:resource]
                           completionHandler:block
                                     context:context];

    [_delegate currentState:self requestToTransferToNewState:SCCaptureRunningStateId payload:nil context:context];
}

- (void)_cancelRecordingWithContext:(NSString *)context resource:(SCCaptureResource *)resource
{
    SCTraceODPCompatibleStart(2);
    SCAssertPerformer(_performer);

    [SCCaptureWorker cancelRecordingWithCaptureResource:resource];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}
@end
