//
//  SCManagedFrameHealthChecker.m
//  Snapchat
//
//  Created by Pinlin Chen on 30/08/2017.
//

#import "SCManagedFrameHealthChecker.h"

#import "SCCameraSettingUtils.h"
#import "SCCameraTweaks.h"

#import <SCFoundation/AVAsset+Helpers.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCLogHelper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCFoundation/UIImage+Helpers.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger+Stats.h>
#import <SCWebP/UIImage+WebP.h>

#import <ImageIO/CGImageProperties.h>
@import Accelerate;

static const char *kSCManagedFrameHealthCheckerQueueLabel = "com.snapchat.frame_health_checker";
static const int kSCManagedFrameHealthCheckerMaxSamples = 2304;
static const float kSCManagedFrameHealthCheckerPossibleBlackThreshold = 20.0;
static const float kSCManagedFrameHealthCheckerScaledImageMaxEdgeLength = 300.0;
static const float kSCManagedFrameHealthCheckerScaledImageScale = 1.0;
// assume we could process at most of 2 RGBA images which are 2304*4096 RGBA image
static const double kSCManagedFrameHealthCheckerMinFreeMemMB = 72.0;

typedef NS_ENUM(NSUInteger, SCManagedFrameHealthCheckType) {
    SCManagedFrameHealthCheck_ImageCapture = 0,
    SCManagedFrameHealthCheck_ImagePreTranscoding,
    SCManagedFrameHealthCheck_ImagePostTranscoding,
    SCManagedFrameHealthCheck_VideoCapture,
    SCManagedFrameHealthCheck_VideoOverlayImage,
    SCManagedFrameHealthCheck_VideoPostTranscoding,
};

typedef NS_ENUM(NSUInteger, SCManagedFrameHealthCheckErrorType) {
    SCManagedFrameHealthCheckError_None = 0,
    SCManagedFrameHealthCheckError_Invalid_Bitmap,
    SCManagedFrameHealthCheckError_Frame_Possibly_Black,
    SCManagedFrameHealthCheckError_Frame_Totally_Black,
    SCManagedFrameHealthCheckError_Execution_Error,
};

typedef struct {
    float R;
    float G;
    float B;
    float A;
} FloatRGBA;

@class SCManagedFrameHealthCheckerTask;
typedef NSMutableDictionary * (^sc_managed_frame_checker_block)(SCManagedFrameHealthCheckerTask *task);

float vDspColorElementSum(const Byte *data, NSInteger stripLength, NSInteger bufferLength)
{
    float sum = 0;
    float colorArray[bufferLength];
    // Convert to float for DSP registerator
    vDSP_vfltu8(data, stripLength, colorArray, 1, bufferLength);
    // Calculate sum of color element
    vDSP_sve(colorArray, 1, &sum, bufferLength);
    return sum;
}

@interface SCManagedFrameHealthCheckerTask : NSObject

@property (nonatomic, assign) SCManagedFrameHealthCheckType type;
@property (nonatomic, strong) id targetObject;
@property (nonatomic, assign) CGSize sourceImageSize;
@property (nonatomic, strong) UIImage *unifiedImage;
@property (nonatomic, strong) NSDictionary *metadata;
@property (nonatomic, strong) NSDictionary *videoProperties;
@property (nonatomic, assign) SCManagedFrameHealthCheckErrorType errorType;

+ (SCManagedFrameHealthCheckerTask *)taskWithType:(SCManagedFrameHealthCheckType)type
                                     targetObject:(id)targetObject
                                         metadata:(NSDictionary *)metadata
                                  videoProperties:(NSDictionary *)videoProperties;

+ (SCManagedFrameHealthCheckerTask *)taskWithType:(SCManagedFrameHealthCheckType)type
                                     targetObject:(id)targetObject
                                         metadata:(NSDictionary *)metadata;

@end

@implementation SCManagedFrameHealthCheckerTask

