//
//  SCManagedPhotoCapturer.m
//  Snapchat
//
//  Created by Chao Pang on 10/5/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCManagedPhotoCapturer.h"

#import "AVCaptureConnection+InputDevice.h"
#import "SCCameraTweaks.h"
#import "SCLogger+Camera.h"
#import "SCManagedCapturer.h"
#import "SCManagedFrameHealthChecker.h"
#import "SCManagedStillImageCapturer_Protected.h"
#import "SCStillImageCaptureVideoInputMethod.h"
#import "SCStillImageDepthBlurFilter.h"

#import <SCCrashLogger/SCCrashLogger.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCPerforming.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCLenses/SCLens.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SClogger+Performance.h>
#import <SCWebP/UIImage+WebP.h>

@import ImageIO;

static NSString *const kSCManagedPhotoCapturerErrorDomain = @"kSCManagedPhotoCapturerErrorDomain";

static NSInteger const kSCManagedPhotoCapturerErrorEncounteredException = 10000;
static NSInteger const kSCManagedPhotoCapturerInconsistentStatus = 10001;

typedef NS_ENUM(NSUInteger, SCManagedPhotoCapturerStatus) {
    SCManagedPhotoCapturerStatusPrepareToCapture,
    SCManagedPhotoCapturerStatusWillCapture,
    SCManagedPhotoCapturerStatusDidFinishProcess,
};

@interface SCManagedPhotoCapturer () <AVCapturePhotoCaptureDelegate>
@end

@implementation SCManagedPhotoCapturer {
    AVCapturePhotoOutput *_photoOutput;

    BOOL _shouldCapture;
    BOOL _shouldEnableHRSI;
    BOOL _portraitModeCaptureEnabled;
    NSUInteger _retries;

    CGPoint _portraitModePointOfInterest;
    SCStillImageDepthBlurFilter *_depthBlurFilter;
    sc_managed_still_image_capturer_capture_still_image_completion_handler_t _callbackBlock;

    SCStillImageCaptureVideoInputMethod *_videoFileMethod;

    SCManagedPhotoCapturerStatus _status;
}

- (instancetype)initWithSession:(AVCaptureSession *)session
                      performer:(id<SCPerforming>)performer
             lensProcessingCore:(id<SCManagedCapturerLensAPI>)lensProcessingCore
                       delegate:(id<SCManagedStillImageCapturerDelegate>)delegate
{
    SCTraceStart();
    self = [super initWithSession:session performer:performer lensProcessingCore:lensProcessingCore delegate:delegate];
    if (self) {
        [self setupWithSession:session];
        _portraitModePointOfInterest = CGPointMake(0.5, 0.5);
    }
    return self;
}

- (void)setupWithSession:(AVCaptureSession *)session
{
    SCTraceStart();
    _photoOutput = [[AVCapturePhotoOutput alloc] init];
    _photoOutput.highResolutionCaptureEnabled = YES;
    [self setAsOutput:session];
}

- (void)setAsOutput:(AVCaptureSession *)session
{
    SCTraceStart();
    if ([session canAddOutput:_photoOutput]) {
        [session addOutput:_photoOutput];
    }
}

- (void)setHighResolutionStillImageOutputEnabled:(BOOL)highResolutionStillImageOutputEnabled
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    // Here we cannot directly set _photoOutput.highResolutionCaptureEnabled, since it will cause
    // black frame blink when enabling lenses. Instead, we enable HRSI in AVCapturePhotoSettings.
    // https://ph.sc-corp.net/T96228
    _shouldEnableHRSI = highResolutionStillImageOutputEnabled;
}

- (void)enableStillImageStabilization
{
    // The lens stabilization is enabled when configure AVCapturePhotoSettings
    // instead of AVCapturePhotoOutput
    SCTraceStart();
}

- (void)setPortraitModeCaptureEnabled:(BOOL)enabled
{
    _portraitModeCaptureEnabled = enabled;
    if (@available(ios 11.0, *)) {
        _photoOutput.depthDataDeliveryEnabled = enabled;
    }
    if (enabled && _depthBlurFilter == nil) {
        _depthBlurFilter = [[SCStillImageDepthBlurFilter alloc] init];
    }
}

- (void)setPortraitModePointOfInterest:(CGPoint)pointOfInterest
{
    _portraitModePointOfInterest = pointOfInterest;
}

