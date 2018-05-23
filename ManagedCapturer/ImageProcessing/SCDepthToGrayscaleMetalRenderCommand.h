//
//  SCDepthToGrayscaleMetalRenderCommand.h
//  Snapchat
//
//  Created by Brian Ng on 12/7/17.
//
//

#import "SCMetalModule.h"

#import <Foundation/Foundation.h>

/*
 @class SCDepthToGrayscaleMetalRenderCommand
 Prepares the command buffer for the SCDepthToGrayscaleMetalModule.metal shader.
 */
@interface SCDepthToGrayscaleMetalRenderCommand : NSObject <SCMetalRenderCommand>

@property (nonatomic, readonly) NSString *functionName;

@end