+ (SCManagedFrameHealthCheckerTask *)taskWithType:(SCManagedFrameHealthCheckType)type
                                     targetObject:(id)targetObject
                                         metadata:(NSDictionary *)metadata
{
    return [self taskWithType:type targetObject:targetObject metadata:metadata videoProperties:nil];
}

+ (SCManagedFrameHealthCheckerTask *)taskWithType:(SCManagedFrameHealthCheckType)type
                                     targetObject:(id)targetObject
                                         metadata:(NSDictionary *)metadata
                                  videoProperties:(NSDictionary *)videoProperties
{
    SCManagedFrameHealthCheckerTask *task = [[SCManagedFrameHealthCheckerTask alloc] init];
    task.type = type;
    task.targetObject = targetObject;
    task.metadata = metadata;
    task.videoProperties = videoProperties;
    return task;
}

- (NSString *)textForSnapType
{
    switch (self.type) {
    case SCManagedFrameHealthCheck_ImageCapture:
    case SCManagedFrameHealthCheck_ImagePreTranscoding:
    case SCManagedFrameHealthCheck_ImagePostTranscoding:
        return @"IMAGE";
    case SCManagedFrameHealthCheck_VideoCapture:
    case SCManagedFrameHealthCheck_VideoOverlayImage:
    case SCManagedFrameHealthCheck_VideoPostTranscoding:
        return @"VIDEO";
    }
}

- (NSString *)textForSource
{
    switch (self.type) {
    case SCManagedFrameHealthCheck_ImageCapture:
        return @"CAPTURE";
    case SCManagedFrameHealthCheck_ImagePreTranscoding:
        return @"PRE_TRANSCODING";
    case SCManagedFrameHealthCheck_ImagePostTranscoding:
        return @"POST_TRANSCODING";
    case SCManagedFrameHealthCheck_VideoCapture:
        return @"CAPTURE";
    case SCManagedFrameHealthCheck_VideoOverlayImage:
        return @"OVERLAY_IMAGE";
    case SCManagedFrameHealthCheck_VideoPostTranscoding:
        return @"POST_TRANSCODING";
    }
}

- (NSString *)textForErrorType
{
    switch (self.errorType) {
    case SCManagedFrameHealthCheckError_None:
        return nil;
    case SCManagedFrameHealthCheckError_Invalid_Bitmap:
        return @"Invalid_Bitmap";
    case SCManagedFrameHealthCheckError_Frame_Possibly_Black:
        return @"Frame_Possibly_Black";
    case SCManagedFrameHealthCheckError_Frame_Totally_Black:
        return @"Frame_Totally_Black";
    case SCManagedFrameHealthCheckError_Execution_Error:
        return @"Execution_Error";
    }
}

@end

@interface SCManagedFrameHealthChecker () {
    id<SCPerforming> _performer;
    // Dictionary structure
    // Key   - NSString, captureSessionID
    // Value - NSMutableArray<SCManagedFrameHealthCheckerTask>
    NSMutableDictionary *_frameCheckTasks;
}

@end

@implementation SCManagedFrameHealthChecker

+ (SCManagedFrameHealthChecker *)sharedInstance
{
    SCTraceODPCompatibleStart(2);
    static SCManagedFrameHealthChecker *checker;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        checker = [[SCManagedFrameHealthChecker alloc] _init];
    });
    return checker;
}

- (instancetype)_init
{
    SCTraceODPCompatibleStart(2);
    if (self = [super init]) {
        // Use the lowest QoS level
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCManagedFrameHealthCheckerQueueLabel
                                            qualityOfService:QOS_CLASS_UTILITY
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCamera];
        _frameCheckTasks = [NSMutableDictionary dictionary];
    }
    return self;
}

