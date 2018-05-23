//
//  SCManagedCaptureDevice.m
//  Snapchat
//
//  Created by Liu Liu on 4/22/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedCaptureDevice.h"

#import "AVCaptureDevice+ConfigurationLock.h"
#import "SCCameraTweaks.h"
#import "SCCaptureCommon.h"
#import "SCCaptureDeviceResolver.h"
#import "SCManagedCaptureDevice+SCManagedCapturer.h"
#import "SCManagedCaptureDeviceAutoExposureHandler.h"
#import "SCManagedCaptureDeviceAutoFocusHandler.h"
#import "SCManagedCaptureDeviceExposureHandler.h"
#import "SCManagedCaptureDeviceFaceDetectionAutoExposureHandler.h"
#import "SCManagedCaptureDeviceFaceDetectionAutoFocusHandler.h"
#import "SCManagedCaptureDeviceFocusHandler.h"
#import "SCManagedCapturer.h"
#import "SCManagedDeviceCapacityAnalyzer.h"

#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCTrace.h>

#import <FBKVOController/FBKVOController.h>

static int32_t const kSCManagedCaptureDeviceMaximumHighFrameRate = 30;
static int32_t const kSCManagedCaptureDeviceMaximumLowFrameRate = 24;

static float const kSCManagedCaptureDevicecSoftwareMaxZoomFactor = 8;

CGFloat const kSCMaxVideoZoomFactor = 100; // the max videoZoomFactor acceptable
CGFloat const kSCMinVideoZoomFactor = 1;

static NSDictionary *SCBestHRSIFormatsForHeights(NSArray *desiredHeights, NSArray *formats, BOOL shouldSupportDepth)
{
    NSMutableDictionary *bestHRSIHeights = [NSMutableDictionary dictionary];
    for (NSNumber *height in desiredHeights) {
        bestHRSIHeights[height] = @0;
    }
    NSMutableDictionary *bestHRSIFormats = [NSMutableDictionary dictionary];
    for (AVCaptureDeviceFormat *format in formats) {
        if (@available(ios 11.0, *)) {
            if (shouldSupportDepth && format.supportedDepthDataFormats.count == 0) {
                continue;
            }
        }
        if (CMFormatDescriptionGetMediaSubType(format.formatDescription) !=
            kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) {
            continue;
        }
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
        NSNumber *height = @(dimensions.height);
        NSNumber *bestHRSI = bestHRSIHeights[height];
        if (bestHRSI) {
            CMVideoDimensions hrsi = format.highResolutionStillImageDimensions;
            // If we enabled HSRI, we only intersted in the ones that is good.
            if (hrsi.height > [bestHRSI intValue]) {
                bestHRSIHeights[height] = @(hrsi.height);
                bestHRSIFormats[height] = format;
            }
        }
    }
    return [bestHRSIFormats copy];
}

static inline float SCDegreesToRadians(float theta)
{
    return theta * (float)M_PI / 180.f;
}

static inline float SCRadiansToDegrees(float theta)
{
    return theta * 180.f / (float)M_PI;
}

@implementation SCManagedCaptureDevice {
    AVCaptureDevice *_device;
    AVCaptureDeviceInput *_deviceInput;
    AVCaptureDeviceFormat *_defaultFormat;
    AVCaptureDeviceFormat *_nightFormat;
    AVCaptureDeviceFormat *_liveVideoStreamingFormat;
    SCManagedCaptureDevicePosition _devicePosition;

    // Configurations on the device, shortcut to avoid re-configurations
    id<SCManagedCaptureDeviceExposureHandler> _exposureHandler;
    id<SCManagedCaptureDeviceFocusHandler> _focusHandler;

    FBKVOController *_observeController;

    // For the private category methods
    NSError *_error;
    BOOL _softwareZoom;
    BOOL _isConnected;
    BOOL _flashActive;
    BOOL _torchActive;
    BOOL _liveVideoStreamingActive;
    float _zoomFactor;
    BOOL _isNightModeActive;
    BOOL _captureDepthData;
}
@synthesize fieldOfView = _fieldOfView;

