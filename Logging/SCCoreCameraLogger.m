//
//  SCCoreCameraLogger.m
//  Snapchat
//
//  Created by Chao Pang on 3/6/18.
//

#import "SCCoreCameraLogger.h"

#import <BlizzardSchema/SCAEvents.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCGhostToSnappable/SCGhostToSnappableSignal.h>
#import <SCLogger/SCCameraMetrics+CameraCreationDelay.h>

static const char *kSCCoreCameraLoggerQueueLabel = "com.snapchat.core-camera-logger-queue";

NSString *const kSCCameraCreationDelayEventStartTimeKey = @"start_time";
NSString *const kSCCameraCreationDelayEventStartTimeAdjustmentKey = @"start_time_adjustment";
NSString *const kSCCameraCreationDelayEventEndTimeKey = @"end_time";
NSString *const kSCCameraCreationDelayEventCaptureSessionIdKey = @"capture_session_id";
NSString *const kSCCameraCreationDelayEventFilterLensIdKey = @"filter_lens_id";
NSString *const kSCCameraCreationDelayEventNightModeDetectedKey = @"night_mode_detected";
NSString *const kSCCameraCreationDelayEventNightModeActiveKey = @"night_mode_active";
NSString *const kSCCameraCreationDelayEventCameraApiKey = @"camera_api";
NSString *const kSCCameraCreationDelayEventCameraLevelKey = @"camera_level";
NSString *const kSCCameraCreationDelayEventCameraPositionKey = @"camera_position";
NSString *const kSCCameraCreationDelayEventCameraOpenSourceKey = @"camera_open_source";
NSString *const kSCCameraCreationDelayEventContentDurationKey = @"content_duration";
NSString *const kSCCameraCreationDelayEventMediaTypeKey = @"media_type";
NSString *const kSCCameraCreationDelayEventStartTypeKey = @"start_type";
NSString *const kSCCameraCreationDelayEventStartSubTypeKey = @"start_sub_type";
NSString *const kSCCameraCreationDelayEventAnalyticsVersion = @"ios_v1";

static inline NSUInteger SCTimeToMS(CFTimeInterval time)
{
    return (NSUInteger)(time * 1000);
}

static NSString *SCDictionaryToJSONString(NSDictionary *dictionary)
{
    NSData *dictData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:nil];
    return [[NSString alloc] initWithData:dictData encoding:NSUTF8StringEncoding];
}

@implementation SCCoreCameraLogger {
    SCQueuePerformer *_performer;
    NSMutableDictionary *_cameraCreationDelayParameters;
    NSMutableDictionary *_cameraCreationDelaySplits;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _cameraCreationDelayParameters = [NSMutableDictionary dictionary];
        _cameraCreationDelaySplits = [NSMutableDictionary dictionary];
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCCoreCameraLoggerQueueLabel
                                            qualityOfService:QOS_CLASS_UNSPECIFIED
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCoreCamera];
    }
    return self;
}

+ (instancetype)sharedInstance
{
    static SCCoreCameraLogger *sharedInstance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[SCCoreCameraLogger alloc] init];
    });
    return sharedInstance;
}

// Camera creation delay metrics

- (void)logCameraCreationDelayEventStartWithCaptureSessionId:(NSString *)captureSessionId
                                                filterLensId:(NSString *)filterLensId
                                      underLowLightCondition:(BOOL)underLowLightCondition
                                           isNightModeActive:(BOOL)isNightModeActive
                                                isBackCamera:(BOOL)isBackCamera
                                                isMainCamera:(BOOL)isMainCamera
{
    CFTimeInterval startTime = CACurrentMediaTime();
    [_performer perform:^{
        [_cameraCreationDelayParameters removeAllObjects];
        [_cameraCreationDelaySplits removeAllObjects];
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeKey] = @(startTime);
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventCaptureSessionIdKey] = captureSessionId ?: @"null";
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventFilterLensIdKey] = filterLensId ?: @"null";
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventNightModeDetectedKey] = @(underLowLightCondition);
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventNightModeActiveKey] = @(isNightModeActive);
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventCameraPositionKey] =
            isBackCamera ? @"back" : @"front";
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventCameraOpenSourceKey] =
            isMainCamera ? @"main_camera" : @"reply_camera";
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTypeKey] = SCLaunchType() ?: @"null";
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventStartSubTypeKey] = SCLaunchSubType() ?: @"null";
    }];
}

