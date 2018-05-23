//
//  SCCaptureStateMachineContext.m
//  Snapchat
//
//  Created by Lin Jia on 10/18/17.
//
//

#import "SCCaptureStateMachineContext.h"

#import "SCCaptureBaseState.h"
#import "SCCaptureImageState.h"
#import "SCCaptureImageWhileRecordingState.h"
#import "SCCaptureInitializedState.h"
#import "SCCaptureRecordingState.h"
#import "SCCaptureResource.h"
#import "SCCaptureRunningState.h"
#import "SCCaptureScanningState.h"
#import "SCCaptureStateMachineBookKeeper.h"
#import "SCCaptureStateUtil.h"
#import "SCCaptureUninitializedState.h"
#import "SCCaptureWorker.h"
#import "SCCapturerToken.h"
#import "SCStateTransitionPayload.h"

#import <SCAudio/SCAudioConfiguration.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger+Performance.h>

@interface SCCaptureStateMachineContext () <SCCaptureStateDelegate> {
    SCQueuePerformer *_queuePerformer;

    // Cache all the states.
    NSMutableDictionary<SCCaptureStateKey *, SCCaptureBaseState *> *_states;
    SCCaptureBaseState *_currentState;
    SCCaptureStateMachineBookKeeper *_bookKeeper;
    SCCaptureResource *_captureResource;
}
@end

@implementation SCCaptureStateMachineContext

- (instancetype)initWithResource:(SCCaptureResource *)resource
{
    self = [super init];
    if (self) {
        SCAssert(resource, @"");
        SCAssert(resource.queuePerformer, @"");
        _captureResource = resource;
        _queuePerformer = resource.queuePerformer;
        _states = [[NSMutableDictionary<SCCaptureStateKey *, SCCaptureBaseState *> alloc] init];
        _bookKeeper = [[SCCaptureStateMachineBookKeeper alloc] init];
        [self _setCurrentState:SCCaptureUninitializedStateId payload:nil context:SCCapturerContext];
    }
    return self;
}

- (void)_setCurrentState:(SCCaptureStateMachineStateId)stateId
                 payload:(SCStateTransitionPayload *)payload
                 context:(NSString *)context
{
    switch (stateId) {
    case SCCaptureUninitializedStateId:
        if (![_states objectForKey:@(stateId)]) {
            SCCaptureUninitializedState *uninitializedState =
                [[SCCaptureUninitializedState alloc] initWithPerformer:_queuePerformer
                                                            bookKeeper:_bookKeeper
                                                              delegate:self];
            [_states setObject:uninitializedState forKey:@(stateId)];
        }
        _currentState = [_states objectForKey:@(stateId)];
        break;
    case SCCaptureInitializedStateId:
        if (![_states objectForKey:@(stateId)]) {
            SCCaptureInitializedState *initializedState =
                [[SCCaptureInitializedState alloc] initWithPerformer:_queuePerformer
                                                          bookKeeper:_bookKeeper
                                                            delegate:self];
            [_states setObject:initializedState forKey:@(stateId)];
        }
        _currentState = [_states objectForKey:@(stateId)];
        break;
    case SCCaptureRunningStateId:
        if (![_states objectForKey:@(stateId)]) {
            SCCaptureRunningState *runningState =
                [[SCCaptureRunningState alloc] initWithPerformer:_queuePerformer bookKeeper:_bookKeeper delegate:self];
            [_states setObject:runningState forKey:@(stateId)];
        }
        _currentState = [_states objectForKey:@(stateId)];
        break;
    case SCCaptureImageStateId:
        if (![_states objectForKey:@(stateId)]) {
            SCCaptureImageState *captureImageState =
                [[SCCaptureImageState alloc] initWithPerformer:_queuePerformer bookKeeper:_bookKeeper delegate:self];
            [_states setObject:captureImageState forKey:@(stateId)];
        }
        _currentState = [_states objectForKey:@(stateId)];
        break;
    case SCCaptureImageWhileRecordingStateId:
        if (![_states objectForKey:@(stateId)]) {
            SCCaptureImageWhileRecordingState *captureImageWhileRecordingState =
                [[SCCaptureImageWhileRecordingState alloc] initWithPerformer:_queuePerformer
                                                                  bookKeeper:_bookKeeper
                                                                    delegate:self];
            [_states setObject:captureImageWhileRecordingState forKey:@(stateId)];
        }
        _currentState = [_states objectForKey:@(stateId)];
        break;
    case SCCaptureScanningStateId:
        if (![_states objectForKey:@(stateId)]) {
            SCCaptureScanningState *scanningState =
                [[SCCaptureScanningState alloc] initWithPerformer:_queuePerformer bookKeeper:_bookKeeper delegate:self];
            [_states setObject:scanningState forKey:@(stateId)];
        }
        _currentState = [_states objectForKey:@(stateId)];
        break;
    case SCCaptureRecordingStateId:
        if (![_states objectForKey:@(stateId)]) {
            SCCaptureRecordingState *recordingState = [[SCCaptureRecordingState alloc] initWithPerformer:_queuePerformer
                                                                                              bookKeeper:_bookKeeper
                                                                                                delegate:self];
            [_states setObject:recordingState forKey:@(stateId)];
        }
        _currentState = [_states objectForKey:@(stateId)];
        break;
    default:
        SCAssert(NO, @"illigal state Id");
        break;
    }
    [_currentState didBecomeCurrentState:payload resource:_captureResource context:context];
}

