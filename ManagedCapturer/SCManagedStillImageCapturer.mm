//
//  SCManagedStillImageCapturer.m
//  Snapchat
//
//  Created by Liu Liu on 4/30/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedStillImageCapturer.h"

#import "SCCameraSettingUtils.h"
#import "SCCameraTweaks.h"
#import "SCCaptureResource.h"
#import "SCLogger+Camera.h"
#import "SCManagedCaptureSession.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerLensAPI.h"
#import "SCManagedFrameHealthChecker.h"
#import "SCManagedLegacyStillImageCapturer.h"
#import "SCManagedPhotoCapturer.h"
#import "SCManagedStillImageCapturerHandler.h"
#import "SCManagedStillImageCapturer_Protected.h"

#import <SCFoundation/NSException+Exceptions.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCPerforming.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/UIImage+CVPixelBufferRef.h>
#import <SCLenses/SCLens.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCWebP/UIImage+WebP.h>

#import <ImageIO/ImageIO.h>

NSString *const kSCManagedStillImageCapturerErrorDomain = @"kSCManagedStillImageCapturerErrorDomain";

NSInteger const kSCCameraShutterSoundID = 1108;

#if !TARGET_IPHONE_SIMULATOR
NSInteger const kSCManagedStillImageCapturerNoStillImageConnection = 1101;
#endif
NSInteger const kSCManagedStillImageCapturerApplicationStateBackground = 1102;

// We will do the image capture regardless if these is still camera adjustment in progress after 0.4 seconds.
NSTimeInterval const kSCManagedStillImageCapturerDeadline = 0.4;
NSTimeInterval const kSCCameraRetryInterval = 0.1;

BOOL SCPhotoCapturerIsEnabled(void)
{
    // Due to the native crash in https://jira.sc-corp.net/browse/CCAM-4904, we guard it >= 10.2
    return SC_AT_LEAST_IOS_10_2;
}

NSDictionary *cameraInfoForBuffer(CMSampleBufferRef imageDataSampleBuffer)
{
    CFDictionaryRef exifAttachments =
        (CFDictionaryRef)CMGetAttachment(imageDataSampleBuffer, kCGImagePropertyExifDictionary, NULL);
    float brightness = [retrieveBrightnessFromEXIFAttachments(exifAttachments) floatValue];
    NSInteger ISOSpeedRating = [retrieveISOSpeedRatingFromEXIFAttachments(exifAttachments) integerValue];
    return @{
        (__bridge NSString *) kCGImagePropertyExifISOSpeedRatings : @(ISOSpeedRating), (__bridge NSString *)
        kCGImagePropertyExifBrightnessValue : @(brightness)
    };
}

@implementation SCManagedStillImageCapturer

+ (instancetype)capturerWithCaptureResource:(SCCaptureResource *)captureResource
{
    if (SCPhotoCapturerIsEnabled()) {
        return [[SCManagedPhotoCapturer alloc] initWithSession:captureResource.managedSession.avSession
                                                     performer:captureResource.queuePerformer
                                            lensProcessingCore:captureResource.lensProcessingCore
                                                      delegate:captureResource.stillImageCapturerHandler];
    } else {
        return [[SCManagedLegacyStillImageCapturer alloc] initWithSession:captureResource.managedSession.avSession
                                                                performer:captureResource.queuePerformer
                                                       lensProcessingCore:captureResource.lensProcessingCore
                                                                 delegate:captureResource.stillImageCapturerHandler];
    }
}

- (instancetype)initWithSession:(AVCaptureSession *)session
                      performer:(id<SCPerforming>)performer
             lensProcessingCore:(id<SCManagedCapturerLensAPI>)lensAPI
                       delegate:(id<SCManagedStillImageCapturerDelegate>)delegate
{
    self = [super init];
    if (self) {
        _session = session;
        _performer = performer;
        _lensAPI = lensAPI;
        _delegate = delegate;
    }
    return self;
}

