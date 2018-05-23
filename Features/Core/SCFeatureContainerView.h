//
//  SCFeatureContainerView.h
//  SCCamera
//
//  Created by Kristian Bauer on 4/17/18.
//

#import <UIKit/UIKit.h>

@protocol SCFeatureContainerView
- (BOOL)isTapGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
- (CGRect)initialCameraTimerFrame;
@end
