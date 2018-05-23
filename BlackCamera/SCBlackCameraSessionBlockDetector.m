//
//  SCBlackCameraSessionBlockDetector.m
//  Snapchat
//
//  Created by Derek Wang on 25/01/2018.
//

#import "SCBlackCameraSessionBlockDetector.h"

#import "SCBlackCameraReporter.h"

#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger.h>

@import CoreGraphics;

// Longer than 5 seconds is considerred as black camera
static CGFloat const kSCBlackCameraBlockingThreshold = 5;
// Will report if session blocks longer than 1 second
static CGFloat const kSCSessionBlockingLogThreshold = 1;

@interface SCBlackCameraSessionBlockDetector () {
    NSTimeInterval _startTime;
}
@property (nonatomic) SCBlackCameraReporter *reporter;

@end

@implementation SCBlackCameraSessionBlockDetector

- (instancetype)initWithReporter:(SCBlackCameraReporter *)reporter
{
    if (self = [super init]) {
        _reporter = reporter;
    }
    return self;
}

- (void)sessionWillCallStartRunning
{
    _startTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)sessionDidCallStartRunning
{
    [self _reportBlackCameraIfNeededWithCause:SCBlackCameraSessionStartRunningBlocked];
    [self _reportBlockingIfNeededWithCause:SCBlackCameraSessionStartRunningBlocked];
}

- (void)sessionWillCommitConfiguration
{
    _startTime = [NSDate timeIntervalSinceReferenceDate];
}

- (void)sessionDidCommitConfiguration
{
    [self _reportBlackCameraIfNeededWithCause:SCBlackCameraSessionConfigurationBlocked];
    [self _reportBlockingIfNeededWithCause:SCBlackCameraSessionConfigurationBlocked];
}

- (void)_reportBlockingIfNeededWithCause:(SCBlackCameraCause)cause
{
    NSTimeInterval duration = [NSDate timeIntervalSinceReferenceDate] - _startTime;
    if (duration >= kSCSessionBlockingLogThreshold) {
        NSString *causeStr = [_reporter causeNameFor:cause];
        [[SCLogger sharedInstance] logEvent:KSCCameraCaptureSessionBlocked
                                 parameters:@{
                                     @"cause" : causeStr,
                                     @"duration" : @(duration)
                                 }];
    }
}

- (void)_reportBlackCameraIfNeededWithCause:(SCBlackCameraCause)cause
{
    NSTimeInterval endTime = [NSDate timeIntervalSinceReferenceDate];
    if (endTime - _startTime >= kSCBlackCameraBlockingThreshold) {
        [_reporter reportBlackCameraWithCause:cause];
    }
}

@end
