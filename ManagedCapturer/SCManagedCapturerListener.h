//#!announcer.rb
//
//  SCManagedCaptuerListener
//  Snapchat
//
//  Created by Liu Liu on 4/23/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCCapturer.h"
#import "SCManagedCaptureDevice.h"
#import "SCManagedRecordedVideo.h"
#import "SCVideoCaptureSessionInfo.h"

#import <SCFoundation/SCFuture.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class SCManagedCapturer;
@class SCManagedCapturerState;
@class LSAGLView;
@class SCManagedCapturerSampleMetadata;

@protocol SCManagedCapturerListener <NSObject>

@optional

// All these calbacks are invoked on main queue

// Start / stop / reset

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didStartRunning:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didStopRunning:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didResetFromRuntimeError:(SCManagedCapturerState *)state;

// Change state methods

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeState:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeNightModeActive:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangePortraitModeActive:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeFlashActive:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeLensesActive:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeARSessionActive:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didChangeFlashSupportedAndTorchSupported:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeZoomFactor:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeLowLightCondition:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeAdjustingExposure:(SCManagedCapturerState *)state;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeCaptureDevicePosition:(SCManagedCapturerState *)state;

// The video preview layer is not maintained as a state, therefore, its change is not related to the state of
// the camera at all, listener show only manage the setup of the videoPreviewLayer.
// Since the AVCaptureVideoPreviewLayer can only attach to one AVCaptureSession per app, it is recommended you
// have a view and controller which manages the video preview layer, and for upper layer, only manage that view
// or view controller, which maintains the pointer consistency. The video preview layer is required to recreate
// every now and then because otherwise we will have cases that the old video preview layer may contain
// residual images.

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didChangeVideoPreviewLayer:(AVCaptureVideoPreviewLayer *)videoPreviewLayer;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeVideoPreviewGLView:(LSAGLView *)videoPreviewGLView;

// Video recording-related methods

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
 didBeginVideoRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
 didBeginAudioRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    willFinishRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session
    recordedVideoFuture:(SCFuture<id<SCManagedRecordedVideo>> *)recordedVideoFuture
              videoSize:(CGSize)videoSize
       placeholderImage:(UIImage *)placeholderImage;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
     didFinishRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session
          recordedVideo:(SCManagedRecordedVideo *)recordedVideo;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
       didFailRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session
                  error:(NSError *)error;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
     didCancelRecording:(SCManagedCapturerState *)state
                session:(SCVideoCaptureSessionInfo)session;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
            didGetError:(NSError *)error
                forType:(SCManagedVideoCapturerInfoType)type
                session:(SCVideoCaptureSessionInfo)session;

- (void)managedCapturerDidCallLenseResume:(id<SCCapturer>)managedCapturer session:(SCVideoCaptureSessionInfo)session;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didAppendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
                sampleMetadata:(SCManagedCapturerSampleMetadata *)sampleMetadata;

// Photo methods
- (void)managedCapturer:(id<SCCapturer>)managedCapturer
       willCapturePhoto:(SCManagedCapturerState *)state
         sampleMetadata:(SCManagedCapturerSampleMetadata *)sampleMetadata;

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didCapturePhoto:(SCManagedCapturerState *)state;

- (BOOL)managedCapturer:(id<SCCapturer>)managedCapturer isUnderDeviceMotion:(SCManagedCapturerState *)state;

- (BOOL)managedCapturer:(id<SCCapturer>)managedCapturer shouldProcessFileInput:(SCManagedCapturerState *)state;

// Face detection
- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didDetectFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID;
- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeExposurePoint:(CGPoint)exposurePoint;
- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeFocusPoint:(CGPoint)focusPoint;
@end
