//
//  SCStillImageDepthBlurFilter.m
//  Snapchat
//
//  Created by Brian Ng on 10/11/17.
//

#import "SCStillImageDepthBlurFilter.h"

#import "SCCameraTweaks.h"
#import "SCProcessingModuleUtils.h"

@import CoreMedia;

@implementation SCStillImageDepthBlurFilter {
    CIContext *_context;
    CIFilter *_filter;
    CVPixelBufferPoolRef _bufferPool;
}

- (instancetype)init
{
    if (self = [super init]) {
        _context = [CIContext contextWithOptions:@{ kCIContextWorkingFormat : @(kCIFormatRGBAh) }];
        _filter = [CIFilter filterWithName:@"CIDepthBlurEffect"];
    }
    return self;
}

- (void)dealloc
{
    CVPixelBufferPoolFlush(_bufferPool, kCVPixelBufferPoolFlushExcessBuffers);
    CVPixelBufferPoolRelease(_bufferPool);
}

- (NSData *)renderWithPhotoData:(NSData *)photoData renderData:(RenderData)renderData NS_AVAILABLE_IOS(11_0)
{
    CIImage *mainImage = [CIImage imageWithData:photoData];
    CVPixelBufferRef disparityImagePixelBuffer = renderData.depthDataMap;
    CIImage *disparityImage = [CIImage imageWithCVPixelBuffer:disparityImagePixelBuffer];
    if (!disparityImage) {
        return photoData;
    }
    [_filter setValue:mainImage forKey:kCIInputImageKey];
    [_filter setValue:disparityImage forKey:kCIInputDisparityImageKey];
    if (renderData.depthBlurPointOfInterest && SCCameraTweaksEnableFilterInputFocusRect()) {
        CGPoint pointOfInterest = *renderData.depthBlurPointOfInterest;
        [_filter setValue:[CIVector vectorWithX:pointOfInterest.x Y:pointOfInterest.y Z:1 W:1]
                   forKey:@"inputFocusRect"];
    }
    CIImage *result = [_filter outputImage];
    if (!result) {
        return photoData;
    }
    CGColorSpaceRef deviceRGBColorSpace = CGColorSpaceCreateDeviceRGB();
    NSData *processedPhotoData = [_context JPEGRepresentationOfImage:result colorSpace:deviceRGBColorSpace options:@{}];
    CGColorSpaceRelease(deviceRGBColorSpace);
    if (!processedPhotoData) {
        return photoData;
    }
    renderData.sampleBuffer = [SCProcessingModuleUtils sampleBufferFromImage:result
                                                             oldSampleBuffer:renderData.sampleBuffer
                                                                  bufferPool:_bufferPool
                                                                     context:_context];
    return processedPhotoData;
}

@end