+ (instancetype)front
{
    SCTraceStart();
    static dispatch_once_t onceToken;
    static SCManagedCaptureDevice *front;
    static dispatch_semaphore_t semaphore;
    dispatch_once(&onceToken, ^{
        semaphore = dispatch_semaphore_create(1);
    });
    /* You can use the tweak below to intentionally kill camera in debug.
    if (SCIsDebugBuild() && SCCameraTweaksKillFrontCamera()) {
        return nil;
    }
     */
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!front) {
        AVCaptureDevice *device =
            [[SCCaptureDeviceResolver sharedInstance] findAVCaptureDevice:AVCaptureDevicePositionFront];
        if (device) {
            front = [[SCManagedCaptureDevice alloc] initWithDevice:device
                                                    devicePosition:SCManagedCaptureDevicePositionFront];
        }
    }
    dispatch_semaphore_signal(semaphore);
    return front;
}

+ (instancetype)back
{
    SCTraceStart();
    static dispatch_once_t onceToken;
    static SCManagedCaptureDevice *back;
    static dispatch_semaphore_t semaphore;
    dispatch_once(&onceToken, ^{
        semaphore = dispatch_semaphore_create(1);
    });
    /* You can use the tweak below to intentionally kill camera in debug.
     if (SCIsDebugBuild() &&  SCCameraTweaksKillBackCamera()) {
       return nil;
     }
     */
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!back) {
        AVCaptureDevice *device =
            [[SCCaptureDeviceResolver sharedInstance] findAVCaptureDevice:AVCaptureDevicePositionBack];
        if (device) {
            back = [[SCManagedCaptureDevice alloc] initWithDevice:device
                                                   devicePosition:SCManagedCaptureDevicePositionBack];
        }
    }
    dispatch_semaphore_signal(semaphore);
    return back;
}

+ (SCManagedCaptureDevice *)dualCamera
{
    SCTraceStart();
    static dispatch_once_t onceToken;
    static SCManagedCaptureDevice *dualCamera;
    static dispatch_semaphore_t semaphore;
    dispatch_once(&onceToken, ^{
        semaphore = dispatch_semaphore_create(1);
    });
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    if (!dualCamera) {
        AVCaptureDevice *device = [[SCCaptureDeviceResolver sharedInstance] findDualCamera];
        if (device) {
            dualCamera = [[SCManagedCaptureDevice alloc] initWithDevice:device
                                                         devicePosition:SCManagedCaptureDevicePositionBackDualCamera];
        }
    }
    dispatch_semaphore_signal(semaphore);
    return dualCamera;
}

+ (instancetype)deviceWithPosition:(SCManagedCaptureDevicePosition)position
{
    switch (position) {
    case SCManagedCaptureDevicePositionFront:
        return [self front];
    case SCManagedCaptureDevicePositionBack:
        return [self back];
    case SCManagedCaptureDevicePositionBackDualCamera:
        return [self dualCamera];
    }
}

+ (BOOL)is1080pSupported
{
    return [SCDeviceName isIphone] && [SCDeviceName isSimilarToIphone6SorNewer];
}

+ (BOOL)isMixCaptureSupported
{
    return !![self front] && !![self back];
}

+ (BOOL)isNightModeSupported
{
    return [SCDeviceName isIphone] && [SCDeviceName isSimilarToIphone6orNewer];
}

+ (BOOL)isEnhancedNightModeSupported
{
    if (SC_AT_LEAST_IOS_11) {
        return [SCDeviceName isIphone] && [SCDeviceName isSimilarToIphone6SorNewer];
    }
    return NO;
}

+ (CGSize)defaultActiveFormatResolution
{
    if ([SCDeviceName isIphoneX]) {
        return CGSizeMake(kSCManagedCapturerVideoActiveFormatWidth1080p,
                          kSCManagedCapturerVideoActiveFormatHeight1080p);
    }
    return CGSizeMake(kSCManagedCapturerDefaultVideoActiveFormatWidth,
                      kSCManagedCapturerDefaultVideoActiveFormatHeight);
}

+ (CGSize)nightModeActiveFormatResolution
{
    if ([SCManagedCaptureDevice isEnhancedNightModeSupported]) {
        return CGSizeMake(kSCManagedCapturerNightVideoHighResActiveFormatWidth,
                          kSCManagedCapturerNightVideoHighResActiveFormatHeight);
    }
    return CGSizeMake(kSCManagedCapturerNightVideoDefaultResActiveFormatWidth,
                      kSCManagedCapturerNightVideoDefaultResActiveFormatHeight);
}

