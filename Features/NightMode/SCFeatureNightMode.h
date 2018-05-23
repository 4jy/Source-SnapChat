//
//  SCFeatureNightMode.h
//  SCCamera
//
//  Created by Kristian Bauer on 4/9/18.
//

#import "SCFeature.h"

@class SCNavigationBarButtonItem, SCPreviewPresenter;

/**
 * Public interface for interacting with camera night mode feature.
 * User spec: https://snapchat.quip.com/w4h4ArzcmXCS
 */
@protocol SCFeatureNightMode <SCFeature>
@property (nonatomic, weak, readwrite) SCPreviewPresenter *previewPresenter;
@property (nonatomic, readonly) SCNavigationBarButtonItem *navigationBarButtonItem;

- (void)interruptGestures;
- (void)hideWithDelayIfNeeded;
@end
