//
//  SCMetalModule.m
//  Snapchat
//
//  Created by Michel Loenngren on 7/19/17.
//
//

#import "SCMetalModule.h"

#import "SCCameraTweaks.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>

@interface SCMetalModule ()
#if !TARGET_IPHONE_SIMULATOR
@property (nonatomic, readonly) id<MTLLibrary> library;
@property (nonatomic, readonly) id<MTLDevice> device;
@property (nonatomic, readonly) id<MTLFunction> function;
@property (nonatomic, readonly) id<MTLComputePipelineState> computePipelineState;
@property (nonatomic, readonly) id<MTLCommandQueue> commandQueue;
@property (nonatomic, readonly) CVMetalTextureCacheRef textureCache;
#endif
@end

@implementation SCMetalModule {
    id<SCMetalRenderCommand> _metalRenderCommand;
}

#if !TARGET_IPHONE_SIMULATOR
@synthesize library = _library;
@synthesize function = _function;
@synthesize computePipelineState = _computePipelineState;
@synthesize commandQueue = _commandQueue;
@synthesize textureCache = _textureCache;
#endif

- (instancetype)initWithMetalRenderCommand:(id<SCMetalRenderCommand>)metalRenderCommand
{
    self = [super init];
    if (self) {
        _metalRenderCommand = metalRenderCommand;
    }
    return self;
}

#pragma mark - SCProcessingModule

- (CMSampleBufferRef)render:(RenderData)renderData
{
    CMSampleBufferRef input = renderData.sampleBuffer;
#if !TARGET_IPHONE_SIMULATOR
    id<MTLComputePipelineState> pipelineState = self.computePipelineState;
    SC_GUARD_ELSE_RETURN_VALUE(pipelineState, input);

    CVMetalTextureCacheRef textureCache = self.textureCache;
    SC_GUARD_ELSE_RETURN_VALUE(textureCache, input);

    id<MTLCommandQueue> commandQueue = self.commandQueue;
    SC_GUARD_ELSE_RETURN_VALUE(commandQueue, input);

    SCMetalTextureResource *textureResource =
        [[SCMetalTextureResource alloc] initWithRenderData:renderData textureCache:textureCache device:self.device];
    id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];
    if (!_metalRenderCommand) {
        SCAssertFail(@"Metal module must be initialized with an SCMetalRenderCommand");
    }
    id<MTLComputeCommandEncoder> commandEncoder = [_metalRenderCommand encodeMetalCommand:commandBuffer
                                                                            pipelineState:pipelineState
                                                                          textureResource:textureResource];

    NSUInteger w = pipelineState.threadExecutionWidth;
    NSUInteger h = pipelineState.maxTotalThreadsPerThreadgroup / w;

    MTLSize threadsPerThreadgroup = MTLSizeMake(w, h, 1);
    MTLSize threadgroupsPerGrid = MTLSizeMake((textureResource.sourceYTexture.width + w - 1) / w,
                                              (textureResource.sourceYTexture.height + h - 1) / h, 1);

    [commandEncoder dispatchThreadgroups:threadgroupsPerGrid threadsPerThreadgroup:threadsPerThreadgroup];

    [commandEncoder endEncoding];
    [commandBuffer commit];
    [commandBuffer waitUntilCompleted];

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(renderData.sampleBuffer);
    SCMetalCopyTexture(textureResource.destinationYTexture, imageBuffer, 0);
    SCMetalCopyTexture(textureResource.destinationUVTexture, imageBuffer, 1);
#endif
    return input;
}

- (BOOL)requiresDepthData
{
    return [_metalRenderCommand requiresDepthData];
}

#pragma mark - Lazy properties

#if !TARGET_IPHONE_SIMULATOR

- (id<MTLLibrary>)library
{
    if (!_library) {
        NSString *libPath = [[NSBundle mainBundle] pathForResource:@"sccamera-default" ofType:@"metallib"];
        NSError *error = nil;
        _library = [self.device newLibraryWithFile:libPath error:&error];
        if (error) {
            SCLogGeneralError(@"Create metallib error: %@", error.description);
        }
    }
    return _library;
}

- (id<MTLDevice>)device
{
    return SCGetManagedCaptureMetalDevice();
}

- (id<MTLFunction>)function
{
    return [self.library newFunctionWithName:[_metalRenderCommand functionName]];
}

- (id<MTLComputePipelineState>)computePipelineState
{
    if (!_computePipelineState) {
        NSError *error = nil;
        _computePipelineState = [self.device newComputePipelineStateWithFunction:self.function error:&error];
        if (error) {
            SCLogGeneralError(@"Error while creating compute pipeline state %@", error.description);
        }
    }
    return _computePipelineState;
}

- (id<MTLCommandQueue>)commandQueue
{
    if (!_commandQueue) {
        _commandQueue = [self.device newCommandQueue];
    }
    return _commandQueue;
}

- (CVMetalTextureCacheRef)textureCache
{
    if (!_textureCache) {
        CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, self.device, nil, &_textureCache);
    }
    return _textureCache;
}

#endif

@end
