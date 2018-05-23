//
//  SCCameraTweaks.h
//  Snapchat
//
//  Created by Liu Liu on 9/16/15.
//  Copyright © 2015 Snapchat, Inc. All rights reserved.
//

#import <SCBase/SCMacros.h>
#import <SCCameraFoundation/SCManagedCaptureDevicePosition.h>
#import <SCTweakAdditions/SCTweakDefines.h>

#import <Tweaks/FBTweakInline.h>

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

// Core Camera

typedef NS_ENUM(NSUInteger, SCManagedCaptureDeviceZoomHandlerType) {
    SCManagedCaptureDeviceDefaultZoom,
    SCManagedCaptureDeviceSavitzkyGolayFilter,
    SCManagedCaptureDeviceLinearInterpolation,
};

typedef NS_ENUM(NSUInteger, SCCameraTweaksStrategyType) {
    SCCameraTweaksStrategyFollowABTest = 0,
    SCCameraTweaksStrategyOverrideToYes,
    SCCameraTweaksStrategyOverrideToNo
};

typedef NS_ENUM(NSUInteger, SCCameraHandsFreeModeType) {
    SCCameraHandsFreeModeTypeABTest = 0,
    SCCameraHandsFreeModeTypeDisabled,
    SCCameraHandsFreeModeTypeMainOnly,
    SCCameraHandsFreeModeTypeChatMoveCaptureButton,
    SCCameraHandsFreeModeTypeMainAndChat,
    SCCameraHandsFreeModeTypeLeftOfCapture,
};

/// Face detection and focus strategy in Tweak. There are less options in internal Tweaks than the A/B testing
/// strategies.
typedef NS_ENUM(NSUInteger, SCCameraFaceFocusModeStrategyType) {
    SCCameraFaceFocusModeStrategyTypeABTest = 0,
    SCCameraFaceFocusModeStrategyTypeDisabled,     // Disabled for both cameras.
    SCCameraFaceFocusModeStrategyTypeOffByDefault, // Enabled for both cameras, but is off by default.
    SCCameraFaceFocusModeStrategyTypeOnByDefault,  // Enabled for both cameras, but is off by default.
};

typedef NS_ENUM(NSUInteger, SCCameraFaceFocusDetectionMethodType) {
    SCCameraFaceFocusDetectionMethodTypeABTest = 0,
    SCCameraFaceFocusDetectionMethodTypeCIDetector, // Use SCCaptureCoreImageFaceDetector
    SCCameraFaceFocusDetectionMethodTypeAVMetadata, // Use SCCaptureMetadataOutputDetector
};

SC_EXTERN_C_BEGIN

extern SCManagedCaptureDeviceZoomHandlerType SCCameraTweaksDeviceZoomHandlerStrategy(void);

extern BOOL SCCameraTweaksBlackCameraRecoveryEnabled(void);

extern BOOL SCCameraTweaksMicPermissionEnabled(void);

extern BOOL SCCameraTweaksEnableCaptureKeepRecordedVideo(void);

extern BOOL SCCameraTweaksEnableHandsFreeXToCancel(void);
extern SCCameraHandsFreeModeType SCCameraTweaksHandsFreeMode(void);

BOOL SCCameraTweaksEnableShortPreviewTransitionAnimationDuration(void);

extern BOOL SCCameraTweaksEnablePreviewPresenterFastPreview(void);

extern BOOL SCCameraTweaksEnableCaptureSharePerformer(void);

extern BOOL SCCameraTweaksEnableFaceDetectionFocus(SCManagedCaptureDevicePosition captureDevicePosition);

extern BOOL SCCameraTweaksTurnOnFaceDetectionFocusByDefault(SCManagedCaptureDevicePosition captureDevicePosition);

extern SCCameraFaceFocusDetectionMethodType SCCameraFaceFocusDetectionMethod(void);

extern CGFloat SCCameraFaceFocusMinFaceSize(void);

