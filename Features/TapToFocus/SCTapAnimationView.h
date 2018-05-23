//
//  SCTapAnimationView.h
//  SCCamera
//
//  Created by Alexander Grytsiuk on 8/26/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class SCTapAnimationView;

typedef void (^SCTapAnimationViewCompletion)(SCTapAnimationView *);

@interface SCTapAnimationView : UIView

+ (instancetype)tapAnimationView;

- (void)showWithCompletion:(SCTapAnimationViewCompletion)completion;

@end
