//
//  SCCaptureFaceDetector.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/27/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This protocol declares properties and methods that are used for face detectors.

#import <Foundation/Foundation.h>

@class SCCaptureResource;
@class SCQueuePerformer;
@class SCCaptureFaceDetectorTrigger;
@class SCCaptureFaceDetectionParser;

@protocol SCCaptureFaceDetector <NSObject>

@property (nonatomic, strong, readonly) SCCaptureFaceDetectorTrigger *trigger;

@property (nonatomic, strong, readonly) SCCaptureFaceDetectionParser *parser;

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource;

- (SCQueuePerformer *)detectionPerformer;

- (void)startDetection;

- (void)stopDetection;

@end
