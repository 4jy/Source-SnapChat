//
//  SCProcessingModule.h
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 5/30/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

typedef struct RenderData {
    CMSampleBufferRef sampleBuffer;
    CVPixelBufferRef depthDataMap;     // Optional - for depth blur rendering
    CGPoint *depthBlurPointOfInterest; // Optional - for depth blur rendering
} RenderData;

/*
 @protocol SCProcessingModule
    A single module that is responsible for the actual image processing work. Multiple modules can be chained
        together by the SCProcessingPipelineBuilder and the frame can be passed through the entire
        SCProcessingPipeline.
 */
@protocol SCProcessingModule <NSObject>

- (CMSampleBufferRef)render:(RenderData)renderData;

// Needed to protect against depth data potentially being nil during the render pass
- (BOOL)requiresDepthData;

@end