- (void)setupWithSession:(AVCaptureSession *)session
{
    UNIMPLEMENTED_METHOD;
}

- (void)setAsOutput:(AVCaptureSession *)session
{
    UNIMPLEMENTED_METHOD;
}

- (void)setHighResolutionStillImageOutputEnabled:(BOOL)highResolutionStillImageOutputEnabled
{
    UNIMPLEMENTED_METHOD;
}

- (void)enableStillImageStabilization
{
    UNIMPLEMENTED_METHOD;
}

- (void)removeAsOutput:(AVCaptureSession *)session
{
    UNIMPLEMENTED_METHOD;
}

- (void)setPortraitModeCaptureEnabled:(BOOL)enabled
{
    UNIMPLEMENTED_METHOD;
}

- (void)setPortraitModePointOfInterest:(CGPoint)pointOfInterest
{
    UNIMPLEMENTED_METHOD;
}

- (void)captureStillImageWithAspectRatio:(CGFloat)aspectRatio
                            atZoomFactor:(float)zoomFactor
                             fieldOfView:(float)fieldOfView
                                   state:(SCManagedCapturerState *)state
                        captureSessionID:(NSString *)captureSessionID
                  shouldCaptureFromVideo:(BOOL)shouldCaptureFromVideo
                       completionHandler:
                           (sc_managed_still_image_capturer_capture_still_image_completion_handler_t)completionHandler
{
    UNIMPLEMENTED_METHOD;
}

#pragma mark - SCManagedDeviceCapacityAnalyzerListener

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeAdjustingExposure:(BOOL)adjustingExposure
{
    UNIMPLEMENTED_METHOD;
}

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeLightingCondition:(SCCapturerLightingConditionType)lightingCondition
{
    UNIMPLEMENTED_METHOD;
}

#pragma mark - SCManagedCapturerListener

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeAdjustingExposure:(SCManagedCapturerState *)state
{
    UNIMPLEMENTED_METHOD;
}

- (UIImage *)imageFromData:(NSData *)data
         currentZoomFactor:(float)currentZoomFactor
         targetAspectRatio:(CGFloat)targetAspectRatio
               fieldOfView:(float)fieldOfView
                     state:(SCManagedCapturerState *)state
              sampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    UIImage *capturedImage = [self imageFromImage:[UIImage sc_imageWithData:data]
                                currentZoomFactor:currentZoomFactor
                                targetAspectRatio:targetAspectRatio
                                      fieldOfView:fieldOfView
                                            state:state];
    // Check capture frame health before showing preview
    NSDictionary *metadata =
        [[SCManagedFrameHealthChecker sharedInstance] metadataForSampleBuffer:sampleBuffer
                                                         photoCapturerEnabled:SCPhotoCapturerIsEnabled()
                                                                  lensEnabled:state.lensesActive
                                                                       lensID:[_lensAPI activeLensId]];
    [[SCManagedFrameHealthChecker sharedInstance] checkImageHealthForCaptureFrameImage:capturedImage
                                                                       captureSettings:metadata
                                                                      captureSessionID:_captureSessionID];
    _captureSessionID = nil;
    return capturedImage;
}

- (UIImage *)imageFromData:(NSData *)data
         currentZoomFactor:(float)currentZoomFactor
         targetAspectRatio:(CGFloat)targetAspectRatio
               fieldOfView:(float)fieldOfView
                     state:(SCManagedCapturerState *)state
                  metadata:(NSDictionary *)metadata
{
    UIImage *capturedImage = [self imageFromImage:[UIImage sc_imageWithData:data]
                                currentZoomFactor:currentZoomFactor
                                targetAspectRatio:targetAspectRatio
                                      fieldOfView:fieldOfView
                                            state:state];
    // Check capture frame health before showing preview
    NSDictionary *newMetadata =
        [[SCManagedFrameHealthChecker sharedInstance] metadataForMetadata:metadata
                                                     photoCapturerEnabled:SCPhotoCapturerIsEnabled()
                                                              lensEnabled:state.lensesActive
                                                                   lensID:[_lensAPI activeLensId]];
    [[SCManagedFrameHealthChecker sharedInstance] checkImageHealthForCaptureFrameImage:capturedImage
                                                                       captureSettings:newMetadata
                                                                      captureSessionID:_captureSessionID];
    _captureSessionID = nil;
    return capturedImage;
}