- (NSMutableDictionary *)metadataForSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    SCTraceODPCompatibleStart(2);
    // add exposure, ISO, brightness
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    if (!sampleBuffer || !CMSampleBufferDataIsReady(sampleBuffer)) {
        return metadata;
    }
    CFDictionaryRef exifAttachments =
        (CFDictionaryRef)CMGetAttachment(sampleBuffer, kCGImagePropertyExifDictionary, NULL);
    NSNumber *exposureTimeNum = retrieveExposureTimeFromEXIFAttachments(exifAttachments);
    if (exposureTimeNum) {
        metadata[@"exposure"] = exposureTimeNum;
    }
    NSNumber *isoSpeedRatingNum = retrieveISOSpeedRatingFromEXIFAttachments(exifAttachments);
    if (isoSpeedRatingNum) {
        metadata[@"iso"] = isoSpeedRatingNum;
    }
    NSNumber *brightnessNum = retrieveBrightnessFromEXIFAttachments(exifAttachments);
    if (brightnessNum) {
        float brightness = [brightnessNum floatValue];
        metadata[@"brightness"] = isfinite(brightness) ? @(brightness) : @(0);
    }

    return metadata;
}

- (NSMutableDictionary *)metadataForMetadata:(NSDictionary *)metadata
{
    SCTraceODPCompatibleStart(2);
    // add exposure, ISO, brightness
    NSMutableDictionary *newMetadata = [NSMutableDictionary dictionary];
    CFDictionaryRef exifAttachments = (__bridge CFDictionaryRef)metadata;
    NSNumber *exposureTimeNum = retrieveExposureTimeFromEXIFAttachments(exifAttachments);
    if (exposureTimeNum) {
        newMetadata[@"exposure"] = exposureTimeNum;
    }
    NSNumber *isoSpeedRatingNum = retrieveISOSpeedRatingFromEXIFAttachments(exifAttachments);
    if (isoSpeedRatingNum) {
        newMetadata[@"iso"] = isoSpeedRatingNum;
    }
    NSNumber *brightnessNum = retrieveBrightnessFromEXIFAttachments(exifAttachments);
    if (brightnessNum) {
        float brightness = [brightnessNum floatValue];
        newMetadata[@"brightness"] = isfinite(brightness) ? @(brightness) : @(0);
    }

    return newMetadata;
}

- (NSMutableDictionary *)metadataForSampleBuffer:(CMSampleBufferRef)sampleBuffer extraInfo:(NSDictionary *)extraInfo
{
    SCTraceODPCompatibleStart(2);
    NSMutableDictionary *metadata = [self metadataForSampleBuffer:sampleBuffer];
    [metadata addEntriesFromDictionary:extraInfo];
    return metadata;
}

- (NSMutableDictionary *)metadataForSampleBuffer:(CMSampleBufferRef)sampleBuffer
                            photoCapturerEnabled:(BOOL)photoCapturerEnabled
                                     lensEnabled:(BOOL)lensesEnabled
                                          lensID:(NSString *)lensID
{
    SCTraceODPCompatibleStart(2);
    NSMutableDictionary *metadata = [self metadataForSampleBuffer:sampleBuffer];
    metadata[@"photo_capturer_enabled"] = @(photoCapturerEnabled);

    metadata[@"lens_enabled"] = @(lensesEnabled);
    if (lensesEnabled) {
        metadata[@"lens_id"] = lensID ?: @"";
    }

    return metadata;
}

- (NSMutableDictionary *)metadataForMetadata:(NSDictionary *)metadata
                        photoCapturerEnabled:(BOOL)photoCapturerEnabled
                                 lensEnabled:(BOOL)lensesEnabled
                                      lensID:(NSString *)lensID
{
    SCTraceODPCompatibleStart(2);
    NSMutableDictionary *newMetadata = [self metadataForMetadata:metadata];
    newMetadata[@"photo_capturer_enabled"] = @(photoCapturerEnabled);

    newMetadata[@"lens_enabled"] = @(lensesEnabled);
    if (lensesEnabled) {
        newMetadata[@"lens_id"] = lensID ?: @"";
    }

    return newMetadata;
}

