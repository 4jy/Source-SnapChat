//
//  SCExposureAdjustProcessingModule.m
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 6/1/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCExposureAdjustProcessingModule.h"

#import "SCProcessingModuleUtils.h"

@import CoreImage;
@import CoreMedia;

static const CGFloat kSCExposureAdjustProcessingModuleMaxEVValue = 2.0;

@implementation SCExposureAdjustProcessingModule {
    CIContext *_context;
    CIFilter *_filter;
    CFMutableDictionaryRef _attributes;
    CVPixelBufferPoolRef _bufferPool;
}

- (instancetype)init
{
    if (self = [super init]) {
        _context = [CIContext context];
        _filter = [CIFilter filterWithName:@"CIExposureAdjust"];
        [_filter setValue:@0.0 forKey:@"inputEV"];
    }
    return self;
}

- (void)setEVValue:(CGFloat)value
{
    CGFloat newEVValue = value * kSCExposureAdjustProcessingModuleMaxEVValue;
    [_filter setValue:@(newEVValue) forKey:@"inputEV"];
}

- (void)dealloc
{
    CVPixelBufferPoolFlush(_bufferPool, kCVPixelBufferPoolFlushExcessBuffers);
    CVPixelBufferPoolRelease(_bufferPool);
}

- (BOOL)requiresDepthData
{
    return NO;
}

- (CMSampleBufferRef)render:(RenderData)renderData
{
    CMSampleBufferRef input = renderData.sampleBuffer;
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(input);
    CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];

    [_filter setValue:image forKey:kCIInputImageKey];
    CIImage *result = [_filter outputImage];

    return [SCProcessingModuleUtils sampleBufferFromImage:result
                                          oldSampleBuffer:input
                                               bufferPool:_bufferPool
                                                  context:_context];
}

@end
