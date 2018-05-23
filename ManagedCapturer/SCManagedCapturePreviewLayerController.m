//
//  SCManagedCapturePreviewLayerController.m
//  Snapchat
//
//  Created by Liu Liu on 5/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturePreviewLayerController.h"

#import "SCBlackCameraDetector.h"
#import "SCCameraTweaks.h"
#import "SCManagedCapturePreviewView.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerListener.h"
#import "SCManagedCapturerUtils.h"
#import "SCMetalUtils.h"

#import <SCFoundation/NSData+Random.h>
#import <SCFoundation/SCCoreGraphicsUtils.h>
#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>
#import <SCFoundation/UIScreen+SCSafeAreaInsets.h>
#import <SCGhostToSnappable/SCGhostToSnappableSignal.h>

#import <FBKVOController/FBKVOController.h>

#define SCLogPreviewLayerInfo(fmt, ...) SCLogCoreCameraInfo(@"[PreviewLayerController] " fmt, ##__VA_ARGS__)
#define SCLogPreviewLayerWarning(fmt, ...) SCLogCoreCameraWarning(@"[PreviewLayerController] " fmt, ##__VA_ARGS__)
#define SCLogPreviewLayerError(fmt, ...) SCLogCoreCameraError(@"[PreviewLayerController] " fmt, ##__VA_ARGS__)

const static CGSize kSCManagedCapturePreviewDefaultRenderSize = {
    .width = 720, .height = 1280,
};

const static CGSize kSCManagedCapturePreviewRenderSize1080p = {
    .width = 1080, .height = 1920,
};

#if !TARGET_IPHONE_SIMULATOR

static NSInteger const kSCMetalCannotAcquireDrawableLimit = 2;

@interface CAMetalLayer (SCSecretFature)

// Call discardContents.
- (void)sc_secretFeature;

@end

@implementation CAMetalLayer (SCSecretFature)

- (void)sc_secretFeature
{
    // "discardContents"
    char buffer[] = {0x9b, 0x96, 0x8c, 0x9c, 0x9e, 0x8d, 0x9b, 0xbc, 0x90, 0x91, 0x8b, 0x9a, 0x91, 0x8b, 0x8c, 0};
    unsigned long len = strlen(buffer);
    for (unsigned idx = 0; idx < len; ++idx) {
        buffer[idx] = ~buffer[idx];
    }
    SEL selector = NSSelectorFromString([NSString stringWithUTF8String:buffer]);
    if ([self respondsToSelector:selector]) {
        NSMethodSignature *signature = [self methodSignatureForSelector:selector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:selector];
        [invocation invoke];
    }
    // For anyone curious, here is the actual implementation for discardContents in 10.3 (With Hopper v4, arm64)
    // From glance, this seems pretty safe to call.
    // void -[CAMetalLayer(CAMetalLayerPrivate) discardContents](int arg0)
    // {
    //     *(r31 + 0xffffffffffffffe0) = r20;
    //     *(0xfffffffffffffff0 + r31) = r19;
    //     r31 = r31 + 0xffffffffffffffe0;
    //     *(r31 + 0x10) = r29;
    //     *(0x20 + r31) = r30;
    //     r29 = r31 + 0x10;
    //     r19 = *(arg0 + sign_extend_64(*(int32_t *)0x1a6300510));
    //     if (r19 != 0x0) {
    //         r0 = loc_1807079dc(*0x1a7811fc8, r19);
    //         r0 = _CAImageQueueConsumeUnconsumed(*(r19 + 0x10));
    //         r0 = _CAImageQueueFlush(*(r19 + 0x10));
    //         r29 = *(r31 + 0x10);
    //         r30 = *(0x20 + r31);
    //         r20 = *r31;
    //         r19 = *(r31 + 0x10);
    //         r31 = r31 + 0x20;
    //         r0 = loc_1807079dc(*0x1a7811fc8, zero_extend_64(0x0));
    //     } else {
    //         r29 = *(r31 + 0x10);
    //         r30 = *(0x20 + r31);
    //         r20 = *r31;
    //         r19 = *(r31 + 0x10);
    //         r31 = r31 + 0x20;
    //     }
    //     return;
    // }
}

