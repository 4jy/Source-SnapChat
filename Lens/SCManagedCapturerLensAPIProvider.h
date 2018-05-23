//
//  SCManagedCapturerLensAPIProvider.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/12/18.
//

#import <Foundation/Foundation.h>

@protocol SCManagedCapturerLensAPI;
@class SCCaptureResource;

/**
 Provider for creating new instances of SCManagedCapturerLensAPI within SCCamera.
 */
@protocol SCManagedCapturerLensAPIProvider <NSObject>

- (id<SCManagedCapturerLensAPI>)lensAPIForCaptureResource:(SCCaptureResource *)captureResouce;

@end
