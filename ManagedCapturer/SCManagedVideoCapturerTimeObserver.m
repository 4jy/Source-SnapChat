//
//  SCManagedVideoCapturerTimeObserver.m
//  Snapchat
//
//  Created by Michel Loenngren on 4/3/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedVideoCapturerTimeObserver.h"

#import "SCTimedTask.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCThreadHelpers.h>

@implementation SCManagedVideoCapturerTimeObserver {
    NSMutableArray<SCTimedTask *> *_tasks;
    BOOL _isProcessing;
}

- (instancetype)init
{
    if (self = [super init]) {
        _tasks = [NSMutableArray new];
        _isProcessing = NO;
    }
    return self;
}

- (void)addTimedTask:(SCTimedTask *_Nonnull)task
{
    SCAssert(!_isProcessing,
             @"[SCManagedVideoCapturerTimeObserver] Trying to add an SCTimedTask after streaming started.");
    SCAssert(CMTIME_IS_VALID(task.targetTime),
             @"[SCManagedVideoCapturerTimeObserver] Trying to add an SCTimedTask with invalid time.");
    [_tasks addObject:task];
    [_tasks sortUsingComparator:^NSComparisonResult(SCTimedTask *_Nonnull obj1, SCTimedTask *_Nonnull obj2) {
        return (NSComparisonResult)CMTimeCompare(obj2.targetTime, obj1.targetTime);
    }];
    SCLogGeneralInfo(@"[SCManagedVideoCapturerTimeObserver] Adding task: %@, task count: %lu", task,
                     (unsigned long)_tasks.count);
}

- (void)processTime:(CMTime)relativePresentationTime
    sessionStartTimeDelayInSecond:(CGFloat)sessionStartTimeDelayInSecond
{
    _isProcessing = YES;
    SCTimedTask *last = _tasks.lastObject;
    while (last && last.task && CMTimeCompare(relativePresentationTime, last.targetTime) >= 0) {
        [_tasks removeLastObject];
        void (^task)(CMTime relativePresentationTime, CGFloat sessionStartTimeDelay) = last.task;
        last.task = nil;
        runOnMainThreadAsynchronously(^{
            task(relativePresentationTime, sessionStartTimeDelayInSecond);
        });
        last = _tasks.lastObject;
    }
}

@end
