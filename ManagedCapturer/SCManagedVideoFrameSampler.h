//
//  SCManagedVideoFrameSampler.h
//  Snapchat
//
//  Created by Michel Loenngren on 3/10/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturerListener.h"

#import <Foundation/Foundation.h>

/**
 Allows consumer to register a block to sample the next CMSampleBufferRef and
 automatically leverages Core image to convert the pixel buffer to a UIImage.
 Returned image will be a copy.
 */
@interface SCManagedVideoFrameSampler : NSObject <SCManagedCapturerListener>

- (void)sampleNextFrame:(void (^)(UIImage *frame, CMTime presentationTime))completeBlock;

@end
