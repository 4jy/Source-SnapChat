//
//  SCCapturerToken.m
//  Snapchat
//
//  Created by Xishuo Liu on 3/24/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCCapturerToken.h"

#import <SCFoundation/NSString+SCFormat.h>

@implementation SCCapturerToken {
    NSString *_identifier;
}

- (instancetype)initWithIdentifier:(NSString *)identifier
{
    if (self = [super init]) {
        _identifier = identifier.copy;
    }
    return self;
}

- (NSString *)debugDescription
{
    return [NSString sc_stringWithFormat:@"%@_%@", _identifier, self];
}

@end
