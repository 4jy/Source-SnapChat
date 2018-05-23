//
//  SCManagedCapturer.m
//  Snapchat
//
//  Created by Lin Jia on 9/28/17.
//

#import "SCManagedCapturer.h"

#import "SCCameraTweaks.h"
#import "SCCaptureCore.h"
#import "SCManagedCapturerV1.h"

@implementation SCManagedCapturer

+ (id<SCCapturer>)sharedInstance
{
    static dispatch_once_t onceToken;
    static id<SCCapturer> managedCapturer;
    dispatch_once(&onceToken, ^{
        managedCapturer = [[SCCaptureCore alloc] init];
    });
    return managedCapturer;
}

@end
