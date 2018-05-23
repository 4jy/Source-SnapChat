//
//  SCCaptureDeviceResolver.m
//  Snapchat
//
//  Created by Lin Jia on 11/8/17.
//
//

#import "SCCaptureDeviceResolver.h"

#import "SCCameraTweaks.h"

#import <SCBase/SCAvailability.h>
#import <SCFoundation/SCAssertWrapper.h>

@interface SCCaptureDeviceResolver () {
    AVCaptureDeviceDiscoverySession *_discoverySession;
}

@end

@implementation SCCaptureDeviceResolver

+ (instancetype)sharedInstance
{
    static SCCaptureDeviceResolver *resolver;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        resolver = [[SCCaptureDeviceResolver alloc] init];
    });
    return resolver;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSMutableArray *deviceTypes = [[NSMutableArray alloc] init];
        [deviceTypes addObject:AVCaptureDeviceTypeBuiltInWideAngleCamera];
        if (SC_AT_LEAST_IOS_10_2) {
            [deviceTypes addObject:AVCaptureDeviceTypeBuiltInDualCamera];
        }
        // TODO: we should KVO _discoverySession.devices.
        _discoverySession =
            [AVCaptureDeviceDiscoverySession discoverySessionWithDeviceTypes:deviceTypes
                                                                   mediaType:AVMediaTypeVideo
                                                                    position:AVCaptureDevicePositionUnspecified];
    }
    return self;
}

- (AVCaptureDevice *)findAVCaptureDevice:(AVCaptureDevicePosition)position
{
    SCAssert(position == AVCaptureDevicePositionFront || position == AVCaptureDevicePositionBack, @"");
    AVCaptureDevice *captureDevice;
    if (position == AVCaptureDevicePositionFront) {
        captureDevice = [self _pickBestFrontCamera:[_discoverySession.devices copy]];
    } else if (position == AVCaptureDevicePositionBack) {
        captureDevice = [self _pickBestBackCamera:[_discoverySession.devices copy]];
    }
    if (captureDevice) {
        return captureDevice;
    }

    if (SC_AT_LEAST_IOS_10_2 && SCCameraTweaksEnableDualCamera()) {
        captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualCamera
                                                           mediaType:AVMediaTypeVideo
                                                            position:position];
        if (captureDevice) {
            return captureDevice;
        }
    }

    // if code still execute, discoverSession failed, then we keep searching.
    captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                                       mediaType:AVMediaTypeVideo
                                                        position:position];
    if (captureDevice) {
        return captureDevice;
    }

#if !TARGET_IPHONE_SIMULATOR
    // We do not return nil at the beginning of the function for simulator, because simulators of different IOS
    // versions can check whether or not our camera device API access is correct.
    SCAssertFail(@"No camera is found.");
#endif
    return nil;
}

- (AVCaptureDevice *)_pickBestFrontCamera:(NSArray<AVCaptureDevice *> *)devices
{
    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionFront) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)_pickBestBackCamera:(NSArray<AVCaptureDevice *> *)devices
{
    // Look for dual camera first if needed. If dual camera not found, continue to look for wide angle camera.
    if (SC_AT_LEAST_IOS_10_2 && SCCameraTweaksEnableDualCamera()) {
        for (AVCaptureDevice *device in devices) {
            if (device.position == AVCaptureDevicePositionBack &&
                device.deviceType == AVCaptureDeviceTypeBuiltInDualCamera) {
                return device;
            }
        }
    }

    for (AVCaptureDevice *device in devices) {
        if (device.position == AVCaptureDevicePositionBack &&
            device.deviceType == AVCaptureDeviceTypeBuiltInWideAngleCamera) {
            return device;
        }
    }
    return nil;
}

- (AVCaptureDevice *)findDualCamera
{
    if (SC_AT_LEAST_IOS_10_2) {
        for (AVCaptureDevice *device in [_discoverySession.devices copy]) {
            if (device.position == AVCaptureDevicePositionBack &&
                device.deviceType == AVCaptureDeviceTypeBuiltInDualCamera) {
                return device;
            }
        }
    }

    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInDualCamera
                                                                        mediaType:AVMediaTypeVideo
                                                                         position:AVCaptureDevicePositionBack];
    if (captureDevice) {
        return captureDevice;
    }

#if !TARGET_IPHONE_SIMULATOR
    // We do not return nil at the beginning of the function for simulator, because simulators of different IOS
    // versions can check whether or not our camera device API access is correct.
    SCAssertFail(@"No camera is found.");
#endif
    return nil;
}

@end
