//
//  SCNightModeButton.h
//  SCCamera
//
//  Created by Liu Liu on 3/19/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <SCBase/SCMacros.h>
#import <SCUIKit/SCGrowingButton.h>

@interface SCNightModeButton : SCGrowingButton
@property (nonatomic, assign, getter=isSelected) BOOL selected;
SC_INIT_AND_NEW_UNAVAILABLE
- (void)show;
- (void)hideWithDelay:(BOOL)delay;
- (BOOL)willHideAfterDelay;
@end
