//
//  SCManagedCaptureDeviceSubjectAreaHandler.m
//  Snapchat
//
//  Created by Xiaokang Liu on 19/03/2018.
//

#import "SCManagedCaptureDeviceSubjectAreaHandler.h"

#import "SCCameraTweaks.h"
#import "SCCaptureResource.h"
#import "SCCaptureWorker.h"
#import "SCManagedCaptureDevice+SCManagedCapturer.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerState.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>

@interface SCManagedCaptureDeviceSubjectAreaHandler () {
    __weak SCCaptureResource *_captureResource;
}
@end

@implementation SCManagedCaptureDeviceSubjectAreaHandler
- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super init];
    if (self) {
        SCAssert(captureResource, @"");
        _captureResource = captureResource;
    }
    return self;
}

- (void)stopObserving
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVCaptureDeviceSubjectAreaDidChangeNotification
                                                  object:nil];
}

- (void)startObserving
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_subjectAreaDidChange:)
                                                 name:AVCaptureDeviceSubjectAreaDidChangeNotification
                                               object:nil];
}

#pragma mark - Private methods
- (void)_subjectAreaDidChange:(NSDictionary *)notification
{
    [_captureResource.queuePerformer perform:^{
        if (_captureResource.device.isConnected && !_captureResource.state.arSessionActive) {
            // Reset to continuous autofocus when the subject area changed
            [_captureResource.device continuousAutofocus];
            [_captureResource.device setExposurePointOfInterest:CGPointMake(0.5, 0.5) fromUser:NO];
            if (SCCameraTweaksEnablePortraitModeAutofocus()) {
                [SCCaptureWorker setPortraitModePointOfInterestAsynchronously:CGPointMake(0.5, 0.5)
                                                            completionHandler:nil
                                                                     resource:_captureResource];
            }
        }
    }];
}
@end
