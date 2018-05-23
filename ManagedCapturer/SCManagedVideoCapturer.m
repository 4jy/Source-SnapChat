//
//  SCManagedVideoCapturer.m
//  Snapchat
//
//  Created by Liu Liu on 5/1/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCManagedVideoCapturer.h"

#import "NSURL+Asset.h"
#import "SCAudioCaptureSession.h"
#import "SCCameraTweaks.h"
#import "SCCapturerBufferedVideoWriter.h"
#import "SCCoreCameraLogger.h"
#import "SCLogger+Camera.h"
#import "SCManagedCapturer.h"
#import "SCManagedFrameHealthChecker.h"
#import "SCManagedVideoCapturerLogger.h"
#import "SCManagedVideoCapturerTimeObserver.h"

#import <SCAudio/SCAudioSession.h>
#import <SCAudio/SCMutableAudioSession.h>
#import <SCBase/SCMacros.h>
#import <SCCameraFoundation/SCManagedAudioDataSourceListenerAnnouncer.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCCoreGraphicsUtils.h>
#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCFuture.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/UIImage+CVPixelBufferRef.h>
#import <SCImageProcess/SCSnapVideoFrameRawData.h>
#import <SCImageProcess/SCVideoFrameRawDataCollector.h>
#import <SCImageProcess/SnapVideoMetadata.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger+Performance.h>
#import <SCLogger/SCLogger.h>

#import <SCAudioScope/SCAudioSessionExperimentAdapter.h>

@import CoreMedia;
@import ImageIO;

static NSString *const kSCAudioCaptureAudioSessionLabel = @"CAMERA";

// wild card audio queue error code
static NSInteger const kSCAudioQueueErrorWildCard = -50;
// kAudioHardwareIllegalOperationError, it means hardware failure
static NSInteger const kSCAudioQueueErrorHardware = 1852797029;

typedef NS_ENUM(NSUInteger, SCManagedVideoCapturerStatus) {
    SCManagedVideoCapturerStatusUnknown,
    SCManagedVideoCapturerStatusIdle,
    SCManagedVideoCapturerStatusPrepareToRecord,
    SCManagedVideoCapturerStatusReadyForRecording,
    SCManagedVideoCapturerStatusRecording,
    SCManagedVideoCapturerStatusError,
};

#define SCLogVideoCapturerInfo(fmt, ...) SCLogCoreCameraInfo(@"[SCManagedVideoCapturer] " fmt, ##__VA_ARGS__)
#define SCLogVideoCapturerWarning(fmt, ...) SCLogCoreCameraWarning(@"[SCManagedVideoCapturer] " fmt, ##__VA_ARGS__)
#define SCLogVideoCapturerError(fmt, ...) SCLogCoreCameraError(@"[SCManagedVideoCapturer] " fmt, ##__VA_ARGS__)

@interface SCManagedVideoCapturer () <SCAudioCaptureSessionDelegate>
// This value has to be atomic because it is read on a different thread (write
// on output queue, as always)
@property (atomic, assign, readwrite) SCManagedVideoCapturerStatus status;

@property (nonatomic, assign) CMTime firstWrittenAudioBufferDelay;

@end

static char *const kSCManagedVideoCapturerQueueLabel = "com.snapchat.managed-video-capturer-queue";
static char *const kSCManagedVideoCapturerPromiseQueueLabel = "com.snapchat.video-capture-promise";

static NSString *const kSCManagedVideoCapturerErrorDomain = @"kSCManagedVideoCapturerErrorDomain";

static NSInteger const kSCManagedVideoCapturerCannotAddAudioVideoInput = 1001;
static NSInteger const kSCManagedVideoCapturerEmptyFrame = 1002;
static NSInteger const kSCManagedVideoCapturerStopBeforeStart = 1003;
static NSInteger const kSCManagedVideoCapturerStopWithoutStart = 1004;
static NSInteger const kSCManagedVideoCapturerZeroVideoSize = -111;

static NSUInteger const kSCVideoContentComplexitySamplingRate = 90;

// This is the maximum time we will wait for the Recording Capturer pipeline to drain
// When video stabilization is turned on the extra frame delay is around 20 frames.
// @30 fps this is 0.66 seconds
static NSTimeInterval const kSCManagedVideoCapturerStopRecordingDeadline = 1.0;

static const char *SCPlaceholderImageGenerationQueueLabel = "com.snapchat.video-capturer-placeholder-queue";

static const char *SCVideoRecordingPreparationQueueLabel = "com.snapchat.video-recording-preparation-queue";

static dispatch_queue_t SCPlaceholderImageGenerationQueue(void)
{
    static dispatch_queue_t queue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = dispatch_queue_create(SCPlaceholderImageGenerationQueueLabel, DISPATCH_QUEUE_SERIAL);
    });
    return queue;
}

@interface SCManagedVideoCapturer () <SCCapturerBufferedVideoWriterDelegate>

@end

@implementation SCManagedVideoCapturer {
    NSTimeInterval _maxDuration;
    NSTimeInterval _recordStartTime;

    SCCapturerBufferedVideoWriter *_videoWriter;

    BOOL _hasWritten;
    SCQueuePerformer *_performer;
    SCQueuePerformer *_videoPreparationPerformer;
    SCAudioCaptureSession *_audioCaptureSession;
    NSError *_lastError;
    UIImage *_placeholderImage;

    // For logging purpose
    BOOL _isVideoSnap;
    NSDictionary *_videoOutputSettings;

    // The following value is used to control the encoder shutdown following a stop recording message.
    // When a shutdown is requested this value will be the timestamp of the last captured frame.
    CFTimeInterval _stopTime;
    NSInteger _stopSession;
    SCAudioConfigurationToken *_preparedAudioConfiguration;
    SCAudioConfigurationToken *_audioConfiguration;

    dispatch_semaphore_t _startRecordingSemaphore;

    // For store the raw frame datas
    NSInteger _rawDataFrameNum;
    NSURL *_rawDataURL;
    SCVideoFrameRawDataCollector *_videoFrameRawDataCollector;

    CMTime _startSessionTime;
    // Indicates how actual processing time of first frame. Also used for camera timer animation start offset.
    NSTimeInterval _startSessionRealTime;
    CMTime _endSessionTime;
    sc_managed_capturer_recording_session_t _sessionId;

    SCManagedVideoCapturerTimeObserver *_timeObserver;
    SCManagedVideoCapturerLogger *_capturerLogger;

    CGSize _outputSize;
    BOOL _isFrontFacingCamera;
    SCPromise<id<SCManagedRecordedVideo>> *_recordedVideoPromise;
    SCManagedAudioDataSourceListenerAnnouncer *_announcer;

    NSString *_captureSessionID;
    CIContext *_ciContext;
}

