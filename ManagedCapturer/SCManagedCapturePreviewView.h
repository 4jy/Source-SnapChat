//
//  SCManagedCapturePreviewView.h
//  Snapchat
//
//  Created by Liu Liu on 5/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@class LSAGLView;

@interface SCManagedCapturePreviewView : UIView

- (instancetype)initWithFrame:(CGRect)frame NS_UNAVAILABLE;

- (instancetype)initWithFrame:(CGRect)frame aspectRatio:(CGFloat)aspectRatio metalLayer:(CALayer *)metalLayer;
// This method is called only once in case the metalLayer is nil previously.
- (void)setupMetalLayer:(CALayer *)metalLayer;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;
@property (nonatomic, strong) LSAGLView *videoPreviewGLView;

@end
