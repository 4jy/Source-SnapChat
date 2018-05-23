//
//  SCManagedVideoCapturerHandler.h
//  Snapchat
//
//  Created by Jingtian Yang on 11/12/2017.
//

#import "SCManagedVideoCapturer.h"

#import <Foundation/Foundation.h>

@class SCCaptureResource;

@interface SCManagedVideoCapturerHandler : NSObject <SCManagedVideoCapturerDelegate>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource;

@end
