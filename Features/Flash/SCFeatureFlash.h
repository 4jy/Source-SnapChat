//
//  SCFeatureFlash.h
//  SCCamera
//
//  Created by Kristian Bauer on 3/27/18.
//

#import "SCFeature.h"

@class SCNavigationBarButtonItem;

/**
 * Public interface for interacting with camera flash feature.
 */
@protocol SCFeatureFlash <SCFeature>
@property (nonatomic, readonly) SCNavigationBarButtonItem *navigationBarButtonItem;

- (void)interruptGestures;

@end
