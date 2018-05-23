//
//  SCCaptureConfigurationAnnouncer.h
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//
//

#import "SCCaptureConfigurationListener.h"

#import <Foundation/Foundation.h>

/*
 All APIs are thread safe. Announcer will not retain your object. So even if customer forgets to call remove listener,
 it will not create zombie objects.
 */
@interface SCCaptureConfigurationAnnouncer : NSObject

/*
 When customer adds an object to be a listener, that object will receive an update of current truth. That is the chance
 for the object to do adjustment according to the current configuration of the camera.
 */
- (void)addListener:(id<SCCaptureConfigurationListener>)listener;

- (void)removeListener:(id<SCCaptureConfigurationListener>)listener;

@end