@end

#endif

@interface SCManagedCapturePreviewLayerController () <SCManagedCapturerListener>

@property (nonatomic) BOOL renderSuspended;

@end

@implementation SCManagedCapturePreviewLayerController {
    SCManagedCapturePreviewView *_view;
    CGSize _drawableSize;
    SCQueuePerformer *_performer;
    FBKVOController *_renderingKVO;
#if !TARGET_IPHONE_SIMULATOR
    CAMetalLayer *_metalLayer;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _renderPipelineState;
    CVMetalTextureCacheRef _textureCache;
    dispatch_semaphore_t _commandBufferSemaphore;
    // If the current view contains an outdated display (or any display)
    BOOL _containOutdatedPreview;
    // If we called empty outdated display already, but for some reason, hasn't emptied it yet.
    BOOL _requireToFlushOutdatedPreview;
    NSMutableSet *_tokenSet;
    NSUInteger _cannotAcquireDrawable;
#endif
}

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static SCManagedCapturePreviewLayerController *managedCapturePreviewLayerController;
    dispatch_once(&onceToken, ^{
        managedCapturePreviewLayerController = [[SCManagedCapturePreviewLayerController alloc] init];
    });
    return managedCapturePreviewLayerController;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
#if !TARGET_IPHONE_SIMULATOR
        // We only allow one renders at a time (Sorry, no double / triple buffering).
        // It has to be created early here, otherwise integrity of other parts of the code is not
        // guaranteed.
        // TODO: I need to reason more about the initialization sequence.
        _commandBufferSemaphore = dispatch_semaphore_create(1);
        // Set _renderSuspended to be YES so that we won't render until it is fully setup.
        _renderSuspended = YES;
        _tokenSet = [NSMutableSet set];
#endif
        // If the screen is less than default size, we should fallback.
        CGFloat nativeScale = [UIScreen mainScreen].nativeScale;
        CGSize screenSize = [UIScreen mainScreen].fixedCoordinateSpace.bounds.size;
        CGSize renderSize = [SCDeviceName isIphoneX] ? kSCManagedCapturePreviewRenderSize1080p
                                                     : kSCManagedCapturePreviewDefaultRenderSize;
        if (screenSize.width * nativeScale < renderSize.width) {
            _drawableSize = CGSizeMake(screenSize.width * nativeScale, screenSize.height * nativeScale);
        } else {
            _drawableSize = SCSizeIntegral(
                SCSizeCropToAspectRatio(renderSize, SCSizeGetAspectRatio(SCManagedCapturerAllScreenSize())));
        }
        _performer = [[SCQueuePerformer alloc] initWithLabel:"SCManagedCapturePreviewLayerController"
                                            qualityOfService:QOS_CLASS_USER_INITIATED
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCoreCamera];

        _renderingKVO = [[FBKVOController alloc] initWithObserver:self];
        [_renderingKVO observe:self
                       keyPath:@keypath(self, renderSuspended)
                       options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         block:^(id observer, id object, NSDictionary *change) {
                             BOOL oldValue = [change[NSKeyValueChangeOldKey] boolValue];
                             BOOL newValue = [change[NSKeyValueChangeNewKey] boolValue];
                             if (oldValue != newValue) {
                                 [[_delegate blackCameraDetectorForManagedCapturePreviewLayerController:self]
                                     capturePreviewDidBecomeVisible:!newValue];
                             }
                         }];
    }
    return self;
}

- (void)pause
{
#if !TARGET_IPHONE_SIMULATOR
    SCTraceStart();
    SCLogPreviewLayerInfo(@"pause Metal rendering performer waiting");
    [_performer performAndWait:^() {
        self.renderSuspended = YES;
    }];
    SCLogPreviewLayerInfo(@"pause Metal rendering performer finished");
#endif
}

