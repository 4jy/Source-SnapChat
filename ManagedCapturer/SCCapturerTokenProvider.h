//
// Created by Aaron Levine on 10/16/17.
//

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

@class SCCapturerToken;

NS_ASSUME_NONNULL_BEGIN
@interface SCCapturerTokenProvider : NSObject

SC_INIT_AND_NEW_UNAVAILABLE
+ (instancetype)providerWithToken:(SCCapturerToken *)token;

- (nullable SCCapturerToken *)getTokenAndInvalidate;

@end
NS_ASSUME_NONNULL_END
