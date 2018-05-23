//
//  SCMetalModule.h
//  Snapchat
//
//  Created by Michel Loenngren on 7/19/17.
//
//

#import "SCMetalTextureResource.h"
#import "SCMetalUtils.h"
#import "SCProcessingModule.h"

#import <Foundation/Foundation.h>

@protocol SCMetalModuleFunctionProvider <NSObject>

@property (nonatomic, readonly) NSString *functionName;

@end

@protocol SCMetalRenderCommand <SCMetalModuleFunctionProvider>

/**
 Sets textures and parameters for the shader function. When implementing this function, the command encoder must be
 computed and the pipeline state set. That is, ensure that there are calls to: [commandBuffer computeCommandEncoder]
 and [commandEncoder setComputePipelineState:pipelineState].
 */
#if !TARGET_IPHONE_SIMULATOR
- (id<MTLComputeCommandEncoder>)encodeMetalCommand:(id<MTLCommandBuffer>)commandBuffer
                                     pipelineState:(id<MTLComputePipelineState>)pipelineState
                                   textureResource:(SCMetalTextureResource *)textureResource;
#endif

- (BOOL)requiresDepthData;

@end

/**
 NOTE: If we start chaining multiple metal modules we should
 not run them back to back but instead chain different render
 passes.
 */
@interface SCMetalModule : NSObject <SCProcessingModule>

// Designated initializer: SCMetalModule should always have a SCMetalRenderCommand
- (instancetype)initWithMetalRenderCommand:(id<SCMetalRenderCommand>)metalRenderCommand;

@end
