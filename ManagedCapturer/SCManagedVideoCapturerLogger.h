//
//  SCCaptureLogger.h
//  Snapchat
//
//  Created by Pinlin on 12/04/2017.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

static NSString *const kSCCapturerStartingStepAudioSession = @"audio_session";
static NSString *const kSCCapturerStartingStepTranscodeingVideoBitrate = @"transcoding_video_bitrate";
static NSString *const kSCCapturerStartingStepOutputSettings = @"output_settings";
static NSString *const kSCCapturerStartingStepVideoFrameRawData = @"video_frame_raw_data";
static NSString *const kSCCapturerStartingStepAudioRecording = @"audio_recording";
static NSString *const kSCCapturerStartingStepAssetWriterConfiguration = @"asset_writer_config";
static NSString *const kSCCapturerStartingStepStartingWriting = @"start_writing";
static NSString *const kCapturerStartingTotalDelay = @"total_delay";

@interface SCManagedVideoCapturerLogger : NSObject

- (void)prepareForStartingLog;
- (void)logStartingStep:(NSString *)stepName;
- (void)endLoggingForStarting;
- (void)logEventIfStartingTooSlow;

@end
