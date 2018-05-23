//
//  SCProcessingPipelineBuilder.m
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 6/1/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCProcessingPipelineBuilder.h"

#import "SCCameraTweaks.h"
#import "SCDepthBlurMetalRenderCommand.h"
#import "SCDepthToGrayscaleMetalRenderCommand.h"
#import "SCDigitalExposureHandler.h"
#import "SCExposureAdjustMetalRenderCommand.h"
#import "SCMetalUtils.h"
#import "SCNightModeEnhancementMetalRenderCommand.h"
#import "SCProcessingPipeline.h"

@implementation SCProcessingPipelineBuilder

- (SCProcessingPipeline *)build
{
    if (!_useExposureAdjust && !_portraitModeEnabled && !_enhancedNightMode) { // in the future: && !useA && !useB ...
        return nil;
    }

    SCProcessingPipeline *processingPipeline = [[SCProcessingPipeline alloc] init];
    NSMutableArray<id<SCProcessingModule>> *processingModules = [NSMutableArray array];

    // order of adding module matters!
    if (_useExposureAdjust && SCDeviceSupportsMetal()) {
        // this check looks redundant right now, but when we have more modules it will be necessary
        SCMetalModule *exposureAdjustMetalModule =
            [[SCMetalModule alloc] initWithMetalRenderCommand:[SCExposureAdjustMetalRenderCommand new]];
        [processingModules addObject:exposureAdjustMetalModule];
    }

    if (_portraitModeEnabled) {
        id<SCMetalRenderCommand> renderCommand = SCCameraTweaksDepthToGrayscaleOverride()
                                                     ? [SCDepthToGrayscaleMetalRenderCommand new]
                                                     : [SCDepthBlurMetalRenderCommand new];
        SCMetalModule *depthBlurMetalModule = [[SCMetalModule alloc] initWithMetalRenderCommand:renderCommand];
        [processingModules addObject:depthBlurMetalModule];
    }

    if (_enhancedNightMode && SCDeviceSupportsMetal()) {
        SCMetalModule *nightModeEnhancementModule =
            [[SCMetalModule alloc] initWithMetalRenderCommand:[SCNightModeEnhancementMetalRenderCommand new]];
        [processingModules addObject:nightModeEnhancementModule];
    }

    processingPipeline.processingModules = processingModules;
    return processingPipeline;
}

@end
