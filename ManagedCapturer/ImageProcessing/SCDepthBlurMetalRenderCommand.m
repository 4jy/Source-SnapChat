//
//  SCDepthBlurMetalRenderCommand.m
//  Snapchat
//
//  Created by Brian Ng on 11/8/17.
//
//

#import "SCDepthBlurMetalRenderCommand.h"

#import "SCCameraTweaks.h"
#import "SCMetalUtils.h"

#import <SCFoundation/NSString+SCFormat.h>

@import MetalPerformanceShaders;

@implementation SCDepthBlurMetalRenderCommand

typedef struct DepthBlurRenderData {
    float depthRange;
    float depthOffset;
    float depthBlurForegroundThreshold;
    float depthBlurBackgroundThreshold;
} DepthBlurRenderData;

#pragma mark - SCMetalRenderCommand

- (id<MTLComputeCommandEncoder>)encodeMetalCommand:(id<MTLCommandBuffer>)commandBuffer
                                     pipelineState:(id<MTLComputePipelineState>)pipelineState
                                   textureResource:(SCMetalTextureResource *)textureResource
{
#if !TARGET_IPHONE_SIMULATOR
    CGFloat depthBlurForegroundThreshold = textureResource.depthBlurForegroundThreshold;
    CGFloat depthBlurBackgroundThreshold =
        textureResource.depthBlurForegroundThreshold > SCCameraTweaksDepthBlurBackgroundThreshold()
            ? SCCameraTweaksDepthBlurBackgroundThreshold()
            : 0;
    DepthBlurRenderData depthBlurRenderData = {
        .depthRange = textureResource.depthRange,
        .depthOffset = textureResource.depthOffset,
        .depthBlurBackgroundThreshold = depthBlurBackgroundThreshold,
        .depthBlurForegroundThreshold = depthBlurForegroundThreshold,
    };
    id<MTLBuffer> depthBlurRenderDataBuffer =
        [textureResource.device newBufferWithLength:sizeof(DepthBlurRenderData)
                                            options:MTLResourceOptionCPUCacheModeDefault];
    memcpy(depthBlurRenderDataBuffer.contents, &depthBlurRenderData, sizeof(DepthBlurRenderData));

    MPSImageGaussianBlur *kernel =
        [[MPSImageGaussianBlur alloc] initWithDevice:textureResource.device sigma:SCCameraTweaksBlurSigma()];
    [kernel encodeToCommandBuffer:commandBuffer
                    sourceTexture:textureResource.sourceYTexture
               destinationTexture:textureResource.sourceBlurredYTexture];

    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:pipelineState];

    [commandEncoder setTexture:textureResource.sourceYTexture atIndex:0];
    [commandEncoder setTexture:textureResource.sourceUVTexture atIndex:1];
    [commandEncoder setTexture:textureResource.sourceDepthTexture atIndex:2];
    [commandEncoder setTexture:textureResource.sourceBlurredYTexture atIndex:3];
    [commandEncoder setTexture:textureResource.destinationYTexture atIndex:4];
    [commandEncoder setTexture:textureResource.destinationUVTexture atIndex:5];
    [commandEncoder setBuffer:depthBlurRenderDataBuffer offset:0 atIndex:0];

    return commandEncoder;
#else
    return nil;
#endif
}

- (BOOL)requiresDepthData
{
    return YES;
}

#pragma mark - SCMetalModuleFunctionProvider

- (NSString *)functionName
{
    return @"kernel_depth_blur";
}

- (NSString *)description
{
    return [NSString sc_stringWithFormat:@"SCDepthBlurMetalRenderCommand (shader function = %@)", self.functionName];
}

@end
