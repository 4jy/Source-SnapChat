//
//  SCBlackCameraDetector.m
//  Snapchat
//
//  Created by Derek Wang on 24/01/2018.
//

#import "SCBlackCameraDetector.h"

#import "SCBlackCameraNoOutputDetector.h"
#import "SCBlackCameraPreviewDetector.h"
#import "SCBlackCameraRunningDetector.h"
#import "SCBlackCameraSessionBlockDetector.h"
#import "SCBlackCameraViewDetector.h"

#import <SCFoundation/SCQueuePerformer.h>

#if !TARGET_IPHONE_SIMULATOR
static char *const kSCBlackCameraDetectorQueueLabel = "com.snapchat.black-camera-detector";
#endif
@interface SCBlackCameraDetector () {
    BOOL _sessionIsRunning;
    BOOL _cameraIsVisible;
    BOOL _previewIsVisible;
}
@property (nonatomic, strong) SCQueuePerformer *queuePerformer;
@property (nonatomic, strong) SCBlackCameraViewDetector *cameraViewDetector;
@property (nonatomic, strong) SCBlackCameraRunningDetector *sessionRunningDetector;
@property (nonatomic, strong) SCBlackCameraPreviewDetector *previewDetector;
@property (nonatomic, strong) SCBlackCameraSessionBlockDetector *sessionBlockDetector;

@end

@implementation SCBlackCameraDetector

- (instancetype)initWithTicketCreator:(id<SCManiphestTicketCreator>)ticketCreator
{
#if !TARGET_IPHONE_SIMULATOR

    self = [super init];
    if (self) {
        _queuePerformer = [[SCQueuePerformer alloc] initWithLabel:kSCBlackCameraDetectorQueueLabel
                                                 qualityOfService:QOS_CLASS_BACKGROUND
                                                        queueType:DISPATCH_QUEUE_SERIAL
                                                          context:SCQueuePerformerContextCamera];

        SCBlackCameraReporter *reporter = [[SCBlackCameraReporter alloc] initWithTicketCreator:ticketCreator];
        _cameraViewDetector = [[SCBlackCameraViewDetector alloc] initWithPerformer:_queuePerformer reporter:reporter];
        _sessionRunningDetector =
            [[SCBlackCameraRunningDetector alloc] initWithPerformer:_queuePerformer reporter:reporter];
        _previewDetector = [[SCBlackCameraPreviewDetector alloc] initWithPerformer:_queuePerformer reporter:reporter];
        _sessionBlockDetector = [[SCBlackCameraSessionBlockDetector alloc] initWithReporter:reporter];
        _blackCameraNoOutputDetector = [[SCBlackCameraNoOutputDetector alloc] initWithReporter:reporter];
    }
    return self;
#else
    return nil;
#endif
}

#pragma mark - Camera view visibility detector
- (void)onCameraViewVisible:(BOOL)visible
{
    SC_GUARD_ELSE_RETURN(visible != _cameraIsVisible);
    _cameraIsVisible = visible;
    [_cameraViewDetector onCameraViewVisible:visible];
}

- (void)onCameraViewVisibleWithTouch:(UIGestureRecognizer *)gesture
{
    [_cameraViewDetector onCameraViewVisibleWithTouch:gesture];
}

#pragma mark - Track [AVCaptureSession startRunning] call
- (void)sessionWillCallStartRunning
{
    [_cameraViewDetector sessionWillCallStartRunning];
    [_sessionBlockDetector sessionWillCallStartRunning];
}

- (void)sessionDidCallStartRunning
{
    [_sessionRunningDetector sessionDidCallStartRunning];
    [_sessionBlockDetector sessionDidCallStartRunning];
}

#pragma mark - Track [AVCaptureSession stopRunning] call
- (void)sessionWillCallStopRunning
{
    [_cameraViewDetector sessionWillCallStopRunning];
    [_sessionRunningDetector sessionWillCallStopRunning];
}

- (void)sessionDidCallStopRunning
{
}

- (void)sessionDidChangeIsRunning:(BOOL)running
{
    SC_GUARD_ELSE_RETURN(running != _sessionIsRunning);
    _sessionIsRunning = running;
    [_sessionRunningDetector sessionDidChangeIsRunning:running];
    [_previewDetector sessionDidChangeIsRunning:running];
}

#pragma mark - Capture preview visibility detector
- (void)capturePreviewDidBecomeVisible:(BOOL)visible
{
    SC_GUARD_ELSE_RETURN(visible != _previewIsVisible);
    _previewIsVisible = visible;
    [_previewDetector capturePreviewDidBecomeVisible:visible];
}

#pragma mark - AVCaptureSession block detector
- (void)sessionWillCommitConfiguration
{
    [_sessionBlockDetector sessionWillCommitConfiguration];
}

- (void)sessionDidCommitConfiguration
{
    [_sessionBlockDetector sessionDidCommitConfiguration];
}

- (void)sessionWillRecreate
{
    [_cameraViewDetector sessionWillRecreate];
}

- (void)sessionDidRecreate
{
    [_cameraViewDetector sessionDidRecreate];
}
@end
