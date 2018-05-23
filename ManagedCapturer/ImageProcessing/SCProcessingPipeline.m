//
//  SCProcessingPipeline.m
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 5/30/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCProcessingPipeline.h"

#import <SCFoundation/NSString+Helpers.h>

@import CoreMedia;

@implementation SCProcessingPipeline

- (CMSampleBufferRef)render:(RenderData)renderData
{
    for (id<SCProcessingModule> module in self.processingModules) {
        if (![module requiresDepthData] || ([module requiresDepthData] && renderData.depthDataMap)) {
            renderData.sampleBuffer = [module render:renderData];
        }
    }

    return renderData.sampleBuffer;
}

- (NSString *)description
{
    NSMutableString *desc = [NSMutableString new];
    [desc appendString:@"ProcessingPipeline, modules: "];
    for (id<SCProcessingModule> module in self.processingModules) {
        [desc appendFormat:@"%@, ", [module description]];
    }
    if (self.processingModules.count > 0) {
        return [desc substringToIndex:desc.lengthOfCharacterSequences - 2];
    }
    return desc;
}

- (BOOL)requiresDepthData
{
    return NO;
}

@end
