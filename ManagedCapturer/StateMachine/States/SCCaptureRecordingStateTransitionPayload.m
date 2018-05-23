//
//  SCCaptureRecordingStateTransitionPayload.m
//  Snapchat
//
//  Created by Jingtian Yang on 12/01/2018.
//

#import "SCCaptureRecordingStateTransitionPayload.h"

@implementation SCCaptureRecordingStateTransitionPayload

- (instancetype)initWithFromState:(SCCaptureStateMachineStateId)fromState
                          toState:(SCCaptureStateMachineStateId)toState
                   outputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
               audioConfiguration:configuration
                      maxDuration:(NSTimeInterval)maxDuration
                          fileURL:(NSURL *)fileURL
                 captureSessionID:(NSString *)captureSessionID
                completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)block
{
    self = [super initWithFromState:fromState toState:toState];
    if (self) {
        _outputSettings = outputSettings;
        _configuration = configuration;
        _maxDuration = maxDuration;
        _fileURL = fileURL;
        _captureSessionID = captureSessionID;
        _block = block;
    }
    return self;
}

@end
