//
//  SCManagedCapturerARSessionHandler.h
//  Snapchat
//
//  Created by Xiaokang Liu on 16/03/2018.
//
// This class is used to handle the AVCaptureSession event when ARSession is enabled.
// The stopARSessionRunning will be blocked till the AVCaptureSessionDidStopRunningNotification event has been received
// successfully,
// after then we can restart AVCaptureSession gracefully.

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

@class SCCaptureResource;

@interface SCManagedCapturerARSessionHandler : NSObject

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource NS_DESIGNATED_INITIALIZER;

- (void)stopObserving;

- (void)stopARSessionRunning NS_AVAILABLE_IOS(11_0);
@end
