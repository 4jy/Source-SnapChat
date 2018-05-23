//
//  SCCaptureCoreImageFaceDetector.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/27/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCCaptureCoreImageFaceDetector.h"

#import "SCCameraTweaks.h"
#import "SCCaptureFaceDetectionParser.h"
#import "SCCaptureFaceDetectorTrigger.h"
#import "SCCaptureResource.h"
#import "SCManagedCapturer.h"

#import <SCFoundation/NSArray+Helpers.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>
#import <SCFoundation/UIImage+CVPixelBufferRef.h>

@import ImageIO;

static const NSTimeInterval kSCCaptureCoreImageFaceDetectorMaxAllowedLatency =
    1; // Drop the face detection result if it is 1 second late.
static const NSInteger kDefaultNumberOfSequentialOutputSampleBuffer = -1; // -1 means no sequential sample buffers.

static char *const kSCCaptureCoreImageFaceDetectorProcessQueue =
    "com.snapchat.capture-core-image-face-detector-process";

@implementation SCCaptureCoreImageFaceDetector {
    CIDetector *_detector;
    SCCaptureResource *_captureResource;

    BOOL _isDetecting;
    BOOL _hasDetectedFaces;
    NSInteger _numberOfSequentialOutputSampleBuffer;
    NSUInteger _detectionFrequency;
    NSDictionary *_detectorOptions;
    SCManagedCaptureDevicePosition _devicePosition;
    CIContext *_context;

    SCQueuePerformer *_callbackPerformer;
    SCQueuePerformer *_processPerformer;

    SCCaptureFaceDetectionParser *_parser;
    SCCaptureFaceDetectorTrigger *_trigger;
}

@synthesize trigger = _trigger;
@synthesize parser = _parser;

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    SCTraceODPCompatibleStart(2);
    self = [super init];
    if (self) {
        SCAssert(captureResource, @"SCCaptureResource should not be nil");
        SCAssert(captureResource.queuePerformer, @"SCQueuePerformer should not be nil");
        _callbackPerformer = captureResource.queuePerformer;
        _captureResource = captureResource;
        _parser = [[SCCaptureFaceDetectionParser alloc]
            initWithFaceBoundsAreaThreshold:pow(SCCameraFaceFocusMinFaceSize(), 2)];
        _processPerformer = [[SCQueuePerformer alloc] initWithLabel:kSCCaptureCoreImageFaceDetectorProcessQueue
                                                   qualityOfService:QOS_CLASS_USER_INITIATED
                                                          queueType:DISPATCH_QUEUE_SERIAL
                                                            context:SCQueuePerformerContextCamera];
        _detectionFrequency = SCExperimentWithFaceDetectionFrequency();
        _devicePosition = captureResource.device.position;
        _trigger = [[SCCaptureFaceDetectorTrigger alloc] initWithDetector:self];
    }
    return self;
}

- (void)_setupDetectionIfNeeded
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(!_detector);
    if (!_context) {
        _context = [CIContext context];
    }
    // For CIDetectorMinFeatureSize, the valid range is [0.0100, 0.5000], otherwise, it will cause a crash.
    if (!_detectorOptions) {
        _detectorOptions = @{
            CIDetectorAccuracy : CIDetectorAccuracyLow,
            CIDetectorTracking : @(YES),
            CIDetectorMaxFeatureCount : @(2),
            CIDetectorMinFeatureSize : @(SCCameraFaceFocusMinFaceSize()),
            CIDetectorNumberOfAngles : @(3)
        };
    }
    @try {
        _detector = [CIDetector detectorOfType:CIDetectorTypeFace context:_context options:_detectorOptions];
    } @catch (NSException *exception) {
        SCLogCoreCameraError(@"Failed to create CIDetector with exception:%@", exception);
    }
}

- (void)_resetDetection
{
    SCTraceODPCompatibleStart(2);
    _detector = nil;
    [self _setupDetectionIfNeeded];
}

- (SCQueuePerformer *)detectionPerformer
{
    return _processPerformer;
}

- (void)startDetection
{
    SCTraceODPCompatibleStart(2);
    SCAssert([[self detectionPerformer] isCurrentPerformer], @"Calling -startDetection in an invalid queue.");
    [self _setupDetectionIfNeeded];
    _isDetecting = YES;
    _hasDetectedFaces = NO;
    _numberOfSequentialOutputSampleBuffer = kDefaultNumberOfSequentialOutputSampleBuffer;
}

- (void)stopDetection
{
    SCTraceODPCompatibleStart(2);
    SCAssert([[self detectionPerformer] isCurrentPerformer], @"Calling -stopDetection in an invalid queue.");
    _isDetecting = NO;
}

- (NSDictionary<NSNumber *, NSValue *> *)_detectFaceFeaturesInImage:(CIImage *)image
                                                    withOrientation:(CGImagePropertyOrientation)orientation
{
    SCTraceODPCompatibleStart(2);
    NSDictionary *opts =
        @{ CIDetectorImageOrientation : @(orientation),
           CIDetectorEyeBlink : @(NO),
           CIDetectorSmile : @(NO) };
    NSArray<CIFeature *> *features = [_detector featuresInImage:image options:opts];
    return [_parser parseFaceBoundsByFaceIDFromCIFeatures:features
                                            withImageSize:image.extent.size
                                         imageOrientation:orientation];
}

#pragma mark - SCManagedVideoDataSourceListener

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN(_isDetecting);

    // Reset detection if the device position changes. Resetting detection should execute in _processPerformer, so we
    // just set a flag here, and then do it later in the perform block.
    BOOL shouldForceResetDetection = NO;
    if (devicePosition != _devicePosition) {
        _devicePosition = devicePosition;
        shouldForceResetDetection = YES;
        _numberOfSequentialOutputSampleBuffer = kDefaultNumberOfSequentialOutputSampleBuffer;
    }

    _numberOfSequentialOutputSampleBuffer++;
    SC_GUARD_ELSE_RETURN(_numberOfSequentialOutputSampleBuffer % _detectionFrequency == 0);
    @weakify(self);
    CFRetain(sampleBuffer);
    [_processPerformer perform:^{
        SCTraceStart();
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);

        if (shouldForceResetDetection) {
            // Resetting detection usually costs no more than 1ms.
            [self _resetDetection];
        }

        CGImagePropertyOrientation orientation =
            (devicePosition == SCManagedCaptureDevicePositionBack ? kCGImagePropertyOrientationRight
                                                                  : kCGImagePropertyOrientationLeftMirrored);
        CIImage *image = [CIImage imageWithCVPixelBuffer:CMSampleBufferGetImageBuffer(sampleBuffer)];
        NSDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID =
            [self _detectFaceFeaturesInImage:image withOrientation:orientation];

        // Calculate the latency for face detection, if it is too long, discard the face detection results.
        NSTimeInterval latency =
            CACurrentMediaTime() - CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer));
        CFRelease(sampleBuffer);
        if (latency >= kSCCaptureCoreImageFaceDetectorMaxAllowedLatency) {
            faceBoundsByFaceID = nil;
        }

        // Only announce face detection result if faceBoundsByFaceID is not empty, or faceBoundsByFaceID was not empty
        // last time.
        if (faceBoundsByFaceID.count > 0 || self->_hasDetectedFaces) {
            self->_hasDetectedFaces = faceBoundsByFaceID.count > 0;
            [self->_callbackPerformer perform:^{
                [self->_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                              didDetectFaceBounds:faceBoundsByFaceID];
            }];
        }
    }];
}

@end
