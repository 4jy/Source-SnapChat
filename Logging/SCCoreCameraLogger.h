//
//  SCCoreCameraLogger.h
//  Snapchat
//
//  Created by Chao Pang on 3/6/18.
//

#import <Foundation/Foundation.h>

/**
 *  CAMERA_CREATION_DELAY event
 */
extern NSString *const kSCCameraCreationDelayEventStartTimeKey;
extern NSString *const kSCCameraCreationDelayEventStartTimeAdjustmentKey;
extern NSString *const kSCCameraCreationDelayEventEndTimeKey;
extern NSString *const kSCCameraCreationDelayEventCaptureSessionIdKey;
extern NSString *const kSCCameraCreationDelayEventFilterLensIdKey;
extern NSString *const kSCCameraCreationDelayEventNightModeDetectedKey;
extern NSString *const kSCCameraCreationDelayEventNightModeActiveKey;
extern NSString *const kSCCameraCreationDelayEventCameraApiKey;
extern NSString *const kSCCameraCreationDelayEventCameraLevelKey;
extern NSString *const kSCCameraCreationDelayEventCameraPositionKey;
extern NSString *const kSCCameraCreationDelayEventCameraOpenSourceKey;
extern NSString *const kSCCameraCreationDelayEventContentDurationKey;
extern NSString *const kSCCameraCreationDelayEventMediaTypeKey;
extern NSString *const kSCCameraCreationDelayEventStartTypeKey;
extern NSString *const kSCCameraCreationDelayEventStartSubTypeKey;
extern NSString *const kSCCameraCreationDelayEventAnalyticsVersion;

@interface SCCoreCameraLogger : NSObject

+ (instancetype)sharedInstance;

/**
 *  CAMERA_CREATION_DELAY event
 */
- (void)logCameraCreationDelayEventStartWithCaptureSessionId:(NSString *)captureSessionId
                                                filterLensId:(NSString *)filterLensId
                                      underLowLightCondition:(BOOL)underLowLightCondition
                                           isNightModeActive:(BOOL)isNightModeActive
                                                isBackCamera:(BOOL)isBackCamera
                                                isMainCamera:(BOOL)isMainCamera;

- (void)logCameraCreationDelaySplitPointRecordingGestureFinished;

- (void)logCameraCreationDelaySplitPointStillImageCaptureApi:(NSString *)api;

- (void)logCameraCreationDelaySplitPointPreCaptureOperationRequested;

- (void)logCameraCreationDelaySplitPointPreCaptureOperationFinishedAt:(CFTimeInterval)time;

- (void)updatedCameraCreationDelayWithContentDuration:(CFTimeInterval)duration;

- (void)logCameraCreationDelaySplitPointCameraCaptureContentReady;

- (void)logCameraCreationDelaySplitPointPreviewFinishedPreparation;

- (void)logCameraCreationDelaySplitPointPreviewDisplayedForImage:(BOOL)isImage;

- (void)logCameraCreationDelaySplitPointPreviewAnimationComplete:(BOOL)isImage;

- (void)logCameraCreationDelaySplitPointPreviewFirstFramePlayed:(BOOL)isImage;

- (void)cancelCameraCreationDelayEvent;

@end
