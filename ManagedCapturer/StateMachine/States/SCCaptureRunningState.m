//
//  SCCaptureRunningState.m
//  Snapchat
//
//  Created by Jingtian Yang on 08/01/2018.
//

#import "SCCaptureRunningState.h"

#import "SCCaptureImageStateTransitionPayload.h"
#import "SCCaptureRecordingStateTransitionPayload.h"
#import "SCCaptureWorker.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerV1_Private.h"
#import "SCScanConfiguration.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCCaptureRunningState () {
    __weak id<SCCaptureStateDelegate> _delegate;
    SCQueuePerformer *_performer;
}

@end

@implementation SCCaptureRunningState

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

- (void)captureStillImageWithResource:(SCCaptureResource *)resource
                          aspectRatio:(CGFloat)aspectRatio
                     captureSessionID:(NSString *)captureSessionID
                    completionHandler:(sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                              context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCCaptureImageStateTransitionPayload *payload =
        [[SCCaptureImageStateTransitionPayload alloc] initWithFromState:SCCaptureRunningStateId
                                                                toState:SCCaptureImageStateId
                                                       captureSessionId:captureSessionID
                                                            aspectRatio:aspectRatio
                                                      completionHandler:completionHandler];
    [_delegate currentState:self requestToTransferToNewState:SCCaptureImageStateId payload:payload context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (SCCaptureStateMachineStateId)stateId
{
    return SCCaptureRunningStateId;
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

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (void)stopRunningWithCapturerToken:(SCCapturerToken *)token
                            resource:(SCCaptureResource *)resource
                   completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                             context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertPerformer(_performer);

    SCLogCapturerInfo(@"Stop running asynchronously. token:%@", token);
    if ([[SCManagedCapturerV1 sharedInstance] stopRunningWithCaptureToken:token
                                                        completionHandler:completionHandler
                                                                  context:context]) {
        [_delegate currentState:self
            requestToTransferToNewState:SCCaptureInitializedStateId
                                payload:nil
                                context:context];
    }

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (void)startScanWithScanConfiguration:(SCScanConfiguration *)configuration
                              resource:(SCCaptureResource *)resource
                               context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Start scan on preview asynchronously. configuration:%@", configuration);
    SCAssertPerformer(_performer);
    [SCCaptureWorker startScanWithScanConfiguration:configuration resource:resource];
    [_delegate currentState:self requestToTransferToNewState:SCCaptureScanningStateId payload:nil context:context];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (void)prepareForRecordingWithResource:(SCCaptureResource *)resource
                     audioConfiguration:(SCAudioConfiguration *)configuration
                                context:(NSString *)context
{
    SCAssertPerformer(_performer);
    SCTraceODPCompatibleStart(2);
    [SCCaptureWorker prepareForRecordingWithAudioConfiguration:configuration resource:resource];

    NSString *apiName =
        [NSString sc_stringWithFormat:@"%@/%@", NSStringFromClass([self class]), NSStringFromSelector(_cmd)];
    [self.bookKeeper logAPICalled:apiName context:context];
}

- (void)startRecordingWithResource:(SCCaptureResource *)resource
                audioConfiguration:(SCAudioConfiguration *)configuration
                    outputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                       maxDuration:(NSTimeInterval)maxDuration
                           fileURL:(NSURL *)fileURL
                  captureSessionID:(NSString *)captureSessionID
                 completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)completionHandler
                           context:(NSString *)context
{
    SCTraceODPCompatibleStart(2);
    SCAssertPerformer(_performer);

    SCCaptureRecordingStateTransitionPayload *payload =
        [[SCCaptureRecordingStateTransitionPayload alloc] initWithFromState:SCCaptureRunningStateId
                                                                    toState:SCCaptureRecordingStateId
                                                             outputSettings:outputSettings
                                                         audioConfiguration:configuration
                                                                maxDuration:maxDuration
                                                                    fileURL:fileURL
                                                           captureSessionID:captureSessionID
                                                          completionHandler:completionHandler];
    [_delegate currentState:self requestToTransferToNewState:SCCaptureRecordingStateId payload:payload context:context];

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
