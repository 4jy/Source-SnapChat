//
//  AVCameraViewEnums.h
//  SCCamera
//
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 The context specifies the way in which the camera is presented to the user.
 The controller can be configured a variety of ways depending on the context.
 */
typedef NS_ENUM(NSUInteger, AVCameraViewControllerContext) {
    AVCameraViewControllerContextMainVC = 1,
    AVCameraViewControllerContextReply,
    AVCameraViewControllerContextDefault = AVCameraViewControllerContextReply,
    AVCameraViewControllerContextSnapAds,
    AVCameraViewControllerContextAddToStory,
};

typedef NS_ENUM(NSInteger, AVCameraViewType) {
    AVCameraViewNoReply = 0,
    AVCameraViewReplyLeft,
    AVCameraViewReplyRight,
    AVCameraViewChat,
    AVCameraViewReplyHydra,
    AVCameraViewSnapAds,
    AVCameraViewGalleryMadeWithLenses,
    AVCameraViewSnapConnectSnapKit,
    AVCameraViewSnappable
};

typedef NS_ENUM(NSUInteger, AVCameraViewControllerRecordingState) {
    AVCameraViewControllerRecordingStateDefault,            // No capture activity
    AVCameraViewControllerRecordingStatePrepareRecording,   // Preparing for recording with delay
    AVCameraViewControllerRecordingStateInitiatedRecording, // Actively recording
    AVCameraViewControllerRecordingStateTakingPicture,      // Taking a still image
    AVCameraViewControllerRecordingStatePictureTaken,       // Picture is taken
    AVCameraViewControllerRecordingStatePreview,            // Preparing to present preview
};

typedef NS_ENUM(NSUInteger, SCCameraRecordingMethod) {
    SCCameraRecordingMethodCameraButton,
    SCCameraRecordingMethodVolumeButton,
    SCCameraRecordingMethodLensInitiated
};