@synthesize performer = _performer;

- (instancetype)init
{
    SCTraceStart();
    return [self initWithQueuePerformer:[[SCQueuePerformer alloc] initWithLabel:kSCManagedVideoCapturerQueueLabel
                                                               qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                                      queueType:DISPATCH_QUEUE_SERIAL
                                                                        context:SCQueuePerformerContextCamera]];
}

- (instancetype)initWithQueuePerformer:(SCQueuePerformer *)queuePerformer
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _performer = queuePerformer;
        _audioCaptureSession = [[SCAudioCaptureSession alloc] init];
        _audioCaptureSession.delegate = self;
        _announcer = [SCManagedAudioDataSourceListenerAnnouncer new];
        self.status = SCManagedVideoCapturerStatusIdle;
        _capturerLogger = [[SCManagedVideoCapturerLogger alloc] init];
        _startRecordingSemaphore = dispatch_semaphore_create(0);
    }
    return self;
}

- (void)dealloc
{
    SCLogVideoCapturerInfo(@"SCVideoCaptureSessionInfo before dealloc: %@",
                           SCVideoCaptureSessionInfoGetDebugDescription(self.activeSession));
}

- (SCVideoCaptureSessionInfo)activeSession
{
    return SCVideoCaptureSessionInfoMake(_startSessionTime, _endSessionTime, _sessionId);
}

- (CGSize)defaultSizeForDeviceFormat:(AVCaptureDeviceFormat *)format
{
    SCTraceStart();
    // if there is no device, and no format
    if (format == nil) {
        // hard code 720p
        return CGSizeMake(kSCManagedCapturerDefaultVideoActiveFormatWidth,
                          kSCManagedCapturerDefaultVideoActiveFormatHeight);
    }
    CMVideoDimensions videoDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    CGSize size = CGSizeMake(videoDimensions.width, videoDimensions.height);
    if (videoDimensions.width > kSCManagedCapturerDefaultVideoActiveFormatWidth &&
        videoDimensions.height > kSCManagedCapturerDefaultVideoActiveFormatHeight) {
        CGFloat scaleFactor = MAX((kSCManagedCapturerDefaultVideoActiveFormatWidth / videoDimensions.width),
                                  (kSCManagedCapturerDefaultVideoActiveFormatHeight / videoDimensions.height));
        size = SCSizeMakeAlignTo(SCSizeApplyScale(size, scaleFactor), 2);
    }
    if ([SCDeviceName isIphoneX]) {
        size = SCSizeApplyScale(size, kSCIPhoneXCapturedImageVideoCropRatio);
    }
    return size;
}

- (CGSize)cropSize:(CGSize)size toAspectRatio:(CGFloat)aspectRatio
{
    if (aspectRatio == kSCManagedCapturerAspectRatioUnspecified) {
        return size;
    }
    // video input is always in landscape mode
    aspectRatio = 1.0 / aspectRatio;
    if (size.width > size.height * aspectRatio) {
        size.width = size.height * aspectRatio;
    } else {
        size.height = size.width / aspectRatio;
    }
    return CGSizeMake(roundf(size.width / 2) * 2, roundf(size.height / 2) * 2);
}

- (SCManagedVideoCapturerOutputSettings *)defaultRecordingOutputSettingsWithDeviceFormat:
    (AVCaptureDeviceFormat *)deviceFormat
{
    SCTraceStart();
    CGFloat aspectRatio = SCManagedCapturedImageAndVideoAspectRatio();
    CGSize outputSize = [self defaultSizeForDeviceFormat:deviceFormat];
    outputSize = [self cropSize:outputSize toAspectRatio:aspectRatio];

    // [TODO](Chao): remove the dependency of SCManagedVideoCapturer on SnapVideoMetaData
    NSInteger videoBitRate = [SnapVideoMetadata averageTranscodingBitRate:outputSize
                                                              isRecording:YES
                                                              highQuality:YES
                                                                 duration:0
                                                               iFrameOnly:NO
                                                     originalVideoBitRate:0
                                                 overlayImageFileSizeBits:0
                                                        videoPlaybackRate:1
                                                            isLagunaVideo:NO
                                                        hasOverlayToBlend:NO
                                                               sourceType:SCSnapVideoFilterSourceTypeUndefined];
    SCTraceSignal(@"Setup transcoding video bitrate");
    [_capturerLogger logStartingStep:kSCCapturerStartingStepTranscodeingVideoBitrate];

    SCManagedVideoCapturerOutputSettings *outputSettings =
        [[SCManagedVideoCapturerOutputSettings alloc] initWithWidth:outputSize.width
                                                             height:outputSize.height
                                                       videoBitRate:videoBitRate
                                                       audioBitRate:64000.0
                                                   keyFrameInterval:15
                                                         outputType:SCManagedVideoCapturerOutputTypeVideoSnap];

    return outputSettings;
}

- (SCQueuePerformer *)_getVideoPreparationPerformer
{
    SCAssert([_performer isCurrentPerformer], @"must run on _performer");
    if (!_videoPreparationPerformer) {
        _videoPreparationPerformer = [[SCQueuePerformer alloc] initWithLabel:SCVideoRecordingPreparationQueueLabel
                                                            qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                                     context:SCQueuePerformerContextCamera];
    }
    return _videoPreparationPerformer;
}

