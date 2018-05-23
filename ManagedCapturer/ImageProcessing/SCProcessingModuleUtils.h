//
//  SCProcessingModuleUtils.h
//  Snapchat
//
//  Created by Brian Ng on 11/10/17.
//

#import <CoreImage/CoreImage.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

@interface SCProcessingModuleUtils : NSObject

+ (CVPixelBufferRef)pixelBufferFromImage:(CIImage *)image
                              bufferPool:(CVPixelBufferPoolRef)bufferPool
                                 context:(CIContext *)context;

+ (CMSampleBufferRef)sampleBufferFromImage:(CIImage *)image
                           oldSampleBuffer:(CMSampleBufferRef)oldSampleBuffer
                                bufferPool:(CVPixelBufferPoolRef)bufferPool
                                   context:(CIContext *)context;
@end