- (void)removeAsOutput:(AVCaptureSession *)session
{
    SCTraceStart();
    [session removeOutput:_photoOutput];
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
    SCTraceStart();
    SCAssert(completionHandler, @"completionHandler shouldn't be nil");
    SCAssert([_performer isCurrentPerformer], @"");
    _retries = 6; // AVFoundation Unknown Error usually resolves itself within 0.5 seconds
    _aspectRatio = aspectRatio;
    _zoomFactor = zoomFactor;
    _fieldOfView = fieldOfView;
    _state = state;
    _captureSessionID = captureSessionID;
    _shouldCaptureFromVideo = shouldCaptureFromVideo;
    SCAssert(!_completionHandler, @"We shouldn't have a _completionHandler at this point otherwise we are destroying "
                                  @"current completion handler.");

    // The purpose of these lines is to attach a strong reference to self to the completion handler.
    // This is because AVCapturePhotoOutput does not hold a strong reference to its delegate, which acts as a completion
    // handler.
    // If self is deallocated during the call to _photoOuptut capturePhotoWithSettings:delegate:, which may happen if
    // any AVFoundationError occurs,
    // then it's callback method, captureOutput:didFinish..., will not be called, and the completion handler will be
    // forgotten.
    // This comes with a risk of a memory leak. If for whatever reason the completion handler field is never used and
    // then unset,
    // then we have a permanent retain cycle.
    _callbackBlock = completionHandler;
    __typeof(self) strongSelf = self;
    _completionHandler = ^(UIImage *fullScreenImage, NSDictionary *metadata, NSError *error) {
        strongSelf->_callbackBlock(fullScreenImage, metadata, error);
        strongSelf->_callbackBlock = nil;
    };
    [[SCLogger sharedInstance] logCameraExposureAdjustmentDelayStart];

    if (!_adjustingExposureManualDetect) {
        SCLogCoreCameraInfo(@"Capturing still image now");
        [self _capturePhotoWithExposureAdjustmentStrategy:kSCCameraExposureAdjustmentStrategyNo];
        _shouldCapture = NO;
    } else {
        SCLogCoreCameraInfo(@"Wait adjusting exposure (or after 0.4 seconds) and then capture still image");
        _shouldCapture = YES;
        [self _deadlineCapturePhoto];
    }
}

#pragma mark - SCManagedDeviceCapacityAnalyzerListener

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeAdjustingExposure:(BOOL)adjustingExposure
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        // Since this is handled on a different thread, therefore, dispatch back to the queue we operated on.
        self->_adjustingExposureManualDetect = adjustingExposure;
        [self _didChangeAdjustingExposure:adjustingExposure
                             withStrategy:kSCCameraExposureAdjustmentStrategyManualDetect];
    }];
}

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeLightingCondition:(SCCapturerLightingConditionType)lightingCondition
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        self->_lightingConditionType = lightingCondition;
    }];
}

#pragma mark - SCManagedCapturerListener

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeAdjustingExposure:(SCManagedCapturerState *)state
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        // Since this is handled on a different thread, therefore, dispatch back to the queue we operated on.
        [self _didChangeAdjustingExposure:state.adjustingExposure withStrategy:kSCCameraExposureAdjustmentStrategyKVO];
    }];
}

#pragma mark - AVCapturePhotoCaptureDelegate

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput
    didFinishProcessingPhotoSampleBuffer:(CMSampleBufferRef)photoSampleBuffer
                previewPhotoSampleBuffer:(CMSampleBufferRef)previewPhotoSampleBuffer
                        resolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
                         bracketSettings:(AVCaptureBracketedStillImageSettings *)bracketSettings
                                   error:(NSError *)error
{
    SCTraceStart();
    if (photoSampleBuffer) {
        CFRetain(photoSampleBuffer);
    }
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        SC_GUARD_ELSE_RUN_AND_RETURN(photoSampleBuffer, [self _photoCaptureDidFailWithError:error]);
        if (self->_status == SCManagedPhotoCapturerStatusWillCapture) {
            NSData *imageData = [AVCapturePhotoOutput JPEGPhotoDataRepresentationForJPEGSampleBuffer:photoSampleBuffer
                                                                            previewPhotoSampleBuffer:nil];

            [[SCLogger sharedInstance] updateLogTimedEvent:kSCCameraMetricsRecordingDelay
                                                  uniqueId:@"IMAGE"
                                                splitPoint:@"DID_FINISH_PROCESSING"];
            [self _capturePhotoFinishedWithImageData:imageData
                                        sampleBuffer:photoSampleBuffer
                                          cameraInfo:cameraInfoForBuffer(photoSampleBuffer)
                                               error:error];

        } else {
            SCLogCoreCameraInfo(@"DidFinishProcessingPhoto with unexpected status: %@",
                                [self _photoCapturerStatusToString:self->_status]);
            [self _photoCaptureDidFailWithError:[NSError errorWithDomain:kSCManagedPhotoCapturerErrorDomain
                                                                    code:kSCManagedPhotoCapturerInconsistentStatus
                                                                userInfo:nil]];
        }
        CFRelease(photoSampleBuffer);
    }];
}

