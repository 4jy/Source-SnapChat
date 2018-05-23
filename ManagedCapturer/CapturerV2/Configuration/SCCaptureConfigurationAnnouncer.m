//
//  SCCaptureConfigurationAnnouncer.m
//  Snapchat
//
//  Created by Lin Jia on 10/2/17.
//
//

#import "SCCaptureConfigurationAnnouncer.h"
#import "SCCaptureConfigurationAnnouncer_Private.h"

#import "SCCaptureConfigurator.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCPerforming.h>

@interface SCCaptureConfigurationAnnouncer () {
    NSHashTable<id<SCCaptureConfigurationListener>> *_listeners;
    SCQueuePerformer *_performer;
    __weak SCCaptureConfigurator *_configurator;
}
@end

@implementation SCCaptureConfigurationAnnouncer

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer configurator:(SCCaptureConfigurator *)configurator
{
    self = [super init];
    if (self) {
        _listeners = [NSHashTable<id<SCCaptureConfigurationListener>> hashTableWithOptions:NSHashTableWeakMemory];
        SCAssert(performer, @"performer should not be nil");
        _performer = performer;
        _configurator = configurator;
    }
    return self;
}

- (void)addListener:(id<SCCaptureConfigurationListener>)listener
{
    [_performer perform:^{
        SCAssert(listener, @"listener should not be nil");
        [_listeners addObject:listener];
        [listener captureConfigurationDidChangeTo:_configurator.currentConfiguration];
    }];
}

- (void)removeListener:(id<SCCaptureConfigurationListener>)listener
{
    [_performer perform:^{
        SCAssert(listener, @"listener should not be nil");
        [_listeners removeObject:listener];
    }];
}

- (void)deliverConfigurationChange:(id<SCManagedCapturerState>)configuration
{
    SCAssertPerformer(_performer);
    for (id<SCCaptureConfigurationListener> listener in _listeners) {
        [listener captureConfigurationDidChangeTo:configuration];
    }
}

- (void)dealloc
{
    [_listeners removeAllObjects];
}
@end