- (void)prepareForRecordingWithAudioConfiguration:(SCAudioConfiguration *)configuration
{
    SCTraceStart();
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        self.status = SCManagedVideoCapturerStatusPrepareToRecord;
        if (_audioConfiguration) {
            [SCAudioSessionExperimentAdapter relinquishConfiguration:_audioConfiguration performer:nil completion:nil];
        }
        __block NSError *audioSessionError = nil;
        _preparedAudioConfiguration = _audioConfiguration =
            [SCAudioSessionExperimentAdapter configureWith:configuration
                                                 performer:[self _getVideoPreparationPerformer]
                                                completion:^(NSError *error) {
                                                    audioSessionError = error;
                                                    if (self.status == SCManagedVideoCapturerStatusPrepareToRecord) {
                                                        dispatch_semaphore_signal(_startRecordingSemaphore);
                                                    }
                                                }];

        // Wait until preparation for recording is done
        dispatch_semaphore_wait(_startRecordingSemaphore, DISPATCH_TIME_FOREVER);
        [_delegate managedVideoCapturer:self
                            didGetError:audioSessionError
                                forType:SCManagedVideoCapturerInfoAudioSessionError
                                session:self.activeSession];
    }];
}

- (SCVideoCaptureSessionInfo)startRecordingAsynchronouslyWithOutputSettings:
                                 (SCManagedVideoCapturerOutputSettings *)outputSettings
                                                         audioConfiguration:(SCAudioConfiguration *)audioConfiguration
                                                                maxDuration:(NSTimeInterval)maxDuration
                                                                      toURL:(NSURL *)URL
                                                               deviceFormat:(AVCaptureDeviceFormat *)deviceFormat
                                                                orientation:(AVCaptureVideoOrientation)videoOrientation
                                                           captureSessionID:(NSString *)captureSessionID
{
    SCTraceStart();
    _captureSessionID = [captureSessionID copy];
    [_capturerLogger prepareForStartingLog];

    [[SCLogger sharedInstance] logTimedEventStart:kSCCameraMetricsAudioDelay
                                         uniqueId:_captureSessionID
                                    isUniqueEvent:NO];

    NSTimeInterval startTime = CACurrentMediaTime();
    [[SCLogger sharedInstance] logPreCaptureOperationRequestedAt:startTime];
    [[SCCoreCameraLogger sharedInstance] logCameraCreationDelaySplitPointPreCaptureOperationRequested];
    _sessionId = arc4random();

    // Set a invalid time so that we don't process videos when no frame available
    _startSessionTime = kCMTimeInvalid;
    _endSessionTime = kCMTimeInvalid;
    _firstWrittenAudioBufferDelay = kCMTimeInvalid;
    _audioQueueStarted = NO;

    SCLogVideoCapturerInfo(@"SCVideoCaptureSessionInfo at start of recording: %@",
                           SCVideoCaptureSessionInfoGetDebugDescription(self.activeSession));

    SCVideoCaptureSessionInfo sessionInfo = self.activeSession;
    [_performer performImmediatelyIfCurrentPerformer:^{
        _maxDuration = maxDuration;
        dispatch_block_t startRecordingBlock = ^{
            _rawDataFrameNum = 0;
            // Begin audio recording asynchronously, first, need to have correct audio session.
            SCTraceStart();
            SCLogVideoCapturerInfo(@"Dequeue begin recording with audio session change delay: %lf seconds",
                                   CACurrentMediaTime() - startTime);
            if (self.status != SCManagedVideoCapturerStatusReadyForRecording) {
                SCLogVideoCapturerInfo(@"SCManagedVideoCapturer status: %lu", (unsigned long)self.status);
                // We may already released, but this should be OK.
                [SCAudioSessionExperimentAdapter relinquishConfiguration:_preparedAudioConfiguration
                                                               performer:nil
                                                              completion:nil];
                return;
            }
            if (_preparedAudioConfiguration != _audioConfiguration) {
                SCLogVideoCapturerInfo(
                    @"SCManagedVideoCapturer has mismatched audio session token, prepared: %@, have: %@",
                    _preparedAudioConfiguration.token, _audioConfiguration.token);
                // We are on a different audio session token already.
                [SCAudioSessionExperimentAdapter relinquishConfiguration:_preparedAudioConfiguration
                                                               performer:nil
                                                              completion:nil];
                return;
            }

            // Divide start recording workflow into different steps to log delay time.
            // And checkpoint is the end of a step
            [_capturerLogger logStartingStep:kSCCapturerStartingStepAudioSession];
            [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                             uniqueId:_captureSessionID
                                             stepName:@"audio_session_start_end"];

            SCLogVideoCapturerInfo(@"Prepare to begin recording");
            _lastError = nil;

            // initialize stopTime to a number much larger than the CACurrentMediaTime() which is the time from Jan 1,
            // 2001
            _stopTime = kCFAbsoluteTimeIntervalSince1970;

            // Restart everything
            _hasWritten = NO;

            SCManagedVideoCapturerOutputSettings *finalOutputSettings =
                outputSettings ? outputSettings : [self defaultRecordingOutputSettingsWithDeviceFormat:deviceFormat];
            _isVideoSnap = finalOutputSettings.outputType == SCManagedVideoCapturerOutputTypeVideoSnap;
            _outputSize = CGSizeMake(finalOutputSettings.height, finalOutputSettings.width);
            [[SCLogger sharedInstance] logEvent:kSCCameraMetricsVideoRecordingStart
                                     parameters:@{
                                         @"video_width" : @(finalOutputSettings.width),
                                         @"video_height" : @(finalOutputSettings.height),
                                         @"bit_rate" : @(finalOutputSettings.videoBitRate),
                                         @"is_video_snap" : @(_isVideoSnap),
                                     }];

            _outputURL = [URL copy];
            _rawDataURL = [_outputURL URLByAppendingPathExtension:@"dat"];
            [_capturerLogger logStartingStep:kSCCapturerStartingStepOutputSettings];

            // Make sure the raw frame data file is gone
            SCTraceSignal(@"Setup video frame raw data");
            [[NSFileManager defaultManager] removeItemAtURL:_rawDataURL error:NULL];
            if ([SnapVideoMetadata deviceMeetsRequirementsForContentAdaptiveVideoEncoding]) {
                if (!_videoFrameRawDataCollector) {
                    _videoFrameRawDataCollector = [[SCVideoFrameRawDataCollector alloc] initWithPerformer:_performer];
                }
                [_videoFrameRawDataCollector prepareForCollectingVideoFrameRawDataWithRawDataURL:_rawDataURL];
            }
            [_capturerLogger logStartingStep:kSCCapturerStartingStepVideoFrameRawData];

            SCLogVideoCapturerInfo(@"Prepare to begin audio recording");

            [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                             uniqueId:_captureSessionID
                                             stepName:@"audio_queue_start_begin"];
            [self _beginAudioQueueRecordingWithCompleteHandler:^(NSError *error) {
                [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                                 uniqueId:_captureSessionID
                                                 stepName:@"audio_queue_start_end"];
                if (error) {
                    [_delegate managedVideoCapturer:self
                                        didGetError:error
                                            forType:SCManagedVideoCapturerInfoAudioQueueError
                                            session:sessionInfo];
                } else {
                    _audioQueueStarted = YES;
                }
                if (self.status == SCManagedVideoCapturerStatusRecording) {
                    [_delegate managedVideoCapturer:self didBeginAudioRecording:sessionInfo];
                }
            }];

            // Call this delegate first so that we have proper state transition from begin recording to finish / error
            [_delegate managedVideoCapturer:self didBeginVideoRecording:sessionInfo];

            // We need to start with a fresh recording file, make sure it's gone
            [[NSFileManager defaultManager] removeItemAtURL:_outputURL error:NULL];
            [_capturerLogger logStartingStep:kSCCapturerStartingStepAudioRecording];

            SCTraceSignal(@"Setup asset writer");

            NSError *error = nil;
            _videoWriter = [[SCCapturerBufferedVideoWriter alloc] initWithPerformer:_performer
                                                                          outputURL:self.outputURL
                                                                           delegate:self
                                                                              error:&error];
            if (error) {
                self.status = SCManagedVideoCapturerStatusError;
                _lastError = error;
                _placeholderImage = nil;
                [_delegate managedVideoCapturer:self
                                    didGetError:error
                                        forType:SCManagedVideoCapturerInfoAssetWriterError
                                        session:sessionInfo];
                [_delegate managedVideoCapturer:self didFailWithError:_lastError session:sessionInfo];
                return;
            }

            [_capturerLogger logStartingStep:kSCCapturerStartingStepAssetWriterConfiguration];
            if (![_videoWriter prepareWritingWithOutputSettings:finalOutputSettings]) {
                _lastError = [NSError errorWithDomain:kSCManagedVideoCapturerErrorDomain
                                                 code:kSCManagedVideoCapturerCannotAddAudioVideoInput
                                             userInfo:nil];
                _placeholderImage = nil;
                [_delegate managedVideoCapturer:self didFailWithError:_lastError session:sessionInfo];
                return;
            }
            SCTraceSignal(@"Observe asset writer status change");
            SCCAssert(_placeholderImage == nil, @"placeholderImage should be nil");
            self.status = SCManagedVideoCapturerStatusRecording;
            // Only log the recording delay event from camera view (excluding video note recording)
            if (_isVideoSnap) {
                [[SCLogger sharedInstance] logTimedEventEnd:kSCCameraMetricsRecordingDelay
                                                   uniqueId:@"VIDEO"
                                                 parameters:@{
                                                     @"type" : @"video"
                                                 }];
            }
            _recordStartTime = CACurrentMediaTime();
        };

        [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                         uniqueId:_captureSessionID
                                         stepName:@"audio_session_start_begin"];

        if (self.status == SCManagedVideoCapturerStatusPrepareToRecord) {
            self.status = SCManagedVideoCapturerStatusReadyForRecording;
            startRecordingBlock();
        } else {
            self.status = SCManagedVideoCapturerStatusReadyForRecording;
            if (_audioConfiguration) {
                [SCAudioSessionExperimentAdapter relinquishConfiguration:_audioConfiguration
                                                               performer:nil
                                                              completion:nil];
            }
            _preparedAudioConfiguration = _audioConfiguration = [SCAudioSessionExperimentAdapter
                configureWith:audioConfiguration
                    performer:_performer
                   completion:^(NSError *error) {
                       if (error) {
                           [_delegate managedVideoCapturer:self
                                               didGetError:error
                                                   forType:SCManagedVideoCapturerInfoAudioSessionError
                                                   session:sessionInfo];
                       }
                       startRecordingBlock();
                   }];
        }
    }];
    return sessionInfo;
}

