//
//  SCManagedCapturePreviewLayerController.h
//  Snapchat
//
//  Created by Liu Liu on 5/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <SCCameraFoundation/SCManagedVideoDataSource.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCGhostToSnappable/SCGhostToSnappableSignal.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <UIKit/UIKit.h>

@protocol SCCapturer;
@class LSAGLView, SCBlackCameraDetector, SCManagedCapturePreviewLayerController;

@protocol SCManagedCapturePreviewLayerControllerDelegate

- (SCBlackCameraDetector *)blackCameraDetectorForManagedCapturePreviewLayerController:
    (SCManagedCapturePreviewLayerController *)controller;
- (sc_create_g2s_ticket_f)g2sTicketForManagedCapturePreviewLayerController:
    (SCManagedCapturePreviewLayerController *)controller;

@end

/**
 * SCManagedCapturePreviewLayerController controls display of frame in a view. The controller has 3
 * different methods for this.
 * AVCaptureVideoPreviewLayer: This is a feed coming straight from the camera and does not allow any
 * image processing or modification of the frames displayed.
 * LSAGLView: OpenGL based video for displaying video that is being processed (Lenses etc.)
 * CAMetalLayer: Metal layer drawing textures on a vertex quad for display on screen.
 */
@interface SCManagedCapturePreviewLayerController : NSObject <SCManagedSampleBufferDisplayController>

@property (nonatomic, strong, readonly) UIView *view;

@property (nonatomic, strong, readonly) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic, strong, readonly) LSAGLView *videoPreviewGLView;

@property (nonatomic, weak) id<SCManagedCapturePreviewLayerControllerDelegate> delegate;

+ (instancetype)sharedInstance;

- (void)pause;

- (void)resume;

- (UIView *)newStandInViewWithRect:(CGRect)rect;

- (void)setManagedCapturer:(id<SCCapturer>)managedCapturer;

// This method returns a token that you can hold on to. As long as the token is hold,
// an outdated view will be hold unless the app backgrounded.
- (NSString *)keepDisplayingOutdatedPreview;

// End displaying the outdated frame with an issued keep token. If there is no one holds
// any token any more, this outdated view will be flushed.
- (void)endDisplayingOutdatedPreview:(NSString *)keepToken;

// Create views for Metal, this method need to be called on the main thread.
- (void)setupPreviewLayer;

// Create render pipeline state, setup shaders for Metal, this need to be called off the main thread.
- (void)setupRenderPipeline;

- (void)applicationDidEnterBackground;

- (void)applicationWillEnterForeground;

- (void)applicationWillResignActive;

- (void)applicationDidBecomeActive;

@end
