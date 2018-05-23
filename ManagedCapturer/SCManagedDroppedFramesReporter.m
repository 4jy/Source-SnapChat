//
//  SCManagedDroppedFramesReporter.m
//  Snapchat
//
//  Created by Michel Loenngren on 3/21/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedDroppedFramesReporter.h"

#import "SCCameraTweaks.h"
#import "SCManagedCapturerState.h"

#import <SCFoundation/SCBackgroundTaskMonitor.h>
#import <SCFoundation/SCLog.h>
#import <SCFrameRate/SCFrameRateEntry.h>
#import <SCFrameRate/SCVideoFrameDropCounter.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger.h>

CGFloat const kSCCaptureTargetFramerate = 30;

@interface SCManagedDroppedFramesReporter ()

@property (nonatomic) SCVideoFrameDropCounter *frameDropCounter;

@end

@implementation SCManagedDroppedFramesReporter {
    SCVideoFrameDropCounter *_frameDropCounter;
    NSUInteger _droppedFrames;
}

- (SCVideoFrameDropCounter *)frameDropCounter
{
    if (_frameDropCounter == nil) {
        _frameDropCounter = [[SCVideoFrameDropCounter alloc] initWithTargetFramerate:kSCCaptureTargetFramerate];
        _droppedFrames = 0;
    }
    return _frameDropCounter;
}

- (void)reportWithKeepLateFrames:(BOOL)keepLateFrames lensesApplied:(BOOL)lensesApplied
{
    if (_frameDropCounter == nil) {
        return;
    }

    NSMutableDictionary *eventDict = [_frameDropCounter.toDict mutableCopy];
    eventDict[@"total_frame_drop_measured"] = @(_droppedFrames);
    eventDict[@"keep_late_frames"] = @(keepLateFrames);
    // if user select none of the lenses when activing the lenses scroll view, we still enable keepLateFrames
    eventDict[@"lenses_applied"] = @(lensesApplied);

    [[SCLogger sharedInstance] logEvent:kSCCameraMetricsFramesDroppedDuringRecording parameters:eventDict];

    // Reset
    _frameDropCounter = nil;
    _droppedFrames = 0;
}

- (void)didChangeCaptureDevicePosition
{
    [_frameDropCounter didChangeCaptureDevicePosition];
}

#pragma mark - SCManagedVideoDataSourceListener

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    [self.frameDropCounter processFrameTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
}

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
           didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    _droppedFrames += 1;
    NSDictionary<NSString *, NSNumber *> *backgroundTaskScreenshot = SCBackgrounTaskScreenshotReport();
    SCLogCoreCameraInfo(@"[SCManagedDroppedFramesReporter] frame dropped, background tasks: %@",
                        backgroundTaskScreenshot);
}

@end
