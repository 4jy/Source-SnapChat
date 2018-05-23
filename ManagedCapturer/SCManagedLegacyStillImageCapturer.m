//
//  SCManagedLegacyStillImageCapturer.m
//  Snapchat
//
//  Created by Chao Pang on 10/4/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCManagedLegacyStillImageCapturer.h"

#import "AVCaptureConnection+InputDevice.h"
#import "SCCameraTweaks.h"
#import "SCLogger+Camera.h"
#import "SCManagedCapturer.h"
#import "SCManagedStillImageCapturer_Protected.h"
#import "SCStillImageCaptureVideoInputMethod.h"

#import <SCCrashLogger/SCCrashLogger.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCPerforming.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCLenses/SCLens.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCWebP/UIImage+WebP.h>

@import ImageIO;

static NSString *const kSCLegacyStillImageCaptureDefaultMethodErrorDomain =
    @"kSCLegacyStillImageCaptureDefaultMethodErrorDomain";
static NSString *const kSCLegacyStillImageCaptureLensStabilizationMethodErrorDomain =
    @"kSCLegacyStillImageCaptureLensStabilizationMethodErrorDomain";

static NSInteger const kSCLegacyStillImageCaptureDefaultMethodErrorEncounteredException = 10000;
static NSInteger const kSCLegacyStillImageCaptureLensStabilizationMethodErrorEncounteredException = 10001;

@implementation SCManagedLegacyStillImageCapturer {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AVCaptureStillImageOutput *_stillImageOutput;
#pragma clang diagnostic pop

    BOOL _shouldCapture;
    NSUInteger _retries;

    SCStillImageCaptureVideoInputMethod *_videoFileMethod;
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
    }
    return self;
}

- (void)setupWithSession:(AVCaptureSession *)session
{
    SCTraceStart();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    _stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
#pragma clang diagnostic pop
    _stillImageOutput.outputSettings = @{AVVideoCodecKey : AVVideoCodecJPEG};
    [self setAsOutput:session];
}

- (void)setAsOutput:(AVCaptureSession *)session
{
    SCTraceStart();
    if ([session canAddOutput:_stillImageOutput]) {
        [session addOutput:_stillImageOutput];
    }
}

- (void)setHighResolutionStillImageOutputEnabled:(BOOL)highResolutionStillImageOutputEnabled
{
    SCTraceStart();
    if (_stillImageOutput.isHighResolutionStillImageOutputEnabled != highResolutionStillImageOutputEnabled) {
        _stillImageOutput.highResolutionStillImageOutputEnabled = highResolutionStillImageOutputEnabled;
    }
}

- (void)setPortraitModeCaptureEnabled:(BOOL)enabled
{
    // Legacy capturer only used on devices running versions under 10.2, which don't support depth data
    // so this function is never called and does not need to be implemented
}

- (void)enableStillImageStabilization
{
    SCTraceStart();
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (_stillImageOutput.isLensStabilizationDuringBracketedCaptureSupported) {
        _stillImageOutput.lensStabilizationDuringBracketedCaptureEnabled = YES;
    }
#pragma clang diagnostic pop
}

- (void)removeAsOutput:(AVCaptureSession *)session
{
    SCTraceStart();
    [session removeOutput:_stillImageOutput];
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
    _retries = 6; // AVFoundation Unknown Error usually resolves itself within 0.5 seconds
    _aspectRatio = aspectRatio;
    _zoomFactor = zoomFactor;
    _fieldOfView = fieldOfView;
    _state = state;
    _captureSessionID = captureSessionID;
    _shouldCaptureFromVideo = shouldCaptureFromVideo;
    SCAssert(!_completionHandler, @"We shouldn't have a _completionHandler at this point otherwise we are destroying "
                                  @"current completion handler.");
    _completionHandler = [completionHandler copy];
    [[SCLogger sharedInstance] logCameraExposureAdjustmentDelayStart];
    if (!_adjustingExposureManualDetect) {
        SCLogCoreCameraInfo(@"Capturing still image now");
        [self _captureStillImageWithExposureAdjustmentStrategy:kSCCameraExposureAdjustmentStrategyNo];
        _shouldCapture = NO;
    } else {
        SCLogCoreCameraInfo(@"Wait adjusting exposure (or after 0.4 seconds) and then capture still image");
        _shouldCapture = YES;
        [self _deadlineCaptureStillImage];
    }
}