extern BOOL SCCameraTweaksSessionLightWeightFixEnabled(void);

SC_EXTERN_C_END

static inline BOOL SCCameraTweaksEnableVideoStabilization(void)
{
    return FBTweakValue(@"Camera", @"Core Camera", @"Enable video stabilization", NO);
}

static inline BOOL SCCameraTweaksEnableForceTouchToToggleCamera(void)
{
    return FBTweakValue(@"Camera", @"Recording", @"Force Touch to Toggle", NO);
}

static inline BOOL SCCameraTweaksEnableStayOnCameraAfterPostingStory(void)
{
    return FBTweakValue(@"Camera", @"Story", @"Stay on camera after posting", NO);
}

static inline BOOL SCCameraTweaksEnableKeepLastFrameOnCamera(void)
{
    return FBTweakValue(@"Camera", @"Core Camera", @"Keep last frame on camera", YES);
}

static inline BOOL SCCameraTweaksSmoothAutoFocusWhileRecording(void)
{
    return FBTweakValue(@"Camera", @"Core Camera", @"Smooth autofocus while recording", YES);
}

static inline NSInteger SCCameraExposureAdjustmentMode(void)
{
    return [FBTweakValue(
        @"Camera", @"Core Camera", @"Adjust Exposure", (id) @0,
        (@{ @0 : @"NO",
            @1 : @"Dynamic enhancement",
            @2 : @"Night vision",
            @3 : @"Inverted night vision" })) integerValue];
}

static inline BOOL SCCameraTweaksRotateToggleCameraButton(void)
{
    return SCTweakValueWithHalt(@"Camera", @"Core Camera", @"Rotate Toggle-Camera Button", NO);
}

static inline CGFloat SCCameraTweaksRotateToggleCameraButtonTime(void)
{
    return FBTweakValue(@"Camera", @"Core Camera", @"Toggle-Camera Button Rotation Time", 0.3);
}

static inline BOOL SCCameraTweaksDefaultPortrait(void)
{
    return FBTweakValue(@"Camera", @"Core Camera", @"Default to Portrait Orientation", YES);
}

// For test purpose
static inline BOOL SCCameraTweaksTranscodingAlwaysFails(void)
{
    return FBTweakValue(@"Camera", @"Core Camera", @"Transcoding always fails", NO);
}

// This tweak disables the video masking behavior of the snap overlays;
// Intended to be used by curators who are on-site snapping special events.
// Ping news-dev@snapchat.com for any questions/comments
static inline BOOL SCCameraTweaksDisableOverlayVideoMask(void)
{
    return FBTweakValue(@"Camera", @"Creative Tools", @"Disable Overlay Video Masking", NO);
}

static inline NSInteger SCCameraTweaksDelayTurnOnFilters(void)
{
    return [FBTweakValue(@"Camera", @"Core Camera", @"Delay turn on filter", (id) @0,
                         (@{ @0 : @"Respect A/B testing",
                             @1 : @"Override to YES",
                             @2 : @"Override to NO" })) integerValue];
}

static inline BOOL SCCameraTweaksEnableExposurePointObservation(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Face Focus", @"Observe Exposure Point", NO);
}

static inline BOOL SCCameraTweaksEnableFocusPointObservation(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Face Focus", @"Observe Focus Point", NO);
}

static inline CGFloat SCCameraTweaksSmoothZoomThresholdTime()
{
    return FBTweakValue(@"Camera", @"Zoom Strategy - Linear Interpolation", @"Threshold time", 0.3);
}

static inline CGFloat SCCameraTweaksSmoothZoomThresholdFactor()
{
    return FBTweakValue(@"Camera", @"Zoom Strategy - Linear Interpolation", @"Threshold factor diff", 0.25);
}

static inline CGFloat SCCameraTweaksSmoothZoomIntermediateFramesPerSecond()
{
    return FBTweakValue(@"Camera", @"Zoom Strategy - Linear Interpolation", @"Intermediate fps", 60);
}

