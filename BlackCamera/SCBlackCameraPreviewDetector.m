//
//  SCBlackCameraPreviewDetector.m
//  Snapchat
//
//  Created by Derek Wang on 25/01/2018.
//

#import "SCBlackCameraPreviewDetector.h"

#import "SCBlackCameraReporter.h"
#import "SCMetalUtils.h"

#import <SCCrashLogger/SCCrashLogger.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>

// Check whether preview is visible when AVCaptureSession is running
static CGFloat const kSCBlackCameraCheckingDelay = 0.5;

@interface SCBlackCameraPreviewDetector () {
    BOOL _previewVisible;
    dispatch_block_t _checkingBlock;
}
@property (nonatomic) SCQueuePerformer *queuePerformer;
@property (nonatomic) SCBlackCameraReporter *reporter;

@end

@implementation SCBlackCameraPreviewDetector

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer reporter:(SCBlackCameraReporter *)reporter
{
    self = [super init];
    if (self) {
        _queuePerformer = performer;
        _reporter = reporter;
    }
    return self;
}

- (void)capturePreviewDidBecomeVisible:(BOOL)visible
{
    [_queuePerformer perform:^{
        _previewVisible = visible;
    }];
}

- (void)sessionDidChangeIsRunning:(BOOL)running
{
    if (running) {
        [self _scheduleCheck];
    } else {
        [_queuePerformer perform:^{
            if (_checkingBlock) {
                dispatch_block_cancel(_checkingBlock);
                _checkingBlock = nil;
            }
        }];
    }
}

- (void)_scheduleCheck
{
    [_queuePerformer perform:^{
        @weakify(self);
        _checkingBlock = dispatch_block_create(0, ^{
            @strongify(self);
            SC_GUARD_ELSE_RETURN(self);
            self->_checkingBlock = nil;
            [self _checkPreviewState];
        });
        [_queuePerformer perform:_checkingBlock after:kSCBlackCameraCheckingDelay];
    }];
}

- (void)_checkPreviewState
{
    if (!_previewVisible) {
        runOnMainThreadAsynchronously(^{
            // Make sure the app is in foreground
            SC_GUARD_ELSE_RETURN([UIApplication sharedApplication].applicationState == UIApplicationStateActive);

            SCBlackCameraCause cause =
                SCDeviceSupportsMetal() ? SCBlackCameraRenderingPaused : SCBlackCameraPreviewIsHidden;
            [_reporter reportBlackCameraWithCause:cause];
            [_reporter fileShakeTicketWithCause:cause];
        });
    }
}

@end