- (NSMutableDictionary *)getPropertiesFromAsset:(AVAsset *)asset
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN_VALUE(asset != nil, nil);
    NSMutableDictionary *properties = [NSMutableDictionary dictionary];
    // file size
    properties[@"file_size"] = @([asset fileSize]);
    // duration
    properties[@"duration"] = @(CMTimeGetSeconds(asset.duration));
    // video track count
    NSArray<AVAssetTrack *> *videoTracks = [asset tracksWithMediaType:AVMediaTypeVideo];
    properties[@"video_track_count"] = @(videoTracks.count);
    if (videoTracks.count > 0) {
        // video bitrate
        properties[@"video_bitrate"] = @([videoTracks.firstObject estimatedDataRate]);
        // frame rate
        properties[@"video_frame_rate"] = @([videoTracks.firstObject nominalFrameRate]);
    }
    // audio track count
    NSArray<AVAssetTrack *> *audioTracks = [asset tracksWithMediaType:AVMediaTypeAudio];
    properties[@"audio_track_count"] = @(audioTracks.count);
    if (audioTracks.count > 0) {
        // audio bitrate
        properties[@"audio_bitrate"] = @([audioTracks.firstObject estimatedDataRate]);
    }
    // playable
    properties[@"playable"] = @(asset.isPlayable);
    return properties;
}

#pragma mark - Image snap

- (void)checkImageHealthForCaptureFrameImage:(UIImage *)image
                             captureSettings:(NSDictionary *)captureSettings
                            captureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (captureSessionID.length == 0) {
        SCLogCoreCameraError(@"[FrameHealthChecker] #IMAGE:CAPTURE - captureSessionID shouldn't be empty");
        return;
    }
    SCManagedFrameHealthCheckerTask *task =
        [SCManagedFrameHealthCheckerTask taskWithType:SCManagedFrameHealthCheck_ImageCapture
                                         targetObject:image
                                             metadata:captureSettings];
    [self _addTask:task withCaptureSessionID:captureSessionID];
}

- (void)checkImageHealthForPreTranscoding:(UIImage *)image
                                 metadata:(NSDictionary *)metadata
                         captureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (captureSessionID.length == 0) {
        SCLogCoreCameraError(@"[FrameHealthChecker] #IMAGE:PRE_CAPTURE - captureSessionID shouldn't be empty");
        return;
    }
    SCManagedFrameHealthCheckerTask *task =
        [SCManagedFrameHealthCheckerTask taskWithType:SCManagedFrameHealthCheck_ImagePreTranscoding
                                         targetObject:image
                                             metadata:metadata];
    [self _addTask:task withCaptureSessionID:captureSessionID];
}

- (void)checkImageHealthForPostTranscoding:(NSData *)imageData
                                  metadata:(NSDictionary *)metadata
                          captureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (captureSessionID.length == 0) {
        SCLogCoreCameraError(@"[FrameHealthChecker] #IMAGE:POST_CAPTURE - captureSessionID shouldn't be empty");
        return;
    }
    SCManagedFrameHealthCheckerTask *task =
        [SCManagedFrameHealthCheckerTask taskWithType:SCManagedFrameHealthCheck_ImagePostTranscoding
                                         targetObject:imageData
                                             metadata:metadata];
    [self _addTask:task withCaptureSessionID:captureSessionID];
}

#pragma mark - Video snap
- (void)checkVideoHealthForCaptureFrameImage:(UIImage *)image
                                    metedata:(NSDictionary *)metadata
                            captureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (captureSessionID.length == 0) {
        SCLogCoreCameraError(@"[FrameHealthChecker] #VIDEO:CAPTURE - captureSessionID shouldn't be empty");
        return;
    }
    SCManagedFrameHealthCheckerTask *task =
        [SCManagedFrameHealthCheckerTask taskWithType:SCManagedFrameHealthCheck_VideoCapture
                                         targetObject:image
                                             metadata:metadata];
    [self _addTask:task withCaptureSessionID:captureSessionID];
}

