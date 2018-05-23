//
//  SCCameraVolumeButtonHandler.h
//  Snapchat
//
//  Created by Xiaomu Wu on 2/27/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SCCameraVolumeButtonHandler;

@protocol SCCameraVolumeButtonHandlerDelegate <NSObject>

- (void)volumeButtonHandlerDidBeginPressingVolumeButton:(SCCameraVolumeButtonHandler *)handler;
- (void)volumeButtonHandlerDidEndPressingVolumeButton:(SCCameraVolumeButtonHandler *)handler;

@end

@interface SCCameraVolumeButtonHandler : NSObject

@property (nonatomic, weak) id<SCCameraVolumeButtonHandlerDelegate> delegate;

- (void)startHandlingVolumeButtonEvents;
- (void)stopHandlingVolumeButtonEvents;
- (void)stopHandlingVolumeButtonEventsWhenPressingEnds;
- (BOOL)isHandlingVolumeButtonEvents;

- (BOOL)isPressingVolumeButton;

@end