- (NSError *)_handleRetryBeginAudioRecordingErrorCode:(NSInteger)errorCode
                                                error:(NSError *)error
                                            micResult:(NSDictionary *)resultInfo
{
    SCTraceStart();
    NSString *resultStr = SC_CAST_TO_CLASS_OR_NIL(resultInfo[SCAudioSessionRetryDataSourceInfoKey], NSString);
    BOOL changeMicSuccess = [resultInfo[SCAudioSessionRetryDataSourceResultKey] boolValue];
    if (!error) {
        SCManagedVideoCapturerInfoType type = SCManagedVideoCapturerInfoAudioQueueRetrySuccess;
        if (changeMicSuccess) {
            if (errorCode == kSCAudioQueueErrorWildCard) {
                type = SCManagedVideoCapturerInfoAudioQueueRetryDataSourceSuccess_audioQueue;
            } else if (errorCode == kSCAudioQueueErrorHardware) {
                type = SCManagedVideoCapturerInfoAudioQueueRetryDataSourceSuccess_hardware;
            }
        }
        [_delegate managedVideoCapturer:self didGetError:nil forType:type session:self.activeSession];
    } else {
        error = [self _appendInfo:resultStr forInfoKey:@"retry_datasource_result" toError:error];
        SCLogVideoCapturerError(@"Retry setting audio session failed with error:%@", error);
    }
    return error;
}