- (instancetype)initWithDevice:(AVCaptureDevice *)device devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _device = device;
        _devicePosition = devicePosition;

        if (SCCameraTweaksEnableFaceDetectionFocus(devicePosition)) {
            _exposureHandler = [[SCManagedCaptureDeviceFaceDetectionAutoExposureHandler alloc]
                 initWithDevice:device
                pointOfInterest:CGPointMake(0.5, 0.5)
                managedCapturer:[SCManagedCapturer sharedInstance]];
            _focusHandler = [[SCManagedCaptureDeviceFaceDetectionAutoFocusHandler alloc]
                 initWithDevice:device
                pointOfInterest:CGPointMake(0.5, 0.5)
                managedCapturer:[SCManagedCapturer sharedInstance]];
        } else {
            _exposureHandler = [[SCManagedCaptureDeviceAutoExposureHandler alloc] initWithDevice:device
                                                                                 pointOfInterest:CGPointMake(0.5, 0.5)];
            _focusHandler = [[SCManagedCaptureDeviceAutoFocusHandler alloc] initWithDevice:device
                                                                           pointOfInterest:CGPointMake(0.5, 0.5)];
        }
        _observeController = [[FBKVOController alloc] initWithObserver:self];
        [self _setAsExposureListenerForDevice:device];
        if (SCCameraTweaksEnableExposurePointObservation()) {
            [self _observeExposurePointForDevice:device];
        }
        if (SCCameraTweaksEnableFocusPointObservation()) {
            [self _observeFocusPointForDevice:device];
        }

        _zoomFactor = 1.0;
        [self _findSupportedFormats];
    }
    return self;
}

- (SCManagedCaptureDevicePosition)position
{
    return _devicePosition;
}

#pragma mark - Setup and hook up with device

- (BOOL)setDeviceAsInput:(AVCaptureSession *)session
{
    SCTraceStart();
    AVCaptureDeviceInput *deviceInput = [self deviceInput];
    if ([session canAddInput:deviceInput]) {
        [session addInput:deviceInput];
    } else {
        NSString *previousSessionPreset = session.sessionPreset;
        session.sessionPreset = AVCaptureSessionPresetInputPriority;
        // Now we surely can add input
        if ([session canAddInput:deviceInput]) {
            [session addInput:deviceInput];
        } else {
            session.sessionPreset = previousSessionPreset;
            return NO;
        }
    }

    [self _enableSubjectAreaChangeMonitoring];

    [self _updateActiveFormatWithSession:session fallbackPreset:AVCaptureSessionPreset640x480];
    if (_device.activeFormat.videoMaxZoomFactor < 1 + 1e-5) {
        _softwareZoom = YES;
    } else {
        _softwareZoom = NO;
        if (_device.videoZoomFactor != _zoomFactor) {
            // Reset the zoom factor
            [self setZoomFactor:_zoomFactor];
        }
    }

    [_exposureHandler setVisible:YES];
    [_focusHandler setVisible:YES];

    _isConnected = YES;

    return YES;
}

- (void)removeDeviceAsInput:(AVCaptureSession *)session
{
    SCTraceStart();
    if (_isConnected) {
        [session removeInput:_deviceInput];
        [_exposureHandler setVisible:NO];
        [_focusHandler setVisible:NO];
        _isConnected = NO;
    }
}

- (void)resetDeviceAsInput
{
    _deviceInput = nil;
    AVCaptureDevice *deviceFound;
    switch (_devicePosition) {
    case SCManagedCaptureDevicePositionFront:
        deviceFound = [[SCCaptureDeviceResolver sharedInstance] findAVCaptureDevice:AVCaptureDevicePositionFront];
        break;
    case SCManagedCaptureDevicePositionBack:
        deviceFound = [[SCCaptureDeviceResolver sharedInstance] findAVCaptureDevice:AVCaptureDevicePositionBack];
        break;
    case SCManagedCaptureDevicePositionBackDualCamera:
        deviceFound = [[SCCaptureDeviceResolver sharedInstance] findDualCamera];
        break;
    }
    if (deviceFound) {
        _device = deviceFound;
    }
}

