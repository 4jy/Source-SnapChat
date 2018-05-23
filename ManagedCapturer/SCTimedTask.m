//
//  SCTimedTask.m
//  Snapchat
//
//  Created by Michel Loenngren on 4/2/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCTimedTask.h"

#import <SCFoundation/NSString+SCFormat.h>

@implementation SCTimedTask

- (instancetype)initWithTargetTime:(CMTime)targetTime
                              task:
                                  (void (^)(CMTime relativePresentationTime, CGFloat sessionStartTimeDelayInSecond))task
{
    if (self = [super init]) {
        _targetTime = targetTime;
        _task = task;
    }
    return self;
}

- (NSString *)description
{
    return [NSString
        sc_stringWithFormat:@"<%@: %p, targetTime: %lld>", NSStringFromClass([self class]), self, _targetTime.value];
}

@end