- (BOOL)_isBottomMicBrokenCode:(NSInteger)errorCode
{
    // we consider both -50 and 1852797029 as a broken microphone case
    return (errorCode == kSCAudioQueueErrorWildCard || errorCode == kSCAudioQueueErrorHardware);
}

- (void)_beginAudioQueueRecordingWithCompleteHandler:(audio_capture_session_block)block
{
    SCTraceStart();
    SCAssert(block, @"block can not be nil");
    @weakify(self);
    void (^beginAudioBlock)(NSError *error) = ^(NSError *error) {
        @strongify(self);
        SC_GUARD_ELSE_RETURN(self);
        [_performer performImmediatelyIfCurrentPerformer:^{

            SCTraceStart();
            NSInteger errorCode = error.code;
            if ([self _isBottomMicBrokenCode:errorCode] &&
                (self.status == SCManagedVideoCapturerStatusReadyForRecording ||
                 self.status == SCManagedVideoCapturerStatusRecording)) {

                SCLogVideoCapturerError(@"Start to retry begin audio queue (error code: %@)", @(errorCode));

                // use front microphone to retry
                NSDictionary *resultInfo = [[SCAudioSession sharedInstance] tryUseFrontMicWithErrorCode:errorCode];
                [self _retryRequestRecordingWithCompleteHandler:^(NSError *error) {
                    // then retry audio queue again
                    [_audioCaptureSession
                        beginAudioRecordingAsynchronouslyWithSampleRate:kSCAudioCaptureSessionDefaultSampleRate
                                                      completionHandler:^(NSError *innerError) {
                                                          NSError *modifyError = [self
                                                              _handleRetryBeginAudioRecordingErrorCode:errorCode
                                                                                                 error:innerError
                                                                                             micResult:resultInfo];
                                                          block(modifyError);
                                                      }];
                }];

            } else {
                block(error);
            }
        }];
    };
    [_audioCaptureSession beginAudioRecordingAsynchronouslyWithSampleRate:kSCAudioCaptureSessionDefaultSampleRate
                                                        completionHandler:^(NSError *error) {
                                                            beginAudioBlock(error);
                                                        }];
}

// This method must not change nullability of error, it should only either append info into userInfo,
// or return the NSError as it is.
- (NSError *)_appendInfo:(NSString *)infoStr forInfoKey:(NSString *)infoKey toError:(NSError *)error
{
    if (!error || infoStr.length == 0 || infoKey.length == 0 || error.domain.length == 0) {
        return error;
    }
    NSMutableDictionary *errorInfo = [[error userInfo] mutableCopy];
    errorInfo[infoKey] = infoStr.length > 0 ? infoStr : @"(null)";

    return [NSError errorWithDomain:error.domain code:error.code userInfo:errorInfo];
}

- (void)_retryRequestRecordingWithCompleteHandler:(audio_capture_session_block)block
{
    SCTraceStart();
    if (_audioConfiguration) {
        [SCAudioSessionExperimentAdapter relinquishConfiguration:_audioConfiguration performer:nil completion:nil];
    }
    SCVideoCaptureSessionInfo sessionInfo = self.activeSession;
    _preparedAudioConfiguration = _audioConfiguration = [SCAudioSessionExperimentAdapter
        configureWith:_audioConfiguration.configuration
            performer:_performer
           completion:^(NSError *error) {
               if (error) {
                   [_delegate managedVideoCapturer:self
                                       didGetError:error
                                           forType:SCManagedVideoCapturerInfoAudioSessionError
                                           session:sessionInfo];
               }
               if (block) {
                   block(error);
               }
           }];
}

#pragma SCCapturerBufferedVideoWriterDelegate

- (void)videoWriterDidFailWritingWithError:(NSError *)error
{
    // If it failed, we call the delegate method, release everything else we
    // have, well, on the output queue obviously
    SCTraceStart();
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        SCVideoCaptureSessionInfo sessionInfo = self.activeSession;
        [_outputURL reloadAssetKeys];
        [self _cleanup];
        [self _disposeAudioRecording];
        self.status = SCManagedVideoCapturerStatusError;
        _lastError = error;
        _placeholderImage = nil;
        [_delegate managedVideoCapturer:self
                            didGetError:error
                                forType:SCManagedVideoCapturerInfoAssetWriterError
                                session:sessionInfo];
        [_delegate managedVideoCapturer:self didFailWithError:_lastError session:sessionInfo];
    }];
}

- (void)_willStopRecording
{
    if (self.status == SCManagedVideoCapturerStatusRecording) {
        // To notify UI continue the preview processing
        SCQueuePerformer *promisePerformer =
            [[SCQueuePerformer alloc] initWithLabel:kSCManagedVideoCapturerPromiseQueueLabel
                                   qualityOfService:QOS_CLASS_USER_INTERACTIVE
                                          queueType:DISPATCH_QUEUE_SERIAL
                                            context:SCQueuePerformerContextCamera];
        _recordedVideoPromise = [[SCPromise alloc] initWithPerformer:promisePerformer];
        [_delegate managedVideoCapturer:self
            willStopWithRecordedVideoFuture:_recordedVideoPromise.future
                                  videoSize:_outputSize
                           placeholderImage:_placeholderImage
                                    session:self.activeSession];
    }
}