- (void)checkVideoHealthForOverlayImage:(UIImage *)image
                               metedata:(NSDictionary *)metadata
                       captureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (captureSessionID.length == 0) {
        SCLogCoreCameraError(@"[FrameHealthChecker] #VIDEO:OVERLAY_IMAGE - captureSessionID shouldn't be empty");
        return;
    }
    // Overlay image could be nil
    if (!image) {
        SCLogCoreCameraInfo(@"[FrameHealthChecker] #VIDEO:OVERLAY_IMAGE - overlayImage is nil.");
        return;
    }
    SCManagedFrameHealthCheckerTask *task =
        [SCManagedFrameHealthCheckerTask taskWithType:SCManagedFrameHealthCheck_VideoOverlayImage
                                         targetObject:image
                                             metadata:metadata];
    [self _addTask:task withCaptureSessionID:captureSessionID];
}

- (void)checkVideoHealthForPostTranscodingThumbnail:(UIImage *)image
                                           metedata:(NSDictionary *)metadata
                                         properties:(NSDictionary *)properties
                                   captureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (captureSessionID.length == 0) {
        SCLogCoreCameraError(@"[FrameHealthChecker] #VIDEO:POST_TRANSCODING - captureSessionID shouldn't be empty");
        return;
    }
    SCManagedFrameHealthCheckerTask *task =
        [SCManagedFrameHealthCheckerTask taskWithType:SCManagedFrameHealthCheck_VideoPostTranscoding
                                         targetObject:image
                                             metadata:metadata
                                      videoProperties:properties];
    [self _addTask:task withCaptureSessionID:captureSessionID];
}

#pragma mark - Task management
- (void)reportFrameHealthCheckForCaptureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (!captureSessionID) {
        SCLogCoreCameraError(@"[FrameHealthChecker] report - captureSessionID shouldn't be nil");
        return;
    }
    [self _asynchronouslyCheckForCaptureSessionID:captureSessionID];
}

#pragma mark - Private functions

/// Scale the source image to a new image with edges less than kSCManagedFrameHealthCheckerScaledImageMaxEdgeLength.
- (UIImage *)_unifyImage:(UIImage *)sourceImage
{
    CGFloat sourceWidth = sourceImage.size.width;
    CGFloat sourceHeight = sourceImage.size.height;

    if (sourceWidth == 0.0 || sourceHeight == 0.0) {
        SCLogCoreCameraInfo(@"[FrameHealthChecker] Tried scaling image with no size");
        return sourceImage;
    }

    CGFloat maxEdgeLength = kSCManagedFrameHealthCheckerScaledImageMaxEdgeLength;

    CGFloat widthScalingFactor = maxEdgeLength / sourceWidth;
    CGFloat heightScalingFactor = maxEdgeLength / sourceHeight;

    CGFloat scalingFactor = MIN(widthScalingFactor, heightScalingFactor);

    if (scalingFactor >= 1) {
        SCLogCoreCameraInfo(@"[FrameHealthChecker] No need to scale image.");
        return sourceImage;
    }

    CGSize targetSize = CGSizeMake(sourceWidth * scalingFactor, sourceHeight * scalingFactor);

    SCLogCoreCameraInfo(@"[FrameHealthChecker] Scaling image from %@ to %@", NSStringFromCGSize(sourceImage.size),
                        NSStringFromCGSize(targetSize));
    return [sourceImage scaledImageToSize:targetSize scale:kSCManagedFrameHealthCheckerScaledImageScale];
}

