//
//  AVCaptureConnection+InputDevice.m
//  Snapchat
//
//  Created by William Morriss on 1/20/15
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "AVCaptureConnection+InputDevice.h"

#import <SCFoundation/SCAssertWrapper.h>

@implementation AVCaptureConnection (InputDevice)

- (AVCaptureDevice *)inputDevice
{
    NSArray *inputPorts = self.inputPorts;
    AVCaptureInputPort *port = [inputPorts firstObject];
    SCAssert([port.input isKindOfClass:[AVCaptureDeviceInput class]], @"unexpected port");
    AVCaptureDeviceInput *deviceInput = (AVCaptureDeviceInput *)port.input;
    AVCaptureDevice *device = deviceInput.device;
    return device;
}

@end