- (void)captureOutput:(AVCapturePhotoOutput *)output
    didFinishProcessingPhoto:(nonnull AVCapturePhoto *)photo
                       error:(nullable NSError *)error NS_AVAILABLE_IOS(11_0)
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        NSData *imageData = [photo fileDataRepresentation];
        SC_GUARD_ELSE_RUN_AND_RETURN(imageData, [self _photoCaptureDidFailWithError:error]);
        if (self->_status == SCManagedPhotoCapturerStatusWillCapture) {
            if (@available(ios 11.0, *)) {
                if (_portraitModeCaptureEnabled) {
                    RenderData renderData = {
                        .depthDataMap = photo.depthData.depthDataMap,
                        .depthBlurPointOfInterest = &_portraitModePointOfInterest,
                    };
                    imageData = [_depthBlurFilter renderWithPhotoData:imageData renderData:renderData];
                }
            }

            [[SCLogger sharedInstance] updateLogTimedEvent:kSCCameraMetricsRecordingDelay
                                                  uniqueId:@"IMAGE"
                                                splitPoint:@"DID_FINISH_PROCESSING"];

            [self _capturePhotoFinishedWithImageData:imageData metadata:photo.metadata error:error];

        } else {
            SCLogCoreCameraInfo(@"DidFinishProcessingPhoto with unexpected status: %@",
                                [self _photoCapturerStatusToString:self->_status]);
            [self _photoCaptureDidFailWithError:[NSError errorWithDomain:kSCManagedPhotoCapturerErrorDomain
                                                                    code:kSCManagedPhotoCapturerInconsistentStatus
                                                                userInfo:nil]];
        }
    }];
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput
    willBeginCaptureForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        if ([self->_delegate respondsToSelector:@selector(managedStillImageCapturerWillCapturePhoto:)]) {
            if (self->_status == SCManagedPhotoCapturerStatusPrepareToCapture) {
                self->_status = SCManagedPhotoCapturerStatusWillCapture;

                [[SCLogger sharedInstance] updateLogTimedEvent:kSCCameraMetricsRecordingDelay
                                                      uniqueId:@"IMAGE"
                                                    splitPoint:@"WILL_BEGIN_CAPTURE"];
                [self->_delegate managedStillImageCapturerWillCapturePhoto:self];
            } else {
                SCLogCoreCameraInfo(@"WillBeginCapture with unexpected status: %@",
                                    [self _photoCapturerStatusToString:self->_status]);
            }
        }
    }];
}

- (void)captureOutput:(AVCapturePhotoOutput *)captureOutput
    didCapturePhotoForResolvedSettings:(AVCaptureResolvedPhotoSettings *)resolvedSettings
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        if ([self->_delegate respondsToSelector:@selector(managedStillImageCapturerDidCapturePhoto:)]) {
            if (self->_status == SCManagedPhotoCapturerStatusWillCapture ||
                self->_status == SCManagedPhotoCapturerStatusDidFinishProcess) {
                [[SCLogger sharedInstance] updateLogTimedEvent:kSCCameraMetricsRecordingDelay
                                                      uniqueId:@"IMAGE"
                                                    splitPoint:@"DID_CAPTURE_PHOTO"];
                [self->_delegate managedStillImageCapturerDidCapturePhoto:self];
            } else {
                SCLogCoreCameraInfo(@"DidCapturePhoto with unexpected status: %@",
                                    [self _photoCapturerStatusToString:self->_status]);
            }
        }
    }];
}

#pragma mark - Private methods

- (void)_didChangeAdjustingExposure:(BOOL)adjustingExposure withStrategy:(NSString *)strategy
{
    if (!adjustingExposure && self->_shouldCapture) {
        SCLogCoreCameraInfo(@"Capturing after adjusting exposure using strategy: %@", strategy);
        [self _capturePhotoWithExposureAdjustmentStrategy:strategy];
        self->_shouldCapture = NO;
    }
}