#pragma mark - Configurations

- (void)_findSupportedFormats
{
    NSInteger defaultHeight = [SCManagedCaptureDevice defaultActiveFormatResolution].height;
    NSInteger nightHeight = [SCManagedCaptureDevice nightModeActiveFormatResolution].height;
    NSInteger liveVideoStreamingHeight = kSCManagedCapturerLiveStreamingVideoActiveFormatHeight;
    NSArray *heights = @[ @(nightHeight), @(defaultHeight), @(liveVideoStreamingHeight) ];
    BOOL formatsShouldSupportDepth = _devicePosition == SCManagedCaptureDevicePositionBackDualCamera;
    NSDictionary *formats = SCBestHRSIFormatsForHeights(heights, _device.formats, formatsShouldSupportDepth);
    _nightFormat = formats[@(nightHeight)];
    _defaultFormat = formats[@(defaultHeight)];
    _liveVideoStreamingFormat = formats[@(liveVideoStreamingHeight)];
}

- (AVCaptureDeviceFormat *)_bestSupportedFormat
{
    if (_isNightModeActive) {
        return _nightFormat;
    }
    if (_liveVideoStreamingActive) {
        return _liveVideoStreamingFormat;
    }
    return _defaultFormat;
}

- (void)setNightModeActive:(BOOL)nightModeActive session:(AVCaptureSession *)session
{
    SCTraceStart();
    if (![SCManagedCaptureDevice isNightModeSupported]) {
        return;
    }
    if (_isNightModeActive == nightModeActive) {
        return;
    }
    _isNightModeActive = nightModeActive;
    [self updateActiveFormatWithSession:session];
}

- (void)setLiveVideoStreaming:(BOOL)liveVideoStreaming session:(AVCaptureSession *)session
{
    SCTraceStart();
    if (_liveVideoStreamingActive == liveVideoStreaming) {
        return;
    }
    _liveVideoStreamingActive = liveVideoStreaming;
    [self updateActiveFormatWithSession:session];
}

- (void)setCaptureDepthData:(BOOL)captureDepthData session:(AVCaptureSession *)session
{
    SCTraceStart();
    _captureDepthData = captureDepthData;
    [self _findSupportedFormats];
    [self updateActiveFormatWithSession:session];
}

- (void)updateActiveFormatWithSession:(AVCaptureSession *)session
{
    [self _updateActiveFormatWithSession:session fallbackPreset:AVCaptureSessionPreset640x480];
    if (_device.videoZoomFactor != _zoomFactor) {
        [self setZoomFactor:_zoomFactor];
    }
}

- (void)_updateActiveFormatWithSession:(AVCaptureSession *)session fallbackPreset:(NSString *)fallbackPreset
{
    AVCaptureDeviceFormat *nextFormat = [self _bestSupportedFormat];
    if (nextFormat && [session canSetSessionPreset:AVCaptureSessionPresetInputPriority]) {
        session.sessionPreset = AVCaptureSessionPresetInputPriority;
        if (nextFormat == _device.activeFormat) {
            // Need to reconfigure frame rate though active format unchanged
            [_device runTask:@"update frame rate"
                withLockedConfiguration:^() {
                    [self _updateDeviceFrameRate];
                }];
        } else {
            [_device runTask:@"update active format"
                withLockedConfiguration:^() {
                    _device.activeFormat = nextFormat;
                    [self _updateDeviceFrameRate];
                }];
        }
    } else {
        session.sessionPreset = fallbackPreset;
    }
    [self _updateFieldOfView];
}

- (void)_updateDeviceFrameRate
{
    int32_t deviceFrameRate;
    if (_liveVideoStreamingActive) {
        deviceFrameRate = kSCManagedCaptureDeviceMaximumLowFrameRate;
    } else {
        deviceFrameRate = kSCManagedCaptureDeviceMaximumHighFrameRate;
    }
    CMTime frameDuration = CMTimeMake(1, deviceFrameRate);
    if (@available(ios 11.0, *)) {
        if (_captureDepthData) {
            // Sync the video frame rate to the max depth frame rate (24 fps)
            if (_device.activeDepthDataFormat.videoSupportedFrameRateRanges.firstObject) {
                frameDuration =
                    _device.activeDepthDataFormat.videoSupportedFrameRateRanges.firstObject.minFrameDuration;
            }
        }
    }
    _device.activeVideoMaxFrameDuration = frameDuration;
    _device.activeVideoMinFrameDuration = frameDuration;
    if (_device.lowLightBoostSupported) {
        _device.automaticallyEnablesLowLightBoostWhenAvailable = YES;
    }
}