- (void)logCameraCreationDelaySplitPointRecordingGestureFinished
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        CFTimeInterval endRecordingTimeOffset =
            time - [_cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeKey] doubleValue];
        NSNumber *recordStartTimeMillis =
            (NSNumber *)_cameraCreationDelaySplits[kSCCameraSubmetricsPreCaptureOperationFinished];
        if (recordStartTimeMillis) {
            CFTimeInterval timeDisplacement = ([recordStartTimeMillis doubleValue] / 1000.0) - endRecordingTimeOffset;
            _cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeAdjustmentKey] = @(timeDisplacement);
        }
        [self _addSplitPointForKey:kSCCameraSubmetricsRecordingGestureFinished atTime:time];
    }];
}

- (void)logCameraCreationDelaySplitPointStillImageCaptureApi:(NSString *)api
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        if (api) {
            _cameraCreationDelayParameters[kSCCameraCreationDelayEventCameraApiKey] = api;
        }
        [self _addSplitPointForKey:kSCCameraSubmetricsPreCaptureOperationRequested atTime:time];
    }];
}

- (void)logCameraCreationDelaySplitPointPreCaptureOperationRequested
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        [self _addSplitPointForKey:kSCCameraSubmetricsPreCaptureOperationRequested atTime:time];
    }];
}

- (void)logCameraCreationDelaySplitPointPreCaptureOperationFinishedAt:(CFTimeInterval)time
{
    [_performer perform:^{
        [self _addSplitPointForKey:kSCCameraSubmetricsPreCaptureOperationFinished atTime:time];
    }];
}

- (void)updatedCameraCreationDelayWithContentDuration:(CFTimeInterval)duration
{
    [_performer perform:^{
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventContentDurationKey] = @(SCTimeToMS(duration));
    }];
}

- (void)logCameraCreationDelaySplitPointCameraCaptureContentReady
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        [self _addSplitPointForKey:kSCCameraSubmetricsCameraCaptureContentReady atTime:time];
    }];
}

- (void)logCameraCreationDelaySplitPointPreviewFinishedPreparation
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        [self _addSplitPointForKey:kSCCameraSubmetricsCameraCaptureContentReady atTime:time];
    }];
}

- (void)logCameraCreationDelaySplitPointPreviewDisplayedForImage:(BOOL)isImage
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        [self _addSplitPointForKey:kSCCameraSubmetricsPreviewLayoutReady atTime:time];
    }];
}

- (void)logCameraCreationDelaySplitPointPreviewAnimationComplete:(BOOL)isImage
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        [self _addSplitPointForKey:kSCCameraSubmetricsPreviewAnimationFinish atTime:time];
        if (_cameraCreationDelaySplits[kSCCameraSubmetricsPreviewPlayerReady]) {
            [self _completeLogCameraCreationDelayEventWithIsImage:isImage atTime:time];
        }
    }];
}

- (void)logCameraCreationDelaySplitPointPreviewFirstFramePlayed:(BOOL)isImage
{
    CFTimeInterval time = CACurrentMediaTime();
    [_performer perform:^{
        [self _addSplitPointForKey:kSCCameraSubmetricsPreviewPlayerReady atTime:time];
        if (_cameraCreationDelaySplits[kSCCameraSubmetricsPreviewAnimationFinish]) {
            [self _completeLogCameraCreationDelayEventWithIsImage:isImage atTime:time];
        }
    }];
}

- (void)cancelCameraCreationDelayEvent
{
    [_performer perform:^{
        [_cameraCreationDelayParameters removeAllObjects];
        [_cameraCreationDelaySplits removeAllObjects];
    }];
}

#pragma - Private methods

- (void)_completeLogCameraCreationDelayEventWithIsImage:(BOOL)isImage atTime:(CFTimeInterval)time
{
    SCAssertPerformer(_performer);
    if (_cameraCreationDelayParameters[kSCCameraCreationDelayEventCaptureSessionIdKey]) {
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventMediaTypeKey] = isImage ? @"image" : @"video";
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventEndTimeKey] = @(time);
        [self _logCameraCreationDelayBlizzardEvent];
    }
    [_cameraCreationDelayParameters removeAllObjects];
    [_cameraCreationDelaySplits removeAllObjects];
}

- (void)_addSplitPointForKey:(NSString *)key atTime:(CFTimeInterval)time
{
    SCAssertPerformer(_performer);
    if (key) {
        CFTimeInterval timeOffset =
            time - [_cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeKey] doubleValue];
        NSNumber *timeAdjustment =
            _cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeAdjustmentKey] ?: @(0);
        _cameraCreationDelaySplits[key] = @(SCTimeToMS(timeOffset + [timeAdjustment doubleValue]));
    }
}

