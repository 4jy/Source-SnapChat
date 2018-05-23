//
//  SCManagedDeviceCapacityAnalyzerHandler.h
//  Snapchat
//
//  Created by Jingtian Yang on 11/12/2017.
//

#import "SCManagedDeviceCapacityAnalyzerListener.h"

#import <Foundation/Foundation.h>

@class SCCaptureResource;

@interface SCManagedDeviceCapacityAnalyzerHandler : NSObject <SCManagedDeviceCapacityAnalyzerListener>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource;

@end
