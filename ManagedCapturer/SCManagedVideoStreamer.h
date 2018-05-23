//
//  SCManagedVideoStreamer.h
//  Snapchat
//
//  Created by Liu Liu on 4/30/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedVideoARDataSource.h"

#import <SCCameraFoundation/SCManagedVideoDataSource.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class ARSession;

/**
 * SCManagedVideoStreamer uses the current AVCaptureSession to create
 * and publish video output frames. SCManagedVideoStreamer also conforms
 * to SCManagedVideoDataSource allowing chained consumption of video frames.
 */
@interface SCManagedVideoStreamer : NSObject <SCManagedVideoDataSource, SCManagedVideoARDataSource>

- (instancetype)initWithSession:(AVCaptureSession *)session
                 devicePosition:(SCManagedCaptureDevicePosition)devicePosition;

- (instancetype)initWithSession:(AVCaptureSession *)session
                      arSession:(ARSession *)arSession
                 devicePosition:(SCManagedCaptureDevicePosition)devicePosition NS_AVAILABLE_IOS(11_0);

- (void)setupWithSession:(AVCaptureSession *)session devicePosition:(SCManagedCaptureDevicePosition)devicePosition;

- (void)setupWithARSession:(ARSession *)arSession NS_AVAILABLE_IOS(11_0);

@end