- (void)_logCameraCreationDelayBlizzardEvent
{
    SCAssertPerformer(_performer);
    SCASharedCameraMetricParams *sharedCameraMetricsParams = [[SCASharedCameraMetricParams alloc] init];
    [sharedCameraMetricsParams setAnalyticsVersion:kSCCameraCreationDelayEventAnalyticsVersion];
    NSString *mediaType = _cameraCreationDelayParameters[kSCCameraCreationDelayEventMediaTypeKey];
    if (mediaType) {
        if ([mediaType isEqualToString:@"image"]) {
            [sharedCameraMetricsParams setMediaType:SCAMediaType_IMAGE];
        } else if ([mediaType isEqualToString:@"video"]) {
            [sharedCameraMetricsParams setMediaType:SCAMediaType_VIDEO];
        }
    }
    if (_cameraCreationDelayParameters[kSCCameraCreationDelayEventNightModeDetectedKey] &&
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventNightModeActiveKey]) {
        BOOL isNightModeDetected =
            [_cameraCreationDelayParameters[kSCCameraCreationDelayEventNightModeDetectedKey] boolValue];
        BOOL isNightModeActive =
            [_cameraCreationDelayParameters[kSCCameraCreationDelayEventNightModeActiveKey] boolValue];
        if (!isNightModeDetected) {
            [sharedCameraMetricsParams setLowLightStatus:SCALowLightStatus_NOT_DETECTED];
        } else if (!isNightModeActive) {
            [sharedCameraMetricsParams setLowLightStatus:SCALowLightStatus_DETECTED];
        } else if (isNightModeActive) {
            [sharedCameraMetricsParams setLowLightStatus:SCALowLightStatus_ENABLED];
        }
    }

    [sharedCameraMetricsParams setPowerMode:[[NSProcessInfo processInfo] isLowPowerModeEnabled]
                                                ? @"LOW_POWER_MODE_ENABLED"
                                                : @"LOW_POWER_MODE_DISABLED"];
    [sharedCameraMetricsParams
        setFilterLensId:_cameraCreationDelayParameters[kSCCameraCreationDelayEventFilterLensIdKey] ?: @"null"];
    [sharedCameraMetricsParams
        setCaptureSessionId:_cameraCreationDelayParameters[kSCCameraCreationDelayEventCaptureSessionIdKey] ?: @"null"];
    [sharedCameraMetricsParams
        setCameraApi:_cameraCreationDelayParameters[kSCCameraCreationDelayEventCameraApiKey] ?: @"null"];
    [sharedCameraMetricsParams
        setCameraPosition:_cameraCreationDelayParameters[kSCCameraCreationDelayEventCameraPositionKey] ?: @"null"];
    [sharedCameraMetricsParams
        setCameraOpenSource:_cameraCreationDelayParameters[kSCCameraCreationDelayEventCameraOpenSourceKey] ?: @"null"];
    [sharedCameraMetricsParams
        setCameraLevel:_cameraCreationDelayParameters[kSCCameraCreationDelayEventCameraLevelKey] ?: @"null"];
    [sharedCameraMetricsParams
        setStartType:_cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTypeKey] ?: @"null"];
    [sharedCameraMetricsParams
        setStartSubType:_cameraCreationDelayParameters[kSCCameraCreationDelayEventStartSubTypeKey] ?: @"null"];
    [sharedCameraMetricsParams setSplits:SCDictionaryToJSONString(_cameraCreationDelaySplits)];

    SCACameraSnapCreateDelay *creationDelay = [[SCACameraSnapCreateDelay alloc] init];
    if (_cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeKey] &&
        _cameraCreationDelayParameters[kSCCameraCreationDelayEventEndTimeKey]) {
        double startTime = [_cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeKey] doubleValue];
        double endTime = [_cameraCreationDelayParameters[kSCCameraCreationDelayEventEndTimeKey] doubleValue];
        NSNumber *timeAdjustment =
            _cameraCreationDelayParameters[kSCCameraCreationDelayEventStartTimeAdjustmentKey] ?: @(0);
        [creationDelay setLatencyMillis:SCTimeToMS(endTime - startTime + [timeAdjustment doubleValue])];
    } else {
        [creationDelay setLatencyMillis:0];
    }

    if (_cameraCreationDelayParameters[kSCCameraCreationDelayEventContentDurationKey]) {
        [creationDelay
            setContentDurationMillis:SCTimeToMS(
                                         [_cameraCreationDelayParameters[kSCCameraCreationDelayEventContentDurationKey]
                                             doubleValue])];
    } else {
        [creationDelay setContentDurationMillis:0];
    }
    [creationDelay setSharedCameraMetricParams:sharedCameraMetricsParams];
    [[SCLogger sharedInstance] logUserTrackedEvent:creationDelay];
}

@end
