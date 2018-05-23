//
//  SCManagedVideoNoSoundLogger.m
//  Snapchat
//
//  Created by Pinlin Chen on 15/07/2017.
//
//

#import "SCManagedVideoNoSoundLogger.h"

#import "SCManagedCapturer.h"
#import "SCManiphestTicketCreator.h"

#import <SCAudio/SCAudioSession+Debug.h>
#import <SCAudio/SCAudioSession.h>
#import <SCFoundation/NSString+Helpers.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCLogHelper.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCUUID.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger.h>

@import AVFoundation;

static BOOL s_startCountingVideoNoSoundFixed;
// Count the number of no sound errors for an App session
static NSUInteger s_noSoundCaseCount = 0;

@interface SCManagedVideoNoSoundLogger () {
    BOOL _isAudioSessionDeactivated;
    int _lenseResumeCount;
}

@property (nonatomic) id<SCManiphestTicketCreator> ticketCreator;

@end

@implementation SCManagedVideoNoSoundLogger

- (instancetype)initWithTicketCreator:(id<SCManiphestTicketCreator>)ticketCreator
{
    if (self = [super init]) {
        _ticketCreator = ticketCreator;
    }
    return self;
}

+ (NSUInteger)noSoundCount
{
    return s_noSoundCaseCount;
}

+ (void)increaseNoSoundCount
{
    s_noSoundCaseCount += 1;
}

+ (void)startCountingVideoNoSoundHaveBeenFixed
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_startCountingVideoNoSoundFixed = YES;
        SCLogGeneralInfo(@"start counting video no sound have been fixed");
    });
}

+ (NSString *)appSessionIdForNoSound
{
    static dispatch_once_t onceToken;
    static NSString *s_AppSessionIdForNoSound = @"SCDefaultSession";
    dispatch_once(&onceToken, ^{
        s_AppSessionIdForNoSound = SCUUID();
    });
    return s_AppSessionIdForNoSound;
}

+ (void)logVideoNoSoundHaveBeenFixedIfNeeded
{
    if (s_startCountingVideoNoSoundFixed) {
        [[SCLogger sharedInstance] logUnsampledEvent:kSCCameraMetricsVideoNoSoundError
                                          parameters:@{
                                              @"have_been_fixed" : @"true",
                                              @"fixed_type" : @"player_leak",
                                              @"asset_writer_success" : @"true",
                                              @"audio_session_success" : @"true",
                                              @"audio_queue_success" : @"true",
                                          }
                                    secretParameters:nil
                                             metrics:nil];
    }
}

+ (void)logAudioSessionCategoryHaveBeenFixed
{
    [[SCLogger sharedInstance] logUnsampledEvent:kSCCameraMetricsVideoNoSoundError
                                      parameters:@{
                                          @"have_been_fixed" : @"true",
                                          @"fixed_type" : @"audio_session_category_mismatch",
                                          @"asset_writer_success" : @"true",
                                          @"audio_session_success" : @"true",
                                          @"audio_queue_success" : @"true",
                                      }
                                secretParameters:nil
                                         metrics:nil];
}

+ (void)logAudioSessionBrokenMicHaveBeenFixed:(NSString *)type
{
    [[SCLogger sharedInstance]
        logUnsampledEvent:kSCCameraMetricsVideoNoSoundError
               parameters:@{
                   @"have_been_fixed" : @"true",
                   @"fixed_type" : @"broken_microphone",
                   @"asset_writer_success" : @"true",
                   @"audio_session_success" : @"true",
                   @"audio_queue_success" : @"true",
                   @"mic_broken_type" : SC_NULL_STRING_IF_NIL(type),
                   @"audio_session_debug_info" :
                       [SCAudioSession sharedInstance].lastRecordingRequestDebugInfo ?: @"(null)",
               }
         secretParameters:nil
                  metrics:nil];
}

- (instancetype)init
{
    if (self = [super init]) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_audioSessionWillDeactivate)
                                                     name:SCAudioSessionWillDeactivateNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(_audioSessionDidActivate)
                                                     name:SCAudioSessionActivatedNotification
                                                   object:nil];
        _firstWrittenAudioBufferDelay = kCMTimeInvalid;
    }
    return self;
}

- (void)resetAll
{
    _audioQueueError = nil;
    _audioSessionError = nil;
    _assetWriterError = nil;
    _retryAudioQueueSuccess = NO;
    _retryAudioQueueSuccessSetDataSource = NO;
    _brokenMicCodeType = nil;
    _lenseActiveWhileRecording = NO;
    _lenseResumeCount = 0;
    _activeLensId = nil;
    self.firstWrittenAudioBufferDelay = kCMTimeInvalid;
}

