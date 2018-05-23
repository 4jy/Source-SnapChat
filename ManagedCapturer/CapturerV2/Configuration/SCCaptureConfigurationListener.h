//
//  SCCaptureConfigurationListener.h
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//

#import "SCManagedCapturerState.h"

#import <Foundation/Foundation.h>

@class SCCaptureConfiguration;

/*
 As a listener to configuration of camera core, you will get an update whenever the configuration changes, and you will
 receive an immutable state object for the current truth.
 */

@protocol SCCaptureConfigurationListener <NSObject>

- (void)captureConfigurationDidChangeTo:(id<SCManagedCapturerState>)state;

@end
