//
//  SCMetalTextureResource.m
//  Snapchat
//
//  Created by Brian Ng on 11/7/17.
//

#import "SCMetalTextureResource.h"

#import "SCCameraSettingUtils.h"
#import "SCCameraTweaks.h"
#import "SCMetalUtils.h"

@import CoreImage;

#if !TARGET_IPHONE_SIMULATOR
static NSInteger const kSCFocusRectSize = 4;
#endif

@interface SCMetalTextureResource ()
#if !TARGET_IPHONE_SIMULATOR
@property (nonatomic, readonly) CVMetalTextureCacheRef textureCache;
#endif
@end

@implementation SCMetalTextureResource {
    RenderData _renderData;
    CVImageBufferRef _imageBuffer;
    CIContext *_context;
}

#if !TARGET_IPHONE_SIMULATOR
@synthesize sourceYTexture = _sourceYTexture;
@synthesize sourceUVTexture = _sourceUVTexture;
@synthesize destinationYTexture = _destinationYTexture;
@synthesize destinationUVTexture = _destinationUVTexture;
@synthesize sourceBlurredYTexture = _sourceBlurredYTexture;
@synthesize sourceDepthTexture = _sourceDepthTexture;
@synthesize depthRange = _depthRange;
@synthesize depthOffset = _depthOffset;
@synthesize depthBlurForegroundThreshold = _depthBlurForegroundThreshold;
@synthesize device = _device;
@synthesize sampleBufferMetadata = _sampleBufferMetadata;

- (instancetype)initWithRenderData:(RenderData)renderData
                      textureCache:(CVMetalTextureCacheRef)textureCache
                            device:(id<MTLDevice>)device
{
    self = [super init];
    if (self) {
        _imageBuffer = CMSampleBufferGetImageBuffer(renderData.sampleBuffer);
        _renderData = renderData;
        _textureCache = textureCache;
        _device = device;
        _context = [CIContext contextWithOptions:@{ kCIContextWorkingFormat : @(kCIFormatRGBAh) }];
    }
    return self;
}
#endif

#if !TARGET_IPHONE_SIMULATOR

- (id<MTLTexture>)sourceYTexture
{
    if (!_sourceYTexture) {
        CVPixelBufferLockBaseAddress(_imageBuffer, kCVPixelBufferLock_ReadOnly);
        _sourceYTexture = SCMetalTextureFromPixelBuffer(_imageBuffer, 0, MTLPixelFormatR8Unorm, _textureCache);
        CVPixelBufferUnlockBaseAddress(_imageBuffer, kCVPixelBufferLock_ReadOnly);
    }
    return _sourceYTexture;
}

- (id<MTLTexture>)sourceUVTexture
{
    if (!_sourceUVTexture) {
        CVPixelBufferLockBaseAddress(_imageBuffer, kCVPixelBufferLock_ReadOnly);
        _sourceUVTexture = SCMetalTextureFromPixelBuffer(_imageBuffer, 1, MTLPixelFormatRG8Unorm, _textureCache);
        CVPixelBufferUnlockBaseAddress(_imageBuffer, kCVPixelBufferLock_ReadOnly);
    }
    return _sourceUVTexture;
}

- (id<MTLTexture>)destinationYTexture
{
    if (!_destinationYTexture) {
        MTLTextureDescriptor *textureDescriptor =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                               width:CVPixelBufferGetWidthOfPlane(_imageBuffer, 0)
                                                              height:CVPixelBufferGetHeightOfPlane(_imageBuffer, 0)
                                                           mipmapped:NO];
        textureDescriptor.usage |= MTLTextureUsageShaderWrite;
        _destinationYTexture = [_device newTextureWithDescriptor:textureDescriptor];
    }
    return _destinationYTexture;
}

- (id<MTLTexture>)destinationUVTexture
{
    if (!_destinationUVTexture) {
        MTLTextureDescriptor *textureDescriptor =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG8Unorm
                                                               width:CVPixelBufferGetWidthOfPlane(_imageBuffer, 1)
                                                              height:CVPixelBufferGetHeightOfPlane(_imageBuffer, 1)
                                                           mipmapped:NO];
        textureDescriptor.usage |= MTLTextureUsageShaderWrite;
        _destinationUVTexture = [_device newTextureWithDescriptor:textureDescriptor];
    }
    return _destinationUVTexture;
}

