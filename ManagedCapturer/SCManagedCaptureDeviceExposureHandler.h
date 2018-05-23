//
//  SCManagedCaptureDeviceExposureHandler.h
//  Snapchat
//
//  Created by Derek Peirce on 3/21/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@protocol SCManagedCaptureDeviceExposureHandler <NSObject>

- (CGPoint)getExposurePointOfInterest;

- (void)setStableExposure:(BOOL)stableExposure;

- (void)setExposurePointOfInterest:(CGPoint)pointOfInterest fromUser:(BOOL)fromUser;

- (void)setVisible:(BOOL)visible;

@end
