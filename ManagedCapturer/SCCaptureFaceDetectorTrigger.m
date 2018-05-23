//
//  SCCaptureFaceDetectorTrigger.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/22/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCCaptureFaceDetectorTrigger.h"

#import "SCCaptureFaceDetector.h"

#import <SCFoundation/SCAppLifecycle.h>
#import <SCFoundation/SCIdleMonitor.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTaskManager.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCCaptureFaceDetectorTrigger () {
    id<SCCaptureFaceDetector> __weak _detector;
}
@end

@implementation SCCaptureFaceDetectorTrigger

- (instancetype)initWithDetector:(id<SCCaptureFaceDetector>)detector
{
    self = [super init];
    if (self) {
        _detector = detector;
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_applicationDidBecomeActive)
                                                     name:kSCPostponedUIApplicationDidBecomeActiveNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_applicationWillResignActive)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];
    }
    return self;
}

#pragma mark - Internal Methods
- (void)_applicationWillResignActive
{
    SCTraceODPCompatibleStart(2);
    [self _stopDetection];
}

- (void)_applicationDidBecomeActive
{
    SCTraceODPCompatibleStart(2);
    [self _waitUntilAppStartCompleteToStartDetection];
}

- (void)_waitUntilAppStartCompleteToStartDetection
{
    SCTraceODPCompatibleStart(2);
    @weakify(self);

    if (SCExperimentWithWaitUntilIdleReplacement()) {
        [[SCTaskManager sharedManager] addTaskToRunWhenAppIdle:"SCCaptureFaceDetectorTrigger.startDetection"
                                                     performer:[_detector detectionPerformer]
                                                         block:^{
                                                             @strongify(self);
                                                             SC_GUARD_ELSE_RETURN(self);

                                                             [self _startDetection];
                                                         }];
    } else {
        [[SCIdleMonitor sharedInstance] waitUntilIdleForTag:"SCCaptureFaceDetectorTrigger.startDetection"
                                              callbackQueue:[_detector detectionPerformer].queue
                                                      block:^{
                                                          @strongify(self);
                                                          SC_GUARD_ELSE_RETURN(self);
                                                          [self _startDetection];
                                                      }];
    }
}

- (void)_startDetection
{
    SCTraceODPCompatibleStart(2);
    [[_detector detectionPerformer] performImmediatelyIfCurrentPerformer:^{
        [_detector startDetection];
    }];
}

- (void)_stopDetection
{
    SCTraceODPCompatibleStart(2);
    [[_detector detectionPerformer] performImmediatelyIfCurrentPerformer:^{
        [_detector stopDetection];
    }];
}

@end
