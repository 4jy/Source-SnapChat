//
//  SCFeatureZooming.h
//  SCCamera
//
//  Created by Xiaokang Liu on 2018/4/19.
//

#import "SCFeature.h"

#import <SCCameraFoundation/SCManagedCaptureDevicePosition.h>
#import <SCSearch/SCSearchSnapZoomLevelProviding.h>

@class SCPreviewPresenter;
@protocol SCFeatureZooming;

@protocol SCFeatureZoomingDelegate <NSObject>
- (void)featureZoomingForceTouchedWhileRecording:(id<SCFeatureZooming>)featureZooming;
- (BOOL)featureZoomingIsInitiatedRecording:(id<SCFeatureZooming>)featureZooming;
@end

@protocol SCFeatureZooming <SCFeature, SCSearchSnapZoomLevelProviding>
@property (nonatomic, weak) id<SCFeatureZoomingDelegate> delegate;
@property (nonatomic, weak) SCPreviewPresenter *previewPresenter;

- (void)resetOffset;
- (void)resetScale;

- (void)cancelPreview;
- (void)flipOffset;

- (void)resetBeginningScale;
- (void)toggleCameraForReset:(SCManagedCaptureDevicePosition)devicePosition;
- (void)recordCurrentZoomStateForReset;
@end
