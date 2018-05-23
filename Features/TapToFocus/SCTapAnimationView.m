//
//  SCTapAnimationView.m
//  SCCamera
//
//  Created by Alexander Grytsiuk on 8/26/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCTapAnimationView.h"

#import <SCBase/SCMacros.h>

@import QuartzCore;

static const CGFloat kSCAnimationStep = 0.167;
static const CGFloat kSCInnerCirclePadding = 2.5;
static const CGFloat kSCTapAnimationViewWidth = 55;
static const CGFloat kSCOuterRingBorderWidth = 1;

static NSString *const kSCOpacityAnimationKey = @"opacity";
static NSString *const kSCScaleAnimationKey = @"scale";

@implementation SCTapAnimationView {
    CALayer *_outerRing;
    CALayer *_innerCircle;
}

#pragma mark Class Methods

+ (instancetype)tapAnimationView
{
    return [[self alloc] initWithFrame:CGRectMake(0, 0, kSCTapAnimationViewWidth, kSCTapAnimationViewWidth)];
}

#pragma mark Life Cycle

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        _outerRing = [CALayer layer];
        _outerRing.backgroundColor = [UIColor clearColor].CGColor;
        _outerRing.borderColor = [UIColor whiteColor].CGColor;
        _outerRing.borderWidth = kSCOuterRingBorderWidth;
        _outerRing.shadowColor = [UIColor blackColor].CGColor;
        _outerRing.shadowOpacity = 0.4;
        _outerRing.shadowOffset = CGSizeMake(0.5, 0.5);
        _outerRing.opacity = 0.0;
        _outerRing.frame = self.bounds;
        _outerRing.cornerRadius = CGRectGetMidX(_outerRing.bounds);
        [self.layer addSublayer:_outerRing];

        _innerCircle = [CALayer layer];
        _innerCircle.backgroundColor = [UIColor whiteColor].CGColor;
        _innerCircle.opacity = 0.0;
        _innerCircle.frame = CGRectInset(self.bounds, kSCInnerCirclePadding, kSCInnerCirclePadding);
        _innerCircle.cornerRadius = CGRectGetMidX(_innerCircle.bounds);
        [self.layer addSublayer:_innerCircle];
    }
    return self;
}

#pragma mark Public

- (void)showWithCompletion:(SCTapAnimationViewCompletion)completion
{
    [_outerRing removeAllAnimations];
    [_innerCircle removeAllAnimations];

    [CATransaction begin];
    [CATransaction setCompletionBlock:^{
        if (completion) {
            completion(self);
        }
    }];
    [self addOuterRingOpacityAnimation];
    [self addOuterRingScaleAnimation];
    [self addInnerCircleOpacityAnimation];
    [self addInnerCircleScaleAnimation];
    [CATransaction commit];
}

#pragma mark Private

- (CAKeyframeAnimation *)keyFrameAnimationWithKeyPath:(NSString *)keyPath
                                             duration:(CGFloat)duration
                                               values:(NSArray *)values
                                             keyTimes:(NSArray *)keyTimes
                                      timingFunctions:(NSArray *)timingFunctions
{
    CAKeyframeAnimation *keyframeAnimation = [CAKeyframeAnimation animationWithKeyPath:keyPath];
    keyframeAnimation.duration = duration;
    keyframeAnimation.values = values;
    keyframeAnimation.keyTimes = keyTimes;
    keyframeAnimation.timingFunctions = timingFunctions;
    keyframeAnimation.fillMode = kCAFillModeForwards;
    keyframeAnimation.removedOnCompletion = NO;

    return keyframeAnimation;
}

- (CABasicAnimation *)animationWithKeyPath:(NSString *)keyPath
                                  duration:(CGFloat)duration
                                 fromValue:(NSValue *)fromValue
                                   toValue:(NSValue *)toValue
                            timingFunction:(CAMediaTimingFunction *)timingFunction
{
    CABasicAnimation *animation = [CABasicAnimation animationWithKeyPath:keyPath];
    animation.duration = duration;
    animation.fromValue = fromValue;
    animation.toValue = toValue;
    animation.timingFunction = timingFunction;
    animation.fillMode = kCAFillModeForwards;
    animation.removedOnCompletion = NO;

    return animation;
}

- (void)addOuterRingOpacityAnimation
{
    CAKeyframeAnimation *animation =
        [self keyFrameAnimationWithKeyPath:@keypath(_outerRing, opacity)
                                  duration:kSCAnimationStep * 5
                                    values:@[ @0.0, @1.0, @1.0, @0.0 ]
                                  keyTimes:@[ @0.0, @0.2, @0.8, @1.0 ]
                           timingFunctions:@[
                               [CAMediaTimingFunction functionWithControlPoints:0.0:0.0:0.0:1.0],
                               [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionLinear],
                               [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                           ]];
    [_outerRing addAnimation:animation forKey:kSCOpacityAnimationKey];
}

- (void)addOuterRingScaleAnimation
{
    CAKeyframeAnimation *animation =
        [self keyFrameAnimationWithKeyPath:@keypath(_innerCircle, transform)
                                  duration:kSCAnimationStep * 3
                                    values:@[
                                        [NSValue valueWithCATransform3D:CATransform3DMakeScale(0.50, 0.50, 1.0)],
                                        [NSValue valueWithCATransform3D:CATransform3DIdentity],
                                        [NSValue valueWithCATransform3D:CATransform3DMakeScale(0.83, 0.83, 1.0)],
                                    ]
                                  keyTimes:@[ @0.0, @0.66, @1.0 ]
                           timingFunctions:@[
                               [CAMediaTimingFunction functionWithControlPoints:0.0:0.0:0.0:1.0],
                               [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                           ]];
    [_outerRing addAnimation:animation forKey:kSCScaleAnimationKey];
}

- (void)addInnerCircleOpacityAnimation
{
    CAKeyframeAnimation *animation =
        [self keyFrameAnimationWithKeyPath:@keypath(_innerCircle, opacity)
                                  duration:kSCAnimationStep * 3
                                    values:@[ @0.0, @0.40, @0.0 ]
                                  keyTimes:@[ @0.0, @0.33, @1.0 ]
                           timingFunctions:@[
                               [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn],
                               [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut],
                           ]];
    [_innerCircle addAnimation:animation forKey:kSCOpacityAnimationKey];
}

- (void)addInnerCircleScaleAnimation
{
    CABasicAnimation *animation =
        [self animationWithKeyPath:@keypath(_innerCircle, transform)
                          duration:kSCAnimationStep * 2
                         fromValue:[NSValue valueWithCATransform3D:CATransform3DMakeScale(0.0, 0.0, 1.0)]
                           toValue:[NSValue valueWithCATransform3D:CATransform3DIdentity]
                    timingFunction:[CAMediaTimingFunction functionWithControlPoints:0.0:0.0:0.0:1.0]];
    [_innerCircle addAnimation:animation forKey:kSCScaleAnimationKey];
}

@end