static inline CGFloat SCCameraTweaksSmoothZoomDelayTolerantTime()
{
    return FBTweakValue(@"Camera", @"Zoom Strategy - Linear Interpolation", @"Delay tolerant time", 0.15);
}

static inline CGFloat SCCameraTweaksSmoothZoomMinStepLength()
{
    return FBTweakValue(@"Camera", @"Zoom Strategy - Linear Interpolation", @"Min step length", 0.05);
}

static inline CGFloat SCCameraTweaksExposureDeadline()
{
    return FBTweakValue(@"Camera", @"Adjust Exposure", @"Exposure Deadline", 0.2);
}

static inline BOOL SCCameraTweaksKillFrontCamera(void)
{
    return SCTweakValueWithHalt(@"Camera", @"Debugging", @"Kill Front Camera", NO);
}

static inline BOOL SCCameraTweaksKillBackCamera(void)
{
    return SCTweakValueWithHalt(@"Camera", @"Debugging", @"Kill Back Camera", NO);
}

#if TARGET_IPHONE_SIMULATOR

static inline BOOL SCCameraTweaksUseRealMockImage(void)
{
    return FBTweakValue(@"Camera", @"Debugging", @"Use real mock image on simulator", YES);
}

#endif

static inline CGFloat SCCameraTweaksShortPreviewTransitionAnimationDuration()
{
    return FBTweakValue(@"Camera", @"Preview Transition", @"Short Animation Duration", 0.35);
}

