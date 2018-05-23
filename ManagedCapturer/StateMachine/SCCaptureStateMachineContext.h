//
//  SCCaptureStateMachineContext.h
//  Snapchat
//
//  Created by Lin Jia on 10/18/17.
//
//

#import "SCCaptureCommon.h"
#import "SCManagedCaptureDevice.h"

#import <SCAudio/SCAudioConfiguration.h>

#import <Foundation/Foundation.h>

/*
 SCCaptureStateMachineContext is the central piece that glues all states together.

 It will pass API calls to the current state.

 The classic state machine design pattern:
 https://en.wikipedia.org/wiki/State_pattern

 It is also the delegate for the states it manages, so that those states can tell stateMachineContext to transit to next
 state.
 */

@class SCCaptureResource;

@class SCCapturerToken;

@interface SCCaptureStateMachineContext : NSObject

- (instancetype)initWithResource:(SCCaptureResource *)resource;

- (void)initializeCaptureWithDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                                        completionHandler:(dispatch_block_t)completionHandler
                                                  context:(NSString *)context;

- (SCCapturerToken *)startRunningWithContext:(NSString *)context completionHandler:(dispatch_block_t)completionHandler;

- (void)stopRunningWithCapturerToken:(SCCapturerToken *)token
                   completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                             context:(NSString *)context;

- (void)stopRunningWithCapturerToken:(SCCapturerToken *)token
                               after:(NSTimeInterval)delay
                   completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                             context:(NSString *)context;

- (void)prepareForRecordingAsynchronouslyWithAudioConfiguration:(SCAudioConfiguration *)configuration
                                                        context:(NSString *)context;

- (void)startRecordingWithOutputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                      audioConfiguration:(SCAudioConfiguration *)configuration
                             maxDuration:(NSTimeInterval)maxDuration
                                 fileURL:(NSURL *)fileURL
                        captureSessionID:(NSString *)captureSessionID
                       completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)completionHandler
                                 context:(NSString *)context;

- (void)stopRecordingWithContext:(NSString *)context;

- (void)cancelRecordingWithContext:(NSString *)context;

- (void)captureStillImageAsynchronouslyWithAspectRatio:(CGFloat)aspectRatio
                                      captureSessionID:(NSString *)captureSessionID
                                     completionHandler:
                                         (sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                                               context:(NSString *)context;

#pragma mark - Scanning
- (void)startScanAsynchronouslyWithScanConfiguration:(SCScanConfiguration *)configuration context:(NSString *)context;
- (void)stopScanAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler context:(NSString *)context;

@end
