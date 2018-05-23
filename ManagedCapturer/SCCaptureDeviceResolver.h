//
//  SCCaptureDeviceResolver.h
//  Snapchat
//
//  Created by Lin Jia on 11/8/17.
//
//

#import <AVFoundation/AVFoundation.h>

/*
 See https://jira.sc-corp.net/browse/CCAM-5843

 Retrieving AVCaptureDevice is a flaky operation. Thus create capture device resolver to make our code more robust.

 Resolver is used to retrieve AVCaptureDevice. We are going to do our best to find the camera for you.

 Resolver is only going to be used by SCManagedCaptureDevice.

 All APIs are thread safe.
 */

@interface SCCaptureDeviceResolver : NSObject

+ (instancetype)sharedInstance;

- (AVCaptureDevice *)findAVCaptureDevice:(AVCaptureDevicePosition)position;

- (AVCaptureDevice *)findDualCamera;

@end
