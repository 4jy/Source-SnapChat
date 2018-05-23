//
//  SCFlashButton.h
//  SCCamera
//
//  Created by Will Wu on 2/13/14.
//  Copyright (c) 2014 Snapchat, Inc. All rights reserved.
//

#import <SCUIKit/SCGrowingButton.h>

typedef NS_ENUM(NSInteger, SCFlashButtonState) { SCFlashButtonStateOn = 0, SCFlashButtonStateOff = 1 };

@interface SCFlashButton : SCGrowingButton
@property (nonatomic, assign) SCFlashButtonState buttonState;
@end
