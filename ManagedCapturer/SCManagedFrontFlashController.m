//
//  SCManagedFrontFlashController.m
//  Snapchat
//
//  Created by Liu Liu on 5/4/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedFrontFlashController.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTrace.h>

@import UIKit;

@implementation SCManagedFrontFlashController {
    BOOL _active;
    UIView *_brightView;
    CGFloat _brightnessWhenFlashAndTorchOff;
}

- (void)_setScreenWithFrontViewFlashActive:(BOOL)flashActive torchActive:(BOOL)torchActive
{
    SCTraceStart();
    SCAssertMainThread();
    BOOL wasActive = _active;
    _active = flashActive || torchActive;
    if (!wasActive && _active) {
        [self _activateFlash:flashActive];
    } else if (wasActive && !_active) {
        [self _deactivateFlash];
    }
}

- (void)_activateFlash:(BOOL)flashActive
{
    UIWindow *mainWindow = [[UIApplication sharedApplication] keyWindow];
    if (!_brightView) {
        CGRect frame = [mainWindow bounds];
        CGFloat maxLength = MAX(CGRectGetWidth(frame), CGRectGetHeight(frame));
        frame.size = CGSizeMake(maxLength, maxLength);
        // Using the max length on either side to be compatible with different orientations
        _brightView = [[UIView alloc] initWithFrame:frame];
        _brightView.userInteractionEnabled = NO;
        _brightView.backgroundColor = [UIColor whiteColor];
    }
    _brightnessWhenFlashAndTorchOff = [UIScreen mainScreen].brightness;
    SCLogGeneralInfo(@"[SCManagedFrontFlashController] Activating flash, setting screen brightness from %f to 1.0",
                     _brightnessWhenFlashAndTorchOff);
    [self _brightenLoop];
    _brightView.alpha = flashActive ? 1.0 : 0.75;
    [mainWindow addSubview:_brightView];
}

- (void)_deactivateFlash
{
    SCLogGeneralInfo(@"[SCManagedFrontFlashController] Deactivating flash, setting screen brightness from %f to %f",
                     [UIScreen mainScreen].brightness, _brightnessWhenFlashAndTorchOff);
    [UIScreen mainScreen].brightness = _brightnessWhenFlashAndTorchOff;
    if (_brightView) {
        [_brightView removeFromSuperview];
    }
}

- (void)_brightenLoop
{
    if (_active) {
        SCLogGeneralInfo(@"[SCManagedFrontFlashController] In brighten loop, setting brightness from %f to 1.0",
                         [UIScreen mainScreen].brightness);
        [UIScreen mainScreen].brightness = 1.0;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^(void) {
            [self _brightenLoop];
        });
    } else {
        SCLogGeneralInfo(@"[SCManagedFrontFlashController] Recording is done, brighten loop ends");
    }
}

- (void)setFlashActive:(BOOL)flashActive
{
    SCTraceStart();
    if (_flashActive != flashActive) {
        _flashActive = flashActive;
        BOOL torchActive = _torchActive;
        runOnMainThreadAsynchronously(^{
            [self _setScreenWithFrontViewFlashActive:flashActive torchActive:torchActive];
        });
    }
}

- (void)setTorchActive:(BOOL)torchActive
{
    SCTraceStart();
    if (_torchActive != torchActive) {
        _torchActive = torchActive;
        BOOL flashActive = _flashActive;
        runOnMainThreadAsynchronously(^{
            [self _setScreenWithFrontViewFlashActive:flashActive torchActive:torchActive];
        });
    }
}

@end