- (void)resume
{
#if !TARGET_IPHONE_SIMULATOR
    SCTraceStart();
    SCLogPreviewLayerInfo(@"resume Metal rendering performer waiting");
    [_performer performAndWait:^() {
        self.renderSuspended = NO;
    }];
    SCLogPreviewLayerInfo(@"resume Metal rendering performer finished");
#endif
}

- (void)setupPreviewLayer
{
#if !TARGET_IPHONE_SIMULATOR
    SCTraceStart();
    SCAssertMainThread();
    SC_GUARD_ELSE_RETURN(SCDeviceSupportsMetal());

    if (!_metalLayer) {
        _metalLayer = [CAMetalLayer new];
        SCLogPreviewLayerInfo(@"setup metalLayer:%@", _metalLayer);

        if (!_view) {
            // Create capture preview view and setup the metal layer
            [self view];
        } else {
            [_view setupMetalLayer:_metalLayer];
        }
    }
#endif
}

- (UIView *)newStandInViewWithRect:(CGRect)rect
{
    return [self.view resizableSnapshotViewFromRect:rect afterScreenUpdates:YES withCapInsets:UIEdgeInsetsZero];
}

- (void)setupRenderPipeline
{
#if !TARGET_IPHONE_SIMULATOR
    SCTraceStart();
    SC_GUARD_ELSE_RETURN(SCDeviceSupportsMetal());
    SCAssertNotMainThread();
    id<MTLDevice> device = SCGetManagedCaptureMetalDevice();
    id<MTLLibrary> shaderLibrary = [device newDefaultLibrary];
    _commandQueue = [device newCommandQueue];
    MTLRenderPipelineDescriptor *renderPipelineDescriptor = [MTLRenderPipelineDescriptor new];
    renderPipelineDescriptor.colorAttachments[0].pixelFormat = MTLPixelFormatBGRA8Unorm;
    renderPipelineDescriptor.vertexFunction = [shaderLibrary newFunctionWithName:@"yuv_vertex_reshape"];
    renderPipelineDescriptor.fragmentFunction = [shaderLibrary newFunctionWithName:@"yuv_fragment_texture"];
    MTLVertexDescriptor *vertexDescriptor = [MTLVertexDescriptor vertexDescriptor];
    vertexDescriptor.attributes[0].format = MTLVertexFormatFloat2; // position
    vertexDescriptor.attributes[0].offset = 0;
    vertexDescriptor.attributes[0].bufferIndex = 0;
    vertexDescriptor.attributes[1].format = MTLVertexFormatFloat2; // texCoords
    vertexDescriptor.attributes[1].offset = 2 * sizeof(float);
    vertexDescriptor.attributes[1].bufferIndex = 0;
    vertexDescriptor.layouts[0].stepRate = 1;
    vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    vertexDescriptor.layouts[0].stride = 4 * sizeof(float);
    renderPipelineDescriptor.vertexDescriptor = vertexDescriptor;
    _renderPipelineState = [device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &_textureCache);
    _metalLayer.device = device;
    _metalLayer.drawableSize = _drawableSize;
    _metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    _metalLayer.framebufferOnly = YES; // It is default to Yes.
    [_performer performAndWait:^() {
        self.renderSuspended = NO;
    }];
    SCLogPreviewLayerInfo(@"did setup render pipeline");
#endif
}

- (UIView *)view
{
    SCTraceStart();
    SCAssertMainThread();
    if (!_view) {
#if TARGET_IPHONE_SIMULATOR
        _view = [[SCManagedCapturePreviewView alloc] initWithFrame:[UIScreen mainScreen].fixedCoordinateSpace.bounds
                                                       aspectRatio:SCSizeGetAspectRatio(_drawableSize)
                                                        metalLayer:nil];
#else
        _view = [[SCManagedCapturePreviewView alloc] initWithFrame:[UIScreen mainScreen].fixedCoordinateSpace.bounds
                                                       aspectRatio:SCSizeGetAspectRatio(_drawableSize)
                                                        metalLayer:_metalLayer];
        SCLogPreviewLayerInfo(@"created SCManagedCapturePreviewView:%@", _view);
#endif
    }
    return _view;
}

