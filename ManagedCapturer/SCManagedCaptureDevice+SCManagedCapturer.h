//
//  SCManagedCaptureDevice+SCManagedCapturer.h
//  Snapchat
//
//  Created by Liu Liu on 5/9/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDevice.h"

#import <AVFoundation/AVFoundation.h>

@interface SCManagedCaptureDevice (SCManagedCapturer)

@property (nonatomic, strong, readonly) AVCaptureDevice *device;

@property (nonatomic, strong, readonly) AVCaptureDeviceInput *deviceInput;

@property (nonatomic, copy, readonly) NSError *error;

@property (nonatomic, assign, readonly) BOOL isConnected;

@property (nonatomic, strong, readonly) AVCaptureDeviceFormat *activeFormat;

// Setup and hook up with device

- (BOOL)setDeviceAsInput:(AVCaptureSession *)session;

- (void)removeDeviceAsInput:(AVCaptureSession *)session;

- (void)resetDeviceAsInput;

// Configurations

@property (nonatomic, assign) BOOL flashActive;

@property (nonatomic, assign) BOOL torchActive;

@property (nonatomic, assign) float zoomFactor;

@property (nonatomic, assign, readonly) BOOL liveVideoStreamingActive;

@property (nonatomic, assign, readonly) BOOL isNightModeActive;

@property (nonatomic, assign, readonly) BOOL isFlashSupported;

@property (nonatomic, assign, readonly) BOOL isTorchSupported;

- (void)setNightModeActive:(BOOL)nightModeActive session:(AVCaptureSession *)session;

- (void)setLiveVideoStreaming:(BOOL)liveVideoStreaming session:(AVCaptureSession *)session;

- (void)setCaptureDepthData:(BOOL)captureDepthData session:(AVCaptureSession *)session;

- (void)setExposurePointOfInterest:(CGPoint)pointOfInterest fromUser:(BOOL)fromUser;

- (void)setAutofocusPointOfInterest:(CGPoint)pointOfInterest;

- (void)continuousAutofocus;

- (void)setRecording:(BOOL)recording;

- (void)updateActiveFormatWithSession:(AVCaptureSession *)session;

// Utilities

- (CGPoint)convertViewCoordinates:(CGPoint)viewCoordinates
                         viewSize:(CGSize)viewSize
                     videoGravity:(NSString *)videoGravity;

@end
