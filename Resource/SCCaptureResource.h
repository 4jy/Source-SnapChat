//
//  SCCaptureResource.h
//  Snapchat
//
//  Created by Lin Jia on 10/19/17.
//
//

#import "SCManagedCapturerLensAPI.h"
#import "SCManagedCapturerListenerAnnouncer.h"
#import "SCSnapCreationTriggers.h"

#import <SCCameraFoundation/SCManagedVideoDataSource.h>

#import <FBKVOController/FBKVOController.h>

#import <Foundation/Foundation.h>

/*
 In general, the function of SCCapturer is to use some resources (such as SCManagedCapturerListenerAnnouncer), to do
 something (such as announce an event).

 SCCaptureResource abstract away the "resources" part of SCCapturer. It has no APIs itself, it is used to be the
 resource which gets passed arround for capturer V2 state machine.
 */
@class SCManagedDeviceCapacityAnalyzer;

@class SCManagedCapturePreviewLayerController;

@class ARSession;

@class SCManagedVideoScanner;

@class LSAGLView;

@protocol SCManagedCapturerLSAComponentTrackerAPI;

@class SCManagedStillImageCapturer;

@class SCManagedVideoCapturer;

@class SCQueuePerformer;

@class SCManagedVideoFrameSampler;

@class SCManagedDroppedFramesReporter;

@class SCManagedVideoStreamReporter;

@protocol SCManagedCapturerGLViewManagerAPI;

@class SCCapturerToken;

@class SCSingleFrameStreamCapturer;

@class SCManagedFrontFlashController;

@class SCManagedVideoCapturerHandler;

@class SCManagedStillImageCapturerHandler;

@class SCManagedDeviceCapacityAnalyzerHandler;

@class SCManagedCaptureDeviceDefaultZoomHandler;

@class SCManagedCaptureDeviceHandler;

@class SCBlackCameraNoOutputDetector;

@class SCCaptureSessionFixer;

@protocol SCCaptureFaceDetector;

@protocol SCManagedCapturerLensAPI;

@protocol SCManagedCapturerARImageCaptureProvider;

@class SCManagedCapturerARSessionHandler;

@class SCManagedCaptureDeviceSubjectAreaHandler;

@class SCManagedCaptureSession;

@class SCBlackCameraDetector;

@protocol SCLensProcessingCore;

@protocol SCManagedCapturerLensAPI;

@protocol SCManagedCapturePreviewLayerControllerDelegate;

typedef enum : NSUInteger {
    SCManagedCapturerStatusUnknown = 0,
    SCManagedCapturerStatusReady,
    SCManagedCapturerStatusRunning,
} SCManagedCapturerStatus;

@protocol SCDeviceMotionProvider

@property (nonatomic, readonly) BOOL isUnderDeviceMotion;

@end

@protocol SCFileInputDecider

@property (nonatomic, readonly) BOOL shouldProcessFileInput;
@property (nonatomic, readonly) NSURL *fileURL;

@end

@interface SCCaptureResource : NSObject

@property (nonatomic, readwrite, assign) SCManagedCapturerStatus status;

@property (nonatomic, readwrite, strong) SCManagedCapturerState *state;

@property (nonatomic, readwrite, strong) SCManagedCaptureDevice *device;

@property (nonatomic, readwrite, strong) id<SCManagedCapturerLensAPI> lensProcessingCore;

@property (nonatomic, readwrite, strong) id<SCManagedCapturerLensAPIProvider> lensAPIProvider;

@property (nonatomic, readwrite, strong) ARSession *arSession NS_AVAILABLE_IOS(11_0);

@property (nonatomic, readwrite, strong) SCManagedStillImageCapturer *arImageCapturer NS_AVAILABLE_IOS(11_0);

@property (nonatomic, readwrite, strong) SCManagedCaptureSession *managedSession;

@property (nonatomic, readwrite, strong) id<SCManagedVideoDataSource> videoDataSource;

@property (nonatomic, readwrite, strong) SCManagedDeviceCapacityAnalyzer *deviceCapacityAnalyzer;

@property (nonatomic, readwrite, strong) SCManagedVideoScanner *videoScanner;

@property (nonatomic, readwrite, strong) SCManagedCapturerListenerAnnouncer *announcer;

@property (nonatomic, readwrite, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic, readwrite, strong) id<SCManagedCapturerGLViewManagerAPI> videoPreviewGLViewManager;

@property (nonatomic, readwrite, strong) SCManagedStillImageCapturer *stillImageCapturer;

