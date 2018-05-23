//
//  SCManagedCapturerLSAComponentTrackerAPI.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/11/18.
//

#import <Foundation/Foundation.h>

@class SCCaptureResource;

/**
 SCCamera protocol providing LSA tracking logic.
 */
@protocol SCManagedCapturerLSAComponentTrackerAPI <NSObject>

- (void)configureWithCaptureResource:(SCCaptureResource *)captureResource;

@end