- (void)setZoomFactor:(float)zoomFactor
{
    SCTraceStart();
    if (_softwareZoom) {
        // Just remember the software zoom scale
        if (zoomFactor <= kSCManagedCaptureDevicecSoftwareMaxZoomFactor && zoomFactor >= 1) {
            _zoomFactor = zoomFactor;
        }
    } else {
        [_device runTask:@"set zoom factor"
            withLockedConfiguration:^() {
                if (zoomFactor <= _device.activeFormat.videoMaxZoomFactor && zoomFactor >= 1) {
                    _zoomFactor = zoomFactor;
                    if (_device.videoZoomFactor != _zoomFactor) {
                        _device.videoZoomFactor = _zoomFactor;
                    }
                }
            }];
    }
    [self _updateFieldOfView];
}

- (void)_updateFieldOfView
{
    float fieldOfView = _device.activeFormat.videoFieldOfView;
    if (_zoomFactor > 1.f) {
        // Adjust the field of view to take the zoom factor into account.
        // Note: this assumes the zoom factor linearly affects the focal length.
        fieldOfView = 2.f * SCRadiansToDegrees(atanf(tanf(SCDegreesToRadians(0.5f * fieldOfView)) / _zoomFactor));
    }
    self.fieldOfView = fieldOfView;
}

- (void)setExposurePointOfInterest:(CGPoint)pointOfInterest fromUser:(BOOL)fromUser
{
    [_exposureHandler setExposurePointOfInterest:pointOfInterest fromUser:fromUser];
}

// called when user taps on a point on screen, to re-adjust camera focus onto that tapped spot.
// this re-adjustment is always necessary, regardless of scenarios (recording video, taking photo, etc),
// therefore we don't have to check _focusLock in this method.
- (void)setAutofocusPointOfInterest:(CGPoint)pointOfInterest
{
    SCTraceStart();
    [_focusHandler setAutofocusPointOfInterest:pointOfInterest];
}

- (void)continuousAutofocus
{
    SCTraceStart();
    [_focusHandler continuousAutofocus];
}

- (void)setRecording:(BOOL)recording
{
    if (SCCameraTweaksSmoothAutoFocusWhileRecording() && [_device isSmoothAutoFocusSupported]) {
        [self _setSmoothFocus:recording];
    } else {
        [self _setFocusLock:recording];
    }
    [_exposureHandler setStableExposure:recording];
}

- (void)_setFocusLock:(BOOL)focusLock
{
    SCTraceStart();
    [_focusHandler setFocusLock:focusLock];
}

- (void)_setSmoothFocus:(BOOL)smoothFocus
{
    SCTraceStart();
    [_focusHandler setSmoothFocus:smoothFocus];
}

- (void)setFlashActive:(BOOL)flashActive
{
    SCTraceStart();
    if (_flashActive != flashActive) {
        if ([_device hasFlash]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            if (flashActive && [_device isFlashModeSupported:AVCaptureFlashModeOn]) {
                [_device runTask:@"set flash active"
                    withLockedConfiguration:^() {
                        _device.flashMode = AVCaptureFlashModeOn;
                    }];
            } else if (!flashActive && [_device isFlashModeSupported:AVCaptureFlashModeOff]) {
                [_device runTask:@"set flash off"
                    withLockedConfiguration:^() {
                        _device.flashMode = AVCaptureFlashModeOff;
                    }];
            }
#pragma clang diagnostic pop
            _flashActive = flashActive;
        } else {
            _flashActive = NO;
        }
    }
}

