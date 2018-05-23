//
//  SCFeatureFlashImpl.h
//  SCCamera
//
//  Created by Kristian Bauer on 3/27/18.
//

#import "SCFeatureFlash.h"

#import <SCBase/SCMacros.h>

@class SCLogger;
@protocol SCCapturer;

/**
 * Interface for camera flash feature. Handles enabling/disabling of camera flash via SCCapturer and UI for displaying
 * flash button.
 * Should only expose initializer. All other vars and methods should be declared in SCFeatureFlash protocol.
 */
@interface SCFeatureFlashImpl : NSObject <SCFeatureFlash>
SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithCapturer:(id<SCCapturer>)capturer logger:(SCLogger *)logger NS_DESIGNATED_INITIALIZER;
@end
