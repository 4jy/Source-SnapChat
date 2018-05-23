//
//  SCSingleFrameStreamCapturer.h
//  Snapchat
//
//  Created by Benjamin Hollis on 5/3/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCCaptureCommon.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>

#import <Foundation/Foundation.h>

@interface SCSingleFrameStreamCapturer : NSObject <SCManagedVideoDataSourceListener>
- (instancetype)initWithCompletion:(sc_managed_capturer_capture_video_frame_completion_handler_t)completionHandler;
@end
