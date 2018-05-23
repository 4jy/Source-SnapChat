//
//  SCExposureAdjustMetalRenderCommand.m
//  Snapchat
//
//  Created by Michel Loenngren on 7/11/17.
//
//

#import "SCExposureAdjustMetalRenderCommand.h"

#import "SCCameraTweaks.h"
#import "SCMetalUtils.h"

#import <SCFoundation/SCAssertWrapper.h>

@import Metal;

@implementation SCExposureAdjustMetalRenderCommand

#pragma mark - SCMetalRenderCommand

- (id<MTLComputeCommandEncoder>)encodeMetalCommand:(id<MTLCommandBuffer>)commandBuffer
                                     pipelineState:(id<MTLComputePipelineState>)pipelineState
                                   textureResource:(SCMetalTextureResource *)textureResource
{
    id<MTLComputeCommandEncoder> commandEncoder = [commandBuffer computeCommandEncoder];
    [commandEncoder setComputePipelineState:pipelineState];
#if !TARGET_IPHONE_SIMULATOR
    [commandEncoder setTexture:textureResource.sourceYTexture atIndex:0];
    [commandEncoder setTexture:textureResource.sourceUVTexture atIndex:1];
    [commandEncoder setTexture:textureResource.destinationYTexture atIndex:2];
    [commandEncoder setTexture:textureResource.destinationUVTexture atIndex:3];
#endif

    return commandEncoder;
}

#pragma mark - SCMetalModuleFunctionProvider

- (NSString *)functionName
{
    if (SCCameraExposureAdjustmentMode() == 1) {
        return @"kernel_exposure_adjust";
    } else if (SCCameraExposureAdjustmentMode() == 2) {
        return @"kernel_exposure_adjust_nightvision";
    } else if (SCCameraExposureAdjustmentMode() == 3) {
        return @"kernel_exposure_adjust_inverted_nightvision";
    } else {
        SCAssertFail(@"Incorrect value from SCCameraExposureAdjustmentMode() %ld",
                     (long)SCCameraExposureAdjustmentMode());
        return nil;
    }
}

- (BOOL)requiresDepthData
{
    return NO;
}

- (NSString *)description
{
    return
        [NSString sc_stringWithFormat:@"SCExposureAdjustMetalRenderCommand (shader function = %@)", self.functionName];
}

@end
