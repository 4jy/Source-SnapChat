//
//  SCManagedCaptureDeviceSubjectAreaHandler.h
//  Snapchat
//
//  Created by Xiaokang Liu on 19/03/2018.
//
// This class is used to handle the AVCaptureDeviceSubjectAreaDidChangeNotification notification for SCManagedCapturer.
// To reset device's settings when the subject area changed

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

@class SCCaptureResource;
@protocol SCCapturer;

@interface SCManagedCaptureDeviceSubjectAreaHandler : NSObject
SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource NS_DESIGNATED_INITIALIZER;

- (void)stopObserving;
- (void)startObserving;
@end
