//
//  SCBlackCameraReporter.h
//  Snapchat
//
//  Created by Derek Wang on 09/01/2018.
//

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SCBlackCameraCause) {
    SCBlackCameraStartRunningNotCalled,       // 1. View is visible, but session startRunning is not called
    SCBlackCameraSessionNotRunning,           // 2. Session startRunning is called, but isRunning is still false
    SCBlackCameraRenderingPaused,             // 3.1 View is visible, but capture preview rendering is paused
    SCBlackCameraPreviewIsHidden,             // 3.2 For non-metal devices, capture preview is hidden
    SCBlackCameraSessionStartRunningBlocked,  // 4.1 AVCaptureSession is blocked at startRunning
    SCBlackCameraSessionConfigurationBlocked, // 4.2 AVCaptureSession is blocked at commitConfiguration

    SCBlackCameraNoOutputData, // 5. Session is running, but no data output
};

@protocol SCManiphestTicketCreator;

@interface SCBlackCameraReporter : NSObject

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithTicketCreator:(id<SCManiphestTicketCreator>)ticketCreator;

- (NSString *)causeNameFor:(SCBlackCameraCause)cause;

- (void)reportBlackCameraWithCause:(SCBlackCameraCause)cause;
- (void)fileShakeTicketWithCause:(SCBlackCameraCause)cause;

@end
