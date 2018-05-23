//
//  SCManagedStillImageCapturerHandler.h
//  Snapchat
//
//  Created by Jingtian Yang on 11/12/2017.
//

#import "SCManagedStillImageCapturer.h"

#import <Foundation/Foundation.h>

@class SCCaptureResource;
@protocol SCDeviceMotionProvider
, SCFileInputDecider;

@interface SCManagedStillImageCapturerHandler : NSObject <SCManagedStillImageCapturerDelegate>

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource;

@end
