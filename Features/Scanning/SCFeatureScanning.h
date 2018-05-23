//
//  SCFeatureScanning.h
//  Snapchat
//
//  Created by Xiaokang Liu on 2018/4/19.
//

#import "SCFeature.h"

@protocol SCFeatureScanning;

@protocol SCFeatureScanningDelegate <NSObject>
- (void)featureScanning:(id<SCFeatureScanning>)featureScanning didFinishWithResult:(NSObject *)resultObject;
@end

/**
 This SCFeature allows the user to long press on the screen to scan a snapcode.
 */
@protocol SCFeatureScanning <SCFeature>
@property (nonatomic, weak) id<SCFeatureScanningDelegate> delegate;
@property (nonatomic, assign) NSTimeInterval lastSuccessfulScanTime;
- (void)startScanning;
- (void)stopScanning;

- (void)stopSearch;
@end
