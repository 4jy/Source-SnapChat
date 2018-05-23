//
//  SCManagedCapturePreviewView.m
//  Snapchat
//
//  Created by Liu Liu on 5/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturePreviewView.h"

#import "SCCameraTweaks.h"
#import "SCManagedCapturePreviewLayerController.h"
#import "SCManagedCapturePreviewViewDebugView.h"
#import "SCMetalUtils.h"

#import <SCFoundation/SCCoreGraphicsUtils.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCTrace.h>

#import <Looksery/LSAGLView.h>

@implementation SCManagedCapturePreviewView {
    CGFloat _aspectRatio;
    CALayer *_containerLayer;
    CALayer *_metalLayer;
    SCManagedCapturePreviewViewDebugView *_debugView;
}

- (instancetype)initWithFrame:(CGRect)frame aspectRatio:(CGFloat)aspectRatio metalLayer:(CALayer *)metalLayer
{
    SCTraceStart();
    SCAssertMainThread();
    self = [super initWithFrame:frame];
    if (self) {
        _aspectRatio = aspectRatio;
        if (SCDeviceSupportsMetal()) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            _metalLayer = metalLayer;
            _metalLayer.frame = [self _layerFrame];
            [self.layer insertSublayer:_metalLayer below:[self.layer sublayers][0]];
            [CATransaction commit];
        } else {
            _containerLayer = [[CALayer alloc] init];
            _containerLayer.frame = [self _layerFrame];
            // Using a container layer such that the software zooming is happening on this layer
            [self.layer insertSublayer:_containerLayer below:[self.layer sublayers][0]];
        }
        if ([self _shouldShowDebugView]) {
            _debugView = [[SCManagedCapturePreviewViewDebugView alloc] init];
            [self addSubview:_debugView];
        }
    }
    return self;
}

- (void)_layoutVideoPreviewLayer
{
    SCAssertMainThread();
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (SCDeviceSupportsMetal()) {
        _metalLayer.frame = [self _layerFrame];
    } else {
        if (_videoPreviewLayer) {
            SCLogGeneralInfo(@"container layer frame %@, video preview layer frame %@",
                             NSStringFromCGRect(_containerLayer.frame), NSStringFromCGRect(_videoPreviewLayer.frame));
        }
        // Using bounds because we don't really care about the position at this point.
        _containerLayer.frame = [self _layerFrame];
        _videoPreviewLayer.frame = _containerLayer.bounds;
        _videoPreviewLayer.position =
            CGPointMake(CGRectGetWidth(_containerLayer.bounds) * 0.5, CGRectGetHeight(_containerLayer.bounds) * 0.5);
    }
    [CATransaction commit];
}

- (void)_layoutVideoPreviewGLView
{
    SCCAssertMainThread();
    _videoPreviewGLView.frame = [self _layerFrame];
}

- (CGRect)_layerFrame
{
    CGRect frame = SCRectMakeWithCenterAndSize(
        SCRectGetMid(self.bounds), SCSizeIntegral(SCSizeExpandToAspectRatio(self.bounds.size, _aspectRatio)));

    CGFloat x = frame.origin.x;
    x = isnan(x) ? 0.0 : (isfinite(x) ? x : INFINITY);

    CGFloat y = frame.origin.y;
    y = isnan(y) ? 0.0 : (isfinite(y) ? y : INFINITY);

    CGFloat width = frame.size.width;
    width = isnan(width) ? 0.0 : (isfinite(width) ? width : INFINITY);

    CGFloat height = frame.size.height;
    height = isnan(height) ? 0.0 : (isfinite(height) ? height : INFINITY);

    return CGRectMake(x, y, width, height);
}

- (void)setVideoPreviewLayer:(AVCaptureVideoPreviewLayer *)videoPreviewLayer
{
    SCAssertMainThread();
    if (_videoPreviewLayer != videoPreviewLayer) {
        [_videoPreviewLayer removeFromSuperlayer];
        _videoPreviewLayer = videoPreviewLayer;
        [_containerLayer addSublayer:_videoPreviewLayer];
        [self _layoutVideoPreviewLayer];
    }
}

- (void)setupMetalLayer:(CALayer *)metalLayer
{
    SCAssert(!_metalLayer, @"_metalLayer should be nil.");
    SCAssert(metalLayer, @"metalLayer must exists.");
    SCAssertMainThread();
    _metalLayer = metalLayer;
    [self.layer insertSublayer:_metalLayer below:[self.layer sublayers][0]];
    [self _layoutVideoPreviewLayer];
}

- (void)setVideoPreviewGLView:(LSAGLView *)videoPreviewGLView
{
    SCAssertMainThread();
    if (_videoPreviewGLView != videoPreviewGLView) {
        [_videoPreviewGLView removeFromSuperview];
        _videoPreviewGLView = videoPreviewGLView;
        [self addSubview:_videoPreviewGLView];
        [self _layoutVideoPreviewGLView];
    }
}

#pragma mark - Overridden methods

- (void)layoutSubviews
{
    SCAssertMainThread();
    [super layoutSubviews];
    [self _layoutVideoPreviewLayer];
    [self _layoutVideoPreviewGLView];
    [self _layoutDebugViewIfNeeded];
}

- (void)setHidden:(BOOL)hidden
{
    SCAssertMainThread();
    [super setHidden:hidden];
    if (hidden) {
        SCLogGeneralInfo(@"[SCManagedCapturePreviewView] - isHidden is being set to YES");
    }
}

#pragma mark - Debug View

- (BOOL)_shouldShowDebugView
{
    // Only show debug view in internal builds and tweak settings are turned on.
    return SCIsInternalBuild() &&
           (SCCameraTweaksEnableFocusPointObservation() || SCCameraTweaksEnableExposurePointObservation());
}

- (void)_layoutDebugViewIfNeeded
{
    SCAssertMainThread();
    SC_GUARD_ELSE_RETURN([self _shouldShowDebugView]);
    _debugView.frame = self.bounds;
    [self bringSubviewToFront:_debugView];
}

@end