- (void)_addTask:(SCManagedFrameHealthCheckerTask *)newTask withCaptureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    if (captureSessionID.length == 0) {
        return;
    }
    [_performer perform:^{
        SCTraceODPCompatibleStart(2);

        CFTimeInterval beforeScaling = CACurrentMediaTime();
        if (newTask.targetObject) {
            if ([newTask.targetObject isKindOfClass:[UIImage class]]) {
                UIImage *sourceImage = (UIImage *)newTask.targetObject;
                newTask.unifiedImage = [self _unifyImage:sourceImage];
                newTask.sourceImageSize = sourceImage.size;
            } else if ([newTask.targetObject isKindOfClass:[NSData class]]) {
                UIImage *sourceImage = [UIImage sc_imageWithData:newTask.targetObject];
                CFTimeInterval betweenDecodingAndScaling = CACurrentMediaTime();
                SCLogCoreCameraInfo(@"[FrameHealthChecker] #Image decoding delay: %f",
                                    betweenDecodingAndScaling - beforeScaling);
                beforeScaling = betweenDecodingAndScaling;
                newTask.unifiedImage = [self _unifyImage:sourceImage];
                newTask.sourceImageSize = sourceImage.size;
            } else {
                SCLogCoreCameraError(@"[FrameHealthChecker] Invalid targetObject class:%@",
                                     NSStringFromClass([newTask.targetObject class]));
            }
            newTask.targetObject = nil;
        }
        SCLogCoreCameraInfo(@"[FrameHealthChecker] #Scale image delay: %f", CACurrentMediaTime() - beforeScaling);

        NSMutableArray *taskQueue = _frameCheckTasks[captureSessionID];
        if (!taskQueue) {
            taskQueue = [NSMutableArray array];
            _frameCheckTasks[captureSessionID] = taskQueue;
        }
        // Remove previous same type task, avoid meaningless task,
        // for example repeat click "Send Button" and then "Back button"
        // will produce a lot of PRE_TRANSCODING and POST_TRANSCODING
        for (SCManagedFrameHealthCheckerTask *task in taskQueue) {
            if (task.type == newTask.type) {
                [taskQueue removeObject:task];
                break;
            }
        }

        [taskQueue addObject:newTask];
    }];
}

- (void)_asynchronouslyCheckForCaptureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    [_performer perform:^{
        SCTraceODPCompatibleStart(2);
        NSMutableArray *tasksQueue = _frameCheckTasks[captureSessionID];
        if (!tasksQueue) {
            return;
        }

        // Check the free memory, if it is too low, drop these tasks
        double memFree = [SCLogger memoryFreeMB];
        if (memFree < kSCManagedFrameHealthCheckerMinFreeMemMB) {
            SCLogCoreCameraWarning(
                @"[FrameHealthChecker] mem_free:%f is too low, dropped checking tasks for captureSessionID:%@", memFree,
                captureSessionID);
            [_frameCheckTasks removeObjectForKey:captureSessionID];
            return;
        }

        __block NSMutableArray *frameHealthInfoArray = [NSMutableArray array];
        // Execute all tasks and wait for complete
        [tasksQueue enumerateObjectsUsingBlock:^(id _Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            SCManagedFrameHealthCheckerTask *task = (SCManagedFrameHealthCheckerTask *)obj;
            NSMutableDictionary *frameHealthInfo;
            UIImage *image = task.unifiedImage;

            if (image) {
                // Get frame health info
                frameHealthInfo = [self _getFrameHealthInfoForImage:image
                                                             source:[task textForSource]
                                                           snapType:[task textForSnapType]
                                                           metadata:task.metadata
                                                    sourceImageSize:task.sourceImageSize
                                                   captureSessionID:captureSessionID];
                NSNumber *isPossibleBlackNum = frameHealthInfo[@"is_possible_black"];
                NSNumber *isTotallyBlackNum = frameHealthInfo[@"is_total_black"];
                NSNumber *hasExecutionError = frameHealthInfo[@"execution_error"];
                if ([isTotallyBlackNum boolValue]) {
                    task.errorType = SCManagedFrameHealthCheckError_Frame_Totally_Black;
                } else if ([isPossibleBlackNum boolValue]) {
                    task.errorType = SCManagedFrameHealthCheckError_Frame_Possibly_Black;
                } else if ([hasExecutionError boolValue]) {
                    task.errorType = SCManagedFrameHealthCheckError_Execution_Error;
                }
            } else {
                frameHealthInfo = [NSMutableDictionary dictionary];
                task.errorType = SCManagedFrameHealthCheckError_Invalid_Bitmap;
            }

            if (frameHealthInfo) {
                frameHealthInfo[@"frame_source"] = [task textForSource];
                frameHealthInfo[@"snap_type"] = [task textForSnapType];
                frameHealthInfo[@"error_type"] = [task textForErrorType];
                frameHealthInfo[@"capture_session_id"] = captureSessionID;
                frameHealthInfo[@"metadata"] = task.metadata;
                if (task.videoProperties.count > 0) {
                    [frameHealthInfo addEntriesFromDictionary:task.videoProperties];
                }
                [frameHealthInfoArray addObject:frameHealthInfo];
            }

            // Release the image as soon as possible to mitigate the memory pressure
            task.unifiedImage = nil;
        }];

        for (NSDictionary *frameHealthInfo in frameHealthInfoArray) {
            if ([frameHealthInfo[@"is_total_black"] boolValue] || [frameHealthInfo[@"is_possible_black"] boolValue]) {
                //                // TODO: Zi Kai Chen - add this back. Normally we use id<SCManiphestTicketCreator> for
                //                this but as this is a shared instance we cannot easily inject it. The work would
                //                involve making this not a shared instance.
                //                SCShakeBetaLogEvent(SCShakeBetaLoggerKeyCCamBlackSnap,
                //                                    JSONStringSerializeObjectForLogging(frameHealthInfo));
            }

            [[SCLogger sharedInstance] logUnsampledEventToEventLogger:kSCCameraMetricsFrameHealthCheckIndex
                                                           parameters:frameHealthInfo
                                                     secretParameters:nil
                                                              metrics:nil];
        }

        [_frameCheckTasks removeObjectForKey:captureSessionID];
    }];
}