- (void)setManagedCapturer:(id<SCCapturer>)managedCapturer
{
    SCTraceStart();
    SCLogPreviewLayerInfo(@"setManagedCapturer:%@", managedCapturer);
    if (SCDeviceSupportsMetal()) {
        [managedCapturer addSampleBufferDisplayController:self context:SCCapturerContext];
    }
    [managedCapturer addListener:self];
}

- (void)applicationDidEnterBackground
{
#if !TARGET_IPHONE_SIMULATOR
    SCTraceStart();
    SCAssertMainThread();
    SC_GUARD_ELSE_RETURN(SCDeviceSupportsMetal());
    SCLogPreviewLayerInfo(@"applicationDidEnterBackground waiting for performer");
    [_performer performAndWait:^() {
        CVMetalTextureCacheFlush(_textureCache, 0);
        [_tokenSet removeAllObjects];
        self.renderSuspended = YES;
    }];
    SCLogPreviewLayerInfo(@"applicationDidEnterBackground signal performer finishes");
#endif
}

- (void)applicationWillResignActive
{
    SC_GUARD_ELSE_RETURN(SCDeviceSupportsMetal());
    SCTraceStart();
    SCAssertMainThread();
#if !TARGET_IPHONE_SIMULATOR
    SCLogPreviewLayerInfo(@"pause Metal rendering");
    [_performer performAndWait:^() {
        self.renderSuspended = YES;
    }];
#endif
}

- (void)applicationDidBecomeActive
{
    SC_GUARD_ELSE_RETURN(SCDeviceSupportsMetal());
    SCTraceStart();
    SCAssertMainThread();
#if !TARGET_IPHONE_SIMULATOR
    SCLogPreviewLayerInfo(@"resume Metal rendering waiting for performer");
    [_performer performAndWait:^() {
        self.renderSuspended = NO;
    }];
    SCLogPreviewLayerInfo(@"resume Metal rendering performer finished");
#endif
}

- (void)applicationWillEnterForeground
{
#if !TARGET_IPHONE_SIMULATOR
    SCTraceStart();
    SCAssertMainThread();
    SC_GUARD_ELSE_RETURN(SCDeviceSupportsMetal());
    SCLogPreviewLayerInfo(@"applicationWillEnterForeground waiting for performer");
    [_performer performAndWait:^() {
        self.renderSuspended = NO;
        if (_containOutdatedPreview && _tokenSet.count == 0) {
            [self _flushOutdatedPreview];
        }
    }];
    SCLogPreviewLayerInfo(@"applicationWillEnterForeground performer finished");
#endif
}

- (NSString *)keepDisplayingOutdatedPreview
{
    SCTraceStart();
    NSString *token = [NSData randomBase64EncodedStringOfLength:8];
#if !TARGET_IPHONE_SIMULATOR
    SCLogPreviewLayerInfo(@"keepDisplayingOutdatedPreview waiting for performer");
    [_performer performAndWait:^() {
        [_tokenSet addObject:token];
    }];
    SCLogPreviewLayerInfo(@"keepDisplayingOutdatedPreview performer finished");
#endif
    return token;
}

- (void)endDisplayingOutdatedPreview:(NSString *)keepToken
{
#if !TARGET_IPHONE_SIMULATOR
    SC_GUARD_ELSE_RETURN(SCDeviceSupportsMetal());
    // I simply use a lock for this. If it becomes a bottleneck, I can figure something else out.
    SCTraceStart();
    SCLogPreviewLayerInfo(@"endDisplayingOutdatedPreview waiting for performer");
    [_performer performAndWait:^() {
        [_tokenSet removeObject:keepToken];
        if (_tokenSet.count == 0 && _requireToFlushOutdatedPreview && _containOutdatedPreview && !_renderSuspended) {
            [self _flushOutdatedPreview];
        }
    }];
    SCLogPreviewLayerInfo(@"endDisplayingOutdatedPreview performer finished");
#endif
}

#pragma mark - SCManagedSampleBufferDisplayController

