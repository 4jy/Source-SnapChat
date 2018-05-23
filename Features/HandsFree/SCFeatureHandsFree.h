//
//  SCFeatureHandsFree.h
//  SCCamera
//
//  Created by Kristian Bauer on 2/26/18.
//

#import "SCFeature.h"

#import <SCCamera/AVCameraViewEnums.h>

@class SCLongPressGestureRecognizer, SCPreviewPresenter;

@protocol SCFeatureHandsFree <SCFeature>
@property (nonatomic, weak) SCPreviewPresenter *previewPresenter;
@property (nonatomic, strong, readonly) SCLongPressGestureRecognizer *longPressGestureRecognizer;

/**
 * Whether the feature is enabled or not.
 */
@property (nonatomic) BOOL enabled;
- (void)setupRecordLifecycleEventsWithMethod:(SCCameraRecordingMethod)method;
- (BOOL)shouldDisplayMultiSnapTooltip;

/**
 * Block called when user cancels hands-free recording via X button.
 */
- (void)setCancelBlock:(dispatch_block_t)cancelBlock;

@end
