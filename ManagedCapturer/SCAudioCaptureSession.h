//
//  SCAudioCaptureSession.h
//  Snapchat
//
//  Created by Liu Liu on 3/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

extern double const kSCAudioCaptureSessionDefaultSampleRate;

typedef void (^audio_capture_session_block)(NSError *error);

@protocol SCAudioCaptureSession;

@protocol SCAudioCaptureSessionDelegate <NSObject>

- (void)audioCaptureSession:(id<SCAudioCaptureSession>)audioCaptureSession
      didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end

@protocol SCAudioCaptureSession <NSObject>

@property (nonatomic, weak) id<SCAudioCaptureSessionDelegate> delegate;

// Return detail informantions dictionary if error occured, else return nil
- (void)beginAudioRecordingAsynchronouslyWithSampleRate:(double)sampleRate
                                      completionHandler:(audio_capture_session_block)completionHandler;

- (void)disposeAudioRecordingSynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler;

@end

@interface SCAudioCaptureSession : NSObject <SCAudioCaptureSession>

@end
