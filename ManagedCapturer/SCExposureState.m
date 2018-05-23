//
//  SCExposureState.m
//  Snapchat
//
//  Created by Derek Peirce on 4/10/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCExposureState.h"

#import "AVCaptureDevice+ConfigurationLock.h"

#import <SCBase/SCMacros.h>

@import AVFoundation;

@implementation SCExposureState {
    float _ISO;
    CMTime _exposureDuration;
}

- (instancetype)initWithDevice:(AVCaptureDevice *)device
{
    if (self = [super init]) {
        _ISO = device.ISO;
        _exposureDuration = device.exposureDuration;
    }
    return self;
}

- (void)applyISOAndExposureDurationToDevice:(AVCaptureDevice *)device
{
    if ([device isExposureModeSupported:AVCaptureExposureModeCustom]) {
        [device runTask:@"set prior exposure"
            withLockedConfiguration:^() {
                CMTime exposureDuration =
                    CMTimeClampToRange(_exposureDuration, CMTimeRangeMake(device.activeFormat.minExposureDuration,
                                                                          device.activeFormat.maxExposureDuration));
                [device setExposureModeCustomWithDuration:exposureDuration
                                                      ISO:SC_CLAMP(_ISO, device.activeFormat.minISO,
                                                                   device.activeFormat.maxISO)
                                        completionHandler:nil];
            }];
    }
}

@end