- (void)enqueueSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
#if !TARGET_IPHONE_SIMULATOR
    // Just drop the frame if it is rendering.
    SC_GUARD_ELSE_RUN_AND_RETURN_VALUE(dispatch_semaphore_wait(_commandBufferSemaphore, DISPATCH_TIME_NOW) == 0,
                                       SCLogPreviewLayerInfo(@"waiting for commandBufferSemaphore signaled"), );
    // Just drop the frame, simple.
    [_performer performAndWait:^() {
        if (_renderSuspended) {
            SCLogGeneralInfo(@"Preview rendering suspends and current sample buffer is dropped");
            dispatch_semaphore_signal(_commandBufferSemaphore);
            return;
        }
        @autoreleasepool {
            const BOOL isFirstPreviewFrame = !_containOutdatedPreview;
            if (isFirstPreviewFrame) {
                // Signal that we receieved the first frame (otherwise this will be YES already).
                SCGhostToSnappableSignalDidReceiveFirstPreviewFrame();
                sc_create_g2s_ticket_f func = [_delegate g2sTicketForManagedCapturePreviewLayerController:self];
                SCG2SActivateManiphestTicketQueueWithTicketCreationFunction(func);
            }
            CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);

            CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
            size_t pixelWidth = CVPixelBufferGetWidth(imageBuffer);
            size_t pixelHeight = CVPixelBufferGetHeight(imageBuffer);
            id<MTLTexture> yTexture =
                SCMetalTextureFromPixelBuffer(imageBuffer, 0, MTLPixelFormatR8Unorm, _textureCache);
            id<MTLTexture> cbCrTexture =
                SCMetalTextureFromPixelBuffer(imageBuffer, 1, MTLPixelFormatRG8Unorm, _textureCache);
            CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

            SC_GUARD_ELSE_RUN_AND_RETURN(yTexture && cbCrTexture, dispatch_semaphore_signal(_commandBufferSemaphore));
            id<MTLCommandBuffer> commandBuffer = _commandQueue.commandBuffer;
            id<CAMetalDrawable> drawable = _metalLayer.nextDrawable;
            if (!drawable) {
                // Count how many times I cannot acquire drawable.
                ++_cannotAcquireDrawable;
                if (_cannotAcquireDrawable >= kSCMetalCannotAcquireDrawableLimit) {
                    // Calling [_metalLayer discardContents] to flush the CAImageQueue
                    SCLogGeneralInfo(@"Cannot acquire drawable, reboot Metal ..");
                    [_metalLayer sc_secretFeature];
                }
                dispatch_semaphore_signal(_commandBufferSemaphore);
                return;
            }
            _cannotAcquireDrawable = 0; // Reset to 0 in case we can acquire drawable.
            MTLRenderPassDescriptor *renderPassDescriptor = [MTLRenderPassDescriptor new];
            renderPassDescriptor.colorAttachments[0].texture = drawable.texture;
            id<MTLRenderCommandEncoder> renderEncoder =
                [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
            [renderEncoder setRenderPipelineState:_renderPipelineState];
            [renderEncoder setFragmentTexture:yTexture atIndex:0];
            [renderEncoder setFragmentTexture:cbCrTexture atIndex:1];
            // TODO: Prob this out of the image buffer.
            // 90 clock-wise rotated texture coordinate.
            // Also do aspect fill.
            float normalizedHeight, normalizedWidth;
            if (pixelWidth * _drawableSize.width > _drawableSize.height * pixelHeight) {
                normalizedHeight = 1.0;
                normalizedWidth = pixelWidth * (_drawableSize.width / pixelHeight) / _drawableSize.height;
            } else {
                normalizedHeight = pixelHeight * (_drawableSize.height / pixelWidth) / _drawableSize.width;
                normalizedWidth = 1.0;
            }
            const float vertices[] = {
                -normalizedHeight, -normalizedWidth, 1, 1, // lower left  -> upper right
                normalizedHeight,  -normalizedWidth, 1, 0, // lower right -> lower right
                -normalizedHeight, normalizedWidth,  0, 1, // upper left  -> upper left
                normalizedHeight,  normalizedWidth,  0, 0, // upper right -> lower left
            };
            [renderEncoder setVertexBytes:vertices length:sizeof(vertices) atIndex:0];
            [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
            [renderEncoder endEncoding];
            // I need to set a minimum duration for the drawable.
            // There is a bug on iOS 10.3, if I present as soon as I can, I am keeping the GPU
            // at 30fps even you swipe between views, that causes undesirable visual jarring.
            // By set a minimum duration, even it is incrediably small (I tried 10ms, and here 60fps works),
            // the OS seems can adjust the frame rate much better when swiping.
            // This is an iOS 10.3 new method.
            if ([commandBuffer respondsToSelector:@selector(presentDrawable:afterMinimumDuration:)]) {
                [(id)commandBuffer presentDrawable:drawable afterMinimumDuration:(1.0 / 60)];
            } else {
                [commandBuffer presentDrawable:drawable];
            }
            [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
                dispatch_semaphore_signal(_commandBufferSemaphore);
            }];
            if (isFirstPreviewFrame) {
                if ([drawable respondsToSelector:@selector(addPresentedHandler:)] &&
                    [drawable respondsToSelector:@selector(presentedTime)]) {
                    [(id)drawable addPresentedHandler:^(id<MTLDrawable> presentedDrawable) {
                        SCGhostToSnappableSignalDidRenderFirstPreviewFrame([(id)presentedDrawable presentedTime]);
                    }];
                } else {
                    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> commandBuffer) {
                        // Using CACurrentMediaTime to approximate.
                        SCGhostToSnappableSignalDidRenderFirstPreviewFrame(CACurrentMediaTime());
                    }];
                }
            }
            // We enqueued an sample buffer to display, therefore, it contains an outdated display (to be clean up).
            _containOutdatedPreview = YES;
            [commandBuffer commit];
        }
    }];
