//
//  SCDepthBlurMetalRenderCommand.h
//  Snapchat
//
//  Created by Brian Ng on 11/8/17.
//
//

#import "SCMetalModule.h"

#import <Foundation/Foundation.h>

/*
 @class SCDepthBlurMetalRenderCommand
    Prepares the command buffer for the SCDepthBlurMetalModule.metal shader.
 */
@interface SCDepthBlurMetalRenderCommand : NSObject <SCMetalRenderCommand>

@property (nonatomic, readonly) NSString *functionName;

@end
