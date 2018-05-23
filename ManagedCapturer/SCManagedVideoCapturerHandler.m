//
//  SCManagedVideoCapturerHandler.m
//  Snapchat
//
//  Created by Jingtian Yang on 11/12/2017.
//

#import "SCManagedVideoCapturerHandler.h"

#import "SCCaptureResource.h"
#import "SCManagedCaptureDevice+SCManagedCapturer.h"
#import "SCManagedCapturer.h"
#import "SCManagedCapturerLensAPI.h"
#import "SCManagedCapturerLogging.h"
#import "SCManagedCapturerSampleMetadata.h"
#import "SCManagedCapturerState.h"
#import "SCManagedDeviceCapacityAnalyzer.h"
#import "SCManagedFrontFlashController.h"
#import "SCManagedVideoFileStreamer.h"
#import "SCManagedVideoFrameSampler.h"
#import "SCManagedVideoStreamer.h"

#import <SCCameraFoundation/SCManagedDataSource.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@interface SCManagedVideoCapturerHandler () {
    __weak SCCaptureResource *_captureResource;
}
@end

@implementation SCManagedVideoCapturerHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super init];
    if (self) {
        SCAssert(captureResource, @"");
        _captureResource = captureResource;
    }
    return self;
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
      didBeginVideoRecording:(SCVideoCaptureSessionInfo)sessionInfo
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Did begin video recording. sessionId:%u", sessionInfo.sessionId);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        SCManagedCapturerState *state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                 didBeginVideoRecording:state
                                                session:sessionInfo];
        });
    }];
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
      didBeginAudioRecording:(SCVideoCaptureSessionInfo)sessionInfo
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Did begin audio recording. sessionId:%u", sessionInfo.sessionId);
    [_captureResource.queuePerformer perform:^{
        if ([_captureResource.fileInputDecider shouldProcessFileInput]) {
            [_captureResource.videoDataSource startStreaming];
        }
        SCTraceStart();
        SCManagedCapturerState *state = [_captureResource.state copy];
        runOnMainThreadAsynchronously(^{
            [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                 didBeginAudioRecording:state
                                                session:sessionInfo];
        });
    }];
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
    willStopWithRecordedVideoFuture:(SCFuture<id<SCManagedRecordedVideo>> *)recordedVideoFuture
                          videoSize:(CGSize)videoSize
                   placeholderImage:(UIImage *)placeholderImage
                            session:(SCVideoCaptureSessionInfo)sessionInfo
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Will stop recording. sessionId:%u placeHolderImage:%@ videoSize:(%f, %f)",
                      sessionInfo.sessionId, placeholderImage, videoSize.width, videoSize.height);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (_captureResource.videoRecording) {
            SCManagedCapturerState *state = [_captureResource.state copy];
            // Then, sync back to main thread to notify will finish recording
            runOnMainThreadAsynchronously(^{
                [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                        willFinishRecording:state
                                                    session:sessionInfo
                                        recordedVideoFuture:recordedVideoFuture
                                                  videoSize:videoSize
                                           placeholderImage:placeholderImage];
            });
        }
    }];
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
 didSucceedWithRecordedVideo:(SCManagedRecordedVideo *)recordedVideo
                     session:(SCVideoCaptureSessionInfo)sessionInfo
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Did succeed recording. sessionId:%u recordedVideo:%@", sessionInfo.sessionId, recordedVideo);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (_captureResource.videoRecording) {
            [self _videoRecordingCleanup];
            SCManagedCapturerState *state = [_captureResource.state copy];
            // Then, sync back to main thread to notify the finish recording
            runOnMainThreadAsynchronously(^{
                [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                         didFinishRecording:state
                                                    session:sessionInfo
                                              recordedVideo:recordedVideo];
            });
        }
    }];
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
            didFailWithError:(NSError *)error
                     session:(SCVideoCaptureSessionInfo)sessionInfo
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Did fail recording. sessionId:%u", sessionInfo.sessionId);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (_captureResource.videoRecording) {
            [self _videoRecordingCleanup];
            SCManagedCapturerState *state = [_captureResource.state copy];
            runOnMainThreadAsynchronously(^{
                [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                           didFailRecording:state
                                                    session:sessionInfo
                                                      error:error];
            });
        }
    }];
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
     didCancelVideoRecording:(SCVideoCaptureSessionInfo)sessionInfo
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Did cancel recording. sessionId:%u", sessionInfo.sessionId);
    [_captureResource.queuePerformer perform:^{
        SCTraceStart();
        if (_captureResource.videoRecording) {
            [self _videoRecordingCleanup];
            SCManagedCapturerState *state = [_captureResource.state copy];
            runOnMainThreadAsynchronously(^{
                [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                         didCancelRecording:state
                                                    session:sessionInfo];
            });
        }
    }];
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
                 didGetError:(NSError *)error
                     forType:(SCManagedVideoCapturerInfoType)type
                     session:(SCVideoCaptureSessionInfo)sessionInfo
{
    SCTraceODPCompatibleStart(2);
    SCLogCapturerInfo(@"Did get error. sessionId:%u errorType:%lu, error:%@", sessionInfo.sessionId, (long)type, error);
    [_captureResource.queuePerformer perform:^{
        runOnMainThreadAsynchronously(^{
            [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                                            didGetError:error
                                                forType:type
                                                session:sessionInfo];
        });
    }];
}

