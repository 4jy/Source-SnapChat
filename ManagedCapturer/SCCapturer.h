//
//  SCManagedCapturer.h
//  Snapchat
//
//  Created by Liu Liu on 4/20/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import "SCCaptureCommon.h"
#import "SCSnapCreationTriggers.h"

#import <SCAudio/SCAudioConfiguration.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

#define SCCapturerContext [NSString sc_stringWithFormat:@"%s/%d", __FUNCTION__, __LINE__]

@class SCBlackCameraDetector;
@protocol SCManagedCapturerListener
, SCManagedCapturerLensAPI, SCDeviceMotionProvider, SCFileInputDecider, SCManagedCapturerARImageCaptureProvider,
    SCManagedCapturerGLViewManagerAPI, SCManagedCapturerLensAPIProvider, SCManagedCapturerLSAComponentTrackerAPI,
    SCManagedCapturePreviewLayerControllerDelegate;

@protocol SCCapturer <NSObject>

@property (nonatomic, readonly) SCBlackCameraDetector *blackCameraDetector;

/**
 * Returns id<SCLensProcessingCore> for the current capturer.
 */
- (id<SCManagedCapturerLensAPI>)lensProcessingCore;

- (CMTime)firstWrittenAudioBufferDelay;
- (BOOL)audioQueueStarted;
- (BOOL)isLensApplied;
- (BOOL)isVideoMirrored;

- (SCVideoCaptureSessionInfo)activeSession;

#pragma mark - Outside resources

- (void)setBlackCameraDetector:(SCBlackCameraDetector *)blackCameraDetector
                             deviceMotionProvider:(id<SCDeviceMotionProvider>)deviceMotionProvider
                                 fileInputDecider:(id<SCFileInputDecider>)fileInputDecider
                           arImageCaptureProvider:(id<SCManagedCapturerARImageCaptureProvider>)arImageCaptureProvider
                                    glviewManager:(id<SCManagedCapturerGLViewManagerAPI>)glViewManager
                                  lensAPIProvider:(id<SCManagedCapturerLensAPIProvider>)lensAPIProvider
                              lsaComponentTracker:(id<SCManagedCapturerLSAComponentTrackerAPI>)lsaComponentTracker
    managedCapturerPreviewLayerControllerDelegate:
        (id<SCManagedCapturePreviewLayerControllerDelegate>)previewLayerControllerDelegate;

#pragma mark - Setup, Start & Stop

// setupWithDevicePositionAsynchronously will be called on the main thread, executed off the main thread, exactly once
- (void)setupWithDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                            completionHandler:(dispatch_block_t)completionHandler
                                      context:(NSString *)context;

/**
 *  Important: Remember to call stopRunningAsynchronously to stop the capture session. Dismissing the view is not enough
 *  @param identifier is for knowing the callsite. Pass in the classname of the callsite is generally suggested.
 *  Currently it is used for debugging purposes. In other words the capture session will work without it.
 */
- (SCCapturerToken *)startRunningAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                             context:(NSString *)context;
- (void)stopRunningAsynchronously:(SCCapturerToken *)token
                completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                          context:(NSString *)context;

- (void)stopRunningAsynchronously:(SCCapturerToken *)token
                completionHandler:(sc_managed_capturer_stop_running_completion_handler_t)completionHandler
                            after:(NSTimeInterval)delay
                          context:(NSString *)context;

- (void)startStreamingAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                  context:(NSString *)context;

- (void)addSampleBufferDisplayController:(id<SCManagedSampleBufferDisplayController>)sampleBufferDisplayController
                                 context:(NSString *)context;

#pragma mark - Recording / Capture

- (void)captureStillImageAsynchronouslyWithAspectRatio:(CGFloat)aspectRatio
                                      captureSessionID:(NSString *)captureSessionID
                                     completionHandler:
                                         (sc_managed_capturer_capture_still_image_completion_handler_t)completionHandler
                                               context:(NSString *)context;
/**
 * Unlike captureStillImageAsynchronouslyWithAspectRatio, this captures a single frame from the ongoing video
 * stream. This should be faster but lower quality (and smaller size), and does not play the shutter sound.
 */
- (void)captureSingleVideoFrameAsynchronouslyWithCompletionHandler:
            (sc_managed_capturer_capture_video_frame_completion_handler_t)completionHandler
                                                           context:(NSString *)context;

- (void)prepareForRecordingAsynchronouslyWithContext:(NSString *)context
                                  audioConfiguration:(SCAudioConfiguration *)configuration;
- (void)startRecordingAsynchronouslyWithOutputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
                                    audioConfiguration:(SCAudioConfiguration *)configuration
                                           maxDuration:(NSTimeInterval)maxDuration
                                               fileURL:(NSURL *)fileURL
                                      captureSessionID:(NSString *)captureSessionID
                                     completionHandler:
                                         (sc_managed_capturer_start_recording_completion_handler_t)completionHandler
                                               context:(NSString *)context;
- (void)stopRecordingAsynchronouslyWithContext:(NSString *)context;
- (void)cancelRecordingAsynchronouslyWithContext:(NSString *)context;

