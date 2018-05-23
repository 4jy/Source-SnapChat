//
//  SCCameraTweaks.m
//  Snapchat
//
//  Created by Liu Liu on 10/4/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCCameraTweaks.h"

#import "SCManagedCapturePreviewLayerController.h"

#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>
#import <SCTweakAdditions/SCTweakDefines.h>

SCManagedCaptureDeviceZoomHandlerType SCCameraTweaksDeviceZoomHandlerStrategy(void)
{

    NSNumber *strategyNumber = SCTweakValueWithHalt(
        @"Camera", @"Core Camera", @"Zoom Strategy",
        @(SCIsMasterBuild() ? SCManagedCaptureDeviceLinearInterpolation : SCManagedCaptureDeviceDefaultZoom), (@{
            @(SCManagedCaptureDeviceDefaultZoom) : @"Default",
            @(SCManagedCaptureDeviceSavitzkyGolayFilter) : @"Savitzky-Golay Filter",
            @(SCManagedCaptureDeviceLinearInterpolation) : @"Linear Interpolation"
        }));
    return (SCManagedCaptureDeviceZoomHandlerType)[strategyNumber integerValue];
}

BOOL SCCameraTweaksEnableFaceDetectionFocus(SCManagedCaptureDevicePosition captureDevicePosition)
{
    SC_GUARD_ELSE_RETURN_VALUE([SCDeviceName isIphone], NO);
    SC_GUARD_ELSE_RETURN_VALUE(captureDevicePosition != SCManagedCaptureDevicePositionBackDualCamera, NO);

    BOOL isFrontCamera = (captureDevicePosition == SCManagedCaptureDevicePositionFront);
    BOOL isEnabled = NO;
    SCCameraFaceFocusModeStrategyType option = SCCameraTweaksFaceFocusStrategy();
    switch (option) {
    case SCCameraFaceFocusModeStrategyTypeABTest:
        if (isFrontCamera) {
            isEnabled = SCExperimentWithFaceDetectionFocusFrontCameraEnabled();
        } else {
            isEnabled = SCExperimentWithFaceDetectionFocusBackCameraEnabled();
        }
        break;
    case SCCameraFaceFocusModeStrategyTypeDisabled:
        isEnabled = NO;
        break;
    case SCCameraFaceFocusModeStrategyTypeOffByDefault:
    case SCCameraFaceFocusModeStrategyTypeOnByDefault:
        isEnabled = YES;
        break;
    }
    return isEnabled;
}

BOOL SCCameraTweaksTurnOnFaceDetectionFocusByDefault(SCManagedCaptureDevicePosition captureDevicePosition)
{
    SC_GUARD_ELSE_RETURN_VALUE([SCDeviceName isIphone], NO);
    SC_GUARD_ELSE_RETURN_VALUE(captureDevicePosition != SCManagedCaptureDevicePositionBackDualCamera, NO);

    BOOL isFrontCamera = (captureDevicePosition == SCManagedCaptureDevicePositionFront);
    BOOL isOnByDefault = NO;
    SCCameraFaceFocusModeStrategyType option = SCCameraTweaksFaceFocusStrategy();
    switch (option) {
    case SCCameraFaceFocusModeStrategyTypeABTest:
        if (isFrontCamera) {
            isOnByDefault = SCExperimentWithFaceDetectionFocusFrontCameraOnByDefault();
        } else {
            isOnByDefault = SCExperimentWithFaceDetectionFocusBackCameraOnByDefault();
        }
        break;
    case SCCameraFaceFocusModeStrategyTypeDisabled:
    case SCCameraFaceFocusModeStrategyTypeOffByDefault:
        isOnByDefault = NO;
        break;
    case SCCameraFaceFocusModeStrategyTypeOnByDefault:
        isOnByDefault = YES;
        break;
    }
    return isOnByDefault;
}

SCCameraFaceFocusDetectionMethodType SCCameraFaceFocusDetectionMethod()
{
    static SCCameraFaceFocusDetectionMethodType detectionMethodType;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SCCameraFaceFocusDetectionMethodType option = SCCameraTweaksFaceFocusDetectionMethodType();
        switch (option) {
        case SCCameraFaceFocusDetectionMethodTypeABTest: {
            // Check the validity of AB value.
            NSUInteger experimentValue = SCExperimentWithFaceDetectionFocusDetectionMethod();
            if (experimentValue >= SCCameraFaceFocusDetectionMethodTypeCIDetector &&
                experimentValue <= SCCameraFaceFocusDetectionMethodTypeAVMetadata) {
                detectionMethodType = experimentValue;
            } else {
                // Use CIDetector by default.
                detectionMethodType = SCCameraFaceFocusDetectionMethodTypeCIDetector;
            }
        } break;
        case SCCameraFaceFocusDetectionMethodTypeAVMetadata:
            detectionMethodType = SCCameraFaceFocusDetectionMethodTypeAVMetadata;
            break;
        case SCCameraFaceFocusDetectionMethodTypeCIDetector:
            detectionMethodType = SCCameraFaceFocusDetectionMethodTypeCIDetector;
            break;
        }
    });
    return detectionMethodType;
}

