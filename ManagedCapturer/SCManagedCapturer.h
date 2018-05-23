//  SCManagedCapturer.h
//  Snapchat
//
//  Created by Liu Liu on 4/20/15.

#import "SCCapturer.h"
#import "SCManagedCapturerListener.h"
#import "SCManagedCapturerUtils.h"

#import <Foundation/Foundation.h>

/*
  SCManagedCapturer is a shell class. Its job is to provide an singleton instance which follows protocol of
  SCManagedCapturerImpl. The reason we use this pattern is because we are building SCManagedCapturerV2. This setup
  offers
  possbility for us to code V2 without breaking the existing app, and can test the new implementation via Tweak.
 */

@interface SCManagedCapturer : NSObject

+ (id<SCCapturer>)sharedInstance;

@end
