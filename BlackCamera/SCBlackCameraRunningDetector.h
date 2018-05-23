//
//  SCBlackCameraRunningDetector.h
//  Snapchat
//
//  Created by Derek Wang on 30/01/2018.
//

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

@class SCQueuePerformer, SCBlackCameraReporter;
@protocol SCManiphestTicketCreator;

@interface SCBlackCameraRunningDetector : NSObject

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithPerformer:(SCQueuePerformer *)performer reporter:(SCBlackCameraReporter *)reporter;

// When session isRunning changed
- (void)sessionDidChangeIsRunning:(BOOL)running;
// Call this after [AVCaptureSession startRunning] is called
- (void)sessionDidCallStartRunning;
// Call this before [AVCaptureSession stopRunning] is called
- (void)sessionWillCallStopRunning;

@end
