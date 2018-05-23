//
//  SCManagedCapturerARSessionHandler.m
//  Snapchat
//
//  Created by Xiaokang Liu on 16/03/2018.
//

#import "SCManagedCapturerARSessionHandler.h"

#import "SCCaptureResource.h"
#import "SCManagedCaptureSession.h"

#import <SCBase/SCAvailability.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>

@import ARKit;

static CGFloat const kSCManagedCapturerARKitShutdownTimeoutDuration = 2;

@interface SCManagedCapturerARSessionHandler () {
    SCCaptureResource *__weak _captureResource;
    dispatch_semaphore_t _arSesssionShutdownSemaphore;
}

@end

@implementation SCManagedCapturerARSessionHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super init];
    if (self) {
        SCAssert(captureResource, @"");
        _captureResource = captureResource;
        _arSesssionShutdownSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)stopObserving
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVCaptureSessionDidStopRunningNotification
                                                  object:nil];
}

- (void)stopARSessionRunning
{
    SCAssertPerformer(_captureResource.queuePerformer);
    SCAssert(SC_AT_LEAST_IOS_11, @"Shoule be only call from iOS 11+");
    if (@available(iOS 11.0, *)) {
        // ARSession stops its internal AVCaptureSession asynchronously. We listen for its callback and actually restart
        // our own capture session once it's finished shutting down so the two ARSessions don't conflict.
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_completeARSessionShutdown:)
                                                     name:AVCaptureSessionDidStopRunningNotification
                                                   object:nil];
        [_captureResource.arSession pause];
        dispatch_semaphore_wait(
            _arSesssionShutdownSemaphore,
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCManagedCapturerARKitShutdownTimeoutDuration * NSEC_PER_SEC)));
    }
}

- (void)_completeARSessionShutdown:(NSNotification *)note
{
    // This notification is only registered for IMMEDIATELY before arkit shutdown.
    // Explicitly guard that the notification object IS NOT the main session's.
    SC_GUARD_ELSE_RETURN(![note.object isEqual:_captureResource.managedSession.avSession]);
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVCaptureSessionDidStopRunningNotification
                                                  object:nil];
    dispatch_semaphore_signal(_arSesssionShutdownSemaphore);
}
@end
