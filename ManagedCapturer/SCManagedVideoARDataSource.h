//
//  SCManagedVideoARDataSource.h
//  Snapchat
//
//  Created by Eyal Segal on 20/10/2017.
//

#import "SCCapturerDefines.h"

#import <SCCameraFoundation/SCManagedVideoDataSource.h>

#import <ARKit/ARKit.h>

@protocol SCManagedVideoARDataSource <SCManagedVideoDataSource>

@property (atomic, strong) ARFrame *currentFrame NS_AVAILABLE_IOS(11_0);

#ifdef SC_USE_ARKIT_FACE
@property (atomic, strong) AVDepthData *lastDepthData NS_AVAILABLE_IOS(11_0);
#endif

@property (atomic, assign) float fieldOfView NS_AVAILABLE_IOS(11_0);

@end
