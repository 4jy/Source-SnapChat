//
//  SCNightModeEnhancementMetalRenderCommand.m
//  Snapchat
//
//  Created by Chao Pang on 12/21/17.
//

#import "SCNightModeEnhancementMetalRenderCommand.h"

#import "SCCameraTweaks.h"
#import "SCMetalUtils.h"

#import <SCFoundation/NSString+SCFormat.h>

@import Metal;

@implementation SCNightModeEnhancementMetalRenderCommand

#pragma mark - SCMetalRenderCommand

- (id<MTLComputeCommandEncoder>)encodeMetalCommand:(id<MTLCommandBuffer>)commandBuffer
                                     pipelineState:(id<MTLComputePipelineState>)pipelineState
                                   textureResource:(SCMetalTextureResource *)textureResource
{
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:pipelineState];
#if !TARGET_IPHONE_SIMULATOR
    SampleBufferMetadata sampleBufferMetadata = {
        .isoSpeedRating = textureResource.sampleBufferMetadata.isoSpeedRating,
        .exposureTime = textureResource.sampleBufferMetadata.exposureTime,
        .brightness = textureResource.sampleBufferMetadata.brightness,
    };
    id<MTLBuffer> metadataBuffer = [textureResource.device newBufferWithLength:sizeof(SampleBufferMetadata)
                                                                       options:MTLResourceOptionCPUCacheModeDefault];
    memcpy(metadataBuffer.contents, &sampleBufferMetadata, sizeof(SampleBufferMetadata));
    [commandEncoder setTexture:textureResource.sourceYTexture atIndex:0];
    [commandEncoder setTexture:textureResource.sourceUVTexture atIndex:1];
    [commandEncoder setTexture:textureResource.destinationYTexture atIndex:2];
    [commandEncoder setTexture:textureResource.destinationUVTexture atIndex:3];
    [commandEncoder setBuffer:metadataBuffer offset:0 atIndex:0];
#endif

    return commandEncoder;
}

#pragma mark - SCMetalModuleFunctionProvider

- (NSString *)functionName
{
    return @"kernel_night_mode_enhancement";
}

- (BOOL)requiresDepthData
{
    return NO;
}

- (NSString *)description
{
    return [NSString
        sc_stringWithFormat:@"SCNightModeEnhancementMetalRenderCommand (shader function = %@)", self.functionName];
}

@end