- (void)_capturePhotoFinishedWithImageData:(NSData *)imageData
                              sampleBuffer:(CMSampleBufferRef)sampleBuffer
                                cameraInfo:(NSDictionary *)cameraInfo
                                     error:(NSError *)error
{
    [self _photoCaptureDidSucceedWithImageData:imageData
                                  sampleBuffer:sampleBuffer
                                    cameraInfo:cameraInfoForBuffer(sampleBuffer)
                                         error:error];
    self->_status = SCManagedPhotoCapturerStatusDidFinishProcess;
}

- (void)_capturePhotoFinishedWithImageData:(NSData *)imageData metadata:(NSDictionary *)metadata error:(NSError *)error
{
    [self _photoCaptureDidSucceedWithImageData:imageData metadata:metadata error:error];
    self->_status = SCManagedPhotoCapturerStatusDidFinishProcess;
}

- (void)_deadlineCapturePhoto
{
    SCTraceStart();
    // Use the SCManagedCapturer's private queue.
    @weakify(self);
    [_performer perform:^{
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        if (self->_shouldCapture) {
            [self _capturePhotoWithExposureAdjustmentStrategy:kSCCameraExposureAdjustmentStrategyDeadline];
            self->_shouldCapture = NO;
        }
    }
                  after:SCCameraTweaksExposureDeadline()];
}

- (void)_capturePhotoWithExposureAdjustmentStrategy:(NSString *)strategy
{
    SCTraceStart();
    [[SCLogger sharedInstance] logCameraExposureAdjustmentDelayEndWithStrategy:strategy];
    if (_shouldCaptureFromVideo) {
        [self captureStillImageFromVideoBuffer];
        return;
    }
    SCAssert([_performer isCurrentPerformer], @"");
    SCAssert(_photoOutput, @"_photoOutput shouldn't be nil");
    _status = SCManagedPhotoCapturerStatusPrepareToCapture;
    AVCapturePhotoOutput *photoOutput = _photoOutput;
    AVCaptureConnection *captureConnection = [self _captureConnectionFromPhotoOutput:photoOutput];
    SCManagedCapturerState *state = [_state copy];
#if !TARGET_IPHONE_SIMULATOR
    if (!captureConnection) {
        sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler = _completionHandler;
        _completionHandler = nil;
        completionHandler(nil, nil, [NSError errorWithDomain:kSCManagedStillImageCapturerErrorDomain
                                                        code:kSCManagedStillImageCapturerNoStillImageConnection
                                                    userInfo:nil]);
    }
#endif
    AVCapturePhotoSettings *photoSettings =
        [self _photoSettingsWithPhotoOutput:photoOutput captureConnection:captureConnection captureState:state];
    // Select appropriate image capture method

    if ([_delegate managedStillImageCapturerShouldProcessFileInput:self]) {
        if (!_videoFileMethod) {
            _videoFileMethod = [[SCStillImageCaptureVideoInputMethod alloc] init];
        }
        [[SCLogger sharedInstance] logStillImageCaptureApi:@"SCStillImageCaptureVideoFileInput"];
        [[SCCoreCameraLogger sharedInstance]
            logCameraCreationDelaySplitPointStillImageCaptureApi:@"SCStillImageCaptureVideoFileInput"];
        [_delegate managedStillImageCapturerWillCapturePhoto:self];
        [_videoFileMethod captureStillImageWithCapturerState:state
            successBlock:^(NSData *imageData, NSDictionary *cameraInfo, NSError *error) {
                [_performer performImmediatelyIfCurrentPerformer:^{
                    [self _photoCaptureDidSucceedWithImageData:imageData
                                                  sampleBuffer:nil
                                                    cameraInfo:cameraInfo
                                                         error:error];
                }];
            }
            failureBlock:^(NSError *error) {
                [_performer performImmediatelyIfCurrentPerformer:^{
                    [self _photoCaptureDidFailWithError:error];
                }];
            }];
    } else {
        [[SCLogger sharedInstance] logStillImageCaptureApi:@"AVCapturePhoto"];
        [[SCCoreCameraLogger sharedInstance] logCameraCreationDelaySplitPointStillImageCaptureApi:@"AVCapturePhoto"];
        @try {
            [photoOutput capturePhotoWithSettings:photoSettings delegate:self];
        } @catch (NSException *e) {
            [SCCrashLogger logHandledException:e];
            [self
                _photoCaptureDidFailWithError:[NSError errorWithDomain:kSCManagedPhotoCapturerErrorDomain
                                                                  code:kSCManagedPhotoCapturerErrorEncounteredException
                                                              userInfo:@{
                                                                  @"exception" : e
                                                              }]];
        }
    }
}

