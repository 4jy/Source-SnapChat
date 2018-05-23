//
//  SCCaptureConfiguration.m
//  Snapchat
//
//  Created by Lin Jia on 10/3/17.
//
//

#import "SCCaptureConfiguration.h"
#import "SCCaptureConfiguration_Private.h"

#import <SCFoundation/SCAppEnvironment.h>
#import <SCFoundation/SCAssertWrapper.h>

@interface SCCaptureConfiguration () {
    BOOL _sealed;
    NSMutableSet<SCCaptureConfigurationDirtyKey *> *_dirtyKeys;
}
@end

@implementation SCCaptureConfiguration

- (instancetype)init
{
    self = [super init];
    if (self) {
        _dirtyKeys = [[NSMutableSet<SCCaptureConfigurationDirtyKey *> alloc] init];
        _sealed = NO;
    }
    return self;
}

- (void)setIsRunning:(BOOL)running
{
    if ([self _configurationSealed]) {
        return;
    }
    _isRunning = running;
    [_dirtyKeys addObject:@(SCCaptureConfigurationKeyIsRunning)];
}

/*
 All set methods will be added later. They follow the format of setIsRunning.
 */

@end

@implementation SCCaptureConfiguration (privateMethods)

- (NSArray *)dirtyKeys
{
    if (!_sealed && SCIsDebugBuild()) {
        SCAssert(NO, @"Configuration not sealed yet, setting is still happening!");
    }
    return [_dirtyKeys allObjects];
}

- (void)seal
{
    _sealed = YES;
}

- (BOOL)_configurationSealed
{
    if (_sealed) {
        if (SCIsDebugBuild()) {
            SCAssert(NO, @"Try to set property after commit configuration to configurator");
        }
        return YES;
    } else {
        return NO;
    }
}

@end
