//
//  SCMetalUtils.h
//  Snapchat
//
//  Created by Michel Loenngren on 7/11/17.
//
//  Utility class for metal related helpers.

#import <Foundation/Foundation.h>
#if !TARGET_IPHONE_SIMULATOR
#import <Metal/Metal.h>
#endif
#import <AVFoundation/AVFoundation.h>

#import <SCBase/SCMacros.h>

SC_EXTERN_C_BEGIN

#if !TARGET_IPHONE_SIMULATOR
extern id<MTLDevice> SCGetManagedCaptureMetalDevice(void);
#endif

static SC_ALWAYS_INLINE BOOL SCDeviceSupportsMetal(void)
{
#if TARGET_CPU_ARM64
    return YES; // All 64 bit system supports Metal.
#else
    return NO;
#endif
}

#if !TARGET_IPHONE_SIMULATOR
static inline id<MTLTexture> SCMetalTextureFromPixelBuffer(CVPixelBufferRef pixelBuffer, size_t planeIndex,
                                                           MTLPixelFormat pixelFormat,
                                                           CVMetalTextureCacheRef textureCache)
{
    size_t width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex);
    size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex);
    CVMetalTextureRef textureRef;
    if (kCVReturnSuccess != CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer,
                                                                      nil, pixelFormat, width, height, planeIndex,
                                                                      &textureRef)) {
        return nil;
    }
    id<MTLTexture> texture = CVMetalTextureGetTexture(textureRef);
    CVBufferRelease(textureRef);
    return texture;
}

static inline void SCMetalCopyTexture(id<MTLTexture> texture, CVPixelBufferRef pixelBuffer, NSUInteger planeIndex)
{
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    void *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, planeIndex);
    NSUInteger bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, planeIndex);
    MTLRegion region = MTLRegionMake2D(0, 0, CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex),
                                       CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex));

    [texture getBytes:baseAddress bytesPerRow:bytesPerRow fromRegion:region mipmapLevel:0];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}
#endif

SC_EXTERN_C_END
