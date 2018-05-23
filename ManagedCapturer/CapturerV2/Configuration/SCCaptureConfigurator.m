//
//  SCCaptureConfiguration.m
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//
//

#import "SCCaptureConfigurator.h"

#import "SCCaptureConfigurationAnnouncer_Private.h"
#import "SCCaptureConfiguration_Private.h"

#import <SCFoundation/SCAssertWrapper.h>

@interface SCCaptureConfigurator () {
    SCQueuePerformer *_performer;
}
@end

@implementation SCCaptureConfigurator

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
{
    self = [super init];
    if (self) {
        _announcer = [[SCCaptureConfigurationAnnouncer alloc] initWithPerformer:performer configurator:self];
        _performer = performer;
        // TODO: initialize _currentConfiguration
    }
    return self;
}

- (void)commitConfiguration:(SCCaptureConfiguration *)configuration
          completionHandler:(SCCaptureConfigurationCompletionHandler)completionHandler
{
    [configuration seal];
    [_performer perform:^() {
        SCAssert(configuration, @"Configuration must be a valid input parameter");
        NSArray<SCCaptureConfigurationDirtyKey *> *dirtyKeys = [configuration dirtyKeys];
        for (SCCaptureConfigurationDirtyKey *key in dirtyKeys) {
            [self _processKey:[key integerValue] configuration:configuration];
        }
        if (completionHandler) {
            // TODO: passing in right parameters.
            completionHandler(NULL, YES);
        }
    }];
}

- (void)_processKey:(SCCaptureConfigurationKey)key configuration:(SCCaptureConfiguration *)configuration
{
    // Tune the hardware depending on what key is dirty, and what is the value is inside configuration.
}

@end