#pragma mark - SCManagedDeviceCapacityAnalyzerListener

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeAdjustingExposure:(BOOL)adjustingExposure
{
    SCTraceStart();
    @weakify(self);
    [_performer performImmediatelyIfCurrentPerformer:^{
        // Since this is handled on a different thread, therefore, dispatch back to the queue we operated on.
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
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

#pragma mark - Private methods

- (void)_didChangeAdjustingExposure:(BOOL)adjustingExposure withStrategy:(NSString *)strategy
{
    if (!adjustingExposure && self->_shouldCapture) {
        SCLogCoreCameraInfo(@"Capturing after adjusting exposure using strategy: %@", strategy);
        [self _captureStillImageWithExposureAdjustmentStrategy:strategy];
        self->_shouldCapture = NO;
    }
}

- (void)_deadlineCaptureStillImage
{
    SCTraceStart();
    // Use the SCManagedCapturer's private queue.
    [_performer perform:^{
        if (_shouldCapture) {
            [self _captureStillImageWithExposureAdjustmentStrategy:kSCCameraExposureAdjustmentStrategyDeadline];
            _shouldCapture = NO;
        }
    }
                  after:SCCameraTweaksExposureDeadline()];
}

- (void)_captureStillImageWithExposureAdjustmentStrategy:(NSString *)strategy
{
    SCTraceStart();
    [[SCLogger sharedInstance] logCameraExposureAdjustmentDelayEndWithStrategy:strategy];
    if (_shouldCaptureFromVideo) {
        [self captureStillImageFromVideoBuffer];
        return;
    }
    SCAssert(_stillImageOutput, @"stillImageOutput shouldn't be nil");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    AVCaptureStillImageOutput *stillImageOutput = _stillImageOutput;
#pragma clang diagnostic pop
    AVCaptureConnection *captureConnection = [self _captureConnectionFromStillImageOutput:stillImageOutput];
    SCManagedCapturerState *state = [_state copy];
    dispatch_block_t legacyStillImageCaptureBlock = ^{
        SCCAssertMainThread();
        // If the application is not in background, and we have still image connection, do thecapture. Otherwise fail.
        if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
            [_performer performImmediatelyIfCurrentPerformer:^{
                sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler =
                    _completionHandler;
                _completionHandler = nil;
                completionHandler(nil, nil,
                                  [NSError errorWithDomain:kSCManagedStillImageCapturerErrorDomain
                                                      code:kSCManagedStillImageCapturerApplicationStateBackground
                                                  userInfo:nil]);
            }];
            return;
        }
#if !TARGET_IPHONE_SIMULATOR
        if (!captureConnection) {
            [_performer performImmediatelyIfCurrentPerformer:^{
                sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler =
                    _completionHandler;
                _completionHandler = nil;
                completionHandler(nil, nil, [NSError errorWithDomain:kSCManagedStillImageCapturerErrorDomain
                                                                code:kSCManagedStillImageCapturerNoStillImageConnection
                                                            userInfo:nil]);
            }];
            return;
        }
#endif
        // Select appropriate image capture method
        if ([_delegate managedStillImageCapturerShouldProcessFileInput:self]) {
            if (!_videoFileMethod) {
                _videoFileMethod = [[SCStillImageCaptureVideoInputMethod alloc] init];
            }
            [[SCLogger sharedInstance] logStillImageCaptureApi:@"SCStillImageCapture"];
            [[SCCoreCameraLogger sharedInstance]
                logCameraCreationDelaySplitPointStillImageCaptureApi:@"SCStillImageCapture"];
            [_videoFileMethod captureStillImageWithCapturerState:state
                successBlock:^(NSData *imageData, NSDictionary *cameraInfo, NSError *error) {
                    [self _legacyStillImageCaptureDidSucceedWithImageData:imageData
                                                             sampleBuffer:nil
                                                               cameraInfo:cameraInfo
                                                                    error:error];
                }
                failureBlock:^(NSError *error) {
                    [self _legacyStillImageCaptureDidFailWithError:error];
                }];
        } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if (stillImageOutput.isLensStabilizationDuringBracketedCaptureSupported && !state.flashActive) {
                [self _captureStabilizedStillImageWithStillImageOutput:stillImageOutput
                                                     captureConnection:captureConnection
                                                         capturerState:state];
            } else {
                [self _captureStillImageWithStillImageOutput:stillImageOutput
                                           captureConnection:captureConnection
                                               capturerState:state];
            }
#pragma clang diagnostic pop
        }
    };
    // We need to call this on main thread and blocking.
    [[SCQueuePerformer mainQueuePerformer] performAndWait:legacyStillImageCaptureBlock];
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (void)_captureStillImageWithStillImageOutput:(AVCaptureStillImageOutput *)stillImageOutput
                             captureConnection:(AVCaptureConnection *)captureConnection
                                 capturerState:(SCManagedCapturerState *)state
{
    [[SCLogger sharedInstance] logStillImageCaptureApi:@"AVStillImageCaptureAsynchronous"];
    [[SCCoreCameraLogger sharedInstance]
        logCameraCreationDelaySplitPointStillImageCaptureApi:@"AVStillImageCaptureAsynchronous"];
    @try {
        [stillImageOutput
            captureStillImageAsynchronouslyFromConnection:captureConnection
                                        completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
                                            if (imageDataSampleBuffer) {
                                                NSData *imageData = [AVCaptureStillImageOutput
                                                    jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                [self
                                                    _legacyStillImageCaptureDidSucceedWithImageData:imageData
                                                                                       sampleBuffer:
                                                                                           imageDataSampleBuffer
                                                                                         cameraInfo:
                                                                                             cameraInfoForBuffer(
                                                                                                 imageDataSampleBuffer)
                                                                                              error:error];
                                            } else {
                                                if (error.domain == AVFoundationErrorDomain && error.code == -11800) {
                                                    // iOS 7 "unknown error"; works if we retry
                                                    [self _legacyStillImageCaptureWillRetryWithError:error];
                                                } else {
                                                    [self _legacyStillImageCaptureDidFailWithError:error];
                                                }
                                            }
                                        }];
    } @catch (NSException *e) {
        [SCCrashLogger logHandledException:e];
        [self _legacyStillImageCaptureDidFailWithError:
                  [NSError errorWithDomain:kSCLegacyStillImageCaptureDefaultMethodErrorDomain
                                      code:kSCLegacyStillImageCaptureDefaultMethodErrorEncounteredException
                                  userInfo:@{
                                      @"exception" : e
                                  }]];
    }
}

- (void)_captureStabilizedStillImageWithStillImageOutput:(AVCaptureStillImageOutput *)stillImageOutput
                                       captureConnection:(AVCaptureConnection *)captureConnection
                                           capturerState:(SCManagedCapturerState *)state
{
    [[SCLogger sharedInstance] logStillImageCaptureApi:@"AVStillImageOutputCaptureBracketAsynchronously"];
    [[SCCoreCameraLogger sharedInstance]
        logCameraCreationDelaySplitPointStillImageCaptureApi:@"AVStillImageOutputCaptureBracketAsynchronously"];
    NSArray *bracketArray = [self _bracketSettingsArray:captureConnection];
    @try {
        [stillImageOutput
            captureStillImageBracketAsynchronouslyFromConnection:captureConnection
                                               withSettingsArray:bracketArray
                                               completionHandler:^(CMSampleBufferRef imageDataSampleBuffer,
                                                                   AVCaptureBracketedStillImageSettings *settings,
                                                                   NSError *err) {
                                                   if (!imageDataSampleBuffer) {
                                                       [self _legacyStillImageCaptureDidFailWithError:err];
                                                       return;
                                                   }
                                                   NSData *jpegData = [AVCaptureStillImageOutput
                                                       jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                                                   [self
                                                       _legacyStillImageCaptureDidSucceedWithImageData:jpegData
                                                                                          sampleBuffer:
                                                                                              imageDataSampleBuffer
                                                                                            cameraInfo:
                                                                                                cameraInfoForBuffer(
                                                                                                    imageDataSampleBuffer)
                                                                                                 error:nil];
                                               }];
    } @catch (NSException *e) {
        [SCCrashLogger logHandledException:e];
        [self _legacyStillImageCaptureDidFailWithError:
                  [NSError errorWithDomain:kSCLegacyStillImageCaptureLensStabilizationMethodErrorDomain
                                      code:kSCLegacyStillImageCaptureLensStabilizationMethodErrorEncounteredException
                                  userInfo:@{
                                      @"exception" : e
                                  }]];
    }
}
#pragma clang diagnostic pop

- (NSArray *)_bracketSettingsArray:(AVCaptureConnection *)stillImageConnection
{
    NSInteger const stillCount = 1;
    NSMutableArray *bracketSettingsArray = [NSMutableArray arrayWithCapacity:stillCount];
    AVCaptureDevice *device = [stillImageConnection inputDevice];
    AVCaptureManualExposureBracketedStillImageSettings *settings = [AVCaptureManualExposureBracketedStillImageSettings
        manualExposureSettingsWithExposureDuration:device.exposureDuration
                                               ISO:AVCaptureISOCurrent];
    for (NSInteger i = 0; i < stillCount; i++) {
        [bracketSettingsArray addObject:settings];
    }
    return [bracketSettingsArray copy];
}

- (void)_legacyStillImageCaptureDidSucceedWithImageData:(NSData *)imageData
                                           sampleBuffer:(CMSampleBufferRef)sampleBuffer
                                             cameraInfo:(NSDictionary *)cameraInfo
                                                  error:(NSError *)error
{
    [[SCLogger sharedInstance] logPreCaptureOperationFinishedAt:CACurrentMediaTime()];
    [[SCCoreCameraLogger sharedInstance]
        logCameraCreationDelaySplitPointPreCaptureOperationFinishedAt:CACurrentMediaTime()];
    if (sampleBuffer) {
        CFRetain(sampleBuffer);
    }
    [_performer performImmediatelyIfCurrentPerformer:^{
        UIImage *fullScreenImage = [self imageFromData:imageData
                                     currentZoomFactor:_zoomFactor
                                     targetAspectRatio:_aspectRatio
                                           fieldOfView:_fieldOfView
                                                 state:_state
                                          sampleBuffer:sampleBuffer];

        sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler = _completionHandler;
        _completionHandler = nil;
        completionHandler(fullScreenImage, cameraInfo, error);
        if (sampleBuffer) {
            CFRelease(sampleBuffer);
        }
    }];
}

- (void)_legacyStillImageCaptureDidFailWithError:(NSError *)error
{
    [_performer performImmediatelyIfCurrentPerformer:^{
        sc_managed_still_image_capturer_capture_still_image_completion_handler_t completionHandler = _completionHandler;
        _completionHandler = nil;
        completionHandler(nil, nil, error);
    }];
}

- (void)_legacyStillImageCaptureWillRetryWithError:(NSError *)error
{
    if (_retries-- > 0) {
        [_performer perform:^{
            [self _captureStillImageWithExposureAdjustmentStrategy:kSCCameraExposureAdjustmentStrategyNo];
        }
                      after:kSCCameraRetryInterval];
    } else {
        [self _legacyStillImageCaptureDidFailWithError:error];
    }
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
- (AVCaptureConnection *)_captureConnectionFromStillImageOutput:(AVCaptureStillImageOutput *)stillImageOutput
#pragma clang diagnostic pop
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    NSArray *connections = [stillImageOutput.connections copy];
    for (AVCaptureConnection *connection in connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
                return connection;
            }
        }
    }
    return nil;
}

@end
