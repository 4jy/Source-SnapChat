//
//  SCLongPressGestureRecognizer.m
//  SCCamera
//
//  Created by Pavlo Antonenko on 4/28/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCLongPressGestureRecognizer.h"

#import <SCFoundation/SCLog.h>

#import <UIKit/UIGestureRecognizerSubclass.h>

@implementation SCLongPressGestureRecognizer {
    CGPoint _initialPoint;
    CGFloat _initialTime;
}

- (instancetype)initWithTarget:(id)target action:(SEL)action
{
    self = [super initWithTarget:target action:action];
    if (self) {
        _allowableMovementAfterBegan = FLT_MAX;
        _timeBeforeUnlimitedMovementAllowed = 0.0;
    }
    return self;
}

- (void)reset
{
    [super reset];
    _initialPoint = CGPointZero;
    _initialTime = 0;
    _forceOfAllTouches = 1.0;
    _maximumPossibleForceOfAllTouches = 1.0;
    self.failedByMovement = NO;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    _initialPoint = [self locationInView:self.view];
    _initialTime = CACurrentMediaTime();
    _forceOfAllTouches = 1.0;
    for (UITouch *touch in touches) {
        _maximumPossibleForceOfAllTouches = MAX(touch.maximumPossibleForce, _maximumPossibleForceOfAllTouches);
        _forceOfAllTouches = MAX(touch.force, _forceOfAllTouches);
    }
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesMoved:touches withEvent:event];

    _forceOfAllTouches = 1.0;
    for (UITouch *touch in touches) {
        _maximumPossibleForceOfAllTouches = MAX(touch.maximumPossibleForce, _maximumPossibleForceOfAllTouches);
        _forceOfAllTouches = MAX(touch.force, _forceOfAllTouches);
    }

    if (!CGPointEqualToPoint(_initialPoint, CGPointZero)) {
        CGPoint currentPoint = [self locationInView:self.view];

        CGFloat distance = hypot(_initialPoint.x - currentPoint.x, _initialPoint.y - currentPoint.y);
        CGFloat timeDifference = CACurrentMediaTime() - _initialTime;

        if (distance > self.allowableMovementAfterBegan && timeDifference < self.timeBeforeUnlimitedMovementAllowed) {
            SCLogGeneralInfo(@"Long press moved %.2f > %.2f after %.3f < %.3f seconds, and is cancelled", distance,
                             self.allowableMovementAfterBegan, timeDifference, self.timeBeforeUnlimitedMovementAllowed);
            self.state = UIGestureRecognizerStateFailed;
            self.failedByMovement = YES;
        }
    }
}

- (void)setEnabled:(BOOL)enabled
{
    SCLogGeneralInfo(@"Setting enabled: %d for %@", enabled, self);
    [super setEnabled:enabled];
}

- (BOOL)isUnlimitedMovementAllowed
{
    return CACurrentMediaTime() - _initialTime > self.timeBeforeUnlimitedMovementAllowed;
}

@end
