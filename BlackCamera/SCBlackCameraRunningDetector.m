//
//  SCBlackCameraRunningDetector.m
//  Snapchat
//
//  Created by Derek Wang on 30/01/2018.
//

#import "SCBlackCameraRunningDetector.h"

#import "SCBlackCameraReporter.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCLogger/SCCameraMetrics.h>

// Check whether we called AVCaptureSession isRunning within this period
static CGFloat const kSCBlackCameraCheckingDelay = 5;

@interface SCBlackCameraRunningDetector () {
    BOOL _isSessionRunning;
    dispatch_block_t _checkSessionBlock;
}
@property (nonatomic) SCQueuePerformer *queuePerformer;
@property (nonatomic) SCBlackCameraReporter *reporter;
@end

@implementation SCBlackCameraRunningDetector

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer reporter:(SCBlackCameraReporter *)reporter
{
    self = [super init];
    if (self) {
        _queuePerformer = performer;
        _reporter = reporter;
    }
    return self;
}

- (void)sessionDidChangeIsRunning:(BOOL)running
{
    [_queuePerformer perform:^{
        _isSessionRunning = running;
    }];
}

- (void)sessionDidCallStartRunning
{
    [self _scheduleCheck];
}

- (void)sessionWillCallStopRunning
{
    [_queuePerformer perform:^{
        if (_checkSessionBlock) {
            dispatch_block_cancel(_checkSessionBlock);
            _checkSessionBlock = nil;
        }
    }];
}

- (void)_scheduleCheck
{
    [_queuePerformer perform:^{
        @weakify(self);
        _checkSessionBlock = dispatch_block_create(0, ^{
            @strongify(self);
            SC_GUARD_ELSE_RETURN(self);
            self->_checkSessionBlock = nil;
            [self _checkSessionState];
        });

        [_queuePerformer perform:_checkSessionBlock after:kSCBlackCameraCheckingDelay];
    }];
}

- (void)_checkSessionState
{
    if (!_isSessionRunning) {
        [_reporter reportBlackCameraWithCause:SCBlackCameraSessionNotRunning];
    }
}

@end
