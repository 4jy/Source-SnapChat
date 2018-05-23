//
//  SCFlashButton.m
//  SCCamera
//
//  Created by Will Wu on 2/13/14.
//  Copyright (c) 2014 Snapchat, Inc. All rights reserved.
//

#import "SCFlashButton.h"

#import <SCUIKit/SCPixelRounding.h>

@implementation SCFlashButton

- (void)setButtonState:(SCFlashButtonState)buttonState
{
    // Don't reset flash button state if it doesn't change.
    if (_buttonState == buttonState) {
        return;
    }
    _buttonState = buttonState;

    if (buttonState == SCFlashButtonStateOn) {
        self.image = [UIImage imageNamed:@"camera_flash_on_v10"];
        self.accessibilityValue = @"on";
    } else {
        self.image = [UIImage imageNamed:@"camera_flash_off_v10"];
        self.accessibilityValue = @"off";
    }

    self.imageInset = SCRoundSizeToPixels(CGSizeMake((CGRectGetWidth(self.bounds) - self.image.size.width) / 2,
                                                     (CGRectGetHeight(self.bounds) - self.image.size.height) / 2));
}

@end
