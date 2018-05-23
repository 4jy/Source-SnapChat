//
//  SCLongPressGestureRecognizer.h
//  SCCamera
//
//  Created by Pavlo Antonenko on 4/28/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

// gesture recognizer cancels, if user moved finger more then defined value, even if long press started, unlike
// UILongPressGestureRecognizer. But if user haven't moved finger for defined time, unlimited movement is allowed.
@interface SCLongPressGestureRecognizer : UILongPressGestureRecognizer

@property (nonatomic, assign) CGFloat allowableMovementAfterBegan;
@property (nonatomic, assign) CGFloat timeBeforeUnlimitedMovementAllowed;
@property (nonatomic, assign, readonly) CGFloat forceOfAllTouches;
@property (nonatomic, assign, readonly) CGFloat maximumPossibleForceOfAllTouches;
@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, assign) BOOL failedByMovement;

- (BOOL)isUnlimitedMovementAllowed;

@end
