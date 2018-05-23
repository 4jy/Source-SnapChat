//
//  SCFeatureToggleCamera.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/17/18.
//

#import <SCCamera/SCFeature.h>
#import <SCCameraFoundation/SCManagedCaptureDevicePosition.h>

@protocol SCCapturer
, SCFeatureToggleCamera, SCLensCameraScreenDataProviderProtocol;

@protocol SCFeatureToggleCameraDelegate <NSObject>

- (void)featureToggleCamera:(id<SCFeatureToggleCamera>)feature
 willToggleToDevicePosition:(SCManagedCaptureDevicePosition)devicePosition;
- (void)featureToggleCamera:(id<SCFeatureToggleCamera>)feature
  didToggleToDevicePosition:(SCManagedCaptureDevicePosition)devicePosition;

@end

/**
 SCFeature protocol for toggling the camera.
 */
@protocol SCFeatureToggleCamera <SCFeature>

@property (nonatomic, weak) id<SCFeatureToggleCameraDelegate> delegate;

- (void)toggleCameraWithRecording:(BOOL)isRecording
                    takingPicture:(BOOL)isTakingPicture
                 lensDataProvider:(id<SCLensCameraScreenDataProviderProtocol>)lensDataProvider
                       completion:(void (^)(BOOL success))completion;

- (void)reset;

@end
