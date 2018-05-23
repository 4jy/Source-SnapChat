//
//  SCManagedStillImageCapturer.h
//  Snapchat
//
//  Created by Liu Liu on 4/30/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCCoreCameraLogger.h"
#import "SCManagedCaptureDevice.h"
#import "SCManagedCapturerListener.h"
#import "SCManagedCapturerState.h"
#import "SCManagedDeviceCapacityAnalyzerListener.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>
#import <SCLogger/SCCameraMetrics+ExposureAdjustment.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

SC_EXTERN_C_BEGIN

extern BOOL SCPhotoCapturerIsEnabled(void);

SC_EXTERN_C_END

@protocol SCPerforming;
@protocol SCManagedStillImageCapturerDelegate;
@class SCCaptureResource;

typedef void (^sc_managed_still_image_capturer_capture_still_image_completion_handler_t)(UIImage *fullScreenImage,
                                                                                         NSDictionary *metadata,
                                                                                         NSError *error);

@interface SCManagedStillImageCapturer
    : NSObject <SCManagedDeviceCapacityAnalyzerListener, SCManagedCapturerListener, SCManagedVideoDataSourceListener> {
    SCManagedCapturerState *_state;
    BOOL _shouldCaptureFromVideo;
    BOOL _captureImageFromVideoImmediately;
    CGFloat _aspectRatio;
    float _zoomFactor;
    float _fieldOfView;
    BOOL _adjustingExposureManualDetect;
    sc_managed_still_image_capturer_capture_still_image_completion_handler_t _completionHandler;
}

+ (instancetype)capturerWithCaptureResource:(SCCaptureResource *)captureResource;

SC_INIT_AND_NEW_UNAVAILABLE;

@property (nonatomic, weak) id<SCManagedStillImageCapturerDelegate> delegate;

- (void)setupWithSession:(AVCaptureSession *)session;

- (void)setAsOutput:(AVCaptureSession *)session;

- (void)removeAsOutput:(AVCaptureSession *)session;

- (void)setHighResolutionStillImageOutputEnabled:(BOOL)highResolutionStillImageOutputEnabled;

- (void)setPortraitModeCaptureEnabled:(BOOL)enabled;

- (void)setPortraitModePointOfInterest:(CGPoint)pointOfInterest;

- (void)enableStillImageStabilization;

- (void)captureStillImageWithAspectRatio:(CGFloat)aspectRatio
                            atZoomFactor:(float)zoomFactor
                             fieldOfView:(float)fieldOfView
                                   state:(SCManagedCapturerState *)state
                        captureSessionID:(NSString *)captureSessionID
                  shouldCaptureFromVideo:(BOOL)shouldCaptureFromVideo
                       completionHandler:
                           (sc_managed_still_image_capturer_capture_still_image_completion_handler_t)completionHandler;

- (void)captureStillImageFromVideoBuffer;

@end

@protocol SCManagedStillImageCapturerDelegate <NSObject>

- (BOOL)managedStillImageCapturerIsUnderDeviceMotion:(SCManagedStillImageCapturer *)managedStillImageCapturer;

- (BOOL)managedStillImageCapturerShouldProcessFileInput:(SCManagedStillImageCapturer *)managedStillImageCapturer;

@optional

- (void)managedStillImageCapturerWillCapturePhoto:(SCManagedStillImageCapturer *)managedStillImageCapturer;

- (void)managedStillImageCapturerDidCapturePhoto:(SCManagedStillImageCapturer *)managedStillImageCapturer;

@end
