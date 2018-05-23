//
//  SCCaptureConfigurationAnnouncer_Private.h
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//
//

#import "SCCaptureConfigurationAnnouncer.h"
#import "SCManagedCapturerState.h"

#import <SCFoundation/SCQueuePerformer.h>

@class SCCaptureConfigurator;

/*
 This private header is only going to be used by SCCaptureConfigurator. Other customers should only use the public
 header.
 */
@interface SCCaptureConfigurationAnnouncer ()
/*
 The announcer is going to be instantiated by SCCaptureConfigurator. It will take in a queue performer. The design is
 that announcer and configurator is going to share the same serial queue to avoid racing. This is something we could
 change later.
 */
- (instancetype)initWithPerformer:(SCQueuePerformer *)performer configurator:(SCCaptureConfigurator *)configurator;

/*
 The API below is called by configurator to notify listener that configuration has changed.
 */
- (void)deliverConfigurationChange:(id<SCManagedCapturerState>)configuration;

@end
