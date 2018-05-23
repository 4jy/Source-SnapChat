//
//  SCManagedCaptureDeviceHandler.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/8/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDevice.h"

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

@class SCCaptureResource;

@interface SCManagedCaptureDeviceHandler : NSObject <SCManagedCaptureDeviceDelegate>

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource;

@end
