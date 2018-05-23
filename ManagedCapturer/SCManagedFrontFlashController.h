//
//  SCManagedFrontFlashController.h
//  Snapchat
//
//  Created by Liu Liu on 5/4/15.
//  Copyright (c) 2015 Liu Liu. All rights reserved.
//

#import <Foundation/Foundation.h>

// This object is only access on SCManagedCapturer thread
@interface SCManagedFrontFlashController : NSObject

@property (nonatomic, assign) BOOL flashActive;

@property (nonatomic, assign) BOOL torchActive;

@end
