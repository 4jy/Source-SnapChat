//
//  SCDepthToGrayscaleMetalRenderCommand.m
//  Snapchat
//
//  Created by Brian Ng on 12/7/17.
//
//

#import "SCDepthToGrayscaleMetalRenderCommand.h"

#import "SCCameraTweaks.h"
#import "SCMetalUtils.h"

#import <SCFoundation/NSString+SCFormat.h>

@import MetalPerformanceShaders;

@implementation SCDepthToGrayscaleMetalRenderCommand

typedef struct DepthToGrayscaleRenderData {
    float depthRange;
    float depthOffset;
} DepthToGrayscaleRenderData;

#pragma mark - SCMetalRenderCommand

- (id<MTLComputeCommandEncoder>)encodeMetalCommand:(id<MTLCommandBuffer>)commandBuffer
                                     pipelineState:(id<MTLComputePipelineState>)pipelineState
                                   textureResource:(SCMetalTextureResource *)textureResource
{
#if !TARGET_IPHONE_SIMULATOR
    DepthToGrayscaleRenderData depthToGrayscaleRenderData = {
        .depthRange = textureResource.depthRange, .depthOffset = textureResource.depthOffset,
    };
    id<MTLBuffer> depthToGrayscaleDataBuffer =
        [textureResource.device newBufferWithLength:sizeof(DepthToGrayscaleRenderData)
                                            options:MTLResourceOptionCPUCacheModeDefault];
    memcpy(depthToGrayscaleDataBuffer.contents, &depthToGrayscaleRenderData, sizeof(DepthToGrayscaleRenderData));

    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:pipelineState];

    [commandEncoder setTexture:textureResource.sourceDepthTexture atIndex:0];
    [commandEncoder setTexture:textureResource.destinationYTexture atIndex:1];
    [commandEncoder setTexture:textureResource.destinationUVTexture atIndex:2];
    [commandEncoder setBuffer:depthToGrayscaleDataBuffer offset:0 atIndex:0];

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
    return @"kernel_depth_to_grayscale";
}

- (NSString *)description
{
    return [NSString
        sc_stringWithFormat:@"SCDepthToGrayscaleMetalRenderCommand (shader function = %@)", self.functionName];
}

@end
