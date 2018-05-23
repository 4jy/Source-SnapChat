//
//  SCManagedDeviceCapacityAnalyzerHandler.m
//  Snapchat
//
//  Created by Jingtian Yang on 11/12/2017.
//

#import "SCManagedDeviceCapacityAnalyzerHandler.h"

#import "SCCaptureResource.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerState.h"
#import "SCManagedCapturerStateBuilder.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCManagedDeviceCapacityAnalyzerHandler () {
    __weak SCCaptureResource *_captureResource;
}
@end

@implementation SCManagedDeviceCapacityAnalyzerHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super init];
    if (self) {
        SCAssert(captureResource, @"");
        _captureResource = captureResource;
    }
    return self;
}

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeLowLightCondition:(BOOL)lowLightCondition
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Change Low Light Condition %d", lowLightCondition);
    [_captureResource.queuePerformer perform:^{
        _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
            setLowLightCondition:lowLightCondition] build];
        SCManagedCapturerState *state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didChangeState:state];
            [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                             didChangeLowLightCondition:state];
        });
    }];
}

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
           didChangeAdjustingExposure:(BOOL)adjustingExposure
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Capacity Analyzer Changes adjustExposure %d", adjustingExposure);
    [_captureResource.queuePerformer perform:^{
        _captureResource.state = [[[SCManagedCapturerStateBuilder withManagedCapturerState:_captureResource.state]
            setAdjustingExposure:adjustingExposure] build];
        SCManagedCapturerState *state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance] didChangeState:state];
            [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                             didChangeAdjustingExposure:state];
        });
    }];
}

@end
