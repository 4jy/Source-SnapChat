//
//  SCManagedStillImageCapturerHandler.m
//  Snapchat
//
//  Created by Jingtian Yang on 11/12/2017.
//

#import "SCManagedStillImageCapturerHandler.h"

#import "SCCaptureResource.h"
#import "SCManagedCaptureDevice+SCManagedCapturer.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerSampleMetadata.h"
#import "SCManagedCapturerState.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCManagedStillImageCapturerHandler () {
    __weak SCCaptureResource *_captureResource;
}

@end

@implementation SCManagedStillImageCapturerHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super init];
    if (self) {
        SCAssert(captureResource, @"");
        _captureResource = captureResource;
    }
    return self;
}

- (void)managedStillImageCapturerWillCapturePhoto:(SCManagedStillImageCapturer *)managedStillImageCapturer
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Will capture photo. stillImageCapturer:%@", _captureResource.stillImageCapturer);
    [_captureResource.queuePerformer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        if (_captureResource.stillImageCapturer) {
            SCManagedCapturerState *state = [_captureResource.state copy];
            SCManagedCapturerSampleMetadata *sampleMetadata = [[SCManagedCapturerSampleMetadata alloc]
                initWithPresentationTimestamp:kCMTimeZero
                                  fieldOfView:_captureResource.device.fieldOfView];
            runOnMainThreadAsynchronously(^{
                [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                           willCapturePhoto:state
                                             sampleMetadata:sampleMetadata];
            });
        }
    }];
}

- (void)managedStillImageCapturerDidCapturePhoto:(SCManagedStillImageCapturer *)managedStillImageCapturer
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Did capture photo. stillImageCapturer:%@", _captureResource.stillImageCapturer);
    [_captureResource.queuePerformer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        if (_captureResource.stillImageCapturer) {
            SCManagedCapturerState *state = [_captureResource.state copy];
            runOnMainThreadAsynchronously(^{
                [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didCapturePhoto:state];
            });
        }
    }];
}

- (BOOL)managedStillImageCapturerIsUnderDeviceMotion:(SCManagedStillImageCapturer *)managedStillImageCapturer
{
    return _captureResource.deviceMotionProvider.isUnderDeviceMotion;
}

- (BOOL)managedStillImageCapturerShouldProcessFileInput:(SCManagedStillImageCapturer *)managedStillImageCapturer
{
    return _captureResource.fileInputDecider.shouldProcessFileInput;
}

@end
