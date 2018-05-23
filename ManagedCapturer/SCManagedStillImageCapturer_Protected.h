//
//  SCManagedStillImageCapturer_Protected.h
//  Snapchat
//
//  Created by Chao Pang on 10/4/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

SC_EXTERN_C_BEGIN
extern NSDictionary *cameraInfoForBuffer(CMSampleBufferRef imageDataSampleBuffer);
SC_EXTERN_C_END

extern NSString *const kSCManagedStillImageCapturerErrorDomain;

#if !TARGET_IPHONE_SIMULATOR
extern NSInteger const kSCManagedStillImageCapturerNoStillImageConnection;
#endif
extern NSInteger const kSCManagedStillImageCapturerApplicationStateBackground;

// We will do the image capture regardless if these is still camera adjustment in progress after 0.4 seconds.
extern NSTimeInterval const kSCManagedStillImageCapturerDeadline;
extern NSTimeInterval const kSCCameraRetryInterval;

@protocol SCManagedCapturerLensAPI;

@interface SCManagedStillImageCapturer () {
  @protected
    id<SCManagedCapturerLensAPI> _lensAPI;
    id<SCPerforming> _performer;
    AVCaptureSession *_session;
    id<SCManagedStillImageCapturerDelegate> __weak _delegate;
    NSString *_captureSessionID;
    SCCapturerLightingConditionType _lightingConditionType;
}

- (instancetype)initWithSession:(AVCaptureSession *)session
                      performer:(id<SCPerforming>)performer
             lensProcessingCore:(id<SCManagedCapturerLensAPI>)lensProcessingCore
                       delegate:(id<SCManagedStillImageCapturerDelegate>)delegate;

- (UIImage *)imageFromData:(NSData *)data
         currentZoomFactor:(float)currentZoomFactor
         targetAspectRatio:(CGFloat)targetAspectRatio
               fieldOfView:(float)fieldOfView
                     state:(SCManagedCapturerState *)state
              sampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (UIImage *)imageFromData:(NSData *)data
         currentZoomFactor:(float)currentZoomFactor
         targetAspectRatio:(CGFloat)targetAspectRatio
               fieldOfView:(float)fieldOfView
                     state:(SCManagedCapturerState *)state
                  metadata:(NSDictionary *)metadata;

- (UIImage *)imageFromImage:(UIImage *)image
          currentZoomFactor:(float)currentZoomFactor
          targetAspectRatio:(CGFloat)targetAspectRatio
                fieldOfView:(float)fieldOfView
                      state:(SCManagedCapturerState *)state;

- (CMTime)adjustedExposureDurationForNightModeWithCurrentExposureDuration:(CMTime)exposureDuration;

@end
