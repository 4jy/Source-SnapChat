//
//  SCCaptureDeviceAuthorization.h
//  Snapchat
//
//  Created by Xiaomu Wu on 8/19/14.
//  Copyright (c) 2014 Snapchat, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SCCaptureDeviceAuthorization : NSObject

// Methods for checking / requesting authorization to use media capture devices of a given type.
+ (BOOL)notDeterminedForMediaType:(NSString *)mediaType;
+ (BOOL)deniedForMediaType:(NSString *)mediaType;
+ (BOOL)restrictedForMediaType:(NSString *)mediaType;
+ (void)requestAccessForMediaType:(NSString *)mediaType completionHandler:(void (^)(BOOL granted))handler;

// Convenience methods for media type == AVMediaTypeVideo
+ (BOOL)notDeterminedForVideoCapture;
+ (BOOL)deniedForVideoCapture;
+ (void)requestAccessForVideoCaptureWithCompletionHandler:(void (^)(BOOL granted))handler;

@end
