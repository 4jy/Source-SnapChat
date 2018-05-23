//
//  SCCaptureMetadataOutputDetector.m
//  Snapchat
//
//  Created by Jiyang Zhu on 12/21/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCCaptureMetadataOutputDetector.h"

#import "SCCameraTweaks.h"
#import "SCCaptureFaceDetectionParser.h"
#import "SCCaptureFaceDetectorTrigger.h"
#import "SCCaptureResource.h"
#import "SCManagedCaptureSession.h"
#import "SCManagedCapturer.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>
#import <SCFoundation/UIImage+CVPixelBufferRef.h>

#define SCLogCaptureMetaDetectorInfo(fmt, ...)                                                                         \
    SCLogCoreCameraInfo(@"[SCCaptureMetadataOutputDetector] " fmt, ##__VA_ARGS__)
#define SCLogCaptureMetaDetectorWarning(fmt, ...)                                                                      \
    SCLogCoreCameraWarning(@"[SCCaptureMetadataOutputDetector] " fmt, ##__VA_ARGS__)
#define SCLogCaptureMetaDetectorError(fmt, ...)                                                                        \
    SCLogCoreCameraError(@"[SCCaptureMetadataOutputDetector] " fmt, ##__VA_ARGS__)

static char *const kSCCaptureMetadataOutputDetectorProcessQueue =
    "com.snapchat.capture-metadata-output-detector-process";

static const NSInteger kDefaultNumberOfSequentialFramesWithFaces = -1; // -1 means no sequential frames with faces.

@interface SCCaptureMetadataOutputDetector () <AVCaptureMetadataOutputObjectsDelegate>

@end

@implementation SCCaptureMetadataOutputDetector {
    BOOL _isDetecting;

    AVCaptureMetadataOutput *_metadataOutput;
    SCCaptureResource *_captureResource;

    SCCaptureFaceDetectionParser *_parser;
    NSInteger _numberOfSequentialFramesWithFaces;
    NSUInteger _detectionFrequency;

    SCQueuePerformer *_callbackPerformer;
    SCQueuePerformer *_metadataProcessPerformer;

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
        SCAssert(captureResource.managedSession.avSession, @"AVCaptureSession should not be nil");
        SCAssert(captureResource.queuePerformer, @"SCQueuePerformer should not be nil");
        _metadataOutput = [AVCaptureMetadataOutput new];
        _callbackPerformer = captureResource.queuePerformer;
        _captureResource = captureResource;
        _detectionFrequency = SCExperimentWithFaceDetectionFrequency();

        _parser = [[SCCaptureFaceDetectionParser alloc]
            initWithFaceBoundsAreaThreshold:pow(SCCameraFaceFocusMinFaceSize(), 2)];
        _metadataProcessPerformer = [[SCQueuePerformer alloc] initWithLabel:kSCCaptureMetadataOutputDetectorProcessQueue
                                                           qualityOfService:QOS_CLASS_DEFAULT
                                                                  queueType:DISPATCH_QUEUE_SERIAL
                                                                    context:SCQueuePerformerContextCamera];
        if ([self _initDetection]) {
            _trigger = [[SCCaptureFaceDetectorTrigger alloc] initWithDetector:self];
        }
    }
    return self;
}

- (AVCaptureSession *)_captureSession
{
    // _captureResource.avSession may change, so we don't retain any specific AVCaptureSession.
    return _captureResource.managedSession.avSession;
}

- (BOOL)_initDetection
{
    BOOL success = NO;
    if ([[self _captureSession] canAddOutput:_metadataOutput]) {
        [[self _captureSession] addOutput:_metadataOutput];
        if ([_metadataOutput.availableMetadataObjectTypes containsObject:AVMetadataObjectTypeFace]) {
            _numberOfSequentialFramesWithFaces = kDefaultNumberOfSequentialFramesWithFaces;
            _metadataOutput.metadataObjectTypes = @[ AVMetadataObjectTypeFace ];
            success = YES;
            SCLogCaptureMetaDetectorInfo(@"AVMetadataObjectTypeFace detection successfully enabled.");
        } else {
            [[self _captureSession] removeOutput:_metadataOutput];
            success = NO;
            SCLogCaptureMetaDetectorError(@"AVMetadataObjectTypeFace is not available for "
                                          @"AVMetadataOutput[%@]",
                                          _metadataOutput);
        }
    } else {
        success = NO;
        SCLogCaptureMetaDetectorError(@"AVCaptureSession[%@] cannot add AVMetadataOutput[%@] as an output",
                                      [self _captureSession], _metadataOutput);
    }
    return success;
}

- (void)startDetection
{
    SCAssert([[self detectionPerformer] isCurrentPerformer], @"Calling -startDetection in an invalid queue.");
    SC_GUARD_ELSE_RETURN(!_isDetecting);
    [_captureResource.queuePerformer performImmediatelyIfCurrentPerformer:^{
        [_metadataOutput setMetadataObjectsDelegate:self queue:_metadataProcessPerformer.queue];
        _isDetecting = YES;
        SCLogCaptureMetaDetectorInfo(@"AVMetadataObjectTypeFace detection successfully enabled.");
    }];
}

- (void)stopDetection
{
    SCAssert([[self detectionPerformer] isCurrentPerformer], @"Calling -stopDetection in an invalid queue.");
    SC_GUARD_ELSE_RETURN(_isDetecting);
    [_captureResource.queuePerformer performImmediatelyIfCurrentPerformer:^{
        [_metadataOutput setMetadataObjectsDelegate:nil queue:NULL];
        _isDetecting = NO;
        SCLogCaptureMetaDetectorInfo(@"AVMetadataObjectTypeFace detection successfully disabled.");
    }];
}

- (SCQueuePerformer *)detectionPerformer
{
    return _captureResource.queuePerformer;
}

#pragma mark - AVCaptureMetadataOutputObjectsDelegate
- (void)captureOutput:(AVCaptureOutput *)output
    didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects
              fromConnection:(AVCaptureConnection *)connection
{
    SCTraceODPCompatibleStart(2);

    BOOL shouldNotify = NO;
    if (metadataObjects.count == 0 &&
        _numberOfSequentialFramesWithFaces !=
            kDefaultNumberOfSequentialFramesWithFaces) { // There were faces detected before, but there is no face right
                                                         // now, so send out the notification.
        _numberOfSequentialFramesWithFaces = kDefaultNumberOfSequentialFramesWithFaces;
        shouldNotify = YES;
    } else if (metadataObjects.count > 0) {
        _numberOfSequentialFramesWithFaces++;
        shouldNotify = (_numberOfSequentialFramesWithFaces % _detectionFrequency == 0);
    }

    SC_GUARD_ELSE_RETURN(shouldNotify);

    NSDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID =
        [_parser parseFaceBoundsByFaceIDFromMetadataObjects:metadataObjects];

    [_callbackPerformer perform:^{
        [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                didDetectFaceBounds:faceBoundsByFaceID];
    }];
}

@end