- (void)startScanAsynchronouslyWithScanConfiguration:(SCScanConfiguration *)configuration context:(NSString *)context;
- (void)stopScanAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler context:(NSString *)context;
- (void)sampleFrameWithCompletionHandler:(void (^)(UIImage *frame, CMTime presentationTime))completionHandler
                                 context:(NSString *)context;

// AddTimedTask will schedule a task to run, it is thread safe API. Your task will run on main thread, so it is not
// recommended to add large amount of tasks which all have the same task target time.
- (void)addTimedTask:(SCTimedTask *)task context:(NSString *)context;

// clearTimedTasks will cancel the tasks, it is thread safe API.
- (void)clearTimedTasksWithContext:(NSString *)context;

#pragma mark - Utilities

- (void)convertViewCoordinates:(CGPoint)viewCoordinates
             completionHandler:(sc_managed_capturer_convert_view_coordniates_completion_handler_t)completionHandler
                       context:(NSString *)context;

- (void)detectLensCategoryOnNextFrame:(CGPoint)point
                               lenses:(NSArray<SCLens *> *)lenses
                           completion:(sc_managed_lenses_processor_category_point_completion_handler_t)completion
                              context:(NSString *)context;

#pragma mark - Configurations

- (void)setDevicePositionAsynchronously:(SCManagedCaptureDevicePosition)devicePosition
                      completionHandler:(dispatch_block_t)completionHandler
                                context:(NSString *)context;

- (void)setFlashActive:(BOOL)flashActive
     completionHandler:(dispatch_block_t)completionHandler
               context:(NSString *)context;

- (void)setLensesActive:(BOOL)lensesActive
      completionHandler:(dispatch_block_t)completionHandler
                context:(NSString *)context;

- (void)setLensesActive:(BOOL)lensesActive
          filterFactory:(SCLookseryFilterFactory *)filterFactory
      completionHandler:(dispatch_block_t)completionHandler
                context:(NSString *)context;

- (void)setLensesInTalkActive:(BOOL)lensesActive
            completionHandler:(dispatch_block_t)completionHandler
                      context:(NSString *)context;

- (void)setTorchActiveAsynchronously:(BOOL)torchActive
                   completionHandler:(dispatch_block_t)completionHandler
                             context:(NSString *)context;

- (void)setNightModeActiveAsynchronously:(BOOL)active
                       completionHandler:(dispatch_block_t)completionHandler
                                 context:(NSString *)context;

- (void)lockZoomWithContext:(NSString *)context;

- (void)unlockZoomWithContext:(NSString *)context;

- (void)setZoomFactorAsynchronously:(CGFloat)zoomFactor context:(NSString *)context;
- (void)resetZoomFactorAsynchronously:(CGFloat)zoomFactor
                       devicePosition:(SCManagedCaptureDevicePosition)devicePosition
                              context:(NSString *)context;

- (void)setExposurePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                        fromUser:(BOOL)fromUser
                               completionHandler:(dispatch_block_t)completionHandler
                                         context:(NSString *)context;

- (void)setAutofocusPointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                completionHandler:(dispatch_block_t)completionHandler
                                          context:(NSString *)context;

- (void)setPortraitModePointOfInterestAsynchronously:(CGPoint)pointOfInterest
                                   completionHandler:(dispatch_block_t)completionHandler
                                             context:(NSString *)context;

- (void)continuousAutofocusAndExposureAsynchronouslyWithCompletionHandler:(dispatch_block_t)completionHandler
                                                                  context:(NSString *)context;

// I need to call these three methods from SCAppDelegate explicitly so that I get the latest information.
- (void)applicationDidEnterBackground;
- (void)applicationWillEnterForeground;
- (void)applicationDidBecomeActive;
- (void)applicationWillResignActive;
- (void)mediaServicesWereReset;
- (void)mediaServicesWereLost;

#pragma mark - Add / Remove Listener

- (void)addListener:(id<SCManagedCapturerListener>)listener;
- (void)removeListener:(id<SCManagedCapturerListener>)listener;
- (void)addVideoDataSourceListener:(id<SCManagedVideoDataSourceListener>)listener;
- (void)removeVideoDataSourceListener:(id<SCManagedVideoDataSourceListener>)listener;
- (void)addDeviceCapacityAnalyzerListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener;
- (void)removeDeviceCapacityAnalyzerListener:(id<SCManagedDeviceCapacityAnalyzerListener>)listener;

- (NSString *)debugInfo;

- (id<SCManagedVideoDataSource>)currentVideoDataSource;

- (void)checkRestrictedCamera:(void (^)(BOOL, BOOL, AVAuthorizationStatus))callback;

// Need to be visible so that classes like SCCaptureSessionFixer can manage capture session
- (void)recreateAVCaptureSession;

#pragma mark - Snap Creation triggers

- (SCSnapCreationTriggers *)snapCreationTriggers;

@optional

- (BOOL)authorizedForVideoCapture;

- (void)preloadVideoCaptureAuthorization;

@end