- (void)_stopRecording
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"Needs to be on the performing queue");
    // Reset stop session as well as stop time.
    ++_stopSession;
    _stopTime = kCFAbsoluteTimeIntervalSince1970;
    SCPromise<id<SCManagedRecordedVideo>> *recordedVideoPromise = _recordedVideoPromise;
    _recordedVideoPromise = nil;
    sc_managed_capturer_recording_session_t sessionId = _sessionId;
    if (self.status == SCManagedVideoCapturerStatusRecording) {
        self.status = SCManagedVideoCapturerStatusIdle;
        if (CMTIME_IS_VALID(_endSessionTime)) {
            [_videoWriter
                finishWritingAtSourceTime:_endSessionTime
                    withCompletionHanlder:^{
                        // actually, make sure everything happens on outputQueue
                        [_performer performImmediatelyIfCurrentPerformer:^{
                            if (sessionId != _sessionId) {
                                SCLogVideoCapturerError(@"SessionId mismatch: before: %@, after: %@", @(sessionId),
                                                        @(_sessionId));
                                return;
                            }
                            [self _disposeAudioRecording];
                            // Log the video snap recording success event w/ parameters, not including video
                            // note
                            if (_isVideoSnap) {
                                [SnapVideoMetadata logVideoEvent:kSCCameraMetricsVideoRecordingSuccess
                                                   videoSettings:_videoOutputSettings
                                                          isSave:NO];
                            }
                            void (^stopRecordingCompletionBlock)(NSURL *) = ^(NSURL *rawDataURL) {
                                SCAssert([_performer isCurrentPerformer], @"Needs to be on the performing queue");
                                SCVideoCaptureSessionInfo sessionInfo = self.activeSession;

                                [self _cleanup];

                                [[SCLogger sharedInstance] logTimedEventStart:@"SNAP_VIDEO_SIZE_LOADING"
                                                                     uniqueId:@""
                                                                isUniqueEvent:NO];
                                CGSize videoSize =
                                    [SnapVideoMetadata videoSizeForURL:_outputURL waitWhileLoadingTracksIfNeeded:YES];
                                [[SCLogger sharedInstance] logTimedEventEnd:@"SNAP_VIDEO_SIZE_LOADING"
                                                                   uniqueId:@""
                                                                 parameters:nil];
                                // Log error if video file is not really ready
                                if (videoSize.width == 0.0 || videoSize.height == 0.0) {
                                    _lastError = [NSError errorWithDomain:kSCManagedVideoCapturerErrorDomain
                                                                     code:kSCManagedVideoCapturerZeroVideoSize
                                                                 userInfo:nil];
                                    [recordedVideoPromise completeWithError:_lastError];
                                    [_delegate managedVideoCapturer:self
                                                   didFailWithError:_lastError
                                                            session:sessionInfo];
                                    _placeholderImage = nil;
                                    return;
                                }
                                // If the video duration is too short, the future object will complete
                                // with error as well
                                SCManagedRecordedVideo *recordedVideo =
                                    [[SCManagedRecordedVideo alloc] initWithVideoURL:_outputURL
                                                                 rawVideoDataFileURL:_rawDataURL
                                                                    placeholderImage:_placeholderImage
                                                                 isFrontFacingCamera:_isFrontFacingCamera];
                                [recordedVideoPromise completeWithValue:recordedVideo];
                                [_delegate managedVideoCapturer:self
                                    didSucceedWithRecordedVideo:recordedVideo
                                                        session:sessionInfo];
                                _placeholderImage = nil;
                            };

                            if (_videoFrameRawDataCollector) {
                                [_videoFrameRawDataCollector
                                    drainFrameDataCollectionWithCompletionHandler:^(NSURL *rawDataURL) {
                                        stopRecordingCompletionBlock(rawDataURL);
                                    }];
                            } else {
                                stopRecordingCompletionBlock(nil);
                            }
                        }];
                    }];

        } else {
            [self _disposeAudioRecording];
            SCVideoCaptureSessionInfo sessionInfo = self.activeSession;
            [self _cleanup];
            self.status = SCManagedVideoCapturerStatusError;
            _lastError = [NSError errorWithDomain:kSCManagedVideoCapturerErrorDomain
                                             code:kSCManagedVideoCapturerEmptyFrame
                                         userInfo:nil];
            _placeholderImage = nil;
            [recordedVideoPromise completeWithError:_lastError];
            [_delegate managedVideoCapturer:self didFailWithError:_lastError session:sessionInfo];
        }
    } else {
        if (self.status == SCManagedVideoCapturerStatusPrepareToRecord ||
            self.status == SCManagedVideoCapturerStatusReadyForRecording) {
            _lastError = [NSError errorWithDomain:kSCManagedVideoCapturerErrorDomain
                                             code:kSCManagedVideoCapturerStopBeforeStart
                                         userInfo:nil];
        } else {
            _lastError = [NSError errorWithDomain:kSCManagedVideoCapturerErrorDomain
                                             code:kSCManagedVideoCapturerStopWithoutStart
                                         userInfo:nil];
        }
        SCVideoCaptureSessionInfo sessionInfo = self.activeSession;
        [self _cleanup];
        _placeholderImage = nil;
        if (_audioConfiguration) {
            [SCAudioSessionExperimentAdapter relinquishConfiguration:_audioConfiguration performer:nil completion:nil];
            _audioConfiguration = nil;
        }
        [recordedVideoPromise completeWithError:_lastError];
        [_delegate managedVideoCapturer:self didFailWithError:_lastError session:sessionInfo];
        self.status = SCManagedVideoCapturerStatusIdle;
        [_capturerLogger logEventIfStartingTooSlow];
    }
}

- (void)stopRecordingAsynchronously
{
    SCTraceStart();
    NSTimeInterval stopTime = CACurrentMediaTime();
    [_performer performImmediatelyIfCurrentPerformer:^{
        _stopTime = stopTime;
        NSInteger stopSession = _stopSession;
        [self _willStopRecording];
        [_performer perform:^{
            // If we haven't stopped yet, call the stop now nevertheless.
            if (stopSession == _stopSession) {
                [self _stopRecording];
            }
        }
                      after:kSCManagedVideoCapturerStopRecordingDeadline];
    }];
}

