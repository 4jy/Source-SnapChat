//
//  SCManagedDeviceCapacityAnalyzer.m
//  Snapchat
//
//  Created by Liu Liu on 5/1/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedDeviceCapacityAnalyzer.h"

#import "SCCameraSettingUtils.h"
#import "SCCameraTweaks.h"
#import "SCManagedCaptureDevice+SCManagedDeviceCapacityAnalyzer.h"
#import "SCManagedCaptureDevice.h"
#import "SCManagedDeviceCapacityAnalyzerListenerAnnouncer.h"

#import <SCFoundation/SCAppEnvironment.h>
#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCPerforming.h>
#import <SCFoundation/SCTrace.h>

#import <FBKVOController/FBKVOController.h>

@import ImageIO;
@import QuartzCore;

NSInteger const kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor6WithHRSI = 500;

NSInteger const kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor6S = 800;

NSInteger const kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor7 = 640;

NSInteger const kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor8 = 800;

// After this much frames we haven't changed exposure time or ISO, we will assume that the adjustingExposure is ended.
static NSInteger const kExposureUnchangedHighWatermark = 5;
// If deadline reached, and we still haven't reached high watermark yet, we will consult the low watermark and at least
// give the system a chance to take not-so-great pictures.
static NSInteger const kExposureUnchangedLowWatermark = 1;
static NSTimeInterval const kExposureUnchangedDeadline = 0.2;

// It seems that between ISO 500 to 640, the brightness value is always somewhere around -0.4 to -0.5.
// Therefore, this threshold probably will work fine.
static float const kBrightnessValueThreshold = -2.25;
// Give some margins between recognized as bright enough and not enough light.
// If the brightness is lower than kBrightnessValueThreshold - kBrightnessValueThresholdConfidenceInterval,
// and then we count the frame as low light frame. Only if the brightness is higher than
// kBrightnessValueThreshold + kBrightnessValueThresholdConfidenceInterval, we think that we
// have enough light, and reset low light frame count to 0. 0.5 is choosing because in dark
// environment, the brightness value changes +-0.3 with minor orientation changes.
static float const kBrightnessValueThresholdConfidenceInterval = 0.5;
// If we are at good light condition for 5 frames, ready to change back
static NSInteger const kLowLightBoostUnchangedLowWatermark = 7;
// Requires we are at low light condition for ~2 seconds (assuming 20~30fps)
static NSInteger const kLowLightBoostUnchangedHighWatermark = 25;

static NSInteger const kSCLightingConditionDecisionWatermark = 15; // For 30 fps, it is 0.5 second
static float const kSCLightingConditionNormalThreshold = 0;
static float const kSCLightingConditionDarkThreshold = -3;

@implementation SCManagedDeviceCapacityAnalyzer {
    float _lastExposureTime;
    int _lastISOSpeedRating;
    NSTimeInterval _lastAdjustingExposureStartTime;

    NSInteger _lowLightBoostLowLightCount;
    NSInteger _lowLightBoostEnoughLightCount;
    NSInteger _exposureUnchangedCount;
    NSInteger _maxISOPresetHigh;

    NSInteger _normalLightingConditionCount;
    NSInteger _darkLightingConditionCount;
    NSInteger _extremeDarkLightingConditionCount;
    SCCapturerLightingConditionType _lightingCondition;

    BOOL _lowLightCondition;
    BOOL _adjustingExposure;

    SCManagedDeviceCapacityAnalyzerListenerAnnouncer *_announcer;
    FBKVOController *_observeController;
    id<SCPerforming> _performer;

    float
        _lastBrightnessToLog; // Remember last logged brightness, only log again if it changes greater than a threshold
}

- (instancetype)initWithPerformer:(id<SCPerforming>)performer
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _performer = performer;
        _maxISOPresetHigh = kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor6WithHRSI;
        if ([SCDeviceName isIphone] && [SCDeviceName isSimilarToIphone8orNewer]) {
            _maxISOPresetHigh = kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor8;
        } else if ([SCDeviceName isIphone] && [SCDeviceName isSimilarToIphone7orNewer]) {
            _maxISOPresetHigh = kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor7;
        } else if ([SCDeviceName isIphone] && [SCDeviceName isSimilarToIphone6SorNewer]) {
            // iPhone 6S supports higher ISO rate for video recording, accommadating that.
            _maxISOPresetHigh = kSCManagedDeviceCapacityAnalyzerMaxISOPresetHighFor6S;
        }
        _announcer = [[SCManagedDeviceCapacityAnalyzerListenerAnnouncer alloc] init];
        _observeController = [[FBKVOController alloc] initWithObserver:self];
    }
    return self;
}

