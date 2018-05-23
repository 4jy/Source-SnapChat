//
//  SCManagedAudioStreamer.h
//  Snapchat
//
//  Created by Ricardo Sánchez-Sáez on 7/28/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import <SCCameraFoundation/SCManagedAudioDataSource.h>

#import <Foundation/Foundation.h>

@interface SCManagedAudioStreamer : NSObject <SCManagedAudioDataSource>

+ (instancetype)sharedInstance;

+ (instancetype) new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end
