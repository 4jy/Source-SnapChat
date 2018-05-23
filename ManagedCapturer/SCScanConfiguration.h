//
//  SCScanConfiguration.h
//  Snapchat
//
//  Created by Yang Dai on 3/7/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturer.h"

#import <SCSession/SCUserSession.h>

@interface SCScanConfiguration : NSObject

@property (nonatomic, strong) sc_managed_capturer_scan_results_handler_t scanResultsHandler;
@property (nonatomic, strong) SCUserSession *userSession;

@end