- (void)cancelRecordingAsynchronously
{
    SCTraceStart();
    [_performer performImmediatelyIfCurrentPerformer:^{
        SCTraceStart();
        SCLogVideoCapturerInfo(@"Cancel recording. status: %lu", (unsigned long)self.status);
        if (self.status == SCManagedVideoCapturerStatusRecording) {
            self.status = SCManagedVideoCapturerStatusIdle;
            [self _disposeAudioRecording];
            [_videoWriter cancelWriting];
            SCVideoCaptureSessionInfo sessionInfo = self.activeSession;
            [self _cleanup];
            _placeholderImage = nil;
            [_delegate managedVideoCapturer:self didCancelVideoRecording:sessionInfo];
        } else if ((self.status == SCManagedVideoCapturerStatusPrepareToRecord) ||
                   (self.status == SCManagedVideoCapturerStatusReadyForRecording)) {
            SCVideoCaptureSessionInfo sessionInfo = self.activeSession;
            [self _cleanup];
            self.status = SCManagedVideoCapturerStatusIdle;
            _placeholderImage = nil;
            if (_audioConfiguration) {
                [SCAudioSessionExperimentAdapter relinquishConfiguration:_audioConfiguration
                                                               performer:nil
                                                              completion:nil];
                _audioConfiguration = nil;
            }
            [_delegate managedVideoCapturer:self didCancelVideoRecording:sessionInfo];
        }
        [_capturerLogger logEventIfStartingTooSlow];
    }];
}

- (void)addTimedTask:(SCTimedTask *)task
{
    [_performer performImmediatelyIfCurrentPerformer:^{
        // Only allow to add observers when we are not recording.
        if (!self->_timeObserver) {
            self->_timeObserver = [SCManagedVideoCapturerTimeObserver new];
        }
        [self->_timeObserver addTimedTask:task];
        SCLogVideoCapturerInfo(@"Added timetask: %@", task);
    }];
}

- (void)clearTimedTasks
{
    // _timeObserver will be initialized lazily when adding timed tasks
    SCLogVideoCapturerInfo(@"Clearing time observer");
    [_performer performImmediatelyIfCurrentPerformer:^{
        if (self->_timeObserver) {
            self->_timeObserver = nil;
        }
    }];
}

- (void)_cleanup
{
    [_videoWriter cleanUp];
    _timeObserver = nil;

    SCLogVideoCapturerInfo(@"SCVideoCaptureSessionInfo before cleanup: %@",
                           SCVideoCaptureSessionInfoGetDebugDescription(self.activeSession));

    _startSessionTime = kCMTimeInvalid;
    _endSessionTime = kCMTimeInvalid;
    _firstWrittenAudioBufferDelay = kCMTimeInvalid;
    _sessionId = 0;
    _captureSessionID = nil;
    _audioQueueStarted = NO;
}

- (void)_disposeAudioRecording
{
    SCLogVideoCapturerInfo(@"Disposing audio recording");
    SCAssert([_performer isCurrentPerformer], @"");
    // Setup the audio session token correctly
    SCAudioConfigurationToken *audioConfiguration = _audioConfiguration;
    [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                     uniqueId:_captureSessionID
                                     stepName:@"audio_queue_stop_begin"];
    NSString *captureSessionID = _captureSessionID;
    [_audioCaptureSession disposeAudioRecordingSynchronouslyWithCompletionHandler:^{
        [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                         uniqueId:captureSessionID
                                         stepName:@"audio_queue_stop_end"];
        SCLogVideoCapturerInfo(@"Did dispose audio recording");
        if (audioConfiguration) {
            [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                             uniqueId:captureSessionID
                                             stepName:@"audio_session_stop_begin"];
            [SCAudioSessionExperimentAdapter
                relinquishConfiguration:audioConfiguration
                              performer:_performer
                             completion:^(NSError *_Nullable error) {
                                 [[SCLogger sharedInstance] logStepToEvent:kSCCameraMetricsAudioDelay
                                                                  uniqueId:captureSessionID
                                                                  stepName:@"audio_session_stop_end"];
                                 [[SCLogger sharedInstance] logTimedEventEnd:kSCCameraMetricsAudioDelay
                                                                    uniqueId:captureSessionID
                                                                  parameters:nil];
                             }];
        }
    }];
    _audioConfiguration = nil;
}

- (CIContext *)ciContext
{
    if (!_ciContext) {
        _ciContext = [CIContext contextWithOptions:nil];
    }
    return _ciContext;
}

#pragma mark - SCAudioCaptureSessionDelegate

- (void)audioCaptureSession:(SCAudioCaptureSession *)audioCaptureSession
      didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    SCTraceStart();
    if (self.status != SCManagedVideoCapturerStatusRecording) {
        return;
    }
    CFRetain(sampleBuffer);
    [_performer performImmediatelyIfCurrentPerformer:^{
        if (self.status == SCManagedVideoCapturerStatusRecording) {
            // Audio always follows video, there is no other way around this :)
            if (_hasWritten && CACurrentMediaTime() - _recordStartTime <= _maxDuration) {
                [self _processAudioSampleBuffer:sampleBuffer];
                [_videoWriter appendAudioSampleBuffer:sampleBuffer];
            }
        }
        CFRelease(sampleBuffer);
    }];
}