- (UIImage *)imageFromImage:(UIImage *)image
          currentZoomFactor:(float)currentZoomFactor
          targetAspectRatio:(CGFloat)targetAspectRatio
                fieldOfView:(float)fieldOfView
                      state:(SCManagedCapturerState *)state
{
    UIImage *fullScreenImage = image;
    if (state.lensesActive && _lensAPI.isLensApplied) {
        fullScreenImage = [_lensAPI processImage:fullScreenImage
                                    maxPixelSize:[_lensAPI maxPixelSize]
                                  devicePosition:state.devicePosition
                                     fieldOfView:fieldOfView];
    }
    // Resize and crop
    return [self resizeImage:fullScreenImage currentZoomFactor:currentZoomFactor targetAspectRatio:targetAspectRatio];
}

- (UIImage *)resizeImage:(UIImage *)image
       currentZoomFactor:(float)currentZoomFactor
       targetAspectRatio:(CGFloat)targetAspectRatio
{
    SCTraceStart();
    if (currentZoomFactor == 1) {
        return SCCropImageToTargetAspectRatio(image, targetAspectRatio);
    } else {
        @autoreleasepool {
            return [self resizeImageUsingCG:image
                          currentZoomFactor:currentZoomFactor
                          targetAspectRatio:targetAspectRatio
                               maxPixelSize:[_lensAPI maxPixelSize]];
        }
    }
}

- (UIImage *)resizeImageUsingCG:(UIImage *)inputImage
              currentZoomFactor:(float)currentZoomFactor
              targetAspectRatio:(CGFloat)targetAspectRatio
                   maxPixelSize:(CGFloat)maxPixelSize
{
    size_t imageWidth = CGImageGetWidth(inputImage.CGImage);
    size_t imageHeight = CGImageGetHeight(inputImage.CGImage);
    SCLogGeneralInfo(@"Captured still image at %dx%d", (int)imageWidth, (int)imageHeight);
    size_t targetWidth, targetHeight;
    float zoomFactor = currentZoomFactor;
    if (imageWidth > imageHeight) {
        targetWidth = maxPixelSize;
        targetHeight = (maxPixelSize * imageHeight + imageWidth / 2) / imageWidth;
        // Update zoom factor here
        zoomFactor *= (float)maxPixelSize / imageWidth;
    } else {
        targetHeight = maxPixelSize;
        targetWidth = (maxPixelSize * imageWidth + imageHeight / 2) / imageHeight;
        zoomFactor *= (float)maxPixelSize / imageHeight;
    }
    if (targetAspectRatio != kSCManagedCapturerAspectRatioUnspecified) {
        SCCropImageSizeToAspectRatio(targetWidth, targetHeight, inputImage.imageOrientation, targetAspectRatio,
                                     &targetWidth, &targetHeight);
    }
    CGContextRef context =
        CGBitmapContextCreate(NULL, targetWidth, targetHeight, CGImageGetBitsPerComponent(inputImage.CGImage),
                              CGImageGetBitsPerPixel(inputImage.CGImage) * targetWidth / 8,
                              CGImageGetColorSpace(inputImage.CGImage), CGImageGetBitmapInfo(inputImage.CGImage));
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGContextDrawImage(context, CGRectMake(targetWidth * 0.5 - imageWidth * 0.5 * zoomFactor,
                                           targetHeight * 0.5 - imageHeight * 0.5 * zoomFactor, imageWidth * zoomFactor,
                                           imageHeight * zoomFactor),
                       inputImage.CGImage);
    CGImageRef thumbnail = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image =
        [UIImage imageWithCGImage:thumbnail scale:inputImage.scale orientation:inputImage.imageOrientation];
    CGImageRelease(thumbnail);
    return image;
}