@property (nonatomic, readwrite, strong) SCManagedVideoCapturer *videoCapturer;

@property (nonatomic, readwrite, strong) SCQueuePerformer *queuePerformer;

@property (nonatomic, readwrite, strong) SCManagedVideoFrameSampler *videoFrameSampler;

@property (nonatomic, readwrite, strong) SCManagedDroppedFramesReporter *droppedFramesReporter;

@property (nonatomic, readwrite, strong) SCManagedVideoStreamReporter *videoStreamReporter; // INTERNAL USE ONLY

@property (nonatomic, readwrite, strong) SCManagedFrontFlashController *frontFlashController;

@property (nonatomic, readwrite, strong) SCManagedVideoCapturerHandler *videoCapturerHandler;

@property (nonatomic, readwrite, strong) SCManagedStillImageCapturerHandler *stillImageCapturerHandler;

@property (nonatomic, readwrite, strong) SCManagedDeviceCapacityAnalyzerHandler *deviceCapacityAnalyzerHandler;

@property (nonatomic, readwrite, strong) SCManagedCaptureDeviceDefaultZoomHandler *deviceZoomHandler;

@property (nonatomic, readwrite, strong) SCManagedCaptureDeviceHandler *captureDeviceHandler;

@property (nonatomic, readwrite, strong) id<SCCaptureFaceDetector> captureFaceDetector;

@property (nonatomic, readwrite, strong) FBKVOController *kvoController;

@property (nonatomic, readwrite, strong) id<SCManagedCapturerLSAComponentTrackerAPI> lsaTrackingComponentHandler;

@property (nonatomic, readwrite, strong) SCManagedCapturerARSessionHandler *arSessionHandler;

@property (nonatomic, assign) SEL completeARSessionShutdown;

@property (nonatomic, assign) SEL handleAVSessionStatusChange;

@property (nonatomic, assign) BOOL videoRecording;

@property (nonatomic, assign) NSInteger numRetriesFixAVCaptureSessionWithCurrentSession;

@property (nonatomic, assign) BOOL appInBackground;

@property (nonatomic, assign) NSUInteger streamingSequence;

@property (nonatomic, assign) BOOL stillImageCapturing;

@property (nonatomic, readwrite, strong) NSTimer *livenessTimer;

@property (nonatomic, readwrite, strong) NSMutableSet<SCCapturerToken *> *tokenSet;

@property (nonatomic, readwrite, strong) SCSingleFrameStreamCapturer *frameCap;

@property (nonatomic, readwrite, strong) id<SCManagedSampleBufferDisplayController> sampleBufferDisplayController;

@property (nonatomic, readwrite, strong) SCSnapCreationTriggers *snapCreationTriggers;

// Different from most properties above, following are main thread properties.
@property (nonatomic, assign) BOOL allowsZoom;

@property (nonatomic, assign) NSUInteger numRetriesFixInconsistencyWithCurrentSession;

@property (nonatomic, readwrite, strong) NSMutableDictionary *debugInfoDict;

@property (nonatomic, assign) BOOL notificationRegistered;

@property (nonatomic, readwrite, strong) SCManagedCaptureDeviceSubjectAreaHandler *deviceSubjectAreaHandler;

@property (nonatomic, assign) SEL sessionRuntimeError;

@property (nonatomic, assign) SEL livenessConsistency;

// TODO: these properties will be refactored into SCCaptureSessionFixer class
// The refactor will be in a separate PR
// Timestamp when _fixAVSessionIfNecessary is called
@property (nonatomic, assign) NSTimeInterval lastFixSessionTimestamp;
// Timestamp when session runtime error is handled
@property (nonatomic, assign) NSTimeInterval lastSessionRuntimeErrorTime;
// Wether we schedule fix of creating session already
@property (nonatomic, assign) BOOL isRecreateSessionFixScheduled;

@property (nonatomic, readwrite, strong) SCCaptureSessionFixer *captureSessionFixer;

@property (nonatomic, readwrite, strong) SCBlackCameraDetector *blackCameraDetector;

@property (nonatomic, readwrite, strong) id<SCDeviceMotionProvider> deviceMotionProvider;

@property (nonatomic, readwrite, strong) id<SCManagedCapturerARImageCaptureProvider> arImageCaptureProvider;

@property (nonatomic, readwrite, strong) id<SCFileInputDecider> fileInputDecider;

@property (nonatomic, readwrite, strong)
    id<SCManagedCapturePreviewLayerControllerDelegate> previewLayerControllerDelegate;
@end
