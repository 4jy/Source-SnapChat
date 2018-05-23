//
//  SCLogger+Camera.h
//  Snapchat
//
//  Created by Derek Peirce on 5/8/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "AVCameraViewEnums.h"

#import <SCBase/SCSignPost.h>
#import <SCLogger/SCLogger.h>

#import <CoreMedia/CoreMedia.h>

typedef NS_ENUM(NSUInteger, CameraCreationDelayLoggingStatus) {
    CAMERA_CREATION_DELAY_LOGGING_START,
    CAMERA_CREATION_DELAY_LOGGINT_LAST_STEP,
    CAMERA_CREATION_DELAY_LOGGING_END,
};

@interface SCLogger (Camera)

@property (nonatomic, strong) NSNumber *cameraCreationDelayLoggingStatus;

- (void)logCameraCreationStartWithMethod:(SCCameraRecordingMethod)method
                           lensesEnabled:(BOOL)lensesEnabled
                            activeLensId:(NSString *)activeLensId
                        captureSessionId:(NSString *)captureSessionId;
- (void)logStillImageCaptureApi:(NSString *)api;
- (void)logPreCaptureOperationRequestedAt:(CFTimeInterval)requestTime;
- (void)logPreCaptureOperationFinishedAt:(CFTimeInterval)time;
- (void)logCameraCaptureRecordingGestureFinishedAtTime:(CFTimeInterval)endRecordingTime;
- (void)logCameraCaptureFinishedWithDuration:(CFTimeInterval)duration;
- (void)logCameraCaptureContentReady;
- (void)logPreviewFinishedPreparation;
- (void)logPreviewDisplayedForImage:(BOOL)isImage;
- (void)logPreviewAnimationComplete:(BOOL)isImage;
- (void)logPreviewFirstFramePlayed:(BOOL)isImage;
- (void)cancelCameraCreationEvent;

- (void)logRecordingMayBeTooShortWithMethod:(SCCameraRecordingMethod)method;
- (void)logRecordingWasTooShortWithFirstFrame:(CMTime)firstFrame
                            frontFacingCamera:(BOOL)isFrontFacing
                                  cameraFlips:(NSInteger)cameraFlips;

- (void)logManagedCapturerSettingFailure:(NSString *)settingTask error:(NSError *)error;
- (void)logCameraExposureAdjustmentDelayStart;
- (void)logCameraExposureAdjustmentDelayEndWithStrategy:(NSString *)strategy;
- (void)logCameraCreationDelaySubMetricsStartWithSignCode:(kSCSignPostCodeEnum)signPostCode;
- (void)logCameraCreationDelaySubMetricsEndWithSignCode:(kSCSignPostCodeEnum)signPostCod;

@end
