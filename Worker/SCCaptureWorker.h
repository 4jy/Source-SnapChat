//
//  SCCaptureWorker.h
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCCaptureResource.h"

#import <SCFoundation/SCQueuePerformer.h>

#import <Foundation/Foundation.h>

/*
 In general, the function of SCCapturer is to use some resources (such as SCManagedCapturerListenerAnnouncer), to do
 something (such as announce an event).

 SCCaptureWorker abstract away the "do something" part of SCCapturer. It has very little internal states/resources.

 SCCaptureWorker is introduced to be shared between CaptureV1 and CaptureV2, to minimize duplication code.

 */

@interface SCCaptureWorker : NSObject

+ (SCCaptureResource *)generateCaptureResource;

+ (void)setupWithCaptureResource:(SCCaptureResource *)captureResource
                  devicePosition:(SCManagedCaptureDevicePosition)devicePosition;

+ (void)setupCapturePreviewLayerController;

+ (void)startRunningWithCaptureResource:(SCCaptureResource *)captureResource
                                  token:(SCCapturerToken *)token
                      completionHandler:(dispatch_block_t)completionHandler;

+ (BOOL)stopRunningWithCaptureResource:(SCCaptureResource *)captureResource
                                 token:(SCCapturerToken *)token
                     completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler;

+ (void)setupVideoPreviewLayer:(SCCaptureResource *)resource;

+ (void)makeVideoPreviewLayer:(SCCaptureResource *)resource;

+ (void)redoVideoPreviewLayer:(SCCaptureResource *)resource;

+ (void)startStreaming:(SCCaptureResource *)resource;

+ (void)setupLivenessConsistencyTimerIfForeground:(SCCaptureResource *)resource;

+ (void)destroyLivenessConsistencyTimer:(SCCaptureResource *)resource;

+ (void)softwareZoomWithDevice:(SCManagedCaptureDevice *)device resource:(SCCaptureResource *)resource;

+ (void)captureStillImageWithCaptureResource:(SCCaptureResource *)captureResource
                                 aspectRatio:(CGFloat)aspectRatio
                            captureSessionID:(NSString *)captureSessionID
                      shouldCaptureFromVideo:(BOOL)shouldCaptureFromVideo
                           completionHandler:
                               (sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                                     context:(NSString *)context;

+ (void)startRecordingWithCaptureResource:(SCCaptureResource *)captureResource
                           outputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                       audioConfiguration:(SCAudioConfiguration *)configuration
                              maxDuration:(NSTimeInterval)maxDuration
                                  fileURL:(NSURL *)fileURL
                         captureSessionID:(NSString *)captureSessionID
                        completionHandler:(sc_managed_capturer_start_recording_completion_handler_t)completionHandler;

+ (void)stopRecordingWithCaptureResource:(SCCaptureResource *)captureResource;

+ (void)cancelRecordingWithCaptureResource:(SCCaptureResource *)captureResource;

+ (SCVideoCaptureSessionInfo)activeSession:(SCCaptureResource *)resource;

+ (BOOL)canRunARSession:(SCCaptureResource *)resource;

+ (void)turnARSessionOn:(SCCaptureResource *)resource;

+ (void)turnARSessionOff:(SCCaptureResource *)resource;

+ (void)clearARKitData:(SCCaptureResource *)resource;

+ (void)updateLensesFieldOfViewTracking:(SCCaptureResource *)captureResource;

+ (CMTime)firstWrittenAudioBufferDelay:(SCCaptureResource *)resource;

+ (BOOL)audioQueueStarted:(SCCaptureResource *)resource;

+ (BOOL)isLensApplied:(SCCaptureResource *)resource;

+ (BOOL)isVideoMirrored:(SCCaptureResource *)resource;

+ (BOOL)shouldCaptureImageFromVideoWithResource:(SCCaptureResource *)resource;

+ (void)setPortraitModePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                   completionHandler:(dispatch_block_t)completionHandler
                                            resource:(SCCaptureResource *)resource;

+ (void)prepareForRecordingWithAudioConfiguration:(SCAudioConfiguration *)configuration
                                         resource:(SCCaptureResource *)resource;

+ (void)stopScanWithCompletionHandler:(dispatch_block_t)completionHandler resource:(SCCaptureResource *)resource;

+ (void)startScanWithScanConfiguration:(SCScanConfiguration *)configuration resource:(SCCaptureResource *)resource;

@end
