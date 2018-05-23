//
//  SCCaptureRecordingState.m
//  Snapchat
//
//  Created by Jingtian Yang on 12/01/2018.
//

#import "SCCaptureRecordingState.h"

#import "SCCaptureImageWhileRecordingStateTransitionPayload.h"
#import "SCCaptureRecordingStateTransitionPayload.h"
#import "SCManagedCapturerV1_Private.h"
#import "SCStateTransitionPayload.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>

@interface SCCaptureRecordingState () {
    __weak id<SCCaptureStateDelegate> _delegate;
    SCQueuePerformer *_performer;
}
@end

@implementation SCCaptureRecordingState

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
    SCAssertPerformer(resource.queuePerformer);
    SCAssert(payload.toState == [self stateId], @"");
    if (![payload isKindOfClass:[SCCaptureRecordingStateTransitionPayload class]]) {
        SCAssertFail(@"wrong payload pass in");
        [_delegate currentState:self requestToTransferToNewState:payload.fromState payload:nil context:context];
        return;
    }

    SCCaptureRecordingStateTransitionPayload *recordingPayload = (SCCaptureRecordingStateTransitionPayload *)payload;
    [SCCaptureWorker startRecordingWithCaptureResource:resource
                                        outputSettings:recordingPayload.outputSettings
                                    audioConfiguration:recordingPayload.configuration
                                           maxDuration:recordingPayload.maxDuration
                                               fileURL:recordingPayload.fileURL
                                      captureSessionID:recordingPayload.captureSessionID
                                     completionHandler:recordingPayload.block];
}

- (void)stopRecordingWithResource:(SCCaptureResource *)resource context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertPerformer(_performer);

    [SCCaptureWorker stopRecordingWithCaptureResource:resource];
    [_delegate currentState:self requestToTransferToNewState:SCCaptureRunningStateId payload:nil context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (void)cancelRecordingWithResource:(SCCaptureResource *)resource context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertPerformer(_performer);

    [SCCaptureWorker cancelRecordingWithCaptureResource:resource];
    [_delegate currentState:self requestToTransferToNewState:SCCaptureRunningStateId payload:nil context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (SCCaptureStateMachineStateId)stateId
{
    return SCCaptureRecordingStateId;
}

- (void)captureStillImageWithResource:(SCCaptureResource *)resource
                          aspectRatio:(CGFloat)aspectRatio
                     captureSessionID:(NSString *)captureSessionID
                    completionHandler:(sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                              context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCCaptureImageWhileRecordingStateTransitionPayload *payload = [
        [SCCaptureImageWhileRecordingStateTransitionPayload alloc] initWithFromState:SCCaptureRecordingStateId
                                                                             toState:SCCaptureImageWhileRecordingStateId
                                                                    captureSessionId:captureSessionID
                                                                         aspectRatio:aspectRatio
                                                                   completionHandler:completionHandler];
    [_delegate currentState:self
        requestToTransferToNewState:SCCaptureImageWhileRecordingStateId
                            payload:payload
                            context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

@end
