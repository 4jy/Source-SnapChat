//
//  SCExposureState.h
//  Snapchat
//
//  Created by Derek Peirce on 4/10/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface SCExposureState : NSObject

- (instancetype)initWithDevice:(AVCaptureDevice *)device;

- (void)applyISOAndExposureDurationToDevice:(AVCaptureDevice *)device;

@end
