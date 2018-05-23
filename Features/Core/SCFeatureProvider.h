//
//  SCFeatureProvider.h
//  SCCamera
//
//  Created by Kristian Bauer on 1/4/18.
//

#import <SCCamera/AVCameraViewEnums.h>

#import <Foundation/Foundation.h>

@class SCFeatureSettingsManager, SCCapturerToken, SCUserSession;

@protocol SCFeature
, SCCapturer, SCFeatureFlash, SCFeatureHandsFree, SCFeatureLensSideButton, SCFeatureLensButtonZ, SCFeatureMemories,
    SCFeatureNightMode, SCFeatureSnapKit, SCFeatureTapToFocusAndExposure, SCFeatureToggleCamera, SCFeatureShazam,
    SCFeatureImageCapture, SCFeatureScanning, SCFeatureZooming;

/**
 * Provides single location for creating and configuring SCFeatures.
 */
@protocol SCFeatureProvider <NSObject>

@property (nonatomic) AVCameraViewType cameraViewType;

@property (nonatomic, readonly) id<SCCapturer> capturer;
@property (nonatomic, strong, readwrite) SCCapturerToken *token;
@property (nonatomic, readonly) SCUserSession *userSession;
// TODO: We should not be reusing AVCameraViewController so eventually the
// context should be removed.
@property (nonatomic, readonly) AVCameraViewControllerContext context;
@property (nonatomic) id<SCFeatureHandsFree> handsFreeRecording;
@property (nonatomic) id<SCFeatureSnapKit> snapKit;
@property (nonatomic) id<SCFeatureTapToFocusAndExposure> tapToFocusAndExposure;
@property (nonatomic) id<SCFeatureMemories> memories;
@property (nonatomic) id<SCFeatureFlash> flash;
@property (nonatomic) id<SCFeatureLensSideButton> lensSideButton;
@property (nonatomic) id<SCFeatureLensButtonZ> lensZButton;
@property (nonatomic) id<SCFeatureNightMode> nightMode;
@property (nonatomic) id<SCFeatureToggleCamera> toggleCamera;
@property (nonatomic) id<SCFeatureShazam> shazam;
@property (nonatomic) id<SCFeatureScanning> scanning;
@property (nonatomic) id<SCFeatureImageCapture> imageCapture;
@property (nonatomic) id<SCFeatureZooming> zooming;

@property (nonatomic, readonly) NSArray<id<SCFeature>> *supportedFeatures;

- (void)resetInstances;

@end