- (void)_photoCaptureDidSucceedWithImageData:(NSData *)imageData
                                sampleBuffer:(CMSampleBufferRef)sampleBuffer
                                  cameraInfo:(NSDictionary *)cameraInfo
                                       error:(NSError *)error
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    [[SCLogger sharedInstance] logPreCaptureOperationFinishedAt:CACurrentMediaTime()];
    [[SCCoreCameraLogger sharedInstance]
        logCameraCreationDelaySplitPointPreCaptureOperationFinishedAt:CACurrentMediaTime()];

    UIImage *fullScreenImage = [self imageFromData:imageData
                                 currentZoomFactor:_zoomFactor
                                 targetAspectRatio:_aspectRatio
                                       fieldOfView:_fieldOfView
                                             state:_state
                                      sampleBuffer:sampleBuffer];
    [[SCLogger sharedInstance] updateLogTimedEvent:kSCCameraMetricsRecordingDelay
                                          uniqueId:@"IMAGE"
                                        splitPoint:@"WILL_START_COMPLETION_HANDLER"];
    sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler = _completionHandler;
    _completionHandler = nil;
    if (completionHandler) {
        completionHandler(fullScreenImage, cameraInfo, error);
    }
}

- (void)_photoCaptureDidSucceedWithImageData:(NSData *)imageData
                                    metadata:(NSDictionary *)metadata
                                       error:(NSError *)error
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    [[SCLogger sharedInstance] logPreCaptureOperationFinishedAt:CACurrentMediaTime()];
    [[SCCoreCameraLogger sharedInstance]
        logCameraCreationDelaySplitPointPreCaptureOperationFinishedAt:CACurrentMediaTime()];

    UIImage *fullScreenImage = [self imageFromData:imageData
                                 currentZoomFactor:_zoomFactor
                                 targetAspectRatio:_aspectRatio
                                       fieldOfView:_fieldOfView
                                             state:_state
                                          metadata:metadata];
    [[SCLogger sharedInstance] updateLogTimedEvent:kSCCameraMetricsRecordingDelay
                                          uniqueId:@"IMAGE"
                                        splitPoint:@"WILL_START_COMPLETION_HANDLER"];
    sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler = _completionHandler;
    _completionHandler = nil;
    if (completionHandler) {
        completionHandler(fullScreenImage, metadata, error);
    }
}

- (void)_photoCaptureDidFailWithError:(NSError *)error
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler = _completionHandler;
    _completionHandler = nil;
    if (completionHandler) {
        completionHandler(nil, nil, error);
    }
}

- (AVCaptureConnection *)_captureConnectionFromPhotoOutput:(AVCapturePhotoOutput *)photoOutput
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    NSArray *connections = [photoOutput.connections copy];
    for (AVCaptureConnection *connection in connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                return connection;
            }
        }
    }
    return nil;
}

- (AVCapturePhotoSettings *)_photoSettingsWithPhotoOutput:(AVCapturePhotoOutput *)photoOutput
                                        captureConnection:(AVCaptureConnection *)captureConnection
                                             captureState:(SCManagedCapturerState *)state
{
    SCTraceStart();
    if ([self _shouldUseBracketPhotoSettingsWithCaptureState:state]) {
        return [self _bracketPhotoSettingsWithPhotoOutput:photoOutput
                                        captureConnection:captureConnection
                                             captureState:state];
    } else {
        return [self _defaultPhotoSettingsWithPhotoOutput:photoOutput captureState:state];
    }
}

- (BOOL)_shouldUseBracketPhotoSettingsWithCaptureState:(SCManagedCapturerState *)state
{
    // According to Apple docmentation, AVCapturePhotoBracketSettings do not support flashMode,
    // autoStillImageStabilizationEnabled, livePhotoMovieFileURL or livePhotoMovieMetadata.
    // Besides, we only use AVCapturePhotoBracketSettings if capture settings needs to be set manually.
    return !state.flashActive && !_portraitModeCaptureEnabled &&
           (([SCManagedCaptureDevice isEnhancedNightModeSupported] && state.isNightModeActive) ||
            [_delegate managedStillImageCapturerIsUnderDeviceMotion:self]);
}

