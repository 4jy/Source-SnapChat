//
//  SCFeature.h
//  SCCamera
//
//  Created by Kristian Bauer on 1/4/18.
//

#import <UIKit/UIKit.h>

/**
 * Top level protocol for UI features
 */
#define SCLogCameraFeatureInfo(fmt, ...) SCLogCoreCameraInfo(@"[SCFeature] " fmt, ##__VA_ARGS__)
@protocol SCFeatureContainerView;
@protocol SCFeature <NSObject>

@optional
- (void)configureWithView:(UIView<SCFeatureContainerView> *)view;
- (void)forwardCameraTimerGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)forwardCameraOverlayTapGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)forwardLongPressGesture:(UIGestureRecognizer *)gestureRecognizer;
- (void)forwardPinchGesture:(UIPinchGestureRecognizer *)gestureRecognizer;
- (void)forwardPanGesture:(UIPanGestureRecognizer *)gestureRecognizer;
- (BOOL)shouldBlockTouchAtPoint:(CGPoint)point;

@end
