//
//  SCSingleFrameStreamCapturer.m
//  Snapchat
//
//  Created by Benjamin Hollis on 5/3/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCSingleFrameStreamCapturer.h"

#import "SCManagedCapturer.h"

@implementation SCSingleFrameStreamCapturer {
    sc_managed_capturer_capture_video_frame_completion_handler_t _callback;
}

- (instancetype)initWithCompletion:(sc_managed_capturer_capture_video_frame_completion_handler_t)completionHandler
{
    self = [super init];
    if (self) {
        _callback = completionHandler;
    }
    return self;
}

#pragma mark - SCManagedVideoDataSourceListener

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    if (_callback) {
        UIImage *image = [self imageFromSampleBuffer:sampleBuffer];
        _callback(image);
    }
    _callback = nil;
}

/**
 * Decode a CMSampleBufferRef to our native camera format (kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
 * as set in SCManagedVideoStreamer) to a UIImage.
 *
 * Code from http://stackoverflow.com/a/31553521/11284
 */
#define clamp(a) (a > 255 ? 255 : (a < 0 ? 0 : a))
// TODO: Use the transform code from SCImageProcessIdentityYUVCommand
- (UIImage *)imageFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    uint8_t *yBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    size_t yPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 0);
    uint8_t *cbCrBuffer = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 1);
    size_t cbCrPitch = CVPixelBufferGetBytesPerRowOfPlane(imageBuffer, 1);

    int bytesPerPixel = 4;
    uint8_t *rgbBuffer = malloc(width * height * bytesPerPixel);

    for (int y = 0; y < height; y++) {
        uint8_t *rgbBufferLine = &rgbBuffer[y * width * bytesPerPixel];
        uint8_t *yBufferLine = &yBuffer[y * yPitch];
        uint8_t *cbCrBufferLine = &cbCrBuffer[(y >> 1) * cbCrPitch];

        for (int x = 0; x < width; x++) {
            int16_t y = yBufferLine[x];
            int16_t cb = cbCrBufferLine[x & ~1] - 128;
            int16_t cr = cbCrBufferLine[x | 1] - 128;

            uint8_t *rgbOutput = &rgbBufferLine[x * bytesPerPixel];

            int16_t r = (int16_t)roundf(y + cr * 1.4);
            int16_t g = (int16_t)roundf(y + cb * -0.343 + cr * -0.711);
            int16_t b = (int16_t)roundf(y + cb * 1.765);

            rgbOutput[0] = 0xff;
            rgbOutput[1] = clamp(b);
            rgbOutput[2] = clamp(g);
            rgbOutput[3] = clamp(r);
        }
    }

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(rgbBuffer, width, height, 8, width * bytesPerPixel, colorSpace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaNoneSkipLast);
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);

    // TODO: Hardcoding UIImageOrientationRight seems cheesy
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0 orientation:UIImageOrientationRight];

    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(quartzImage);
    free(rgbBuffer);

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

    return image;
}

@end
