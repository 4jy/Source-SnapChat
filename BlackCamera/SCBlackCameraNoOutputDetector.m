//
//  SCBlackCameraDetectorNoOutput.m
//  Snapchat
//
//  Created by Derek Wang on 05/12/2017.
//
//  This detector is used to detect the case that session is running, but there is no sample buffer output

#import "SCBlackCameraNoOutputDetector.h"

#import "SCBlackCameraReporter.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger.h>

static CGFloat const kShortCheckingDelay = 0.5f;
static CGFloat const kLongCheckingDelay = 3.0f;
static char *const kSCBlackCameraDetectorQueueLabel = "com.snapchat.black-camera-detector";

@interface SCBlackCameraNoOutputDetector () {
    BOOL _sampleBufferReceived;
    BOOL _blackCameraDetected;
    // Whether we receive first frame after we detected black camera, that's maybe because the checking delay is too
    // short, and we will switch to kLongCheckingDelay next time we do the checking
    BOOL _blackCameraRecovered;
    // Whether checking is scheduled, to avoid duplicated checking
    BOOL _checkingScheduled;
    // Whether AVCaptureSession is stopped, if stopped, we don't need to check black camera any more
    // It is set on main thread, read on background queue
    BOOL _sessionStoppedRunning;
}
@property (nonatomic) SCQueuePerformer *queuePerformer;
@property (nonatomic) SCBlackCameraReporter *reporter;
@end

@implementation SCBlackCameraNoOutputDetector

- (instancetype)initWithReporter:(SCBlackCameraReporter *)reporter
{
    self = [super init];
    if (self) {
        _queuePerformer = [[SCQueuePerformer alloc] initWithLabel:kSCBlackCameraDetectorQueueLabel
                                                 qualityOfService:QOS_CLASS_BACKGROUND
                                                        queueType:DISPATCH_QUEUE_SERIAL
                                                          context:SCQueuePerformerContextCamera];
        _reporter = reporter;
    }
    return self;
}

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    // The block is very light-weight
    [self.queuePerformer perform:^{
        if (_blackCameraDetected) {
            // Detected a black camera case
            _blackCameraDetected = NO;
            _blackCameraRecovered = YES;
            SCLogCoreCameraInfo(@"[BlackCamera] Black camera recovered");
            if (SCExperimentWithBlackCameraReporting()) {
                [[SCLogger sharedInstance] logUnsampledEvent:KSCCameraBlackCamera
                                                  parameters:@{
                                                      @"type" : @"RECOVERED"
                                                  }
                                            secretParameters:nil
                                                     metrics:nil];
            }
        }

        // Received buffer!
        _sampleBufferReceived = YES;
    }];
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didStartRunning:(SCManagedCapturerState *)state
{
    SCAssertMainThread();
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateBackground) {
        SCLogCoreCameraInfo(@"[BlackCamera] In background, skip checking");
        return;
    }
    _sessionStoppedRunning = NO;
    [self.queuePerformer perform:^{
        SCTraceODPCompatibleStart(2);
        if (_checkingScheduled) {
            SCLogCoreCameraInfo(@"[BlackCamera] Checking is scheduled, skip");
            return;
        }
        if (_sessionStoppedRunning) {
            SCLogCoreCameraInfo(@"[BlackCamera] AVCaptureSession stopped, should not check");
            return;
        }
        _sampleBufferReceived = NO;
        if (_blackCameraRecovered) {
            SCLogCoreCameraInfo(@"[BlackCamera] Last black camera recovered, let's wait longer to check this time");
        }
        SCLogCoreCameraInfo(@"[BlackCamera] Schedule black camera checking");
        [self.queuePerformer perform:^{
            SCTraceODPCompatibleStart(2);
            if (!_sessionStoppedRunning) {
                if (!_sampleBufferReceived) {
                    _blackCameraDetected = YES;
                    [_reporter reportBlackCameraWithCause:SCBlackCameraNoOutputData];
                    [self.delegate detector:self didDetectBlackCamera:managedCapturer];
                } else {
                    SCLogCoreCameraInfo(@"[BlackCamera] No black camera");
                    _blackCameraDetected = NO;
                }
            } else {
                SCLogCoreCameraInfo(@"[BlackCamera] AVCaptureSession stopped");
                _blackCameraDetected = NO;
            }
            _blackCameraRecovered = NO;
            _checkingScheduled = NO;
        }
                               after:_blackCameraRecovered ? kLongCheckingDelay : kShortCheckingDelay];
        _checkingScheduled = YES;
    }];
}
- (void)managedCapturer:(id<SCCapturer>)managedCapturer didStopRunning:(SCManagedCapturerState *)state
{
    SCAssertMainThread();
    _sessionStoppedRunning = YES;
    [self.queuePerformer perform:^{
        SCTraceODPCompatibleStart(2);
        _sampleBufferReceived = NO;
    }];
}

@end
