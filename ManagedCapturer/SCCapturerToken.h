//
//  SCCapturerToken.h
//  Snapchat
//
//  Created by Xishuo Liu on 3/24/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCCapturerToken : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier NS_DESIGNATED_INITIALIZER;

- (instancetype)init __attribute__((unavailable("Use initWithIdentifier: instead.")));
- (instancetype) new __attribute__((unavailable("Use initWithIdentifier: instead.")));

@end
