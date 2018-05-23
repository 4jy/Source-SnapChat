//
//  SCCaptureDeviceAuthorization.m
//  Snapchat
//
//  Created by Xiaomu Wu on 8/19/14.
//  Copyright (c) 2014 Snapchat, Inc. All rights reserved.
//

#import "SCCaptureDeviceAuthorization.h"

#import <BlizzardSchema/SCAEvents.h>
#import <SCFoundation/SCTrace.h>
#import <SCLogger/SCLogger.h>

@import AVFoundation;

@implementation SCCaptureDeviceAuthorization

#pragma mark - Public

+ (BOOL)notDeterminedForMediaType:(NSString *)mediaType
{
    return [AVCaptureDevice authorizationStatusForMediaType:mediaType] == AVAuthorizationStatusNotDetermined;
}

+ (BOOL)deniedForMediaType:(NSString *)mediaType
{
    return [AVCaptureDevice authorizationStatusForMediaType:mediaType] == AVAuthorizationStatusDenied;
}

+ (BOOL)restrictedForMediaType:(NSString *)mediaType
{
    return [AVCaptureDevice authorizationStatusForMediaType:mediaType] == AVAuthorizationStatusRestricted;
}

+ (void)requestAccessForMediaType:(NSString *)mediaType completionHandler:(void (^)(BOOL granted))handler
{
    [AVCaptureDevice requestAccessForMediaType:mediaType completionHandler:handler];
}

#pragma mark - Convenience methods for AVMediaTypeVideo

+ (BOOL)notDeterminedForVideoCapture
{
    return [self notDeterminedForMediaType:AVMediaTypeVideo];
}

+ (BOOL)deniedForVideoCapture
{
    return [self deniedForMediaType:AVMediaTypeVideo];
}

+ (void)requestAccessForVideoCaptureWithCompletionHandler:(void (^)(BOOL granted))handler
{
    BOOL firstTimeAsking =
        [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] == AVAuthorizationStatusNotDetermined;
    [self requestAccessForMediaType:AVMediaTypeVideo
                  completionHandler:^(BOOL granted) {
                      if (firstTimeAsking) {
                          SCAPermissionPromptResponse *responseEvent = [[SCAPermissionPromptResponse alloc] init];
                          [responseEvent setPermissionPromptType:SCAPermissionPromptType_OS_CAMERA];
                          [responseEvent setAccepted:granted];
                          [[SCLogger sharedInstance] logUserTrackedEvent:responseEvent];
                      }
                      if (handler) {
                          handler(granted);
                      }
                  }];
}

@end
