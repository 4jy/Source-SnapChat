//
// Created by Aaron Levine on 10/16/17.
//

#import "SCCapturerTokenProvider.h"

#import "SCCapturerToken.h"

#import <SCBase/SCAssignment.h>
#import <SCFoundation/SCAssertWrapper.h>

@implementation SCCapturerTokenProvider {
    SCCapturerToken *_Nullable _token;
}

+ (instancetype)providerWithToken:(SCCapturerToken *)token
{
    return [[self alloc] initWithToken:token];
}

- (instancetype)initWithToken:(SCCapturerToken *)token
{
    self = [super init];
    if (self) {
        _token = token;
    }

    return self;
}

- (nullable SCCapturerToken *)getTokenAndInvalidate
{
    // ensure serial access by requiring calls be on the main thread
    SCAssertMainThread();

    let token = _token;
    _token = nil;

    return token;
}

@end
