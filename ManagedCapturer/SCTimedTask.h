//
//  SCTimedTask.h
//  Snapchat
//
//  Created by Michel Loenngren on 4/2/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

/*
 Block based timed task
 */
@interface SCTimedTask : NSObject

@property (nonatomic, assign) CMTime targetTime;
@property (nonatomic, copy) void (^task)(CMTime relativePresentationTime, CGFloat sessionStartTimeDelayInSecond);

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithTargetTime:(CMTime)targetTime
                              task:(void (^)(CMTime relativePresentationTime,
                                             CGFloat sessionStartTimeDelayInSecond))task;

- (NSString *)description;

@end
