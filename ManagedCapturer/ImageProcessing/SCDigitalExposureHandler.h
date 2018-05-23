//
//  SCDigitalExposureHandler.h
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 6/15/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

@class SCExposureAdjustProcessingModule;

/*
 @class SCDigitalExposureHandler
    The SCDigitalExposureHandler will be built by the SCProcessingBuilder when the user indicates that he/she
        wants to add SCExposureAdjustProcessingModule to the processing pipeline. The builder will take care
        of initializing the handler by linking the processing module. Caller of the builder can then link up
        the handler to the UI element (in this case, SCExposureSlider) so that user's control is hooked up to
        the processing module.

 */
@interface SCDigitalExposureHandler : NSObject

- (instancetype)initWithProcessingModule:(SCExposureAdjustProcessingModule *)processingModule;
- (void)setExposureParameter:(CGFloat)value;

@end
