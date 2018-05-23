//
//  SCCaptureConfiguration.h
//  Snapchat
//
//  Created by Lin Jia on 10/3/17.
//
//

#import "SCCaptureConfigurationAnnouncer.h"
#import "SCManagedCaptureDevice.h"
#import "SCManagedCapturerState.h"
#import "SCVideoCaptureSessionInfo.h"

#import <SCFoundation/SCQueuePerformer.h>

#import <Looksery/LSAGLView.h>

#import <Foundation/Foundation.h>

/*
 SCCaptureConfiguration is the configuration class which is going to be used for customer to configure camera. This is
 how to use it:

 SCCaptureConfiguration *configuration = [SCCaptureConfiguration new];

 // Conduct the setting here.
 e.g:
 configuration.torchActive = YES;

 // Commit your configuration
 [captureConfigurator commitConfiguration:configuration
                        completionHandler:handler]

 Here are several interesting facts about SCCaptureConfiguration:
 1) Though SCCaptureConfiguration has so many parameters, you don't need to care the parameters which you do not intend
to set. For example, if you only want to set night mode active, here is the code:

 SCCaptureConfiguration *configuration = [SCCaptureConfiguration new];

 configuration.isNightModeActive = YES;

 [captureConfigurator commitConfiguration:configuration
                        completionHandler:handler]

 That is it.

 2) you can set multiple configuration settings, then commit, before you commit, nothing will happen, e.g.:

 SCCaptureConfiguration *configuration = [SCCaptureConfiguration new];

 configuration.isNightModeActive = YES;
 configuration.zoomFactor = 5;
 configuration.lensesActive = YES;

 [captureConfigurator commitConfiguration:configuration
                        completionHandler:handler]

 3) commit a configuration means the configuration is gone. If you set parameters on configuration after it is commited,
it will crash on debug build, and on other builds such as production, the setting will be ignored, e.g.:

 SCCaptureConfiguration *configuration = [SCCaptureConfiguration new];

 configuration.isNightModeActive = YES;

 [captureConfigurator commitConfiguration:configuration
                        completionHandler:handler]

 // The line below will crash on debug, and ignored on other builds.
 configuration.zoomFactor = 5;

 4) commiting a configuration is an atomic action. That means all changes customers want to have on camera will happen
in a group. If 2 customers commit at the same time, we will handle them one by one.

 5) We are still figuring out what parameters should be in this configuration, parameters could be added or deleted
 later. In the end, the configuration is going to be the only way customers confige the camera.

 */

@interface SCCaptureConfiguration : NSObject

@property (nonatomic, assign) BOOL isRunning;

@property (nonatomic, assign) BOOL isNightModeActive;

@property (nonatomic, assign) BOOL lowLightCondition;

@property (nonatomic, assign) BOOL adjustingExposure;

@property (nonatomic, assign) SCManagedCaptureDevicePosition devicePosition;

@property (nonatomic, assign) CGFloat zoomFactor;

@property (nonatomic, assign) BOOL flashSupported;

@property (nonatomic, assign) BOOL torchSupported;

@property (nonatomic, assign) BOOL flashActive;

@property (nonatomic, assign) BOOL torchActive;

@property (nonatomic, assign) BOOL lensesActive;

@property (nonatomic, assign) BOOL arSessionActive;

@property (nonatomic, assign) BOOL liveVideoStreaming;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *videoPreviewLayer;

@property (nonatomic, strong) LSAGLView *videoPreviewGLView;

@property (nonatomic, assign) SCVideoCaptureSessionInfo captureSessionInfo;

@end
