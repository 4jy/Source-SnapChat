//
//  SCStillImageDepthBlurFilter.h
//  Snapchat
//
//  Created by Brian Ng on 10/11/17.
//

#import "SCProcessingModule.h"

#import <Foundation/Foundation.h>

/*
 @class SCStillImageDepthBlurFilter
    This module uses the CIDepthBlurEffect CIFilter that uses rgb and depth information to produce an image with
    the portrait mode effect (background blurred, foreground sharp).
 */
@interface SCStillImageDepthBlurFilter : NSObject

// Applies the CIDepthBlurEffect filter to a still image capture photo. If an error occured, the original
// photoData will be returned
- (NSData *)renderWithPhotoData:(NSData *)photoData renderData:(RenderData)renderData NS_AVAILABLE_IOS(11_0);

@end
