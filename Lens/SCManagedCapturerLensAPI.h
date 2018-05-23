//
//  SCManagedCapturerLensAPI.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/11/18.
//

#import "SCManagedCapturerListener.h"
#import "SCManagedVideoARDataSource.h"

#import <SCCameraFoundation/SCManagedCaptureDevicePosition.h>
#import <SCLenses/SCLens.h>

#import <Foundation/Foundation.h>

@protocol SCManagedAudioDataSourceListener
, SCManagedVideoARDataSource;
@class LSAComponentManager;

/**
 Encapsulation of LensesProcessingCore for use in SCCamera.
 */
@protocol SCManagedCapturerLensAPI <SCManagedCapturerListener>

@property (nonatomic, strong, readonly) LSAComponentManager *componentManager;
@property (nonatomic, strong) NSString *activeLensId;
@property (nonatomic, readonly) BOOL isLensApplied;
@property (nonatomic, strong, readonly)
    id<SCManagedAudioDataSourceListener, SCManagedVideoDataSourceListener> capturerListener;

typedef void (^SCManagedCapturerLensAPIPointOfInterestCompletion)(SCLensCategory *category, NSInteger categoriesCount);

- (void)setAspectRatio:(BOOL)isLiveStreaming;

- (SCLens *)appliedLens;

- (void)setFieldOfView:(float)fieldOfView;

- (void)setAsFieldOfViewListenerForDevice:(SCManagedCaptureDevice *)captureDevice;

- (void)setAsFieldOfViewListenerForARDataSource:(id<SCManagedVideoARDataSource>)arDataSource NS_AVAILABLE_IOS(11_0);

- (void)removeFieldOfViewListener;

- (void)setModifySource:(BOOL)modifySource;

- (void)setLensesActive:(BOOL)lensesActive
       videoOrientation:(AVCaptureVideoOrientation)videoOrientation
          filterFactory:(SCLookseryFilterFactory *)filterFactory;

- (void)detectLensCategoryOnNextFrame:(CGPoint)point
                     videoOrientation:(AVCaptureVideoOrientation)videoOrientation
                               lenses:(NSArray<SCLens *> *)lenses
                           completion:(SCManagedCapturerLensAPIPointOfInterestCompletion)completion;

- (void)setShouldMuteAllSounds:(BOOL)shouldMuteAllSounds;

- (UIImage *)processImage:(UIImage *)image
             maxPixelSize:(NSInteger)maxPixelSize
           devicePosition:(SCManagedCaptureDevicePosition)position
              fieldOfView:(float)fieldOfView;

- (void)setShouldProcessARFrames:(BOOL)shouldProcessARFrames;

- (NSInteger)maxPixelSize;

@end
