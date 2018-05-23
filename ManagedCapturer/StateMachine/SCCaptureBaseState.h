//
//  SCCaptureBaseState.h
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCCaptureCommon.h"
#import "SCCaptureStateDelegate.h"
#import "SCCaptureStateMachineBookKeeper.h"
#import "SCCaptureStateUtil.h"
#import "SCCaptureWorker.h"
#import "SCManagedCaptureDevice.h"
#import "SCManagedCapturerState.h"
#import "SCStateTransitionPayload.h"

#import <Foundation/Foundation.h>

@class SCCaptureResource;

@class SCCapturerToken;

@class SCAudioConfiguration;

@class SCQueuePerformer;
/*
 Every state machine state needs to inherent SCCaptureBaseState to have the APIs. State machine state in general will
 only implement APIs which are legal for itself. If illegal APIs are invoked, SCCaptureBaseState will handle it.
 The intended behavior:
 1) crash using SCAssert in Debug build,
 2) ignore api call, and log the call, for alpha/master/production.
 3) in the future, we will introduce dangerous API call concept, and restart camera in such case, to avoid bad state.

 Every state machine state is going to be built to follow functional programming as more as possible. The shared
 resources between them will be passed into the API via SCCaptureResource.
 */

@interface SCCaptureBaseState : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
                       bookKeeper:(SCCaptureStateMachineBookKeeper *)bookKeeper
                         delegate:(id<SCCaptureStateDelegate>)delegate;

/* The following API will be invoked at the moment state context promote the state to be current state. State use this
 * chance to do something, such as start recording for recording state.
 */
- (void)didBecomeCurrentState:(SCStateTransitionPayload *)payload
                     resource:(SCCaptureResource *)resource
                      context:(NSString *)context;

- (SCCaptureStateMachineStateId)stateId;

- (void)initializeCaptureWithDevicePosition:(SCManagedCaptureDevicePosition)devicePosition
                                   resource:(SCCaptureResource *)resource
                          completionHandler:(dispatch_block_t)completionHandler
                                    context:(NSString *)context;

- (void)startRunningWithCapturerToken:(SCCapturerToken *)token
                             resource:(SCCaptureResource *)resource
                    completionHandler:(dispatch_block_t)completionHandler
                              context:(NSString *)context;

- (void)stopRunningWithCapturerToken:(SCCapturerToken *)token
                            resource:(SCCaptureResource *)resource
                   completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                             context:(NSString *)context;

- (void)prepareForRecordingWithResource:(SCCaptureResource *)resource
                     audioConfiguration:(SCAudioConfiguration *)configuration
                                context:(NSString *)context;

- (void)startRecordingWithResource:(SCCaptureResource *)resource
                audioConfiguration:(SCAudioConfiguration *)configuration
                    outputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                       maxDuration:(NSTimeInterval)maxDuration
                           fileURL:(NSURL *)fileURL
                  captureSessionID:(NSString *)captureSessionID
                 completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)completionHandler
                           context:(NSString *)context;

- (void)stopRecordingWithResource:(SCCaptureResource *)resource context:(NSString *)context;

- (void)cancelRecordingWithResource:(SCCaptureResource *)resource context:(NSString *)context;

- (void)captureStillImageWithResource:(SCCaptureResource *)resource
                          aspectRatio:(CGFloat)aspectRatio
                     captureSessionID:(NSString *)captureSessionID
                    completionHandler:(sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                              context:(NSString *)context;

- (void)startScanWithScanConfiguration:(SCScanConfiguration *)configuration
                              resource:(SCCaptureResource *)resource
                               context:(NSString *)context;

- (void)stopScanWithCompletionHandler:(dispatch_block_t)completionHandler
                             resource:(SCCaptureResource *)resource
                              context:(NSString *)context;

@property (nonatomic, strong, readonly) SCCaptureStateMachineBookKeeper *bookKeeper;
@end