static inline SCCameraTweaksStrategyType SCCameraTweaksPreviewTransitionAnimationDurationStrategy()
{
    NSNumber *strategy = SCTweakValueWithHalt(@"Camera", @"Preview Transition", @"Enable Short Animation Duration",
                                              (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                                  @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                                  @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                                  @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                                              }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

static inline CGFloat SCCameraTweaksEnablePortraitModeButton(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Enable Button", NO);
}

static inline CGFloat SCCameraTweaksDepthBlurForegroundThreshold(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Foreground Blur Threshold", 0.3);
}

static inline CGFloat SCCameraTweaksDepthBlurBackgroundThreshold(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Background Blur Threshold", 0.1);
}

static inline CGFloat SCCameraTweaksBlurSigma(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Blur Sigma", 4.0);
}

static inline BOOL SCCameraTweaksEnableFilterInputFocusRect(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Filter Input Focus Rect", NO);
}

static inline BOOL SCCameraTweaksEnablePortraitModeTapToFocus(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Tap to Focus", NO);
}

static inline BOOL SCCameraTweaksEnablePortraitModeAutofocus(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Autofocus", NO);
}

static inline BOOL SCCameraTweaksDepthToGrayscaleOverride(void)
{
    return FBTweakValue(@"Camera", @"Core Camera - Portrait Mode", @"Depth to Grayscale Override", NO);
}

static inline SCCameraTweaksStrategyType SCCameraTweaksEnableHandsFreeXToCancelStrategy(void)
{
    NSNumber *strategy = SCTweakValueWithHalt(@"Camera", @"Hands-Free Recording", @"X to Cancel",
                                              (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                                  @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                                  @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                                  @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                                              }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

static inline SCCameraHandsFreeModeType SCCameraTweaksHandsFreeModeType()
{
    NSNumber *strategy = SCTweakValueWithHalt(
        @"Camera", @"Hands-Free Recording", @"Enabled", (id) @(SCCameraHandsFreeModeTypeABTest), (@{
            @(SCCameraHandsFreeModeTypeABTest) : @"Respect A/B testing",
            @(SCCameraHandsFreeModeTypeDisabled) : @"Disable",
            @(SCCameraHandsFreeModeTypeMainOnly) : @"Main Camera only",
            @(SCCameraHandsFreeModeTypeChatMoveCaptureButton) : @"Main Camera + move Chat capture button",
            @(SCCameraHandsFreeModeTypeMainAndChat) : @"Main + Chat Cameras",
            @(SCCameraHandsFreeModeTypeLeftOfCapture) : @"Left of Main + Chat Cameras"
        }));
    return (SCCameraHandsFreeModeType)[strategy unsignedIntegerValue];
}

static inline SCCameraTweaksStrategyType SCCameraTweaksPreviewPresenterFastPreviewStrategy(void)
{
    NSNumber *strategy = SCTweakValueWithHalt(@"Camera", @"Preview Presenter", @"Fast Preview",
                                              (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                                  @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                                  @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                                  @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                                              }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

static inline NSInteger SCCameraTweaksEnableCaptureKeepRecordedVideoStrategy(void)
{
    NSNumber *strategy =
        SCTweakValueWithHalt(@"Camera", @"Core Camera - Capture Keep Recorded Video",
                             @"Enable Capture Keep Recorded Video", (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                 @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                 @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                 @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                             }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

static inline NSInteger SCCameraTweaksEnableCaptureSharePerformerStrategy(void)
{
    NSNumber *strategy =
        SCTweakValueWithHalt(@"Camera", @"Core Camera - Capture Share Performer", @"Enable Capture Share Performer",
                             (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                 @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                 @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                 @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                             }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

static inline SCCameraFaceFocusModeStrategyType SCCameraTweaksFaceFocusStrategy()
{
    NSNumber *strategy =
        SCTweakValueWithHalt(@"Camera", @"Core Camera - Face Focus", @"Enable Face Focus",
                             (id) @(SCCameraFaceFocusModeStrategyTypeABTest), (@{
                                 @(SCCameraFaceFocusModeStrategyTypeABTest) : @"Respect A/B testing",
                                 @(SCCameraFaceFocusModeStrategyTypeDisabled) : @"Disabled",
                                 @(SCCameraFaceFocusModeStrategyTypeOffByDefault) : @"Enabled, off by default",
                                 @(SCCameraFaceFocusModeStrategyTypeOnByDefault) : @"Enabled, on by default",
                             }));
    return (SCCameraFaceFocusModeStrategyType)[strategy unsignedIntegerValue];
}

static inline SCCameraFaceFocusDetectionMethodType SCCameraTweaksFaceFocusDetectionMethodType()
{
    NSNumber *strategy =
        SCTweakValueWithHalt(@"Camera", @"Core Camera - Face Focus", @"Detection Method",
                             (id) @(SCCameraFaceFocusDetectionMethodTypeABTest), (@{
                                 @(SCCameraFaceFocusDetectionMethodTypeABTest) : @"Respect A/B testing",
                                 @(SCCameraFaceFocusDetectionMethodTypeCIDetector) : @"CIDetector",
                                 @(SCCameraFaceFocusDetectionMethodTypeAVMetadata) : @"AVMetadata",
                             }));
    return (SCCameraFaceFocusDetectionMethodType)[strategy unsignedIntegerValue];
}

static inline int SCCameraTweaksFaceFocusDetectionFrequency()
{
    return FBTweakValue(@"Camera", @"Core Camera - Face Focus", @"Detection Frequency", 3, 1, 30);
}

static inline BOOL SCCameraTweaksFaceFocusMinFaceSizeRespectABTesting()
{
    return SCTweakValueWithHalt(@"Camera", @"Core Camera - Face Focus", @"Min Face Size Respect AB", YES);
}

static inline CGFloat SCCameraTweaksFaceFocusMinFaceSizeValue()
{
    return FBTweakValue(@"Camera", @"Core Camera - Face Focus", @"Min Face Size", 0.25, 0.01, 0.5);
}

static inline BOOL SCCameraTweaksEnableDualCamera(void)
{
    return SCTweakValueWithHalt(@"Camera", @"Core Camera - Dual Camera", @"Enable Dual Camera", NO);
}
