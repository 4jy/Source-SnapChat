//
//  SCContextAwareSnapCreationThrottleRequest.m
//  SCCamera
//
//  Created by Cheng Jiang on 4/24/18.
//

#import "SCContextAwareSnapCreationThrottleRequest.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCContextAwareTaskManagementResourceProvider.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>

#import <Tweaks/FBTweakInline.h>

BOOL SCCATMSnapCreationEnabled(void)
{
    static dispatch_once_t capturingOnceToken;
    static BOOL capturingImprovementEnabled;
    dispatch_once(&capturingOnceToken, ^{
        BOOL enabledWithAB = SCExperimentWithContextAwareTaskManagementCapturingImprovementEnabled();
        NSInteger tweakOption = [FBTweakValue(@"CATM", @"Performance Improvement", @"Capturing", (id) @0,
                                              (@{ @0 : @"Respect A/B",
                                                  @1 : @"YES",
                                                  @2 : @"NO" })) integerValue];
        switch (tweakOption) {
        case 0:
            capturingImprovementEnabled = enabledWithAB;
            break;
        case 1:
            capturingImprovementEnabled = YES;
            break;
        case 2:
            capturingImprovementEnabled = NO;
            break;
        default:
            SCCAssertFail(@"Illegal option");
        }
    });
    return capturingImprovementEnabled;
}

@implementation SCContextAwareSnapCreationThrottleRequest {
    NSString *_requestID;
}

- (instancetype)init
{
    if (self = [super init]) {
        _requestID = @"SCContextAwareSnapCreationThrottleRequest";
    }
    return self;
}

- (BOOL)shouldThrottle:(SCApplicationContextState)context
{
    return SCCATMSnapCreationEnabled() && context != SCApplicationContextStateCamera;
}

- (NSString *)requestID
{
    return _requestID;
}

- (BOOL)isEqual:(id<SCContextAwareThrottleRequest>)object
{
    return [[object requestID] isEqualToString:_requestID];
}

@end
