//
//  SCFeatureLensButtonZ.h
//  SCCamera
//
//  Created by Anton Udovychenko on 4/24/18.
//

#import "AVCameraViewEnums.h"
#import "SCFeature.h"

#import <Foundation/Foundation.h>

@protocol SCFeatureLensButtonZ;
@class SCGrowingButton, SCLens;

NS_ASSUME_NONNULL_BEGIN

@protocol SCFeatureLensButtonZDelegate <NSObject>
- (void)featureLensZButton:(id<SCFeatureLensButtonZ>)featureLensZButton
        didPressLensButton:(SCGrowingButton *)lensButton;
- (nullable NSArray<SCLens *> *)allLenses;
@end

@protocol SCFeatureLensButtonZ <SCFeature>

@property (nonatomic, weak) id<SCFeatureLensButtonZDelegate> delegate;

- (void)setLensButtonActive:(BOOL)active;

@end

NS_ASSUME_NONNULL_END