- (void)initializeCaptureWithDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                                        completionHandler:(dispatch_block_t)completionHandler
                                                  context:(NSString *)context
{
    [SCCaptureWorker setupCapturePreviewLayerController];

    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState initializeCaptureWithDevicePosition:devicePosition
                                                  resource:_captureResource
                                         completionHandler:completionHandler
                                                   context:context];
    }];
}

- (SCCapturerToken *)startRunningWithContext:(NSString *)context completionHandler:(dispatch_block_t)completionHandler
{
    [[SCLogger sharedInstance] updateLogTimedEventStart:kSCCameraMetricsOpen uniqueId:@""];

    SCCapturerToken *token = [[SCCapturerToken alloc] initWithIdentifier:context];
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState startRunningWithCapturerToken:token
                                            resource:_captureResource
                                   completionHandler:completionHandler
                                             context:context];
    }];

    return token;
}

- (void)stopRunningWithCapturerToken:(SCCapturerToken *)token
                   completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                             context:(NSString *)context
{
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState stopRunningWithCapturerToken:token
                                           resource:_captureResource
                                  completionHandler:completionHandler
                                            context:context];
    }];
}

- (void)stopRunningWithCapturerToken:(SCCapturerToken *)token
                               after:(NSTimeInterval)delay
                   completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                             context:(NSString *)context
{
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState stopRunningWithCapturerToken:token
                                           resource:_captureResource
                                  completionHandler:completionHandler
                                            context:context];
    }
                       after:delay];
}

- (void)prepareForRecordingAsynchronouslyWithAudioConfiguration:(SCAudioConfiguration *)configuration
                                                        context:(NSString *)context
{
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState prepareForRecordingWithResource:_captureResource
                                    audioConfiguration:configuration
                                               context:context];
    }];
}

- (void)startRecordingWithOutputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                      audioConfiguration:(SCAudioConfiguration *)configuration
                             maxDuration:(NSTimeInterval)maxDuration
                                 fileURL:(NSURL *)fileURL
                        captureSessionID:(NSString *)captureSessionID
                       completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)completionHandler
                                 context:(NSString *)context
{
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState startRecordingWithResource:_captureResource
                               audioConfiguration:configuration
                                   outputSettings:outputSettings
                                      maxDuration:maxDuration
                                          fileURL:fileURL
                                 captureSessionID:captureSessionID
                                completionHandler:completionHandler
                                          context:context];
    }];
}

- (void)stopRecordingWithContext:(NSString *)context
{
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState stopRecordingWithResource:_captureResource context:context];
    }];
}

- (void)cancelRecordingWithContext:(NSString *)context
{
    SCTraceResumeToken resumeToken = SCTraceCapture();
    [_queuePerformer perform:^{
        SCTraceResume(resumeToken);
        [_currentState cancelRecordingWithResource:_captureResource context:context];
    }];
}

- (void)captureStillImageAsynchronouslyWithAspectRatio:(CGFloat)aspectRatio
                                      captureSessionID:(NSString *)captureSessionID
                                     completionHandler:
                                         (sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                                               context:(NSString *)context
{
    [_queuePerformer perform:^() {
        [_currentState captureStillImageWithResource:_captureResource
                                         aspectRatio:aspectRatio
                                    captureSessionID:captureSessionID
                                   completionHandler:completionHandler
                                             context:context];
    }];
}

- (void)startScanAsynchronouslyWithScanConfiguration:(SCScanConfiguration *)configuration context:(NSString *)context
{
    [_queuePerformer perform:^() {
        [_currentState startScanWithScanConfiguration:configuration resource:_captureResource context:context];
    }];
}

- (void)stopScanAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler context:(NSString *)context
{
    [_queuePerformer perform:^() {
        [_currentState stopScanWithCompletionHandler:completionHandler resource:_captureResource context:context];
    }];
}

- (void)currentState:(SCCaptureBaseState *)state
    requestToTransferToNewState:(SCCaptureStateMachineStateId)newState
                        payload:(SCStateTransitionPayload *)payload
                        context:(NSString *)context
{
    SCAssertPerformer(_queuePerformer);
    SCAssert(_currentState == state, @"state: %@ newState: %@ context:%@", SCCaptureStateName([state stateId]),
             SCCaptureStateName(newState), context);
    if (payload) {
        SCAssert(payload.fromState == [state stateId], @"From state id check");
        SCAssert(payload.toState == newState, @"To state id check");
    }

    if (_currentState != state) {
        return;
    }

    [_bookKeeper stateTransitionFrom:[state stateId] to:newState context:context];
    [self _setCurrentState:newState payload:payload context:context];
}

@end