- (AVCapturePhotoSettings *)_defaultPhotoSettingsWithPhotoOutput:(AVCapturePhotoOutput *)photoOutput
                                                    captureState:(SCManagedCapturerState *)state
{
    SCTraceStart();
    // Specify the output file format
    AVCapturePhotoSettings *photoSettings =
        [AVCapturePhotoSettings photoSettingsWithFormat:@{AVVideoCodecKey : AVVideoCodecJPEG}];

    // Enable HRSI if necessary
    if (photoSettings.isHighResolutionPhotoEnabled != _shouldEnableHRSI) {
        photoSettings.highResolutionPhotoEnabled = _shouldEnableHRSI;
    }

    // Turn on flash if active and supported by device
    if (state.flashActive && state.flashSupported) {
        photoSettings.flashMode = AVCaptureFlashModeOn;
    }

    // Turn on stabilization if available
    // Seems that setting autoStillImageStabilizationEnabled doesn't work during video capture session,
    // but we set enable it anyway as it is harmless.
    if (photoSettings.isAutoStillImageStabilizationEnabled) {
        photoSettings.autoStillImageStabilizationEnabled = YES;
    }

    if (_portraitModeCaptureEnabled) {
        if (@available(ios 11.0, *)) {
            photoSettings.depthDataDeliveryEnabled = YES;
        }
    }

    return photoSettings;
}

- (AVCapturePhotoSettings *)_bracketPhotoSettingsWithPhotoOutput:(AVCapturePhotoOutput *)photoOutput
                                               captureConnection:(AVCaptureConnection *)captureConnection
                                                    captureState:(SCManagedCapturerState *)state
{
    SCTraceStart();
    OSType rawPixelFormatType = [photoOutput.availableRawPhotoPixelFormatTypes.firstObject unsignedIntValue];
    NSArray<AVCaptureBracketedStillImageSettings *> *bracketedSettings =
        [self _bracketSettingsArray:captureConnection withCaptureState:state];
    SCAssert(bracketedSettings.count <= photoOutput.maxBracketedCapturePhotoCount,
             @"Bracket photo count cannot exceed maximum count");
    // Specify the output file format and raw pixel format
    AVCapturePhotoBracketSettings *photoSettings =
        [AVCapturePhotoBracketSettings photoBracketSettingsWithRawPixelFormatType:rawPixelFormatType
                                                                  processedFormat:@{
                                                                      AVVideoCodecKey : AVVideoCodecJPEG
                                                                  }
                                                                bracketedSettings:bracketedSettings];

    // Enable HRSI if necessary
    if (photoSettings.isHighResolutionPhotoEnabled != _shouldEnableHRSI) {
        photoSettings.highResolutionPhotoEnabled = _shouldEnableHRSI;
    }

    // If lens stabilization is supportd, enable the stabilization when device is moving
    if (photoOutput.isLensStabilizationDuringBracketedCaptureSupported && !photoSettings.isLensStabilizationEnabled &&
        [_delegate managedStillImageCapturerIsUnderDeviceMotion:self]) {
        photoSettings.lensStabilizationEnabled = YES;
    }
    return photoSettings;
}

- (NSArray *)_bracketSettingsArray:(AVCaptureConnection *)stillImageConnection
                  withCaptureState:(SCManagedCapturerState *)state
{
    NSInteger const stillCount = 1;
    NSMutableArray *bracketSettingsArray = [NSMutableArray arrayWithCapacity:stillCount];
    AVCaptureDevice *device = [stillImageConnection inputDevice];
    CMTime exposureDuration = device.exposureDuration;
    if ([SCManagedCaptureDevice isEnhancedNightModeSupported] && state.isNightModeActive) {
        exposureDuration = [self adjustedExposureDurationForNightModeWithCurrentExposureDuration:exposureDuration];
    }
    AVCaptureBracketedStillImageSettings *settings = [AVCaptureManualExposureBracketedStillImageSettings
        manualExposureSettingsWithExposureDuration:exposureDuration
                                               ISO:AVCaptureISOCurrent];
    for (NSInteger i = 0; i < stillCount; i++) {
        [bracketSettingsArray addObject:settings];
    }
    return [bracketSettingsArray copy];
}

- (NSString *)_photoCapturerStatusToString:(SCManagedPhotoCapturerStatus)status
{
    switch (status) {
    case SCManagedPhotoCapturerStatusPrepareToCapture:
        return @"PhotoCapturerStatusPrepareToCapture";
    case SCManagedPhotoCapturerStatusWillCapture:
        return @"PhotoCapturerStatusWillCapture";
    case SCManagedPhotoCapturerStatusDidFinishProcess:
        return @"PhotoCapturerStatusDidFinishProcess";
    }
}

@end
