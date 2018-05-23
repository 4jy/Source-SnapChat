//
//  SCBlackCameraSessionBlockDetector.h
//  Snapchat
//
//  Created by Derek Wang on 25/01/2018.
//

#import "SCBlackCameraReporter.h"

#import <Foundation/Foundation.h>

@interface SCBlackCameraSessionBlockDetector : NSObject

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithReporter:(SCBlackCameraReporter *)reporter;

- (void)sessionWillCallStartRunning;
- (void)sessionDidCallStartRunning;

- (void)sessionWillCommitConfiguration;
- (void)sessionDidCommitConfiguration;

@end
