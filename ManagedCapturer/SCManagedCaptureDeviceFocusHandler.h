//
//  SCManagedCaptureDeviceFocusHandler.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/7/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@protocol SCManagedCaptureDeviceFocusHandler <NSObject>

- (CGPoint)getFocusPointOfInterest;

/// Called when subject area changes.
- (void)continuousAutofocus;

/// Called when user taps.
- (void)setAutofocusPointOfInterest:(CGPoint)pointOfInterest;

- (void)setSmoothFocus:(BOOL)smoothFocus;

- (void)setFocusLock:(BOOL)focusLock;

- (void)setVisible:(BOOL)visible;

@end
