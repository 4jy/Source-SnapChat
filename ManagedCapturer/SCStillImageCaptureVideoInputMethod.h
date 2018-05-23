//
//  SCStillImageCaptureVideoInputMethod.h
//  Snapchat
//
//  Created by Alexander Grytsiuk on 3/16/16.
//  Copyright © 2016 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturerState.h"

#import <AVFoundation/AVFoundation.h>

@interface SCStillImageCaptureVideoInputMethod : NSObject

- (void)captureStillImageWithCapturerState:(SCManagedCapturerState *)state
                              successBlock:(void (^)(NSData *imageData, NSDictionary *cameraInfo,
                                                     NSError *error))successBlock
                              failureBlock:(void (^)(NSError *error))failureBlock;
@end
