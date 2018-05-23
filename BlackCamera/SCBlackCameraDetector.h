//
//  SCBlackCameraDetector.h
//  Snapchat
//
//  Created by Derek Wang on 24/01/2018.
//

#import "SCBlackCameraReporter.h"

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SCBlackCameraNoOutputDetector;

@interface SCBlackCameraDetector : NSObject

@property (nonatomic, strong) SCBlackCameraNoOutputDetector *blackCameraNoOutputDetector;

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithTicketCreator:(id<SCManiphestTicketCreator>)ticketCreator;

// CameraView visible/invisible
- (void)onCameraViewVisible:(BOOL)visible;

- (void)onCameraViewVisibleWithTouch:(UIGestureRecognizer *)touch;

// Call this when [AVCaptureSession startRunning] is called
- (void)sessionWillCallStartRunning;
- (void)sessionDidCallStartRunning;

// Call this when [AVCaptureSession stopRunning] is called
- (void)sessionWillCallStopRunning;
- (void)sessionDidCallStopRunning;

// Call this when [AVCaptureSession commitConfiguration] is called
- (void)sessionWillCommitConfiguration;
- (void)sessionDidCommitConfiguration;

- (void)sessionDidChangeIsRunning:(BOOL)running;

// For CapturePreview visibility detector
- (void)capturePreviewDidBecomeVisible:(BOOL)visible;

/**
 Mark the start of creating new session
 When we fix black camera by creating new session, some detector may report black camera because we called
 [AVCaptureSession stopRunning] on old AVCaptureSession, so we need to tell the detector the session is recreating, so
 it is fine to call [AVCaptureSession stopRunning] on old AVCaptureSession.
 */
- (void)sessionWillRecreate;
/**
 Mark the end of creating new session
 */
- (void)sessionDidRecreate;

@end
