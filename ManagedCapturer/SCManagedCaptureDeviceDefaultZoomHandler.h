//
//  SCManagedCaptureDeviceDefaultZoomHandler.h
//  Snapchat
//
//  Created by Yu-Kuan Lai on 4/12/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <SCBase/SCMacros.h>

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class SCManagedCaptureDevice;
@class SCCaptureResource;

@interface SCManagedCaptureDeviceDefaultZoomHandler : NSObject

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource;

- (void)setZoomFactor:(CGFloat)zoomFactor forDevice:(SCManagedCaptureDevice *)device immediately:(BOOL)immediately;
- (void)softwareZoomWithDevice:(SCManagedCaptureDevice *)device;

@end
