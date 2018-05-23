//
//  SCCaptureBaseState.m
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCCaptureBaseState.h"

#import "SCCaptureStateMachineBookKeeper.h"
#import "SCCapturerToken.h"
#import "SCManagedCapturerV1_Private.h"

#import <SCFoundation/SCAppEnvironment.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>

@implementation SCCaptureBaseState {
    SCCaptureStateMachineBookKeeper *_bookKeeper;
    SCQueuePerformer *_performer;
    __weak id<SCCaptureStateDelegate> _delegate;
}

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate
{
    self = [super init];
    if (self) {
        SCAssert(performer, @"");
        SCAssert(bookKeeper, @"");
        _bookKeeper = bookKeeper;
        _performer = performer;
        _delegate = delegate;
    }
    return self;
}

- (SCCaptureStateMachineStateId)stateId
{
    return SCCaptureBaseStateId;
}

- (void)didBecomeCurrentState:(SCStateTransitionPayload *)payload
                     resource:(SCCaptureResource *)resource
                      context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"didBecomeCurrentState" context:context];
}

- (void)initializeCaptureWithDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
                                   resource:(SCCaptureResource *)resource
                          completionHandler:(dispatch_block_t)completionHandler
                                    context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"initializeCaptureWithDevicePosition" context:context];
}

- (void)startRunningWithCapturerToken:(SCCapturerToken *)token
                             resource:(SCCaptureResource *)resource
                    completionHandler:(dispatch_block_t)completionHandler
                              context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"startRunningWithCapturerToken" context:context];
}

- (void)stopRunningWithCapturerToken:(SCCapturerToken *)token
                            resource:(SCCaptureResource *)resource
                   completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                             context:(NSString *)context
{
    SCAssertPerformer(_performer);
    BOOL actuallyStopped = [[SCManagedCapturerV1 sharedInstance] stopRunningWithCaptureToken:token
                                                                           completionHandler:completionHandler
                                                                                     context:context];
    // TODO: Fix CCAM-14450
    // This is a temporary solution for https://jira.sc-corp.net/browse/CCAM-14450
    // It is caused by switching from scanning state to stop running state when the view is disappearing in the scanning
    // state, which can be reproduced by triggering scanning and then switch to maps page.
    // We remove SCAssert to ingore the crashes in master branch and will find a solution for the illegal call for the
    // state machine later

    if (self.stateId != SCCaptureScanningStateId) {
        SCAssert(!actuallyStopped, @"actuallyStopped in state: %@ with context: %@", SCCaptureStateName([self stateId]),
                 context);
    } else {
        SCLogCaptureStateMachineInfo(@"actuallyStopped:%d in state: %@ with context: %@", actuallyStopped,
                                     SCCaptureStateName([self stateId]), context);
    }

    if (actuallyStopped) {
        [_delegate currentState:self
            requestToTransferToNewState:SCCaptureInitializedStateId
                                payload:nil
                                context:context];
    }
}

- (void)prepareForRecordingWithResource:(SCCaptureResource *)resource
                     audioConfiguration:(SCAudioConfiguration *)configuration
                                context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"prepareForRecordingWithResource" context:context];
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
    [self _handleBaseStateBehavior:@"startRecordingWithResource" context:context];
}

- (void)stopRecordingWithResource:(SCCaptureResource *)resource context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"stopRecordingWithResource" context:context];
}

- (void)cancelRecordingWithResource:(SCCaptureResource *)resource context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"cancelRecordingWithResource" context:context];
}

- (void)captureStillImageWithResource:(SCCaptureResource *)resource
                          aspectRatio:(CGFloat)aspectRatio
                     captureSessionID:(NSString *)captureSessionID
                    completionHandler:(sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                              context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"captureStillImageWithResource" context:context];
}

- (void)startScanWithScanConfiguration:(SCScanConfiguration *)configuration
                              resource:(SCCaptureResource *)resource
                               context:(NSString *)context
{
    [self _handleBaseStateBehavior:@"startScanWithScanConfiguration" context:context];
}

- (void)stopScanWithCompletionHandler:(dispatch_block_t)completionHandler
                             resource:(SCCaptureResource *)resource
                              context:(NSString *)context
{
    // Temporary solution until IDT-12520 is resolved.
    [SCCaptureWorker stopScanWithCompletionHandler:completionHandler resource:resource];
    //[self _handleBaseStateBehavior:@"stopScanWithCompletionHandler"];
}

- (void)_handleBaseStateBehavior:(NSString *)illegalAPIName context:(NSString *)context
{
    [_bookKeeper state:[self stateId]
        illegalAPIcalled:illegalAPIName
               callStack:[NSThread callStackSymbols]
                 context:context];
    if (SCIsDebugBuild()) {
        SCAssertFail(@"illegal API invoked on capture state machine");
    }
}

- (SCCaptureStateMachineBookKeeper *)bookKeeper
{
    return _bookKeeper;
}
@end
