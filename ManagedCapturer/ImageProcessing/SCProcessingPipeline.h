//
//  SCProcessingPipeline.h
//  Snapchat
//
//  Created by Yu-Kuan (Anthony) Lai on 5/30/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCProcessingModule.h"

#import <Foundation/Foundation.h>

/*
 @class SCProcessingPipeline
    The SCProcessingPipeline chains together a series of SCProcessingModules and passes the frame through
        each of them in a pre-determined order. This is done through a chain of command, where the resulting
        frame from the the first module is passed to the second, then to the third, etc.
 */
@interface SCProcessingPipeline : NSObject <SCProcessingModule>

@property (nonatomic, strong) NSMutableArray<id<SCProcessingModule>> *processingModules;

@end
