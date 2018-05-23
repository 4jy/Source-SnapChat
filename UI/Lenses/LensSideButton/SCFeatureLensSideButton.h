//
//  SCFeatureLensSideButton.h
//  SCCamera
//
//  Created by Anton Udovychenko on 4/12/18.
//

#import "AVCameraViewEnums.h"
#import "SCFeature.h"

#import <Foundation/Foundation.h>

@protocol SCFeatureLensSideButton;
@class SCGrowingButton, SCLens;

NS_ASSUME_NONNULL_BEGIN

@protocol SCFeatureLensSideButtonDelegate <NSObject>
- (void)featureLensSideButton:(id<SCFeatureLensSideButton>)featureLensSideButton
           didPressLensButton:(SCGrowingButton *)lensButton;
- (nullable SCLens *)firstApplicableLens;
@end

@protocol SCFeatureLensSideButton <SCFeature>

@property (nonatomic, weak) id<SCFeatureLensSideButtonDelegate> delegate;

- (void)updateLensButtonVisibility:(CGFloat)visibilityPercentage;
- (void)showLensButtonIfNeeded;

@end

NS_ASSUME_NONNULL_END
