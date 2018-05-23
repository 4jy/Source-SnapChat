//
//  SCMetalTextureResource.h
//  Snapchat
//
//  Created by Brian Ng on 11/7/17.
//

#import "SCProcessingModule.h"
#import "SCCapturerDefines.h"

#import <Foundation/Foundation.h>
#if !TARGET_IPHONE_SIMULATOR
#import <Metal/Metal.h>
#endif

/*
 @class SCMetalTextureResource
    The SCMetalTextureResource is created by SCMetalModule and is passed to a SCMetalRenderCommand.
        This resource provides a collection of textures for rendering, where a SCMetalRenderCommand
        selects which textures it needs. Textures are lazily initialiazed to optimize performance.
        Additionally, information pertaining to depth is provided if normalizing depth is desired:
        depthRange is the range of possible depth values [depthOffset, depthOffset + depthRange],
        where depthOffset is the min depth value in the given depth map.
    NOTE: This class is NOT thread safe -- ensure any calls are made by a performer by calling
        SCAssertPerformer before actually accessing any textures
 */
@interface SCMetalTextureResource : NSObject

#if !TARGET_IPHONE_SIMULATOR
@property (nonatomic, readonly) id<MTLTexture> sourceYTexture;
@property (nonatomic, readonly) id<MTLTexture> sourceUVTexture;
@property (nonatomic, readonly) id<MTLTexture> destinationYTexture;
@property (nonatomic, readonly) id<MTLTexture> destinationUVTexture;

// Textures for SCDepthBlurMetalCommand
@property (nonatomic, readonly) id<MTLTexture> sourceBlurredYTexture;
@property (nonatomic, readonly) id<MTLTexture> sourceDepthTexture;

@property (nonatomic, readonly) id<MTLDevice> device;
#endif

// Available depth-related auxiliary resources (when depth data is provided)
@property (nonatomic, readonly) float depthRange;
@property (nonatomic, readonly) float depthOffset;
@property (nonatomic, readonly) CGFloat depthBlurForegroundThreshold;
@property (nonatomic, readonly) SampleBufferMetadata sampleBufferMetadata;

#if !TARGET_IPHONE_SIMULATOR
- (instancetype)initWithRenderData:(RenderData)renderData
                      textureCache:(CVMetalTextureCacheRef)textureCache
                            device:(id<MTLDevice>)device;
#endif

@end
