//
//  SCLogger+Camera.m
//  Snapchat
//
//  Created by Derek Peirce on 5/8/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCLogger+Camera.h"

#import "SCCameraTweaks.h"

#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCLogger/SCCameraMetrics+CameraCreationDelay.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger+Performance.h>

#import <objc/runtime.h>

@implementation SCLogger (Camera)

@dynamic cameraCreationDelayLoggingStatus;

- (NSNumber *)cameraCreationDelayLoggingStatus
{
    return objc_getAssociatedObject(self, @selector(cameraCreationDelayLoggingStatus));
}

- (void)setCameraCreationDelayLoggingStatus:(NSNumber *)status
{
    objc_setAssociatedObject(self, @selector(cameraCreationDelayLoggingStatus), status,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)shouldLogCameraCreationDelay
{
    return [[self cameraCreationDelayLoggingStatus] intValue] != CAMERA_CREATION_DELAY_LOGGING_END;
}

- (void)logCameraCreationDelayEnd
{
    if ([[self cameraCreationDelayLoggingStatus] intValue] == CAMERA_CREATION_DELAY_LOGGINT_LAST_STEP) {
        SCTraceSignPostEndForMetrics(kSCSignPostCameraCreationDelay, 0, 0, 0, 0);
        [self setCameraCreationDelayLoggingStatus:@(CAMERA_CREATION_DELAY_LOGGING_END)];
    } else {
        [self setCameraCreationDelayLoggingStatus:@(CAMERA_CREATION_DELAY_LOGGINT_LAST_STEP)];
    }
}

- (void)logCameraCreationStartWithMethod:(SCCameraRecordingMethod)method
                           lensesEnabled:(BOOL)lensesEnabled
                            activeLensId:(NSString *)activeLensId
                        captureSessionId:(NSString *)captureSessionId
{
    NSMutableDictionary *parameters = [@{
        @"lens_ui_enabled" : @(lensesEnabled),
        @"analytics_version" : kSCCameraDelayEventVersion,
        @"method" : @(method),
    } mutableCopy];
    if (lensesEnabled && activeLensId) {
        [parameters setObject:activeLensId forKey:@"lens_id"];
    }
    if (captureSessionId) {
        [parameters setObject:captureSessionId forKey:@"capture_session_id"];
    }
    [self setCameraCreationDelayLoggingStatus:@(CAMERA_CREATION_DELAY_LOGGING_START)];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraCreationDelay];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraRecordingGestureFinished];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraPreCaptureOperationRequested];
    [[SCLogger sharedInstance] logTimedEventStart:kSCCameraCaptureDelayEvent
                                         uniqueId:@""
                                    isUniqueEvent:NO
                                       parameters:parameters
                               shouldLogStartTime:YES];
}

- (void)logCameraExposureAdjustmentDelayStart
{
    [[SCLogger sharedInstance] logTimedEventStart:kSCCameraExposureAdjustmentDelay
                                         uniqueId:@""
                                    isUniqueEvent:NO
                                       parameters:nil
                               shouldLogStartTime:YES];
}

- (void)logCameraExposureAdjustmentDelayEndWithStrategy:(NSString *)strategy
{
    [[SCLogger sharedInstance] logTimedEventEnd:kSCCameraExposureAdjustmentDelay
                                       uniqueId:@""
                                     parameters:@{
                                         @"strategy" : strategy
                                     }];
}

- (void)logCameraCaptureRecordingGestureFinishedAtTime:(CFTimeInterval)endRecordingTime
{
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraRecordingGestureFinished];
    [[SCLogger sharedInstance]
        updateLogTimedEvent:kSCCameraCaptureDelayEvent
                   uniqueId:@""
                     update:^(NSMutableDictionary *startParameters) {
                         NSMutableDictionary *eventParameters =
                             startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventParametersKey];
                         NSNumber *recordStartTime =
                             (NSNumber *)eventParameters[kSCCameraSubmetricsPreCaptureOperationFinished];
                         CFTimeInterval endRecordingTimeOffset =
                             endRecordingTime -
                             [startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventTimeKey] doubleValue];
                         if (recordStartTime) {
                             CFTimeInterval timeDisplacement =
                                 ([recordStartTime doubleValue] / 1000.0) - endRecordingTimeOffset;
                             [eventParameters setObject:@(timeDisplacement)
                                                 forKey:SCPerformanceMetricsKey.kSCLoggerStartEventTimeAdjustmentKey];
                         }
                         [self addSplitPoint:kSCCameraSubmetricsRecordingGestureFinished
                                      atTime:endRecordingTime
                                     toEvent:startParameters];
                     }];
}

