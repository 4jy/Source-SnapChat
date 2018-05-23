//
//  SCProcessingModuleUtils.m
//  Snapchat
//
//  Created by Brian Ng on 11/10/17.
//

#import "SCProcessingModuleUtils.h"

#import <SCFoundation/SCLog.h>

@import CoreImage;

@implementation SCProcessingModuleUtils

+ (CVPixelBufferRef)pixelBufferFromImage:(CIImage *)image
                              bufferPool:(CVPixelBufferPoolRef)bufferPool
                                 context:(CIContext *)context
{
    CVReturn result;

    if (bufferPool == NULL) {
        NSDictionary *pixelAttributes = @{
            (NSString *) kCVPixelBufferIOSurfacePropertiesKey : @{}, (NSString *)
            kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), (NSString *)
            kCVPixelBufferWidthKey : @(image.extent.size.width), (NSString *)
            kCVPixelBufferHeightKey : @(image.extent.size.height)
        };
        result = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL,
                                         (__bridge CFDictionaryRef _Nullable)(pixelAttributes), &bufferPool);
        if (result != kCVReturnSuccess) {
            SCLogGeneralError(@"[Processing Pipeline] Error creating pixel buffer pool %i", result);
            return NULL;
        }
    }

    CVPixelBufferRef resultBuffer = NULL;
    result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, bufferPool, &resultBuffer);

    if (result == kCVReturnSuccess) {
        [context render:image toCVPixelBuffer:resultBuffer];
    } else {
        SCLogGeneralError(@"[Processing Pipeline] Error creating pixel buffer from pool %i", result);
    }
    return resultBuffer;
}

+ (CMSampleBufferRef)sampleBufferFromImage:(CIImage *)image
                           oldSampleBuffer:(CMSampleBufferRef)oldSampleBuffer
                                bufferPool:(CVPixelBufferPoolRef)bufferPool
                                   context:(CIContext *)context
{
    CVPixelBufferRef pixelBuffer =
        [SCProcessingModuleUtils pixelBufferFromImage:image bufferPool:bufferPool context:context];
    if (!pixelBuffer) {
        SCLogGeneralError(@"[Processing Pipeline] Error creating new pixel buffer from image");
        return oldSampleBuffer;
    }

    CMSampleBufferRef newSampleBuffer = NULL;
    CMSampleTimingInfo timimgInfo = kCMTimingInfoInvalid;
    CMSampleBufferGetSampleTimingInfo(oldSampleBuffer, 0, &timimgInfo);

    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus status = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    if (status != noErr) {
        SCLogGeneralError(@"[Processing Pipeline] Error creating video format description %i", (int)status);
        CVPixelBufferRelease(pixelBuffer);
        return oldSampleBuffer;
    }

    status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo,
                                                &timimgInfo, &newSampleBuffer);
    if (status != noErr) {
        SCLogGeneralError(@"[Processing Pipeline] Error creating CMSampleBuffer %i", (int)status);
        CVPixelBufferRelease(pixelBuffer);
        return oldSampleBuffer;
    }

    CVPixelBufferRelease(pixelBuffer);
    return newSampleBuffer;
}

@end