CGFloat SCCameraFaceFocusMinFaceSize(void)
{
    static CGFloat minFaceSize;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (SCCameraTweaksFaceFocusMinFaceSizeRespectABTesting()) {
            minFaceSize = (CGFloat)SCExperimentWithFaceDetectionMinFaceSize();
        } else {
            minFaceSize = SCCameraTweaksFaceFocusMinFaceSizeValue();
        }
        if (minFaceSize < 0.01 || minFaceSize > 0.5) {
            minFaceSize = 0.25; // Default value is 0.25
        }
    });
    return minFaceSize;
}

BOOL SCCameraTweaksEnableCaptureKeepRecordedVideo(void)
{
    static BOOL enableCaptureKeepRecordedVideo;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksEnableCaptureKeepRecordedVideoStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes: {
            enableCaptureKeepRecordedVideo = YES;
            break;
        }
        case SCCameraTweaksStrategyOverrideToNo: {
            enableCaptureKeepRecordedVideo = NO;
            break;
        }
        case SCCameraTweaksStrategyFollowABTest: {
            enableCaptureKeepRecordedVideo = SCExperimentWithCaptureKeepRecordedVideo();
            break;
        }
        default: {
            enableCaptureKeepRecordedVideo = NO;
            break;
        }
        }
    });
    return enableCaptureKeepRecordedVideo;
}

static inline SCCameraTweaksStrategyType SCCameraTweaksBlackCameraRecoveryStrategy(void)
{
    NSNumber *strategy = SCTweakValueWithHalt(@"Camera", @"Core Camera", @"Black Camera Recovery",
                                              (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                                  @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                                  @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                                  @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                                              }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

BOOL SCCameraTweaksBlackCameraRecoveryEnabled(void)
{
    static BOOL enabled;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksBlackCameraRecoveryStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes:
            enabled = YES;
            break;
        case SCCameraTweaksStrategyOverrideToNo:
            enabled = NO;
            break;
        case SCCameraTweaksStrategyFollowABTest:
            enabled = SCExperimentWithBlackCameraRecovery();
            break;
        default:
            enabled = NO;
            break;
        }
    });
    return enabled;
}

static inline SCCameraTweaksStrategyType SCCameraTweaksMicrophoneNotificationStrategy(void)
{
    NSNumber *strategy = SCTweakValueWithHalt(@"Camera", @"Core Camera", @"Mic Notification",
                                              (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                                  @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                                  @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                                  @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                                              }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

BOOL SCCameraTweaksMicPermissionEnabled(void)
{
    static BOOL enabled;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksMicrophoneNotificationStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes:
            enabled = YES;
            break;
        case SCCameraTweaksStrategyOverrideToNo:
            enabled = NO;
            break;
        case SCCameraTweaksStrategyFollowABTest:
            enabled = SCExperimentWithMicrophonePermissionNotificationEnabled();
            break;
        default:
            enabled = NO;
            break;
        }
    });
    return enabled;
}

SCCameraHandsFreeModeType SCCameraTweaksHandsFreeMode(void)
{
    static SCCameraHandsFreeModeType handsFreeModeType;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SCCameraHandsFreeModeType option = SCCameraTweaksHandsFreeModeType();
        switch (option) {
        case SCCameraHandsFreeModeTypeDisabled:
            handsFreeModeType = SCCameraHandsFreeModeTypeDisabled;
            break;
        case SCCameraHandsFreeModeTypeMainOnly:
            handsFreeModeType = SCCameraHandsFreeModeTypeMainOnly;
            break;
        case SCCameraHandsFreeModeTypeChatMoveCaptureButton:
            handsFreeModeType = SCCameraHandsFreeModeTypeChatMoveCaptureButton;
            break;
        case SCCameraHandsFreeModeTypeMainAndChat:
            handsFreeModeType = SCCameraHandsFreeModeTypeMainAndChat;
            break;
        case SCCameraHandsFreeModeTypeLeftOfCapture:
            handsFreeModeType = SCCameraHandsFreeModeTypeLeftOfCapture;
            break;
        case SCCameraHandsFreeModeTypeABTest:
        default:
            handsFreeModeType = SCExperimentWithHandsFreeMode();
            break;
        }
    });
    return handsFreeModeType;
}