- (void)setTorchActive:(BOOL)torchActive
{
    SCTraceStart();
    if (_torchActive != torchActive) {
        if ([_device hasTorch]) {
            if (torchActive && [_device isTorchModeSupported:AVCaptureTorchModeOn]) {
                [_device runTask:@"set torch active"
                    withLockedConfiguration:^() {
                        [_device setTorchMode:AVCaptureTorchModeOn];
                    }];
            } else if (!torchActive && [_device isTorchModeSupported:AVCaptureTorchModeOff]) {
                [_device runTask:@"set torch off"
                    withLockedConfiguration:^() {
                        _device.torchMode = AVCaptureTorchModeOff;
                    }];
            }
            _torchActive = torchActive;
        } else {
            _torchActive = NO;
        }
    }
}

#pragma mark - Utilities

- (BOOL)isFlashSupported
{
    return _device.hasFlash;
}

- (BOOL)isTorchSupported
{
    return _device.hasTorch;
}

- (CGPoint)convertViewCoordinates:(CGPoint)viewCoordinates
                         viewSize:(CGSize)viewSize
                     videoGravity:(NSString *)videoGravity
{
    SCTraceStart();
    CGPoint pointOfInterest = CGPointMake(.5f, .5f);
    CGRect cleanAperture;
    AVCaptureDeviceInput *deviceInput = [self deviceInput];
    NSArray *ports = [deviceInput.ports copy];
    if ([videoGravity isEqualToString:AVLayerVideoGravityResize]) {
        // Scale, switch x and y, and reverse x
        return CGPointMake(viewCoordinates.y / viewSize.height, 1.f - (viewCoordinates.x / viewSize.width));
    }
    for (AVCaptureInputPort *port in ports) {
        if ([port mediaType] == AVMediaTypeVideo && port.formatDescription) {
            cleanAperture = CMVideoFormatDescriptionGetCleanAperture(port.formatDescription, YES);
            CGSize apertureSize = cleanAperture.size;
            CGPoint point = viewCoordinates;
            CGFloat apertureRatio = apertureSize.height / apertureSize.width;
            CGFloat viewRatio = viewSize.width / viewSize.height;
            CGFloat xc = .5f;
            CGFloat yc = .5f;
            if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
                if (viewRatio > apertureRatio) {
                    CGFloat y2 = viewSize.height;
                    CGFloat x2 = viewSize.height * apertureRatio;
                    CGFloat x1 = viewSize.width;
                    CGFloat blackBar = (x1 - x2) / 2;
                    // If point is inside letterboxed area, do coordinate conversion; otherwise, don't change the
                    // default value returned (.5,.5)
                    if (point.x >= blackBar && point.x <= blackBar + x2) {
                        // Scale (accounting for the letterboxing on the left and right of the video preview),
                        // switch x and y, and reverse x
                        xc = point.y / y2;
                        yc = 1.f - ((point.x - blackBar) / x2);
                    }
                } else {
                    CGFloat y2 = viewSize.width / apertureRatio;
                    CGFloat y1 = viewSize.height;
                    CGFloat x2 = viewSize.width;
                    CGFloat blackBar = (y1 - y2) / 2;
                    // If point is inside letterboxed area, do coordinate conversion. Otherwise, don't change the
                    // default value returned (.5,.5)
                    if (point.y >= blackBar && point.y <= blackBar + y2) {
                        // Scale (accounting for the letterboxing on the top and bottom of the video preview),
                        // switch x and y, and reverse x
                        xc = ((point.y - blackBar) / y2);
                        yc = 1.f - (point.x / x2);
                    }
                }
            } else if ([videoGravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
                // Scale, switch x and y, and reverse x
                if (viewRatio > apertureRatio) {
                    CGFloat y2 = apertureSize.width * (viewSize.width / apertureSize.height);
                    xc = (point.y + ((y2 - viewSize.height) / 2.f)) / y2; // Account for cropped height
                    yc = (viewSize.width - point.x) / viewSize.width;
                } else {
                    CGFloat x2 = apertureSize.height * (viewSize.height / apertureSize.width);
                    yc = 1.f - ((point.x + ((x2 - viewSize.width) / 2)) / x2); // Account for cropped width
                    xc = point.y / viewSize.height;
                }
            }
            pointOfInterest = CGPointMake(xc, yc);
            break;
        }
    }
    return pointOfInterest;
}

#pragma mark - SCManagedCapturer friendly methods

- (AVCaptureDevice *)device
{
    return _device;
}