#endif
}

- (void)flushOutdatedPreview
{
    SCTraceStart();
#if !TARGET_IPHONE_SIMULATOR
    // This method cannot drop frames (otherwise we will have residual on the screen).
    SCLogPreviewLayerInfo(@"flushOutdatedPreview waiting for performer");
    [_performer performAndWait:^() {
        _requireToFlushOutdatedPreview = YES;
        SC_GUARD_ELSE_RETURN(!_renderSuspended);
        // Have to make sure we have no token left before return.
        SC_GUARD_ELSE_RETURN(_tokenSet.count == 0);
        [self _flushOutdatedPreview];
    }];
    SCLogPreviewLayerInfo(@"flushOutdatedPreview performer finished");
#endif
}

- (void)_flushOutdatedPreview
{
    SCTraceStart();
    SCAssertPerformer(_performer);
#if !TARGET_IPHONE_SIMULATOR
    SCLogPreviewLayerInfo(@"flushOutdatedPreview containOutdatedPreview:%d", _containOutdatedPreview);
    // I don't care if this has renderSuspended or not, assuming I did the right thing.
    // Emptied, no need to do this any more on foregrounding.
    SC_GUARD_ELSE_RETURN(_containOutdatedPreview);
    _containOutdatedPreview = NO;
    _requireToFlushOutdatedPreview = NO;
    [_metalLayer sc_secretFeature];
#endif
}

#pragma mark - SCManagedCapturerListener

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didChangeVideoPreviewLayer:(AVCaptureVideoPreviewLayer *)videoPreviewLayer
{
    SCTraceStart();
    SCAssertMainThread();
    // Force to load the view
    [self view];
    _view.videoPreviewLayer = videoPreviewLayer;
    SCLogPreviewLayerInfo(@"didChangeVideoPreviewLayer:%@", videoPreviewLayer);
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeVideoPreviewGLView:(LSAGLView *)videoPreviewGLView
{
    SCTraceStart();
    SCAssertMainThread();
    // Force to load the view
    [self view];
    _view.videoPreviewGLView = videoPreviewGLView;
    SCLogPreviewLayerInfo(@"didChangeVideoPreviewGLView:%@", videoPreviewGLView);
}

@end
