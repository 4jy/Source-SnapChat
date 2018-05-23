//
//  SCCaptureDeviceAuthorizationChecker.h
//  Snapchat
//
//  Created by Sun Lei on 15/03/2018.
//

@class SCQueuePerformer;

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

/*
 In general, the function of SCCaptureDeviceAuthorizationChecker is to speed up the checking of AVMediaTypeVideo
 authorization. It would cache the authorization value. 'preloadVideoCaptureAuthorization' would be called very early
 after the app is launched to populate the cached value. 'authorizedForVideoCapture' could be called to get the value
 synchronously.

 */

@interface SCCaptureDeviceAuthorizationChecker : NSObject

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithPerformer:(SCQueuePerformer *)performer NS_DESIGNATED_INITIALIZER;

- (BOOL)authorizedForVideoCapture;

- (void)preloadVideoCaptureAuthorization;

@end
