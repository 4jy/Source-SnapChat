//
//  SCManagedCaptureDeviceDefaultZoomHandler.m
//  Snapchat
//
//  Created by Yu-Kuan Lai on 4/12/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceDefaultZoomHandler_Private.h"

#import "SCCaptureResource.h"
#import "SCManagedCaptureDevice+SCManagedCapturer.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerStateBuilder.h"
#import "SCMetalUtils.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@implementation SCManagedCaptureDeviceDefaultZoomHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super init];
    if (self) {
        _captureResource = captureResource;
    }

    return self;
}

- (void)setZoomFactor:(CGFloat)zoomFactor forDevice:(SCManagedCaptureDevice *)device immediately:(BOOL)immediately
{
    [self _setZoomFactor:zoomFactor forManagedCaptureDevice:device];
}

- (void)softwareZoomWithDevice:(SCManagedCaptureDevice *)device
{
    SCTraceODPCompatibleStart(2);
    SCAssert([_captureResource.queuePerformer isCurrentPerformer] ||
                 [[SCQueuePerformer mainQueuePerformer] isCurrentPerformer],
             @"");
    SCAssert(device.softwareZoom, @"Only do software zoom for software zoom device");

    SC_GUARD_ELSE_RETURN(!SCDeviceSupportsMetal());
    float zoomFactor = device.zoomFactor;
    SCLogCapturerInfo(@"Adjusting software zoom factor to: %f", zoomFactor);
    AVCaptureVideoPreviewLayer *videoPreviewLayer = _captureResource.videoPreviewLayer;
    [[SCQueuePerformer mainQueuePerformer] perform:^{
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        // I end up need to change its superlayer transform to get the zoom effect
        videoPreviewLayer.superlayer.affineTransform = CGAffineTransformMakeScale(zoomFactor, zoomFactor);
        [CATransaction commit];
    }];
}

- (void)_setZoomFactor:(CGFloat)zoomFactor forManagedCaptureDevice:(SCManagedCaptureDevice *)device
{
    SCTraceODPCompatibleStart(2);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (device) {
            SCLogCapturerInfo(@"Set zoom factor: %f -> %f", _captureResource.state.zoomFactor, zoomFactor);
            [device setZoomFactor:zoomFactor];
            BOOL zoomFactorChanged = NO;
            // If the device is our current device, send the notification, update the
            // state.
            if (device.isConnected && device == _captureResource.device) {
                if (device.softwareZoom) {
                    [self softwareZoomWithDevice:device];
                }
                _captureResource.state = [[[SCManagedCapturerStateBuilder
                    withManagedCapturerState:_captureResource.state] setZoomFactor:zoomFactor] build];
                zoomFactorChanged = YES;
            }
            SCManagedCapturerState *state = [_captureResource.state copy];
            runOnMainThreadAsynchronously(^{
                if (zoomFactorChanged) {
                    [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                                 didChangeState:state];
                    [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                            didChangeZoomFactor:state];
                }
            });
        }
    }];
}

@end
