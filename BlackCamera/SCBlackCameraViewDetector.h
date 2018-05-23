//
//  SCBlackCameraDetectorCameraView.h
//  Snapchat
//
//  Created by Derek Wang on 24/01/2018.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class SCQueuePerformer, SCBlackCameraReporter;
@protocol SCManiphestTicketCreator;

@interface SCBlackCameraViewDetector : NSObject

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer reporter:(SCBlackCameraReporter *)reporter;

// CameraView visible/invisible
- (void)onCameraViewVisible:(BOOL)visible;

- (void)onCameraViewVisibleWithTouch:(UIGestureRecognizer *)gesture;

// Call this when [AVCaptureSession startRunning] is called
- (void)sessionWillCallStartRunning;
// Call this when [AVCaptureSession stopRunning] is called
- (void)sessionWillCallStopRunning;

- (void)sessionWillRecreate;
- (void)sessionDidRecreate;

@end
