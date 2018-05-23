//
//  SCManagedVideoCapturerTimeObserver.h
//  Snapchat
//
//  Created by Michel Loenngren on 4/3/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

@class SCTimedTask;

/*
 Class keeping track of SCTimedTasks and firing them on the main thread
 when needed.
 */
@interface SCManagedVideoCapturerTimeObserver : NSObject

- (void)addTimedTask:(SCTimedTask *_Nonnull)task;

- (void)processTime:(CMTime)relativePresentationTime
    sessionStartTimeDelayInSecond:(CGFloat)sessionStartTimeDelayInSecond;

@end