- (id<MTLTexture>)sourceBlurredYTexture
{
    if (!_sourceBlurredYTexture) {
        MTLTextureDescriptor *textureDescriptor =
            [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                               width:CVPixelBufferGetWidthOfPlane(_imageBuffer, 0)
                                                              height:CVPixelBufferGetHeightOfPlane(_imageBuffer, 0)
                                                           mipmapped:NO];
        textureDescriptor.usage |= MTLTextureUsageShaderWrite;
        _sourceBlurredYTexture = [_device newTextureWithDescriptor:textureDescriptor];
    }
    return _sourceBlurredYTexture;
}

- (id<MTLTexture>)sourceDepthTexture
{
    if (!_sourceDepthTexture) {
        CVPixelBufferLockBaseAddress(_imageBuffer, kCVPixelBufferLock_ReadOnly);
        _sourceDepthTexture =
            SCMetalTextureFromPixelBuffer(_renderData.depthDataMap, 0, MTLPixelFormatR16Float, _textureCache);
        CVPixelBufferUnlockBaseAddress(_imageBuffer, kCVPixelBufferLock_ReadOnly);
    }
    return _sourceDepthTexture;
}

- (float)depthRange
{
    if (_depthRange == 0) {
        //  Get min/max values of depth image to normalize
        size_t bufferWidth = CVPixelBufferGetWidth(_renderData.depthDataMap);
        size_t bufferHeight = CVPixelBufferGetHeight(_renderData.depthDataMap);
        size_t bufferBytesPerRow = CVPixelBufferGetBytesPerRow(_renderData.depthDataMap);

        CVPixelBufferLockBaseAddress(_renderData.depthDataMap, kCVPixelBufferLock_ReadOnly);
        unsigned char *pixelBufferPointer = CVPixelBufferGetBaseAddress(_renderData.depthDataMap);
        __fp16 *bufferPtr = (__fp16 *)pixelBufferPointer;
        uint32_t ptrInc = (int)bufferBytesPerRow / sizeof(__fp16);

        float depthMin = MAXFLOAT;
        float depthMax = -MAXFLOAT;
        for (int j = 0; j < bufferHeight; j++) {
            for (int i = 0; i < bufferWidth; i++) {
                float value = bufferPtr[i];
                if (!isnan(value)) {
                    depthMax = MAX(depthMax, value);
                    depthMin = MIN(depthMin, value);
                }
            }
            bufferPtr += ptrInc;
        }
        CVPixelBufferUnlockBaseAddress(_renderData.depthDataMap, kCVPixelBufferLock_ReadOnly);
        _depthRange = depthMax - depthMin;
        _depthOffset = depthMin;
    }
    return _depthRange;
}

- (float)depthOffset
{
    if (_depthRange == 0) {
        [self depthRange];
    }
    return _depthOffset;
}

- (CGFloat)depthBlurForegroundThreshold
{
    if (_renderData.depthBlurPointOfInterest) {
        CGPoint point = *_renderData.depthBlurPointOfInterest;
        CIImage *disparityImage = [CIImage imageWithCVPixelBuffer:_renderData.depthDataMap];
        CIVector *vector =
            [CIVector vectorWithX:point.x * CVPixelBufferGetWidth(_renderData.depthDataMap) - kSCFocusRectSize / 2
                                Y:point.y * CVPixelBufferGetHeight(_renderData.depthDataMap) - kSCFocusRectSize / 2
                                Z:kSCFocusRectSize
                                W:kSCFocusRectSize];
        CIImage *minMaxImage =
            [[disparityImage imageByClampingToExtent] imageByApplyingFilter:@"CIAreaMinMaxRed"
                                                        withInputParameters:@{kCIInputExtentKey : vector}];
        UInt8 pixel[4] = {0, 0, 0, 0};
        [_context render:minMaxImage
                toBitmap:&pixel
                rowBytes:4
                  bounds:CGRectMake(0, 0, 1, 1)
                  format:kCIFormatRGBA8
              colorSpace:nil];
        CGFloat disparity = pixel[1] / 255.0;
        CGFloat normalizedDisparity = (disparity - self.depthOffset) / self.depthRange;
        return normalizedDisparity;
    } else {
        return SCCameraTweaksDepthBlurForegroundThreshold();
    }
}

- (SampleBufferMetadata)sampleBufferMetadata
{
    SampleBufferMetadata sampleMetadata = {
        .isoSpeedRating = 0, .exposureTime = 0.033, .brightness = 0,
    };
    retrieveSampleBufferMetadata(_renderData.sampleBuffer, &sampleMetadata);
    return sampleMetadata;
}

#endif

@end
