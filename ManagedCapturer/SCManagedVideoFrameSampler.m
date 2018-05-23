//
//  SCManagedVideoFrameSampler.m
//  Snapchat
//
//  Created by Michel Loenngren on 3/10/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedVideoFrameSampler.h"

#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/UIImage+CVPixelBufferRef.h>

@import CoreImage;
@import ImageIO;

@interface SCManagedVideoFrameSampler ()

@property (nonatomic, copy) void (^frameSampleBlock)(UIImage *, CMTime);
@property (nonatomic, strong) CIContext *ciContext;

@end

@implementation SCManagedVideoFrameSampler

- (void)sampleNextFrame:(void (^)(UIImage *, CMTime))completeBlock
{
    _frameSampleBlock = completeBlock;
}

#pragma mark - SCManagedCapturerListener

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didAppendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
                sampleMetadata:(SCManagedCapturerSampleMetadata *)sampleMetadata
{
    void (^block)(UIImage *, CMTime) = _frameSampleBlock;
    _frameSampleBlock = nil;

    if (!block) {
        return;
    }

    CVImageBufferRef cvImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    UIImage *image;
    if (cvImageBuffer) {
        CGImageRef cgImage = SCCreateCGImageFromPixelBufferRef(cvImageBuffer);
        image = [[UIImage alloc] initWithCGImage:cgImage scale:1.0 orientation:UIImageOrientationRight];
        CGImageRelease(cgImage);
    }
    runOnMainThreadAsynchronously(^{
        block(image, presentationTime);
    });
}

- (CIContext *)ciContext
{
    if (!_ciContext) {
        _ciContext = [CIContext context];
    }
    return _ciContext;
}

@end