- (NSDictionary *)managedVideoCapturerGetExtraFrameHealthInfo:(SCManagedVideoCapturer *)managedVideoCapturer
{
    SCTraceODPCompatibleStart(2);
    if (_captureResource.state.lensesActive) {
        return @{
            @"lens_active" : @(YES),
            @"lens_id" : ([_captureResource.lensProcessingCore activeLensId] ?: [NSNull null])
        };
    }
    return nil;
}

- (void)managedVideoCapturer:(SCManagedVideoCapturer *)managedVideoCapturer
  didAppendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
       presentationTimestamp:(CMTime)presentationTimestamp
{
    CFRetain(sampleBuffer);
    [_captureResource.queuePerformer perform:^{
        SCManagedCapturerSampleMetadata *sampleMetadata =
            [[SCManagedCapturerSampleMetadata alloc] initWithPresentationTimestamp:presentationTimestamp
                                                                       fieldOfView:_captureResource.device.fieldOfView];
        [_captureResource.announcer managedCapturer:[SCManagedCapturer sharedInstance]
                         didAppendVideoSampleBuffer:sampleBuffer
                                     sampleMetadata:sampleMetadata];
        CFRelease(sampleBuffer);
    }];
}

- (void)_videoRecordingCleanup
{
    SCTraceODPCompatibleStart(2);
    SCAssert(_captureResource.videoRecording, @"clean up function only can be called if the "
                                              @"video recording is still in progress.");
    SCAssert([_captureResource.queuePerformer isCurrentPerformer], @"");
    SCLogCapturerInfo(@"Video recording cleanup. previous state:%@", _captureResource.state);
    [_captureResource.videoDataSource removeListener:_captureResource.videoCapturer];
    if (_captureResource.videoFrameSampler) {
        SCManagedVideoFrameSampler *sampler = _captureResource.videoFrameSampler;
        _captureResource.videoFrameSampler = nil;
        [_captureResource.announcer removeListener:sampler];
    }
    // Add back other listeners to video streamer
    [_captureResource.videoDataSource addListener:_captureResource.deviceCapacityAnalyzer];
    if (!_captureResource.state.torchActive) {
        // We should turn off torch for the device that we specifically turned on
        // for recording
        [_captureResource.device setTorchActive:NO];
        if (_captureResource.state.devicePosition == SCManagedCaptureDevicePositionFront) {
            _captureResource.frontFlashController.torchActive = NO;
        }
    }

    // Unlock focus on both front and back camera if they were locked.
    // Even if ARKit was being used during recording, it'll be shut down by the time we get here
    // So DON'T match the ARKit check we use around [_ setRecording:YES]
    SCManagedCaptureDevice *front = [SCManagedCaptureDevice front];
    SCManagedCaptureDevice *back = [SCManagedCaptureDevice back];
    [front setRecording:NO];
    [back setRecording:NO];
    _captureResource.videoRecording = NO;
    if (_captureResource.state.lensesActive) {
        BOOL modifySource = _captureResource.videoRecording || _captureResource.state.liveVideoStreaming;
        [_captureResource.lensProcessingCore setModifySource:modifySource];
    }
}

@end