- (void)checkVideoFileAndLogIfNeeded:(NSURL *)videoURL
{
    AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];

    __block BOOL hasAudioTrack = ([asset tracksWithMediaType:AVMediaTypeAudio].count > 0);

    dispatch_block_t block = ^{

        // Log no audio issues have been fixed
        if (hasAudioTrack) {
            if (_retryAudioQueueSuccess) {
                [SCManagedVideoNoSoundLogger logAudioSessionCategoryHaveBeenFixed];
            } else if (_retryAudioQueueSuccessSetDataSource) {
                [SCManagedVideoNoSoundLogger logAudioSessionBrokenMicHaveBeenFixed:_brokenMicCodeType];
            } else {
                [SCManagedVideoNoSoundLogger logVideoNoSoundHaveBeenFixedIfNeeded];
            }
        } else {
            // Log no audio issues caused by no permission into "wont_fixed_type", won't show in Grafana
            BOOL isPermissonGranted =
                [[SCAudioSession sharedInstance] recordPermission] == AVAudioSessionRecordPermissionGranted;
            if (!isPermissonGranted) {
                [SCManagedVideoNoSoundLogger increaseNoSoundCount];
                [[SCLogger sharedInstance]
                    logUnsampledEvent:kSCCameraMetricsVideoNoSoundError
                           parameters:@{
                               @"wont_fix_type" : @"no_permission",
                               @"no_sound_count" :
                                   [@([SCManagedVideoNoSoundLogger noSoundCount]) stringValue] ?: @"(null)",
                               @"session_id" : [SCManagedVideoNoSoundLogger appSessionIdForNoSound] ?: @"(null)"
                           }
                     secretParameters:nil
                              metrics:nil];

            }
            // Log no audio issues caused by microphone occupied into "wont_fixed_type", for example Phone Call,
            // It won't show in Grafana
            // TODO: maybe we should prompt the user of these errors in the future
            else if (_audioSessionError.code == AVAudioSessionErrorInsufficientPriority ||
                     _audioQueueError.code == AVAudioSessionErrorInsufficientPriority) {
                NSDictionary *parameters = @{
                    @"wont_fix_type" : @"microphone_in_use",
                    @"asset_writer_error" : _assetWriterError ? [_assetWriterError description] : @"(null)",
                    @"audio_session_error" : _audioSessionError.userInfo ?: @"(null)",
                    @"audio_queue_error" : _audioQueueError.userInfo ?: @"(null)",
                    @"audio_session_deactivated" : _isAudioSessionDeactivated ? @"true" : @"false",
                    @"audio_session_debug_info" :
                        [SCAudioSession sharedInstance].lastRecordingRequestDebugInfo ?: @"(null)",
                    @"no_sound_count" : [@([SCManagedVideoNoSoundLogger noSoundCount]) stringValue] ?: @"(null)",
                    @"session_id" : [SCManagedVideoNoSoundLogger appSessionIdForNoSound] ?: @"(null)"
                };

                [SCManagedVideoNoSoundLogger increaseNoSoundCount];
                [[SCLogger sharedInstance] logUnsampledEvent:kSCCameraMetricsVideoNoSoundError
                                                  parameters:parameters
                                            secretParameters:nil
                                                     metrics:nil];
                [_ticketCreator createAndFileBetaReport:JSONStringSerializeObjectForLogging(parameters)];
            } else {
                // Log other new no audio issues, use "have_been_fixed=false" to show in Grafana
                NSDictionary *parameters = @{
                    @"have_been_fixed" : @"false",
                    @"asset_writer_error" : _assetWriterError ? [_assetWriterError description] : @"(null)",
                    @"audio_session_error" : _audioSessionError.userInfo ?: @"(null)",
                    @"audio_queue_error" : _audioQueueError.userInfo ?: @"(null)",
                    @"asset_writer_success" : [NSString stringWithBool:_assetWriterError == nil],
                    @"audio_session_success" : [NSString stringWithBool:_audioSessionError == nil],
                    @"audio_queue_success" : [NSString stringWithBool:_audioQueueError == nil],
                    @"audio_session_deactivated" : _isAudioSessionDeactivated ? @"true" : @"false",
                    @"video_duration" : [NSString sc_stringWithFormat:@"%f", CMTimeGetSeconds(asset.duration)],
                    @"is_audio_session_nil" :
                        [[SCAudioSession sharedInstance] noSoundCheckAudioSessionIsNil] ? @"true" : @"false",
                    @"lenses_active" : [NSString stringWithBool:self.lenseActiveWhileRecording],
                    @"active_lense_id" : self.activeLensId ?: @"(null)",
                    @"lense_audio_resume_count" : @(_lenseResumeCount),
                    @"first_audio_buffer_delay" :
                        [NSString sc_stringWithFormat:@"%f", CMTimeGetSeconds(self.firstWrittenAudioBufferDelay)],
                    @"audio_session_debug_info" :
                        [SCAudioSession sharedInstance].lastRecordingRequestDebugInfo ?: @"(null)",
                    @"audio_queue_started" : [NSString stringWithBool:_audioQueueStarted],
                    @"no_sound_count" : [@([SCManagedVideoNoSoundLogger noSoundCount]) stringValue] ?: @"(null)",
                    @"session_id" : [SCManagedVideoNoSoundLogger appSessionIdForNoSound] ?: @"(null)"
                };
                [SCManagedVideoNoSoundLogger increaseNoSoundCount];
                [[SCLogger sharedInstance] logUnsampledEvent:kSCCameraMetricsVideoNoSoundError
                                                  parameters:parameters
                                            secretParameters:nil
                                                     metrics:nil];
                [_ticketCreator createAndFileBetaReport:JSONStringSerializeObjectForLogging(parameters)];
            }
        }
    };
    if (hasAudioTrack) {
        block();
    } else {
        // Wait for all tracks to be loaded, in case of error counting the metric
        [asset loadValuesAsynchronouslyForKeys:@[ @"tracks" ]
                             completionHandler:^{
                                 // Return when the tracks couldn't be loaded
                                 NSError *error = nil;
                                 if ([asset statusOfValueForKey:@"tracks" error:&error] != AVKeyValueStatusLoaded ||
                                     error != nil) {
                                     return;
                                 }

                                 // check audio track again
                                 hasAudioTrack = ([asset tracksWithMediaType:AVMediaTypeAudio].count > 0);
                                 runOnMainThreadAsynchronously(block);
                             }];
    }
}

- (void)_audioSessionWillDeactivate
{
    _isAudioSessionDeactivated = YES;
}

- (void)_audioSessionDidActivate
{
    _isAudioSessionDeactivated = NO;
}

- (void)managedLensesProcessorDidCallResumeAllSounds
{
    _lenseResumeCount += 1;
}

@end
