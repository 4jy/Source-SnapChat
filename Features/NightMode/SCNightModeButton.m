//
//  SCNightModeButton.m
//  SCCamera
//
//  Created by Liu Liu on 3/19/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCNightModeButton.h"

#import <SCFoundation/SCAssertWrapper.h>

static NSTimeInterval const kSCNightModeButtonHiddenDelay = 2.5;

@implementation SCNightModeButton {
    dispatch_block_t _delayedHideBlock;
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.image = [UIImage imageNamed:@"camera_nightmode_off_v10"];
        self.imageInset = CGSizeMake((CGRectGetWidth(self.bounds) - self.image.size.width) / 2,
                                     (CGRectGetHeight(self.bounds) - self.image.size.height) / 2);
    }
    return self;
}

- (void)setSelected:(BOOL)selected
{
    SC_GUARD_ELSE_RETURN(_selected != selected);
    if (selected) {
        [self _cancelDelayedHideAnimation];
        self.image = [UIImage imageNamed:@"camera_nightmode_on_v10"];
    } else {
        self.image = [UIImage imageNamed:@"camera_nightmode_off_v10"];
    }
    self.imageInset = CGSizeMake((CGRectGetWidth(self.bounds) - self.image.size.width) / 2,
                                 (CGRectGetHeight(self.bounds) - self.image.size.height) / 2);
    _selected = selected;
}

- (void)show
{
    SC_GUARD_ELSE_RETURN(self.hidden);
    SCAssertMainThread();
    [self _cancelDelayedHideAnimation];
    self.hidden = NO;
    [self animate];
}

- (void)hideWithDelay:(BOOL)delay
{
    SC_GUARD_ELSE_RETURN(!self.hidden);
    SCAssertMainThread();
    [self _cancelDelayedHideAnimation];
    if (delay) {
        @weakify(self);
        _delayedHideBlock = dispatch_block_create(0, ^{
            @strongify(self);
            SC_GUARD_ELSE_RETURN(self);
            [UIView animateWithDuration:0.3
                animations:^{
                    self.alpha = 0;
                }
                completion:^(BOOL finished) {
                    self.alpha = 1;
                    self.hidden = YES;
                    _delayedHideBlock = nil;
                }];
        });
        dispatch_time_t delayTime =
            dispatch_time(DISPATCH_TIME_NOW, (int64_t)(kSCNightModeButtonHiddenDelay * NSEC_PER_SEC));
        dispatch_after(delayTime, dispatch_get_main_queue(), _delayedHideBlock);
    } else {
        self.hidden = YES;
    }
}

- (BOOL)willHideAfterDelay
{
    return _delayedHideBlock != nil;
}

#pragma mark - Private

- (void)_cancelDelayedHideAnimation
{
    SC_GUARD_ELSE_RETURN(_delayedHideBlock);
    dispatch_cancel(_delayedHideBlock);
    _delayedHideBlock = nil;
}

@end
