//
//  SCCaptureConfigurator.h
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//
//

#import "SCCaptureConfiguration.h"
#import "SCCaptureConfigurationAnnouncer.h"
#import "SCManagedCaptureDevice.h"
#import "SCVideoCaptureSessionInfo.h"

#import <SCFoundation/SCQueuePerformer.h>

#import <Looksery/LSAGLView.h>

#import <Foundation/Foundation.h>

/*
 SCCaptureConfigurator is the class you use to config the setting of the camera hardware. Such as setting the camera to
 be front or back, setting camera hardware to be certain resolution, or to activate night mode.

 You can use this class for many things:

 a) do 1 time poking to checkout the current camera configuration via the currentConfiguration.

 Note that we represent configuration via id<SCManagedCapturerState>. It is going to be an immutable object.

 b) register to be the listener of the configuration change via the announcer.
 Every time a camera configuration change, you will receive an update.

 c) set the configuration via commitConfiguration API. You convey your setting intention via SCCaptureConfiguration.

 You can register a completionHandler to be called after your configuration gets done.

 Inside the completionHandler, we will pass you an error if it happens, and there will be a boolean cameraChanged. If
 your configuration already equals the current configuration of the camera, we will not change the camera, the boolean
 will be true.

 d) All APIs are thread safe.
 */

typedef void (^SCCaptureConfigurationCompletionHandler)(NSError *error, BOOL cameraChanged);

@interface SCCaptureConfigurator : NSObject

@property (nonatomic, strong, readonly) SCCaptureConfigurationAnnouncer *announcer;

@property (nonatomic, strong, readonly) id<SCManagedCapturerState> currentConfiguration;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer;

- (void)commitConfiguration:(SCCaptureConfiguration *)configuration
          completionHandler:(SCCaptureConfigurationCompletionHandler)completionHandler;

@end