- (void)logStillImageCaptureApi:(NSString *)api
{
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraPreCaptureOperationRequested];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraPreCaptureOperationFinished];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraCaptureContentReady];
    CFTimeInterval requestTime = CACurrentMediaTime();
    [self updateLogTimedEvent:kSCCameraCaptureDelayEvent
                     uniqueId:@""
                       update:^(NSMutableDictionary *startParameters) {
                           NSMutableDictionary *eventParameters =
                               startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventParametersKey];
                           [eventParameters setObject:api forKey:@"api_type"];
                           [eventParameters setObject:@(1) forKey:@"camera_api_level"];
                           [self addSplitPoint:@"PRE_CAPTURE_OPERATION_REQUESTED"
                                        atTime:requestTime
                                       toEvent:startParameters];
                       }];
}

- (void)logPreCaptureOperationRequestedAt:(CFTimeInterval)requestTime
{
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraPreCaptureOperationRequested];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraPreCaptureOperationFinished];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraCaptureContentReady];
    [self updateLogTimedEvent:kSCCameraCaptureDelayEvent
                     uniqueId:@""
                   splitPoint:kSCCameraSubmetricsPreCaptureOperationRequested
                         time:requestTime];
}

- (void)logPreCaptureOperationFinishedAt:(CFTimeInterval)time
{
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraPreCaptureOperationFinished];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraPreviewPlayerReady];
    [self updateLogTimedEvent:kSCCameraCaptureDelayEvent
                     uniqueId:@""
                   splitPoint:kSCCameraSubmetricsPreCaptureOperationFinished
                         time:time];
}

- (void)logCameraCaptureFinishedWithDuration:(CFTimeInterval)duration
{
    [[SCLogger sharedInstance]
        updateLogTimedEvent:kSCCameraCaptureDelayEvent
                   uniqueId:@""
                     update:^(NSMutableDictionary *startParameters) {
                         NSMutableDictionary *eventParameters =
                             startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventParametersKey];
                         [eventParameters setObject:@(SCTimeInMillisecond(duration)) forKey:@"content_duration"];
                     }];
}

- (void)logCameraCaptureContentReady
{
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraCaptureContentReady];
    [[SCLogger sharedInstance] updateLogTimedEvent:kSCCameraCaptureDelayEvent
                                          uniqueId:@""
                                        splitPoint:kSCCameraSubmetricsCameraCaptureContentReady];
}

- (void)logPreviewFinishedPreparation
{
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraPreviewFinishPreparation];
    [self logCameraCreationDelaySubMetricsStartWithSignCode:kSCSignPostCameraPreviewAnimationFinish];
    [self updateLogTimedEvent:kSCCameraCaptureDelayEvent
                     uniqueId:@""
                   splitPoint:kSCCameraSubmetricsPreviewFinishPreparation];
}

- (void)logPreviewDisplayedForImage:(BOOL)isImage
{
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraPreviewLayoutReady];
    [self updateLogTimedEvent:kSCCameraCaptureDelayEvent uniqueId:@"" splitPoint:kSCCameraSubmetricsPreviewLayoutReady];
}

- (void)logPreviewAnimationComplete:(BOOL)isImage
{
    [self updateLogTimedEvent:kSCCameraCaptureDelayEvent
                     uniqueId:@""
                   splitPoint:kSCCameraSubmetricsPreviewAnimationFinish];
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraPreviewAnimationFinish];
    [self logCameraCreationDelayEnd];
    [self conditionallyLogTimedEventEnd:kSCCameraCaptureDelayEvent
                               uniqueId:@""
                             parameters:@{
                                 @"type" : isImage ? @"image" : @"video",
                             }
                              shouldLog:^BOOL(NSDictionary *startParameters) {
                                  // For video, PREVIEW_PLAYER_READY and PREVIEW_ANIMATION_FINISH can happen in either
                                  // order. So here we check for existence of this key, and end timer if the other
                                  // event have happened.
                                  NSMutableDictionary *eventParameters =
                                      startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventParametersKey];
                                  return eventParameters[kSCCameraSubmetricsPreviewPlayerReady] != nil;
                              }];
}

