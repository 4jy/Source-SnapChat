//
//  SCBlackCameraDetectorCameraView.m
//  Snapchat
//
//  Created by Derek Wang on 24/01/2018.
//

#import "SCBlackCameraViewDetector.h"

#import "SCBlackCameraReporter.h"
#import "SCCaptureDeviceAuthorization.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCLogger/SCCameraMetrics.h>

// Check whether we called [AVCaptureSession startRunning] within this period
static CGFloat const kSCBlackCameraCheckingDelay = 0.5;

@interface SCBlackCameraViewDetector () {
    BOOL _startRunningCalled;
    BOOL _sessionIsRecreating;
    dispatch_block_t _checkSessionBlock;
}
@property (nonatomic) SCQueuePerformer *queuePerformer;
@property (nonatomic) SCBlackCameraReporter *reporter;
@property (nonatomic, weak) UIGestureRecognizer *cameraViewGesture;
@end

@implementation SCBlackCameraViewDetector

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer reporter:(SCBlackCameraReporter *)reporter
{
    self = [super init];
    if (self) {
        _queuePerformer = performer;
        _reporter = reporter;
    }
    return self;
}

#pragma mark - Camera view visibility change trigger
- (void)onCameraViewVisible:(BOOL)visible
{
    SCTraceODPCompatibleStart(2);
    SCLogCoreCameraInfo(@"[BlackCamera] onCameraViewVisible: %d", visible);
    BOOL firstTimeAccess = [SCCaptureDeviceAuthorization notDeterminedForVideoCapture];
    if (firstTimeAccess) {
        // We don't want to check black camera for firstTimeAccess
        return;
    }
    // Visible and application is active
    if (visible && [UIApplication sharedApplication].applicationState == UIApplicationStateActive) {
        // Since this method is usually called before the view is actually visible, leave some margin to check
        [self _scheduleCheckDelayed:YES];
    } else {
        [_queuePerformer perform:^{
            if (_checkSessionBlock) {
                dispatch_block_cancel(_checkSessionBlock);
                _checkSessionBlock = nil;
            }
        }];
    }
}

// Call this when [AVCaptureSession startRunning] is called
- (void)sessionWillCallStartRunning
{
    [_queuePerformer perform:^{
        _startRunningCalled = YES;
    }];
}

- (void)sessionWillCallStopRunning
{
    [_queuePerformer perform:^{
        _startRunningCalled = NO;
    }];
}

- (void)_scheduleCheckDelayed:(BOOL)delay
{
    [_queuePerformer perform:^{
        SC_GUARD_ELSE_RETURN(!_checkSessionBlock);
        @weakify(self);
        _checkSessionBlock = dispatch_block_create(0, ^{
            @strongify(self);
            SC_GUARD_ELSE_RETURN(self);
            self->_checkSessionBlock = nil;
            [self _checkSessionState];
        });

        if (delay) {
            [_queuePerformer perform:_checkSessionBlock after:kSCBlackCameraCheckingDelay];
        } else {
            [_queuePerformer perform:_checkSessionBlock];
        }
    }];
}

- (void)_checkSessionState
{
    SCLogCoreCameraInfo(@"[BlackCamera] checkSessionState startRunning: %d, sessionIsRecreating: %d",
                        _startRunningCalled, _sessionIsRecreating);
    if (!_startRunningCalled && !_sessionIsRecreating) {
        [_reporter reportBlackCameraWithCause:SCBlackCameraStartRunningNotCalled];
        [_reporter fileShakeTicketWithCause:SCBlackCameraStartRunningNotCalled];
    }
}

- (void)sessionWillRecreate
{
    [_queuePerformer perform:^{
        _sessionIsRecreating = YES;
    }];
}

- (void)sessionDidRecreate
{
    [_queuePerformer perform:^{
        _sessionIsRecreating = NO;
    }];
}

- (void)onCameraViewVisibleWithTouch:(UIGestureRecognizer *)gesture
{
    if (gesture != _cameraViewGesture) {
        // Skip repeating gesture
        self.cameraViewGesture = gesture;
        [self _scheduleCheckDelayed:NO];
    }
}

@end