- (void)addListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener
{
    SCTraceStart();
    [_announcer addListener:listener];
}

- (void)removeListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener
{
    SCTraceStart();
    [_announcer removeListener:listener];
}

- (void)setLowLightConditionEnabled:(BOOL)lowLightConditionEnabled
{
    SCTraceStart();
    if (_lowLightConditionEnabled != lowLightConditionEnabled) {
        _lowLightConditionEnabled = lowLightConditionEnabled;
        if (!lowLightConditionEnabled) {
            _lowLightBoostLowLightCount = 0;
            _lowLightBoostEnoughLightCount = 0;
            _lowLightCondition = NO;
            [_announcer managedDeviceCapacityAnalyzer:self didChangeLowLightCondition:_lowLightCondition];
        }
    }
}

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceStart();
    SampleBufferMetadata metadata = {
        .isoSpeedRating = _lastISOSpeedRating, .brightness = 0, .exposureTime = _lastExposureTime,
    };
    retrieveSampleBufferMetadata(sampleBuffer, &metadata);
    if ((SCIsDebugBuild() || SCIsMasterBuild())
        // Enable this on internal build only (excluding alpha)
        && fabs(metadata.brightness - _lastBrightnessToLog) > 0.5f) {
        // Log only when brightness change is greater than 0.5
        _lastBrightnessToLog = metadata.brightness;
        SCLogCoreCameraInfo(@"ExposureTime: %f, ISO: %ld, Brightness: %f", metadata.exposureTime,
                            (long)metadata.isoSpeedRating, metadata.brightness);
    }
    [self _automaticallyDetectAdjustingExposure:metadata.exposureTime ISOSpeedRating:metadata.isoSpeedRating];
    _lastExposureTime = metadata.exposureTime;
    _lastISOSpeedRating = metadata.isoSpeedRating;
    if (!_adjustingExposure && _lastISOSpeedRating <= _maxISOPresetHigh &&
        _lowLightConditionEnabled) { // If we are not recording, we are not at ISO higher than we needed
        [self _automaticallyDetectLowLightCondition:metadata.brightness];
    }
    [self _automaticallyDetectLightingConditionWithBrightness:metadata.brightness];
    [_announcer managedDeviceCapacityAnalyzer:self didChangeBrightness:metadata.brightness];
}

- (void)setAsFocusListenerForDevice:(SCManagedCaptureDevice *)captureDevice
{
    SCTraceStart();
    [_observeController observe:captureDevice.device
                        keyPath:@keypath(captureDevice.device, adjustingFocus)
                        options:NSKeyValueObservingOptionNew
                         action:@selector(_adjustingFocusingChanged:)];
}

- (void)removeFocusListener
{
    SCTraceStart();
    [_observeController unobserveAll];
}

#pragma mark - Private methods

- (void)_automaticallyDetectAdjustingExposure:(float)currentExposureTime ISOSpeedRating:(NSInteger)currentISOSpeedRating
{
    SCTraceStart();
    if (currentISOSpeedRating != _lastISOSpeedRating || fabsf(currentExposureTime - _lastExposureTime) > FLT_MIN) {
        _exposureUnchangedCount = 0;
    } else {
        ++_exposureUnchangedCount;
    }
    NSTimeInterval currentTime = CACurrentMediaTime();
    if (_exposureUnchangedCount >= kExposureUnchangedHighWatermark ||
        (currentTime - _lastAdjustingExposureStartTime > kExposureUnchangedDeadline &&
         _exposureUnchangedCount >= kExposureUnchangedLowWatermark)) {
        // The exposure values haven't changed for kExposureUnchangedHighWatermark times, considering the adjustment
        // as done. Otherwise, if we waited long enough, and the exposure unchange count at least reached low
        // watermark, we will call it done and give it a shot.
        if (_adjustingExposure) {
            _adjustingExposure = NO;
            SCLogGeneralInfo(@"Adjusting exposure is done, unchanged count: %zd", _exposureUnchangedCount);
            [_announcer managedDeviceCapacityAnalyzer:self didChangeAdjustingExposure:_adjustingExposure];
        }
    } else {
        // Otherwise signal that we have adjustments on exposure
        if (!_adjustingExposure) {
            _adjustingExposure = YES;
            _lastAdjustingExposureStartTime = currentTime;
            [_announcer managedDeviceCapacityAnalyzer:self didChangeAdjustingExposure:_adjustingExposure];
        }
    }
}

