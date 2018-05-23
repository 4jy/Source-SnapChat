//
//  SCCaptureCore.h
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//
//

#import "SCCaptureStateMachineContext.h"
#import "SCCapturer.h"

#import <SCFoundation/SCPerforming.h>

#import <Foundation/Foundation.h>

@class SCCaptureConfigurator;

/*
 SCCaptureCore abstracts away the hardware aspect of a camera. SCCaptureCore is the V2 version of the
 SCManagedCapturerV1.

 SCCaptureCore itself does very little things actually. Its main job is to expose APIs of camera hardware to outside
 customers. The actual heavy lifting is done via delegating the jobs to multiple worker classes.

 We generally categorize the operation of camera hardware into 2 categories:

 1) make camera hardware do state transition. Such as what is shown in this graph:
 https://docs.google.com/presentation/d/1KWk-XSgO0wFAjBZXsl_OnHBGpi_pd9-ds6Wje8vX-0s/edit#slide=id.g2017e46295_1_10

 2) config camera hardware setting, such as setting the camera to be front or back, such as setting camera hardware to
 be certain resolution, or to activate night mode.

 Indeed, we create 2 working classes to do the heavy lifting. Both of them are under construction. Feel free to checkout
 SCCaptureConfigurator, which is responsible for 2).

 */

@interface SCCaptureCore : NSObject <SCCapturer>

@property (nonatomic, strong, readonly) SCCaptureStateMachineContext *stateMachine;

@end
