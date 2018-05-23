//
//  AVCaptureConnection+InputDevice.h
//  Snapchat
//
//  Created by William Morriss on 1/20/15
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface AVCaptureConnection (InputDevice)

- (AVCaptureDevice *)inputDevice;

@end
