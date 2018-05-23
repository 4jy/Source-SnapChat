//
//  SCCaptureResource.m
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCCaptureResource.h"

#import "SCBlackCameraDetector.h"
#import "SCManagedCapturerState.h"
#import "SCManagedFrontFlashController.h"
#import "SCManagedVideoCapturer.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>

#import <FBKVOController/FBKVOController.h>

@interface SCCaptureResource () {
    FBKVOController *_previewHiddenKVO;
}

@end

@implementation SCCaptureResource

- (SCManagedFrontFlashController *)frontFlashController
{
    SCTraceODPCompatibleStart(2);
    SCAssert([self.queuePerformer isCurrentPerformer], @"");
    if (!_frontFlashController) {
        _frontFlashController = [[SCManagedFrontFlashController alloc] init];
    }
    return _frontFlashController;
}

- (void)setVideoPreviewLayer:(AVCaptureVideoPreviewLayer *)layer
{
    SC_GUARD_ELSE_RETURN(layer != _videoPreviewLayer);

    if (_videoPreviewLayer) {
        [_previewHiddenKVO unobserve:_videoPreviewLayer];
    }
    _videoPreviewLayer = layer;

    SC_GUARD_ELSE_RETURN(_videoPreviewLayer);

    if (!_previewHiddenKVO) {
        _previewHiddenKVO = [[FBKVOController alloc] initWithObserver:self];
    }

    [_previewHiddenKVO observe:_videoPreviewLayer
                       keyPath:@keypath(_videoPreviewLayer.hidden)
                       options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                         block:^(id observer, id object, NSDictionary *change) {
                             BOOL oldValue = [change[NSKeyValueChangeOldKey] boolValue];
                             BOOL newValue = [change[NSKeyValueChangeNewKey] boolValue];
                             if (oldValue != newValue) {
                                 [_blackCameraDetector capturePreviewDidBecomeVisible:!newValue];
                             }
                         }];
}
@end
