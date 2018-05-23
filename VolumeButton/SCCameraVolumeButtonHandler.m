//
//  SCCameraVolumeButtonHandler.m
//  Snapchat
//
//  Created by Xiaomu Wu on 2/27/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCCameraVolumeButtonHandler.h"

#import <SCFoundation/SCLog.h>
#import <SCFoundation/UIApplication+SCSecretFeature2.h>

@implementation SCCameraVolumeButtonHandler {
    NSString *_secretFeatureToken;
    BOOL _pressingButton1; // volume down button
    BOOL _pressingButton2; // volume up button
    BOOL _stopsHandlingWhenPressingEnds;
}

#pragma mark - NSObject

- (instancetype)init
{
    self = [super init];
    if (self) {
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        UIApplication *application = [UIApplication sharedApplication];
        [notificationCenter addObserver:self
                               selector:@selector(_handleButton1Down:)
                                   name:[application sc_eventNotificationName1]
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(_handleButton1Up:)
                                   name:[application sc_eventNotificationName2]
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(_handleButton2Down:)
                                   name:[application sc_eventNotificationName3]
                                 object:nil];
        [notificationCenter addObserver:self
                               selector:@selector(_handleButton2Up:)
                                   name:[application sc_eventNotificationName4]
                                 object:nil];
    }
    return self;
}

- (void)dealloc
{
    if (_secretFeatureToken) {
        [[UIApplication sharedApplication] sc_disableSecretFeature2:_secretFeatureToken];
    }
}

#pragma mark - Public

- (void)startHandlingVolumeButtonEvents
{
    _stopsHandlingWhenPressingEnds = NO;
    [self _resetPressingButtons];
    if ([self isHandlingVolumeButtonEvents]) {
        return;
    }
    SCLogGeneralInfo(@"[Volume Buttons] Start handling volume button events");
    _secretFeatureToken = [[[UIApplication sharedApplication] sc_enableSecretFeature2] copy];
}

- (void)stopHandlingVolumeButtonEvents
{
    if (![self isHandlingVolumeButtonEvents]) {
        return;
    }
    SCLogGeneralInfo(@"[Volume Buttons] Stop handling volume button events");
    [[UIApplication sharedApplication] sc_disableSecretFeature2:_secretFeatureToken];
    _secretFeatureToken = nil;
    _stopsHandlingWhenPressingEnds = NO;
}

- (void)stopHandlingVolumeButtonEventsWhenPressingEnds
{
    if (![self isHandlingVolumeButtonEvents]) {
        return;
    }
    if (![self isPressingVolumeButton]) {
        return;
    }
    SCLogGeneralInfo(@"[Volume Buttons] Stop handling volume button events when pressing ends");
    _stopsHandlingWhenPressingEnds = YES;
}

- (BOOL)isHandlingVolumeButtonEvents
{
    return (_secretFeatureToken != nil);
}

- (BOOL)isPressingVolumeButton
{
    return _pressingButton1 || _pressingButton2;
}

- (void)_resetPressingButtons
{
    _pressingButton1 = NO;
    _pressingButton2 = NO;
}

#pragma mark - Private

- (void)_handleButton1Down:(NSNotification *)notification
{
    if (![self isHandlingVolumeButtonEvents]) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 1 down, not handled");
        return;
    }
    if (_pressingButton1) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 1 down, already down");
        return;
    }
    SCLogGeneralInfo(@"[Volume Buttons] Volume button 1 down");
    [self _changePressingButton:^{
        _pressingButton1 = YES;
    }];
}

- (void)_handleButton1Up:(NSNotification *)notification
{
    if (![self isHandlingVolumeButtonEvents]) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 1 up, not handled");
        return;
    }
    if (!_pressingButton1) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 1 up, already up");
        return;
    }
    SCLogGeneralInfo(@"[Volume Buttons] Volume button 1 up");
    [self _changePressingButton:^{
        _pressingButton1 = NO;
    }];
}

- (void)_handleButton2Down:(NSNotification *)notification
{
    if (![self isHandlingVolumeButtonEvents]) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 2 down, not handled");
        return;
    }
    if (_pressingButton2) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 2 down, already down");
        return;
    }
    SCLogGeneralInfo(@"[Volume Buttons] Volume button 2 down");
    [self _changePressingButton:^{
        _pressingButton2 = YES;
    }];
}

- (void)_handleButton2Up:(NSNotification *)notification
{
    if (![self isHandlingVolumeButtonEvents]) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 2 up, not handled");
        return;
    }
    if (!_pressingButton2) {
        SCLogGeneralInfo(@"[Volume Buttons] Volume button 2 up, already up");
        return;
    }
    SCLogGeneralInfo(@"[Volume Buttons] Volume button 2 up");
    [self _changePressingButton:^{
        _pressingButton2 = NO;
    }];
}

- (void)_changePressingButton:(void (^)(void))change
{
    BOOL oldPressingVolumeButton = [self isPressingVolumeButton];
    change();
    BOOL newPressingVolumeButton = [self isPressingVolumeButton];

    if (!oldPressingVolumeButton && newPressingVolumeButton) {
        [_delegate volumeButtonHandlerDidBeginPressingVolumeButton:self];
    } else if (oldPressingVolumeButton && !newPressingVolumeButton) {
        [_delegate volumeButtonHandlerDidEndPressingVolumeButton:self];
        if (_stopsHandlingWhenPressingEnds) {
            [self stopHandlingVolumeButtonEvents];
        }
    }
}

@end
