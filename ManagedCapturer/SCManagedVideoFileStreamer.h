//
//  SCManagedVideoFileStreamer.h
//  Snapchat
//
//  Created by Alexander Grytsiuk on 3/4/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import <SCCameraFoundation/SCManagedVideoDataSource.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

typedef void (^sc_managed_video_file_streamer_pixel_buffer_completion_handler_t)(CVPixelBufferRef pixelBuffer);

/**
 * SCManagedVideoFileStreamer reads a video file from provided NSURL to create
 * and publish video output frames. SCManagedVideoFileStreamer also conforms
 * to SCManagedVideoDataSource allowing chained consumption of video frames.
 */
@interface SCManagedVideoFileStreamer : NSObject <SCManagedVideoDataSource>

- (instancetype)initWithPlaybackForURL:(NSURL *)URL;
- (void)getNextPixelBufferWithCompletion:(sc_managed_video_file_streamer_pixel_buffer_completion_handler_t)completion;

@end
