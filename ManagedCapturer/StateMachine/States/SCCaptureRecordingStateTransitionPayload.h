//
//  SCCaptureRecordingStateTransitionPayload.h
//  Snapchat
//
//  Created by Jingtian Yang on 12/01/2018.
//

#import "SCCaptureCommon.h"
#import "SCManagedVideoCapturerOutputSettings.h"
#import "SCStateTransitionPayload.h"

#import <SCAudio/SCAudioConfiguration.h>

#import <Foundation/Foundation.h>

@interface SCCaptureRecordingStateTransitionPayload : SCStateTransitionPayload

@property (nonatomic, readonly, strong) SCManagedVideoCapturerOutputSettings *outputSettings;

@property (nonatomic, readonly, strong) SCAudioConfiguration *configuration;

@property (nonatomic, readonly, assign) NSTimeInterval maxDuration;

@property (nonatomic, readonly, strong) NSURL *fileURL;

@property (nonatomic, readonly, strong) NSString *captureSessionID;

@property (nonatomic, readonly, copy) sc_managed_capturer_start_recording_completion_handler_t block;

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithFromState:(SCCaptureStateMachineStateId)fromState
                          toState:(SCCaptureStateMachineStateId)toState
                   outputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
               audioConfiguration:(SCAudioConfiguration *)configuration
                      maxDuration:(NSTimeInterval)maxDuration
                          fileURL:(NSURL *)fileURL
                 captureSessionID:(NSString *)captureSessionID
                completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)block;

@end
