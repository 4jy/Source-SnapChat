//
//  SCManagedVideoCapturer.h
//  Snapchat
//
//  Created by Liu Liu on 5/1/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedRecordedVideo.h"
#import "SCManagedVideoCapturerOutputSettings.h"
#import "SCVideoCaptureSessionInfo.h"

#import <SCCameraFoundation/SCManagedAudioDataSource.h>
#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>
#import <SCFoundation/SCFuture.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

typedef void (^sc_managed_video_capturer_recording_completion_handler_t)(NSURL *fileURL, NSError *error);

@class SCManagedVideoCapturer, SCTimedTask;

@protocol SCManagedVideoCapturerDelegate <NSObject>

// All these calbacks are invoked on a private queue for video recording channels

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
      didBeginVideoRecording:(SCVideoCaptureSessionInfo)sessionInfo;

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
      didBeginAudioRecording:(SCVideoCaptureSessionInfo)sessionInfo;

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
    willStopWithRecordedVideoFuture:(SCFuture<id<SCManagedRecordedVideo>> *)videoProviderFuture
                          videoSize:(CGSize)videoSize
                   placeholderImage:(UIImage *)placeholderImage
                            session:(SCVideoCaptureSessionInfo)sessionInfo;

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
 didSucceedWithRecordedVideo:(SCManagedRecordedVideo *)recordedVideo
                     session:(SCVideoCaptureSessionInfo)sessionInfo;

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
            didFailWithError:(NSError *)error
                     session:(SCVideoCaptureSessionInfo)sessionInfo;

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
     didCancelVideoRecording:(SCVideoCaptureSessionInfo)sessionInfo;

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
                 didGetError:(NSError *)error
                     forType:(SCManagedVideoCapturerInfoType)type
                     session:(SCVideoCaptureSessionInfo)sessionInfo;

- (NSDictionary *)managedVideoCapturerGetExtraFrameHealthInfo:(SCManagedVideoCapturer *)managedVideoCapturer;

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
  didAppendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
       presentationTimestamp:(CMTime)presentationTimestamp;

@end

/**
 * AVFoundation backed class that writes frames to an output file. SCManagedVideoCapturer
 * uses SCManagedVideoCapturerOutputSettings to determine output settings. If no output
 * settings are passed in (nil) SCManagedVideoCapturer will fall back on default settings.
 */
@interface SCManagedVideoCapturer : NSObject <SCManagedVideoDataSourceListener, SCManagedAudioDataSource>

/**
 * Return the output URL that passed into beginRecordingToURL method
 */
@property (nonatomic, copy, readonly) NSURL *outputURL;

@property (nonatomic, weak) id<SCManagedVideoCapturerDelegate> delegate;
@property (nonatomic, readonly) SCVideoCaptureSessionInfo activeSession;
@property (nonatomic, assign, readonly) CMTime firstWrittenAudioBufferDelay;
@property (nonatomic, assign, readonly) BOOL audioQueueStarted;

- (instancetype)initWithQueuePerformer:(SCQueuePerformer *)queuePerformer;

- (void)prepareForRecordingWithAudioConfiguration:(SCAudioConfiguration *)configuration;
- (SCVideoCaptureSessionInfo)startRecordingAsynchronouslyWithOutputSettings:
                                 (SCManagedVideoCapturerOutputSettings *)outputSettings
                                                         audioConfiguration:(SCAudioConfiguration *)audioConfiguration
                                                                maxDuration:(NSTimeInterval)maxDuration
                                                                      toURL:(NSURL *)URL
                                                               deviceFormat:(AVCaptureDeviceFormat *)deviceFormat
                                                                orientation:(AVCaptureVideoOrientation)videoOrientation
                                                           captureSessionID:(NSString *)captureSessionID;

- (void)stopRecordingAsynchronously;
- (void)cancelRecordingAsynchronously;

// Schedule a task to run, it is thread safe.
- (void)addTimedTask:(SCTimedTask *)task;

// Clear all tasks, it is thread safe.
- (void)clearTimedTasks;

@end
