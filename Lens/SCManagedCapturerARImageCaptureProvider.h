//
//  SCManagedCapturerARImageCaptureProvider.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/11/18.
//

#import <Foundation/Foundation.h>

@class SCManagedStillImageCapturer;
@protocol SCManagedCapturerLensAPI
, SCPerforming;

/**
 Bridging protocol providing the ARImageCapturer subclass of SCManagedStillImageCapturer
 to capture core.
 */
@protocol SCManagedCapturerARImageCaptureProvider <NSObject>

- (SCManagedStillImageCapturer *)arImageCapturerWith:(id<SCPerforming>)performer
                                  lensProcessingCore:(id<SCManagedCapturerLensAPI>)lensProcessingCore;

@end
