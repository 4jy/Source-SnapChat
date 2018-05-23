//
//  SCManagedCapturerUtils.m
//  Snapchat
//
//  Created by Chao Pang on 10/4/17.
//

#import "SCManagedCapturerUtils.h"

#import "SCCaptureCommon.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCCoreGraphicsUtils.h>
#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/UIScreen+SCSafeAreaInsets.h>

// This is to calculate the crop ratio for generating the image shown in Preview page
// Check https://snapchat.quip.com/lU3kAoDxaAFG for our design.
const CGFloat kSCIPhoneXCapturedImageVideoCropRatio = (397.0 * 739.0) / (375.0 * 812.0);

CGFloat SCManagedCapturedImageAndVideoAspectRatio(void)
{
    static dispatch_once_t onceToken;
    static CGFloat aspectRatio;
    dispatch_once(&onceToken, ^{
        CGSize screenSize = [UIScreen mainScreen].fixedCoordinateSpace.bounds.size;
        UIEdgeInsets safeAreaInsets = [UIScreen sc_safeAreaInsets];
        aspectRatio = SCSizeGetAspectRatio(
            CGSizeMake(screenSize.width, screenSize.height - safeAreaInsets.top - safeAreaInsets.bottom));
    });
    return aspectRatio;
}

CGSize SCManagedCapturerAllScreenSize(void)
{
    static CGSize size;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize screenSize = [UIScreen mainScreen].fixedCoordinateSpace.bounds.size;
        // This logic is complicated because we need to handle iPhone X properly.
        // See https://snapchat.quip.com/lU3kAoDxaAFG for our design.
        UIEdgeInsets safeAreaInsets = [UIScreen sc_safeAreaInsets];
        UIEdgeInsets visualSafeInsets = [UIScreen sc_visualSafeInsets];
        // This really is just some coordinate computations:
        // We know in preview, our size is (screenWidth, screenHeight - topInset - bottomInset)
        // We know that when the preview image is in the camera screen, the height is screenHeight - visualTopInset,
        // thus, we need to figure out in camera screen, what's the bleed-over width should be
        // (screenWidth * (screenHeight - visualTopInset) / (screenHeight - topInset - bottomInset)
        size = CGSizeMake(roundf(screenSize.width * (screenSize.height - visualSafeInsets.top) /
                                 (screenSize.height - safeAreaInsets.top - safeAreaInsets.bottom)),
                          screenSize.height);
    });
    return size;
}

CGSize SCAsyncImageCapturePlaceholderViewSize(void)
{
    static CGSize size;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGSize screenSize = [UIScreen mainScreen].fixedCoordinateSpace.bounds.size;
        UIEdgeInsets safeAreaInsets = [UIScreen sc_safeAreaInsets];
        UIEdgeInsets visualSafeInsets = [UIScreen sc_visualSafeInsets];
        size = CGSizeMake(roundf((screenSize.height - visualSafeInsets.top) * screenSize.width /
                                 (screenSize.height - safeAreaInsets.top - safeAreaInsets.bottom)),
                          screenSize.height - visualSafeInsets.top);
    });
    return size;
}

CGFloat SCAdjustedAspectRatio(UIImageOrientation orientation, CGFloat aspectRatio)
{
    SCCAssert(aspectRatio != kSCManagedCapturerAspectRatioUnspecified, @"");
    switch (orientation) {
    case UIImageOrientationLeft:
    case UIImageOrientationRight:
    case UIImageOrientationLeftMirrored:
    case UIImageOrientationRightMirrored:
        return 1.0 / aspectRatio;
    default:
        return aspectRatio;
    }
}

UIImage *SCCropImageToTargetAspectRatio(UIImage *image, CGFloat targetAspectRatio)
{
    if (SCNeedsCropImageToAspectRatio(image.CGImage, image.imageOrientation, targetAspectRatio)) {
        CGImageRef croppedImageRef =
            SCCreateCroppedImageToAspectRatio(image.CGImage, image.imageOrientation, targetAspectRatio);
        UIImage *croppedImage =
            [UIImage imageWithCGImage:croppedImageRef scale:image.scale orientation:image.imageOrientation];
        CGImageRelease(croppedImageRef);
        return croppedImage;
    } else {
        return image;
    }
}

void SCCropImageSizeToAspectRatio(size_t inputWidth, size_t inputHeight, UIImageOrientation orientation,
                                  CGFloat aspectRatio, size_t *outputWidth, size_t *outputHeight)
{
    SCCAssert(outputWidth != NULL && outputHeight != NULL, @"");
    aspectRatio = SCAdjustedAspectRatio(orientation, aspectRatio);
    if (inputWidth > roundf(inputHeight * aspectRatio)) {
        *outputHeight = inputHeight;
        *outputWidth = roundf(*outputHeight * aspectRatio);
    } else {
        *outputWidth = inputWidth;
        *outputHeight = roundf(*outputWidth / aspectRatio);
    }
}

BOOL SCNeedsCropImageToAspectRatio(CGImageRef image, UIImageOrientation orientation, CGFloat aspectRatio)
{
    if (aspectRatio == kSCManagedCapturerAspectRatioUnspecified) {
        return NO;
    }
    aspectRatio = SCAdjustedAspectRatio(orientation, aspectRatio);
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    return (width != roundf(height * aspectRatio));
}

CGRect SCCalculateRectToCrop(size_t imageWidth, size_t imageHeight, size_t croppedWidth, size_t croppedHeight)
{
    if ([SCDeviceName isIphoneX]) {
        // X is pushed all the way over to crop out top section but none of bottom
        CGFloat x = (imageWidth - croppedWidth);
        // Crop y symmetrically.
        CGFloat y = roundf((imageHeight - croppedHeight) / 2.0);

        return CGRectMake(x, y, croppedWidth, croppedHeight);
    }
    return CGRectMake((imageWidth - croppedWidth) / 2, (imageHeight - croppedHeight) / 2, croppedWidth, croppedHeight);
}

CGImageRef SCCreateCroppedImageToAspectRatio(CGImageRef image, UIImageOrientation orientation, CGFloat aspectRatio)
{
    SCCAssert(aspectRatio != kSCManagedCapturerAspectRatioUnspecified, @"");
    size_t width = CGImageGetWidth(image);
    size_t height = CGImageGetHeight(image);
    size_t croppedWidth, croppedHeight;
    if ([SCDeviceName isIphoneX]) {
        size_t adjustedWidth = (size_t)(width * kSCIPhoneXCapturedImageVideoCropRatio);
        size_t adjustedHeight = (size_t)(height * kSCIPhoneXCapturedImageVideoCropRatio);
        SCCropImageSizeToAspectRatio(adjustedWidth, adjustedHeight, orientation, aspectRatio, &croppedWidth,
                                     &croppedHeight);
    } else {
        SCCropImageSizeToAspectRatio(width, height, orientation, aspectRatio, &croppedWidth, &croppedHeight);
    }
    CGRect cropRect = SCCalculateRectToCrop(width, height, croppedWidth, croppedHeight);
    return CGImageCreateWithImageInRect(image, cropRect);
}