- (void)logPreviewFirstFramePlayed:(BOOL)isImage
{
    [self updateLogTimedEvent:kSCCameraCaptureDelayEvent uniqueId:@"" splitPoint:kSCCameraSubmetricsPreviewPlayerReady];
    [self logCameraCreationDelaySubMetricsEndWithSignCode:kSCSignPostCameraPreviewPlayerReady];
    [self logCameraCreationDelayEnd];
    [self conditionallyLogTimedEventEnd:kSCCameraCaptureDelayEvent
                               uniqueId:@""
                             parameters:@{
                                 @"type" : isImage ? @"image" : @"video",
                             }
                              shouldLog:^BOOL(NSDictionary *startParameters) {
                                  NSMutableDictionary *eventParameters =
                                      startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventParametersKey];
                                  // See the comment above for PREVIEW_PLAYER_READY and PREVIEW_ANIMATION_FINISH.
                                  return eventParameters[kSCCameraSubmetricsPreviewAnimationFinish] != nil;
                              }];
}

- (void)cancelCameraCreationEvent
{
    [self cancelLogTimedEvent:kSCCameraCaptureDelayEvent uniqueId:@""];
}

- (void)logRecordingMayBeTooShortWithMethod:(SCCameraRecordingMethod)method
{
    [[SCLogger sharedInstance] cancelLogTimedEvent:kSCCameraMetricsRecordingTooShort uniqueId:@""];
    [[SCLogger sharedInstance] logTimedEventStart:kSCCameraMetricsRecordingTooShort
                                         uniqueId:@""
                                    isUniqueEvent:NO
                                       parameters:@{
                                           @"method" : @(method),
                                           @"analytics_version" : kSCCameraRecordingTooShortVersion,
                                       }
                               shouldLogStartTime:YES];
}

- (void)logRecordingWasTooShortWithFirstFrame:(CMTime)firstFrame
                            frontFacingCamera:(BOOL)isFrontFacing
                                  cameraFlips:(NSInteger)cameraFlips
{
    [self logTimedEventEnd:kSCCameraMetricsRecordingTooShort
                  uniqueId:@""
                    update:^(NSDictionary *startParameters, CFTimeInterval eventEndTime, CFTimeInterval adjustedTime) {
                        NSMutableDictionary *eventParameters =
                            startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventParametersKey];
                        if (CMTIME_IS_VALID(firstFrame)) {
                            CFTimeInterval startTime =
                                [startParameters[SCPerformanceMetricsKey.kSCLoggerStartEventTimeKey] doubleValue];
                            CFTimeInterval firstFrameRelative = CMTimeGetSeconds(firstFrame) - startTime;
                            [eventParameters setObject:@(firstFrameRelative) forKey:@"first_frame_s"];
                        }
                        [eventParameters setObject:@(isFrontFacing) forKey:@"is_front_facing"];
                        if (cameraFlips) {
                            [eventParameters setObject:@(cameraFlips > 0) forKey:@"has_camera_been_flipped"];
                        }
                    }];
}

- (void)logManagedCapturerSettingFailure:(NSString *)settingTask error:(NSError *)error
{
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc] init];
    parameters[@"setting_task"] = settingTask;
    if (error) {
        parameters[@"setting error"] = error;
    }
    [[SCLogger sharedInstance] logTimedEventEnd:kSCCameraManagedCaptureSettingFailure
                                       uniqueId:@""
                                     parameters:parameters];
}

- (void)logCameraCreationDelaySubMetricsStartWithSignCode:(kSCSignPostCodeEnum)signPostCode
{
    if ([self shouldLogCameraCreationDelay]) {
        SCTraceSignPostStartForMetrics(signPostCode, 0, 0, 0, 0);
    }
}

- (void)logCameraCreationDelaySubMetricsEndWithSignCode:(kSCSignPostCodeEnum)signPostCode
{
    if ([self shouldLogCameraCreationDelay]) {
        SCTraceSignPostEndForMetrics(signPostCode, 0, 0, 0, 0);
    }
}

@end