- (AVCaptureDeviceInput *)deviceInput
{
    SCTraceStart();
    if (!_deviceInput) {
        NSError *error = nil;
        _deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:_device error:&error];
        if (!_deviceInput) {
            _error = [error copy];
        }
    }
    return _deviceInput;
}

- (NSError *)error
{
    return _error;
}

- (BOOL)softwareZoom
{
    return _softwareZoom;
}

- (BOOL)isConnected
{
    return _isConnected;
}

- (BOOL)flashActive
{
    return _flashActive;
}

- (BOOL)torchActive
{
    return _torchActive;
}

- (float)zoomFactor
{
    return _zoomFactor;
}

- (BOOL)isNightModeActive
{
    return _isNightModeActive;
}

- (BOOL)liveVideoStreamingActive
{
    return _liveVideoStreamingActive;
}

- (BOOL)isAvailable
{
    return [_device isConnected];
}

#pragma mark - Private methods

- (void)_enableSubjectAreaChangeMonitoring
{
    SCTraceStart();
    [_device runTask:@"enable SubjectAreaChangeMonitoring"
        withLockedConfiguration:^() {
            _device.subjectAreaChangeMonitoringEnabled = YES;
        }];
}

- (AVCaptureDeviceFormat *)activeFormat
{
    return _device.activeFormat;
}

#pragma mark - Observe -adjustingExposure
- (void)_setAsExposureListenerForDevice:(AVCaptureDevice *)device
{
    SCTraceStart();
    SCLogCoreCameraInfo(@"Set exposure adjustment KVO for device: %ld", (long)device.position);
    [_observeController observe:device
                        keyPath:@keypath(device, adjustingExposure)
                        options:NSKeyValueObservingOptionNew
                         action:@selector(_adjustingExposureChanged:)];
}

- (void)_adjustingExposureChanged:(NSDictionary *)change
{
    SCTraceStart();
    BOOL adjustingExposure = [change[NSKeyValueChangeNewKey] boolValue];
    SCLogCoreCameraInfo(@"KVO exposure changed to %d", adjustingExposure);
    if ([self.delegate respondsToSelector:@selector(managedCaptureDevice:didChangeAdjustingExposure:)]) {
        [self.delegate managedCaptureDevice:self didChangeAdjustingExposure:adjustingExposure];
    }
}

#pragma mark - Observe -exposurePointOfInterest
- (void)_observeExposurePointForDevice:(AVCaptureDevice *)device
{
    SCTraceStart();
    SCLogCoreCameraInfo(@"Set exposure point KVO for device: %ld", (long)device.position);
    [_observeController observe:device
                        keyPath:@keypath(device, exposurePointOfInterest)
                        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         action:@selector(_exposurePointOfInterestChanged:)];
}

- (void)_exposurePointOfInterestChanged:(NSDictionary *)change
{
    SCTraceStart();
    CGPoint exposurePoint = [change[NSKeyValueChangeNewKey] CGPointValue];
    SCLogCoreCameraInfo(@"KVO exposure point changed to %@", NSStringFromCGPoint(exposurePoint));
    if ([self.delegate respondsToSelector:@selector(managedCaptureDevice:didChangeExposurePoint:)]) {
        [self.delegate managedCaptureDevice:self didChangeExposurePoint:exposurePoint];
    }
}

#pragma mark - Observe -focusPointOfInterest
- (void)_observeFocusPointForDevice:(AVCaptureDevice *)device
{
    SCTraceStart();
    SCLogCoreCameraInfo(@"Set focus point KVO for device: %ld", (long)device.position);
    [_observeController observe:device
                        keyPath:@keypath(device, focusPointOfInterest)
                        options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                         action:@selector(_focusPointOfInterestChanged:)];
}

- (void)_focusPointOfInterestChanged:(NSDictionary *)change
{
    SCTraceStart();
    CGPoint focusPoint = [change[NSKeyValueChangeNewKey] CGPointValue];
    SCLogCoreCameraInfo(@"KVO focus point changed to %@", NSStringFromCGPoint(focusPoint));
    if ([self.delegate respondsToSelector:@selector(managedCaptureDevice:didChangeFocusPoint:)]) {
        [self.delegate managedCaptureDevice:self didChangeFocusPoint:focusPoint];
    }
}

- (void)dealloc
{
    [_observeController unobserveAll];
}

@end
