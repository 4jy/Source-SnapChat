//
//  SCCaptureFaceDetectorTrigger.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/22/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class is used to control when should SCCaptureFaceDetector starts and stops.

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

@protocol SCCaptureFaceDetector;

@interface SCCaptureFaceDetectorTrigger : NSObject

SC_INIT_AND_NEW_UNAVAILABLE;

- (instancetype)initWithDetector:(id<SCCaptureFaceDetector>)detector;

@end
