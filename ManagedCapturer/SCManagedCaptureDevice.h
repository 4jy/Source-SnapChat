//
//  SCManagedCaptureDevice.h
//  Snapchat
//
//  Created by Liu Liu on 4/22/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import <SCCameraFoundation/SCManagedCaptureDevicePosition.h>
#import <SCCameraFoundation/SCManagedCaptureDeviceProtocol.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

extern CGFloat const kSCMaxVideoZoomFactor;
extern CGFloat const kSCMinVideoZoomFactor;

@class SCManagedCaptureDevice;

@protocol SCManagedCaptureDeviceDelegate <NSObject>

@optional
- (void)managedCaptureDevice:(SCManagedCaptureDevice *)device didChangeAdjustingExposure:(BOOL)adjustingExposure;
- (void)managedCaptureDevice:(SCManagedCaptureDevice *)device didChangeExposurePoint:(CGPoint)exposurePoint;
- (void)managedCaptureDevice:(SCManagedCaptureDevice *)device didChangeFocusPoint:(CGPoint)focusPoint;

@end

@interface SCManagedCaptureDevice : NSObject <SCManagedCaptureDeviceProtocol>

@property (nonatomic, weak) id<SCManagedCaptureDeviceDelegate> delegate;

// These two class methods are thread safe
+ (instancetype)front;

+ (instancetype)back;

+ (instancetype)dualCamera;

+ (instancetype)deviceWithPosition:(SCManagedCaptureDevicePosition)position;

+ (BOOL)is1080pSupported;

+ (BOOL)isMixCaptureSupported;

+ (BOOL)isNightModeSupported;

+ (BOOL)isEnhancedNightModeSupported;

+ (CGSize)defaultActiveFormatResolution;

+ (CGSize)nightModeActiveFormatResolution;

- (BOOL)softwareZoom;

- (SCManagedCaptureDevicePosition)position;

- (BOOL)isAvailable;

@end
