//
//  SCFeatureCoordinator.h
//  SCCamera
//
//  Created by Kristian Bauer on 1/4/18.
//

#import "SCFeature.h"

#import <SCBase/SCMacros.h>

@protocol SCFeatureProvider;
@class SCCameraOverlayView;

/**
 * Handles creation of SCFeatures and communication between owner and features.
 */
@interface SCFeatureCoordinator : NSObject

SC_INIT_AND_NEW_UNAVAILABLE;
- (instancetype)initWithFeatureContainerView:(SCCameraOverlayView *)containerView
                                    provider:(id<SCFeatureProvider>)provider;

/**
 * Asks provider for features with given featureTypes specified in initializer.
 */
- (void)reloadFeatures;

/**
 * Eventually won't need this, but in order to use new framework w/ existing architecture, need a way to forward
 * gestures to individual features.
 */
- (void)forwardCameraTimerGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)forwardCameraOverlayTapGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)forwardLongPressGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)forwardPinchGesture:(UIPinchGestureRecognizer *)recognizer;
- (void)forwardPanGesture:(UIPanGestureRecognizer *)recognizer;
/**
 * To prevent gestures on AVCameraViewController from triggering at the same time as feature controls, need to provide a
 * way for features to indicate that they will block a touch with given point.
 */
- (BOOL)shouldBlockTouchAtPoint:(CGPoint)point;

@end
