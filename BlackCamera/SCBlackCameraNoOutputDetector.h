//
//  SCBlackCameraNoOutputDetector.h
//  Snapchat
//
//  Created by Derek Wang on 05/12/2017.
//

#import "SCManagedCapturerListener.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>

#import <Foundation/Foundation.h>

@class SCBlackCameraNoOutputDetector, SCBlackCameraReporter;
@protocol SCManiphestTicketCreator;

@protocol SCBlackCameraDetectorDelegate
- (void)detector:(SCBlackCameraNoOutputDetector *)detector didDetectBlackCamera:(id<SCCapturer>)capture;
@end

@interface SCBlackCameraNoOutputDetector : NSObject <SCManagedVideoDataSourceListener, SCManagedCapturerListener>

@property (nonatomic, weak) id<SCBlackCameraDetectorDelegate> delegate;
- (instancetype)initWithReporter:(SCBlackCameraReporter *)reporter;

@end
