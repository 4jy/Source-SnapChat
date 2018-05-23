//
//  SCProcessingPipelineBuilder.h
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 6/1/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SCDigitalExposureHandler;
@class SCProcessingPipeline;

/*
 @class SCProcessingPipelineBuilder
    The builder object is responsible for creating the SCProcessingPipeline, the underneath
        SCProcessingModules, and eventually chaining the SCProcessingModules together in a pre-determined
        order. The builder is also responsible for providing consumers with handler objects.

 */
@interface SCProcessingPipelineBuilder : NSObject

@property (nonatomic) BOOL useExposureAdjust;
@property (nonatomic) BOOL portraitModeEnabled;
@property (nonatomic) BOOL enhancedNightMode;

- (SCProcessingPipeline *)build;

@end
