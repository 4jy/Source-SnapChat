//
//  SCExposureAdjustMetalRenderCommand.h
//  Snapchat
//
//  Created by Michel Loenngren on 7/11/17.
//
//

#import "SCMetalModule.h"

#import <Foundation/Foundation.h>

/*
 @class SCExposureAdjustProcessingModule
    Prepares the command buffer for the SCExposureAdjustProcessingModule.metal shader.
 */
@interface SCExposureAdjustMetalRenderCommand : SCMetalModule <SCMetalRenderCommand>

@property (nonatomic, readonly) NSString *functionName;

@end
