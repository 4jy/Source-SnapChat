//
//  SCManagedVideoCapturerLogger.m
//  Snapchat
//
//  Created by Pinlin on 12/04/2017.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedVideoCapturerLogger.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger.h>

@import QuartzCore;

@interface SCManagedVideoCapturerLogger () {
    // For time profiles metric during start recording
    NSMutableDictionary *_startingStepsDelayTime;
    NSTimeInterval _beginStartTime;
    NSTimeInterval _lastCheckpointTime;
    NSTimeInterval _startedTime;
}

@end

@implementation SCManagedVideoCapturerLogger

- (instancetype)init
{
    self = [super init];
    if (self) {
        _startingStepsDelayTime = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)prepareForStartingLog
{
    _beginStartTime = CACurrentMediaTime();
    _lastCheckpointTime = _beginStartTime;
    [_startingStepsDelayTime removeAllObjects];
}

- (void)logStartingStep:(NSString *)stepname
{
    SCAssert(_beginStartTime > 0, @"logger is not ready yet, please call prepareForStartingLog at first");
    NSTimeInterval currentCheckpointTime = CACurrentMediaTime();
    _startingStepsDelayTime[stepname] = @(currentCheckpointTime - _lastCheckpointTime);
    _lastCheckpointTime = currentCheckpointTime;
}

- (void)endLoggingForStarting
{
    SCAssert(_beginStartTime > 0, @"logger is not ready yet, please call prepareForStartingLog at first");
    _startedTime = CACurrentMediaTime();
    [self logStartingStep:kSCCapturerStartingStepStartingWriting];
    _startingStepsDelayTime[kCapturerStartingTotalDelay] = @(CACurrentMediaTime() - _beginStartTime);
}

- (void)logEventIfStartingTooSlow
{
    if (_beginStartTime > 0) {
        if (_startingStepsDelayTime.count == 0) {
            // It should not be here. We only need to log once.
            return;
        }
        SCLogGeneralWarning(@"Capturer starting delay(in second):%f", _startedTime - _beginStartTime);
        [[SCLogger sharedInstance] logEvent:kSCCameraMetricsVideoCapturerStartDelay parameters:_startingStepsDelayTime];
        // Clean all delay times after logging
        [_startingStepsDelayTime removeAllObjects];
        _beginStartTime = 0;
    }
}

@end