- (NSMutableDictionary *)_getFrameHealthInfoForImage:(UIImage *)image
                                              source:(NSString *)source
                                            snapType:(NSString *)snapType
                                            metadata:(NSDictionary *)metadata
                                     sourceImageSize:(CGSize)sourceImageSize
                                    captureSessionID:(NSString *)captureSessionID
{
    SCTraceODPCompatibleStart(2);
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    size_t samplesCount = 0;
    CFTimeInterval start = CACurrentMediaTime();
    CGImageRef imageRef = image.CGImage;
    size_t imageWidth = CGImageGetWidth(imageRef);
    size_t imageHeight = CGImageGetHeight(imageRef);
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(imageRef));
    CFTimeInterval getImageDataTime = CACurrentMediaTime();
    if (pixelData) {
        const Byte *imageData = CFDataGetBytePtr(pixelData);
        NSInteger stripLength = 0;
        NSInteger bufferLength = 0;
        NSInteger imagePixels = imageWidth * imageHeight;
        // Limit the max sampled frames
        if (imagePixels > kSCManagedFrameHealthCheckerMaxSamples) {
            stripLength = imagePixels / kSCManagedFrameHealthCheckerMaxSamples * 4;
            bufferLength = kSCManagedFrameHealthCheckerMaxSamples;
        } else {
            stripLength = 4;
            bufferLength = imagePixels;
        }
        samplesCount = bufferLength;

        // Avoid dividing by zero
        if (samplesCount != 0) {
            FloatRGBA sumRGBA = [self _getSumRGBAFromData:imageData
                                              stripLength:stripLength
                                             bufferLength:bufferLength
                                               bitmapInfo:CGImageGetBitmapInfo(imageRef)];
            float averageR = sumRGBA.R / samplesCount;
            float averageG = sumRGBA.G / samplesCount;
            float averageB = sumRGBA.B / samplesCount;
            float averageA = sumRGBA.A / samplesCount;
            parameters[@"average_sampled_rgba_r"] = @(averageR);
            parameters[@"average_sampled_rgba_g"] = @(averageG);
            parameters[@"average_sampled_rgba_b"] = @(averageB);
            parameters[@"average_sampled_rgba_a"] = @(averageA);
            parameters[@"origin_frame_width"] = @(sourceImageSize.width);
            parameters[@"origin_frame_height"] = @(sourceImageSize.height);
            // Also report possible black to identify the intentional black snap by covering camera.
            // Normally, the averageA very near 255, but for video overlay image, it is very small.
            // So we use averageA > 250 to avoid considing video overlay image as possible black.
            if (averageA > 250 && averageR < kSCManagedFrameHealthCheckerPossibleBlackThreshold &&
                averageG < kSCManagedFrameHealthCheckerPossibleBlackThreshold &&
                averageB < kSCManagedFrameHealthCheckerPossibleBlackThreshold) {
                parameters[@"is_possible_black"] = @(YES);
                // Use this parameters for BigQuery conditions in Grafana
                if (averageR == 0 && averageG == 0 && averageB == 0) {
                    parameters[@"is_total_black"] = @(YES);
                }
            }
        } else {
            SCLogCoreCameraError(@"[FrameHealthChecker] #%@:%@ - samplesCount is zero! captureSessionID:%@", snapType,
                                 source, captureSessionID);
            parameters[@"execution_error"] = @(YES);
        }
        CFRelease(pixelData);
    } else {
        SCLogCoreCameraError(@"[FrameHealthChecker] #%@:%@ - pixelData is nil! captureSessionID:%@", snapType, source,
                             captureSessionID);
        parameters[@"execution_error"] = @(YES);
    }
    parameters[@"sample_size"] = @(samplesCount);

    CFTimeInterval end = CACurrentMediaTime();
    SCLogCoreCameraInfo(@"[FrameHealthChecker] #%@:%@ - GET_IMAGE_DATA_TIME:%f SAMPLE_DATA_TIME:%f TOTAL_TIME:%f",
                        snapType, source, getImageDataTime - start, end - getImageDataTime, end - start);
    return parameters;
}

- (FloatRGBA)_getSumRGBAFromData:(const Byte *)imageData
                     stripLength:(NSInteger)stripLength
                    bufferLength:(NSInteger)bufferLength
                      bitmapInfo:(CGBitmapInfo)bitmapInfo
{
    SCTraceODPCompatibleStart(2);
    FloatRGBA sumRGBA;
    if ((bitmapInfo & kCGImageAlphaPremultipliedFirst) && (bitmapInfo & kCGImageByteOrder32Little)) {
        // BGRA
        sumRGBA.B = vDspColorElementSum(imageData, stripLength, bufferLength);
        sumRGBA.G = vDspColorElementSum(imageData + 1, stripLength, bufferLength);
        sumRGBA.R = vDspColorElementSum(imageData + 2, stripLength, bufferLength);
        sumRGBA.A = vDspColorElementSum(imageData + 3, stripLength, bufferLength);
    } else {
        // TODO. support other types beside RGBA
        sumRGBA.R = vDspColorElementSum(imageData, stripLength, bufferLength);
        sumRGBA.G = vDspColorElementSum(imageData + 1, stripLength, bufferLength);
        sumRGBA.B = vDspColorElementSum(imageData + 2, stripLength, bufferLength);
        sumRGBA.A = vDspColorElementSum(imageData + 3, stripLength, bufferLength);
    }
    return sumRGBA;
}

@end