- (void)_automaticallyDetectLowLightCondition:(float)brightness
{
    SCTraceStart();
    if (!_lowLightCondition && _lastISOSpeedRating == _maxISOPresetHigh) {
        // If we are at the stage that we need to use higher ISO (because current ISO is maxed out)
        // and the brightness is lower than the threshold
        if (brightness < kBrightnessValueThreshold - kBrightnessValueThresholdConfidenceInterval) {
            // Either count how many frames like this continuously we encountered
            // Or if reached the watermark, change the low light boost mode
            if (_lowLightBoostLowLightCount >= kLowLightBoostUnchangedHighWatermark) {
                _lowLightCondition = YES;
                [_announcer managedDeviceCapacityAnalyzer:self didChangeLowLightCondition:_lowLightCondition];
            } else {
                ++_lowLightBoostLowLightCount;
            }
        } else if (brightness >= kBrightnessValueThreshold + kBrightnessValueThresholdConfidenceInterval) {
            // If the brightness is consistently better, reset the low light boost unchanged count to 0
            _lowLightBoostLowLightCount = 0;
        }
    } else if (_lowLightCondition) {
        // Check the current ISO to see if we can disable low light boost
        if (_lastISOSpeedRating <= _maxISOPresetHigh &&
            brightness >= kBrightnessValueThreshold + kBrightnessValueThresholdConfidenceInterval) {
            if (_lowLightBoostEnoughLightCount >= kLowLightBoostUnchangedLowWatermark) {
                _lowLightCondition = NO;
                [_announcer managedDeviceCapacityAnalyzer:self didChangeLowLightCondition:_lowLightCondition];
                _lowLightBoostEnoughLightCount = 0;
            } else {
                ++_lowLightBoostEnoughLightCount;
            }
        }
    }
}

- (void)_adjustingFocusingChanged:(NSDictionary *)change
{
    SCTraceStart();
    BOOL adjustingFocus = [change[NSKeyValueChangeNewKey] boolValue];
    [_performer perform:^{
        [_announcer managedDeviceCapacityAnalyzer:self didChangeAdjustingFocus:adjustingFocus];
    }];
}

- (void)_automaticallyDetectLightingConditionWithBrightness:(float)brightness
{
    if (brightness >= kSCLightingConditionNormalThreshold) {
        if (_normalLightingConditionCount > kSCLightingConditionDecisionWatermark) {
            if (_lightingCondition != SCCapturerLightingConditionTypeNormal) {
                _lightingCondition = SCCapturerLightingConditionTypeNormal;
                [_announcer managedDeviceCapacityAnalyzer:self
                               didChangeLightingCondition:SCCapturerLightingConditionTypeNormal];
            }
        } else {
            _normalLightingConditionCount++;
        }
        _darkLightingConditionCount = 0;
        _extremeDarkLightingConditionCount = 0;
    } else if (brightness >= kSCLightingConditionDarkThreshold) {
        if (_darkLightingConditionCount > kSCLightingConditionDecisionWatermark) {
            if (_lightingCondition != SCCapturerLightingConditionTypeDark) {
                _lightingCondition = SCCapturerLightingConditionTypeDark;
                [_announcer managedDeviceCapacityAnalyzer:self
                               didChangeLightingCondition:SCCapturerLightingConditionTypeDark];
            }
        } else {
            _darkLightingConditionCount++;
        }
        _normalLightingConditionCount = 0;
        _extremeDarkLightingConditionCount = 0;
    } else {
        if (_extremeDarkLightingConditionCount > kSCLightingConditionDecisionWatermark) {
            if (_lightingCondition != SCCapturerLightingConditionTypeExtremeDark) {
                _lightingCondition = SCCapturerLightingConditionTypeExtremeDark;
                [_announcer managedDeviceCapacityAnalyzer:self
                               didChangeLightingCondition:SCCapturerLightingConditionTypeExtremeDark];
            }
        } else {
            _extremeDarkLightingConditionCount++;
        }
        _normalLightingConditionCount = 0;
        _darkLightingConditionCount = 0;
    }
}

@end
