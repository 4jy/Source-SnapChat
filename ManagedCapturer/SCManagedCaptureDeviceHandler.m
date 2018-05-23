//
//  SCManagedCaptureDeviceHandler.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/8/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureDeviceHandler.h"

#import "SCCaptureResource.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerState.h"
#import "SCManagedCapturerStateBuilder.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCManagedCaptureDeviceHandler ()

@property (nonatomic, weak) SCCaptureResource *captureResource;

@end

@implementation SCManagedCaptureDeviceHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super init];
    if (self) {
        SCAssert(captureResource, @"SCCaptureResource should not be nil.");
        _captureResource = captureResource;
    }
    return self;
}

- (void)managedCaptureDevice:(SCManagedCaptureDevice *)device didChangeAdjustingExposure:(BOOL)adjustingExposure
{
    SC_GUARD_ELSE_RETURN(device == _captureResource.device);
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"KVO Changes adjustingExposure %d", adjustingExposure);
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

- (void)managedCaptureDevice:(SCManagedCaptureDevice *)device didChangeExposurePoint:(CGPoint)exposurePoint
{
    SC_GUARD_ELSE_RETURN(device == self.captureResource.device);
    SCTraceODPCompatibleStart(2);
    runOnMainThreadAsynchronously(^{
        [self.captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                 didChangeExposurePoint:exposurePoint];
    });
}

- (void)managedCaptureDevice:(SCManagedCaptureDevice *)device didChangeFocusPoint:(CGPoint)focusPoint
{
    SC_GUARD_ELSE_RETURN(device == self.captureResource.device);
    SCTraceODPCompatibleStart(2);
    runOnMainThreadAsynchronously(^{
        [self.captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                    didChangeFocusPoint:focusPoint];
    });
}

@end
