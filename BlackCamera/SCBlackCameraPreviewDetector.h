//
//  SCBlackCameraPreviewDetector.h
//  Snapchat
//
//  Created by Derek Wang on 25/01/2018.
//

#import <Foundation/Foundation.h>

@class SCQueuePerformer, SCBlackCameraReporter;
@protocol SCManiphestTicketCreator;

@interface SCBlackCameraPreviewDetector : NSObject

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer reporter:(SCBlackCameraReporter *)reporter;

- (void)sessionDidChangeIsRunning:(BOOL)running;
- (void)capturePreviewDidBecomeVisible:(BOOL)visible;

@end