BOOL SCCameraTweaksEnableHandsFreeXToCancel(void)
{
    static BOOL enableHandsFreeXToCancel;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksEnableHandsFreeXToCancelStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes: {
            enableHandsFreeXToCancel = YES;
            break;
        }
        case SCCameraTweaksStrategyOverrideToNo: {
            enableHandsFreeXToCancel = NO;
            break;
        }
        case SCCameraTweaksStrategyFollowABTest: {
            enableHandsFreeXToCancel = SCExperimentWithHandsFreeXToCancel();
            break;
        }
        default: {
            enableHandsFreeXToCancel = NO;
            break;
        }
        }
    });
    return enableHandsFreeXToCancel;
}

BOOL SCCameraTweaksEnableShortPreviewTransitionAnimationDuration(void)
{
    static BOOL enableShortPreviewTransitionAnimationDuration;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksPreviewTransitionAnimationDurationStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes: {
            enableShortPreviewTransitionAnimationDuration = YES;
            break;
        }
        case SCCameraTweaksStrategyOverrideToNo: {
            enableShortPreviewTransitionAnimationDuration = NO;
            break;
        }
        case SCCameraTweaksStrategyFollowABTest: {
            enableShortPreviewTransitionAnimationDuration = SCExperimentWithShortPreviewTransitionAnimationDuration();
            break;
        }
        default: {
            enableShortPreviewTransitionAnimationDuration = YES;
            break;
        }
        }
    });
    return enableShortPreviewTransitionAnimationDuration;
}

BOOL SCCameraTweaksEnablePreviewPresenterFastPreview(void)
{
    static BOOL enablePreviewPresenterFastPreview;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksPreviewPresenterFastPreviewStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes: {
            enablePreviewPresenterFastPreview = YES;
            break;
        }
        case SCCameraTweaksStrategyOverrideToNo: {
            enablePreviewPresenterFastPreview = NO;
            break;
        }
        case SCCameraTweaksStrategyFollowABTest: {
            enablePreviewPresenterFastPreview = SCExperimentWithPreviewPresenterFastPreview();
            break;
        }
        default: {
            enablePreviewPresenterFastPreview = NO;
            break;
        }
        }
    });
    return enablePreviewPresenterFastPreview;
}

BOOL SCCameraTweaksEnableCaptureSharePerformer(void)
{
    static BOOL enableCaptureSharePerformer;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksEnableCaptureSharePerformerStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes: {
            enableCaptureSharePerformer = YES;
            break;
        }
        case SCCameraTweaksStrategyOverrideToNo: {
            enableCaptureSharePerformer = NO;
            break;
        }
        case SCCameraTweaksStrategyFollowABTest: {
            enableCaptureSharePerformer = SCExperimentWithCaptureSharePerformer();
            break;
        }
        default: {
            enableCaptureSharePerformer = NO;
            break;
        }
        }
    });
    return enableCaptureSharePerformer;
}

static inline SCCameraTweaksStrategyType SCCameraTweaksSessionLightWeightFixStrategy(void)
{
    NSNumber *strategy = SCTweakValueWithHalt(@"Camera", @"Core Camera", @"Light-weight Session Fix",
                                              (id) @(SCCameraTweaksStrategyFollowABTest), (@{
                                                  @(SCCameraTweaksStrategyFollowABTest) : @"Respect A/B testing",
                                                  @(SCCameraTweaksStrategyOverrideToYes) : @"Override to YES",
                                                  @(SCCameraTweaksStrategyOverrideToNo) : @"Override to NO"
                                              }));
    return (SCCameraTweaksStrategyType)[strategy unsignedIntegerValue];
}

BOOL SCCameraTweaksSessionLightWeightFixEnabled(void)
{
    static BOOL enabled;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        switch (SCCameraTweaksSessionLightWeightFixStrategy()) {
        case SCCameraTweaksStrategyOverrideToYes:
            enabled = YES;
            break;
        case SCCameraTweaksStrategyOverrideToNo:
            enabled = NO;
            break;
        case SCCameraTweaksStrategyFollowABTest:
            enabled = SCExperimentWithSessionLightWeightFix();
            break;
        default:
            enabled = NO;
            break;
        }
    });
    return enabled;
}
