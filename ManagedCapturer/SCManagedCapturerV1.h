//
//  SCManagedCapturer.h
//  Snapchat
//
//  Created by Liu Liu on 4/20/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCCaptureCommon.h"
#import "SCCapturer.h"

#import <SCFoundation/SCTraceODPCompatible.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

/**
 * Manage AVCaptureSession with SCManagedCapturerV1
 *
 * In phantom, there are a lot of places we use AVCaptureSession. However, since for each app, only one session
 * can run at the same time, we need some kind of management for the capture session.
 *
 * SCManagedCapturerV1 manages the state of capture session in following ways:
 *
 * All operations in SCManagedCapturerV1 are handled on a serial queue, to ensure its sequence. All callbacks (either
 * on the listener or the completion handler) are on the main thread. The state of SCManagedCapturerV1 are conveniently
 * maintained in a SCManagedCapturerState object, which is immutable and can be passed across threads, it mains a
 * consistent view of the capture session, if it is not delayed (thus, the state may deliver as current active device
 * is back camera on main thread, but in reality, on the serial queue, the active device switched to the front camera
 * already. However, this is OK because state.devicePosition will be back camera and with all its setup at that time.
 * Note that it is impossible to have an on-time view of the state across threads without blocking each other).
 *
 * For main use cases, you setup the capturer, add the preview layer, and then can call capture still image
 * or record video, and SCManagedCapturerV1 will do the rest (make sure it actually captures image / video, recover
 * from error, or setup our more advanced image / video post-process).
 *
 * The key classes that drive the recording flow are SCManagedVideoStreamer and SCManagedVideoFileStreamer which
 * conform to SCManagedVideoDataSource. They will stream images to consumers conforming to
 * SCManagedVideoDataSourceListener
 * such as SCManagedLensesProcessor, SCManagedDeviceCapacityAnalyzer, SCManagedVideoScanner and ultimately
 * SCManagedVideoCapturer and SCManagedStillImageCapturer which record the final output.
 *
 */
@class SCCaptureResource;

extern NSString *const kSCLensesTweaksDidChangeFileInput;

@interface SCManagedCapturerV1 : NSObject <SCCapturer, SCTimeProfilable>

+ (SCManagedCapturerV1 *)sharedInstance;

/*
 The following APIs are reserved to be only used for SCCaptureCore aka managedCapturerV2.
 */
- (instancetype)initWithResource:(SCCaptureResource *)resource;

@end
