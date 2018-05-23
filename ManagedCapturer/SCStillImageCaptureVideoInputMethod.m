//
//  SCStillImageCaptureVideoInputMethod.m
//  Snapchat
//
//  Created by Alexander Grytsiuk on 3/16/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCStillImageCaptureVideoInputMethod.h"

#import "SCManagedCapturer.h"
#import "SCManagedVideoFileStreamer.h"

typedef unsigned char uchar_t;
int clamp(int val, int low, int high)
{
    if (val < low)
        val = low;
    if (val > high)
        val = high;
    return val;
}

void yuv2rgb(uchar_t yValue, uchar_t uValue, uchar_t vValue, uchar_t *r, uchar_t *g, uchar_t *b)
{
    double red = yValue + (1.370705 * (vValue - 128));
    double green = yValue - (0.698001 * (vValue - 128)) - (0.337633 * (uValue - 128));
    double blue = yValue + (1.732446 * (uValue - 128));
    *r = clamp(red, 0, 255);
    *g = clamp(green, 0, 255);
    *b = clamp(blue, 0, 255);
}

void convertNV21DataToRGBData(int width, int height, uchar_t *nv21Data, uchar_t *rgbData, int rgbBytesPerPixel,
                              int rgbBytesPerRow)
{
    uchar_t *uvData = nv21Data + height * width;
    for (int h = 0; h < height; h++) {
        uchar_t *yRowBegin = nv21Data + h * width;
        uchar_t *uvRowBegin = uvData + h / 2 * width;
        uchar_t *rgbRowBegin = rgbData + rgbBytesPerRow * h;
        for (int w = 0; w < width; w++) {
            uchar_t *rgbPixelBegin = rgbRowBegin + rgbBytesPerPixel * w;
            yuv2rgb(yRowBegin[w], uvRowBegin[w / 2 * 2], uvRowBegin[w / 2 * 2 + 1], &(rgbPixelBegin[0]),
                    &(rgbPixelBegin[1]), &(rgbPixelBegin[2]));
        }
    }
}

@implementation SCStillImageCaptureVideoInputMethod

- (void)captureStillImageWithCapturerState:(SCManagedCapturerState *)state
                              successBlock:(void (^)(NSData *imageData, NSDictionary *cameraInfo,
                                                     NSError *error))successBlock
                              failureBlock:(void (^)(NSError *error))failureBlock
{
    id<SCManagedVideoDataSource> videoDataSource = [[SCManagedCapturer sharedInstance] currentVideoDataSource];
    if ([videoDataSource isKindOfClass:[SCManagedVideoFileStreamer class]]) {
        SCManagedVideoFileStreamer *videoFileStreamer = (SCManagedVideoFileStreamer *)videoDataSource;
        [videoFileStreamer getNextPixelBufferWithCompletion:^(CVPixelBufferRef pixelBuffer) {
            BOOL shouldFlip = state.devicePosition == SCManagedCaptureDevicePositionFront;
#if TARGET_IPHONE_SIMULATOR
            UIImage *uiImage = [self imageWithCVPixelBuffer:pixelBuffer];
            CGImageRef videoImage = uiImage.CGImage;
            UIImage *capturedImage = [UIImage
                imageWithCGImage:shouldFlip ? [self flipCGImage:videoImage size:uiImage.size].CGImage : videoImage
                           scale:1.0
                     orientation:UIImageOrientationRight];
#else
            CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
            CIContext *temporaryContext = [CIContext contextWithOptions:nil];

            CGSize size = CGSizeMake(CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
            CGImageRef videoImage =
                [temporaryContext createCGImage:ciImage fromRect:CGRectMake(0, 0, size.width, size.height)];

            UIImage *capturedImage =
                [UIImage imageWithCGImage:shouldFlip ? [self flipCGImage:videoImage size:size].CGImage : videoImage
                                    scale:1.0
                              orientation:UIImageOrientationRight];

            CGImageRelease(videoImage);
#endif
            if (successBlock) {
                successBlock(UIImageJPEGRepresentation(capturedImage, 1.0), nil, nil);
            }
        }];
    } else {
        if (failureBlock) {
            failureBlock([NSError errorWithDomain:NSStringFromClass(self.class) code:-1 userInfo:nil]);
        }
    }
}

- (UIImage *)flipCGImage:(CGImageRef)cgImage size:(CGSize)size
{
    UIGraphicsBeginImageContext(size);
    CGContextDrawImage(UIGraphicsGetCurrentContext(), CGRectMake(0, 0, size.width, size.height), cgImage);
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

- (UIImage *)imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer
{
    CVPixelBufferLockBaseAddress(imageBuffer, 0);

    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    size_t rgbBytesPerPixel = 4;
    size_t rgbBytesPerRow = width * rgbBytesPerPixel;

    uchar_t *nv21Data = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0);
    uchar_t *rgbData = malloc(rgbBytesPerRow * height);

    convertNV21DataToRGBData((int)width, (int)height, nv21Data, rgbData, (int)rgbBytesPerPixel, (int)rgbBytesPerRow);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context =
        CGBitmapContextCreate(rgbData, width, height, 8, rgbBytesPerRow, colorSpace, kCGImageAlphaNoneSkipLast);
    CGImageRef cgImage = CGBitmapContextCreateImage(context);

    UIImage *result = [UIImage imageWithCGImage:cgImage];

    CGImageRelease(cgImage);
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(rgbData);

    CVPixelBufferUnlockBaseAddress(imageBuffer, 0);

    return result;
}

- (NSString *)methodName
{
    return @"VideoInput";
}

@end
