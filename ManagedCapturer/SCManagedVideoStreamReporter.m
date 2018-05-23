//
//  SCManagedVideoStreamReporter.m
//  Snapchat
//
//  Created by Liu Liu on 5/16/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCManagedVideoStreamReporter.h"

#import <SCFoundation/SCLog.h>
#import <SCLogger/SCLogger.h>

static NSTimeInterval const SCManagedVideoStreamReporterInterval = 10;

@implementation SCManagedVideoStreamReporter {
    NSUInteger _droppedSampleBuffers;
    NSUInteger _outputSampleBuffers;
    NSTimeInterval _lastReportTime;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _lastReportTime = CACurrentMediaTime();
    }
    return self;
}

- (void)_reportIfNeeded
{
    NSTimeInterval currentTime = CACurrentMediaTime();
    if (currentTime - _lastReportTime > SCManagedVideoStreamReporterInterval) {
        SCLogGeneralInfo(@"Time: (%.3f - %.3f], Video Streamer Dropped %tu, Output %tu", _lastReportTime, currentTime,
                         _droppedSampleBuffers, _outputSampleBuffers);
        _droppedSampleBuffers = _outputSampleBuffers = 0;
        _lastReportTime = currentTime;
    }
}

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    ++_outputSampleBuffers;
    [self _reportIfNeeded];
}

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
           didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    ++_droppedSampleBuffers;
    [self _reportIfNeeded];
}

@end