- (CMTime)adjustedExposureDurationForNightModeWithCurrentExposureDuration:(CMTime)exposureDuration
{
    CMTime adjustedExposureDuration = exposureDuration;
    if (_lightingConditionType == SCCapturerLightingConditionTypeDark) {
        adjustedExposureDuration = CMTimeMultiplyByFloat64(exposureDuration, 1.5);
    } else if (_lightingConditionType == SCCapturerLightingConditionTypeExtremeDark) {
        adjustedExposureDuration = CMTimeMultiplyByFloat64(exposureDuration, 2.5);
    }
    return adjustedExposureDuration;
}

#pragma mark - SCManagedVideoDataSourceListener

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceStart();
    SC_GUARD_ELSE_RETURN(_captureImageFromVideoImmediately);
    _captureImageFromVideoImmediately = NO;
    @weakify(self);
    CFRetain(sampleBuffer);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        [self _didCapturePhotoFromVideoBuffer];
        UIImageOrientation orientation = devicePosition == SCManagedCaptureDevicePositionBack
                                             ? UIImageOrientationRight
                                             : UIImageOrientationLeftMirrored;
        UIImage *videoImage = [UIImage imageWithPixelBufferRef:CMSampleBufferGetImageBuffer(sampleBuffer)
                                                   backingType:UIImageBackingTypeCGImage
                                                   orientation:orientation
                                                       context:[CIContext contextWithOptions:nil]];
        UIImage *fullScreenImage = [self imageFromImage:videoImage
                                      currentZoomFactor:_zoomFactor
                                      targetAspectRatio:_aspectRatio
                                            fieldOfView:_fieldOfView
                                                  state:_state];
        NSMutableDictionary *cameraInfo = [cameraInfoForBuffer(sampleBuffer) mutableCopy];
        cameraInfo[@"capture_image_from_video_buffer"] = @"enabled";
        [self _didFinishProcessingFromVideoBufferWithImage:fullScreenImage cameraInfo:cameraInfo];
        CFRelease(sampleBuffer);
    }];
}

- (void)_willBeginCapturePhotoFromVideoBuffer
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        if ([self->_delegate respondsToSelector:@selector(managedStillImageCapturerWillCapturePhoto:)]) {
            [self->_delegate managedStillImageCapturerWillCapturePhoto:self];
        }
    }];
}

- (void)_didCapturePhotoFromVideoBuffer
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        if ([self->_delegate respondsToSelector:@selector(managedStillImageCapturerDidCapturePhoto:)]) {
            [self->_delegate managedStillImageCapturerDidCapturePhoto:self];
        }
    }];
}

- (void)_didFinishProcessingFromVideoBufferWithImage:(UIImage *)image cameraInfo:(NSDictionary *)cameraInfo
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        [[SCLogger sharedInstance] logPreCaptureOperationFinishedAt:CACurrentMediaTime()];
        [[SCCoreCameraLogger sharedInstance]
            logCameraCreationDelaySplitPointPreCaptureOperationFinishedAt:CACurrentMediaTime()];
        sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler = _completionHandler;
        _completionHandler = nil;
        if (completionHandler) {
            completionHandler(image, cameraInfo, nil);
        }
    }];
}

- (void)captureStillImageFromVideoBuffer
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        AudioServicesPlaySystemSoundWithCompletion(kSCCameraShutterSoundID, nil);
        [self _willBeginCapturePhotoFromVideoBuffer];
        self->_captureImageFromVideoImmediately = YES;
    }];
}

@end