#pragma mark - SCManagedVideoDataSourceListener

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceStart();
    if (self.status != SCManagedVideoCapturerStatusRecording) {
        return;
    }
    CFRetain(sampleBuffer);
    [_performer performImmediatelyIfCurrentPerformer:^{
        // the following check will allow the capture pipeline to drain
        if (CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer)) > _stopTime) {
            [self _stopRecording];
        } else {
            if (self.status == SCManagedVideoCapturerStatusRecording) {
                _isFrontFacingCamera = (devicePosition == SCManagedCaptureDevicePositionFront);
                CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
                if (CMTIME_IS_VALID(presentationTime)) {
                    SCLogVideoCapturerInfo(@"Obtained video data source at time %lld", presentationTime.value);
                } else {
                    SCLogVideoCapturerInfo(@"Obtained video data source with an invalid time");
                }
                if (!_hasWritten) {
                    // Start writing!
                    [_videoWriter startWritingAtSourceTime:presentationTime];
                    [_capturerLogger endLoggingForStarting];
                    _startSessionTime = presentationTime;
                    _startSessionRealTime = CACurrentMediaTime();
                    SCLogVideoCapturerInfo(@"First frame processed %f seconds after presentation Time",
                                           _startSessionRealTime - CMTimeGetSeconds(presentationTime));
                    _hasWritten = YES;
                    [[SCLogger sharedInstance] logPreCaptureOperationFinishedAt:CMTimeGetSeconds(presentationTime)];
                    [[SCCoreCameraLogger sharedInstance]
                        logCameraCreationDelaySplitPointPreCaptureOperationFinishedAt:CMTimeGetSeconds(
                                                                                          presentationTime)];
                    SCLogVideoCapturerInfo(@"SCVideoCaptureSessionInfo after first frame: %@",
                                           SCVideoCaptureSessionInfoGetDebugDescription(self.activeSession));
                }
                // Only respect video end session time, audio can be cut off, not video,
                // not video
                if (CMTIME_IS_INVALID(_endSessionTime)) {
                    _endSessionTime = presentationTime;
                } else {
                    _endSessionTime = CMTimeMaximum(_endSessionTime, presentationTime);
                }
                if (CACurrentMediaTime() - _recordStartTime <= _maxDuration) {
                    [_videoWriter appendVideoSampleBuffer:sampleBuffer];
                    [self _processVideoSampleBuffer:sampleBuffer];
                }
                if (_timeObserver) {
                    [_timeObserver processTime:CMTimeSubtract(presentationTime, _startSessionTime)
                        sessionStartTimeDelayInSecond:_startSessionRealTime - CMTimeGetSeconds(_startSessionTime)];
                }
            }
        }
        CFRelease(sampleBuffer);
    }];
}

- (void)_generatePlaceholderImageWithPixelBuffer:(CVImageBufferRef)pixelBuffer metaData:(NSDictionary *)metadata
{
    SCTraceStart();
    CVImageBufferRef imageBuffer = CVPixelBufferRetain(pixelBuffer);
    if (imageBuffer) {
        dispatch_async(SCPlaceholderImageGenerationQueue(), ^{
            UIImage *placeholderImage = [UIImage imageWithPixelBufferRef:imageBuffer
                                                             backingType:UIImageBackingTypeCGImage
                                                             orientation:UIImageOrientationRight
                                                                 context:[self ciContext]];
            placeholderImage =
                SCCropImageToTargetAspectRatio(placeholderImage, SCManagedCapturedImageAndVideoAspectRatio());
            [_performer performImmediatelyIfCurrentPerformer:^{
                // After processing, assign it back.
                if (self.status == SCManagedVideoCapturerStatusRecording) {
                    _placeholderImage = placeholderImage;
                    // Check video frame health by placeholder image
                    [[SCManagedFrameHealthChecker sharedInstance]
                        checkVideoHealthForCaptureFrameImage:placeholderImage
                                                    metedata:metadata
                                            captureSessionID:_captureSessionID];
                }
                CVPixelBufferRelease(imageBuffer);
            }];
        });
    }
}

#pragma mark - Pixel Buffer methods

- (void)_processVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    SC_GUARD_ELSE_RETURN(sampleBuffer);
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    BOOL shouldGeneratePlaceholderImage = CMTimeCompare(presentationTime, _startSessionTime) == 0;

    CVImageBufferRef outputPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (outputPixelBuffer) {
        [self _addVideoRawDataWithPixelBuffer:outputPixelBuffer];
        if (shouldGeneratePlaceholderImage) {
            NSDictionary *extraInfo = [_delegate managedVideoCapturerGetExtraFrameHealthInfo:self];
            NSDictionary *metadata =
                [[[SCManagedFrameHealthChecker sharedInstance] metadataForSampleBuffer:sampleBuffer extraInfo:extraInfo]
                    copy];
            [self _generatePlaceholderImageWithPixelBuffer:outputPixelBuffer metaData:metadata];
        }
    }

    [_delegate managedVideoCapturer:self
         didAppendVideoSampleBuffer:sampleBuffer
              presentationTimestamp:CMTimeSubtract(presentationTime, _startSessionTime)];
}

- (void)_processAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    [_announcer managedAudioDataSource:self didOutputSampleBuffer:sampleBuffer];
    if (!CMTIME_IS_VALID(self.firstWrittenAudioBufferDelay)) {
        self.firstWrittenAudioBufferDelay =
            CMTimeSubtract(CMSampleBufferGetPresentationTimeStamp(sampleBuffer), _startSessionTime);
    }
}

- (void)_addVideoRawDataWithPixelBuffer:(CVImageBufferRef)pixelBuffer
{
    if (_videoFrameRawDataCollector && [SnapVideoMetadata deviceMeetsRequirementsForContentAdaptiveVideoEncoding] &&
        ((_rawDataFrameNum % kSCVideoContentComplexitySamplingRate) == 0) && (_rawDataFrameNum > 0)) {
        if (_videoFrameRawDataCollector) {
            CVImageBufferRef imageBuffer = CVPixelBufferRetain(pixelBuffer);
            [_videoFrameRawDataCollector collectVideoFrameRawDataWithImageBuffer:imageBuffer
                                                                        frameNum:_rawDataFrameNum
                                                                      completion:^{
                                                                          CVPixelBufferRelease(imageBuffer);
                                                                      }];
        }
    }
    _rawDataFrameNum++;
}

#pragma mark - SCManagedAudioDataSource

- (void)addListener:(id<SCManagedAudioDataSourceListener>)listener
{
    [_announcer addListener:listener];
}

- (void)removeListener:(id<SCManagedAudioDataSourceListener>)listener
{
    [_announcer removeListener:listener];
}

- (void)startStreamingWithAudioConfiguration:(SCAudioConfiguration *)configuration
{
    SCAssertFail(@"Controlled by recorder");
}

- (void)stopStreaming
{
    SCAssertFail(@"Controlled by recorder");
}

- (BOOL)isStreaming
{
    return self.status == SCManagedVideoCapturerStatusRecording;
}

@end
