//
//  SCManagedCaptureSession.m
//  Snapchat
//
//  Created by Derek Wang on 02/03/2018.
//

#import "SCManagedCaptureSession.h"

#import "SCBlackCameraDetector.h"

#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCManagedCaptureSession () {
    SCBlackCameraDetector *_blackCameraDetector;
}

@end

@implementation SCManagedCaptureSession

- (instancetype)initWithBlackCameraDetector:(SCBlackCameraDetector *)detector
{
    self = [super init];
    if (self) {
        _avSession = [[AVCaptureSession alloc] init];
        _blackCameraDetector = detector;
    }
    return self;
}

- (void)startRunning
{
    SCTraceODPCompatibleStart(2);
    [_blackCameraDetector sessionWillCallStartRunning];
    [_avSession startRunning];
    [_blackCameraDetector sessionDidCallStartRunning];
}

- (void)stopRunning
{
    SCTraceODPCompatibleStart(2);
    [_blackCameraDetector sessionWillCallStopRunning];
    [_avSession stopRunning];
    [_blackCameraDetector sessionDidCallStopRunning];
}

- (void)performConfiguration:(nonnull void (^)(void))block
{
    SC_GUARD_ELSE_RETURN(block);
    [self beginConfiguration];
    block();
    [self commitConfiguration];
}

- (void)beginConfiguration
{
    [_avSession beginConfiguration];
}

- (void)commitConfiguration
{
    SCTraceODPCompatibleStart(2);
    [_blackCameraDetector sessionWillCommitConfiguration];
    [_avSession commitConfiguration];
    [_blackCameraDetector sessionDidCommitConfiguration];
}

- (BOOL)isRunning
{
    return _avSession.isRunning;
}

@end
