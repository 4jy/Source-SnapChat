//
//  SCDigitalExposureHandler.m
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 6/15/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCDigitalExposureHandler.h"

#import "SCExposureAdjustProcessingModule.h"

@implementation SCDigitalExposureHandler {
    __weak SCExposureAdjustProcessingModule *_processingModule;
}

- (instancetype)initWithProcessingModule:(SCExposureAdjustProcessingModule *)processingModule
{
    if (self = [super init]) {
        _processingModule = processingModule;
    }
    return self;
}

- (void)setExposureParameter:(CGFloat)value
{
    [_processingModule setEVValue:value];
}

@end
