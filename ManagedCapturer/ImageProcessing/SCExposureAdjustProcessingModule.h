//
//  SCExposureAdjustProcessingModule.h
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 6/1/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCProcessingModule.h"

#import <Foundation/Foundation.h>

/**
 NOTE: If we start chaining multiple CIImage modules we should
 not run them back to back but instead in one CIImage pass
 as CoreImage will merge the shaders for best performance
*/

/*
 @class SCExposureAdjustProcessingModule
    This module use the CIExposureAdjust CIFilter to process the frames. It use the value provided by
    the SCDigitalExposurehandler as evValue (default is 0).
  */
@interface SCExposureAdjustProcessingModule : NSObject <SCProcessingModule>

- (void)setEVValue:(CGFloat)value;

@end
