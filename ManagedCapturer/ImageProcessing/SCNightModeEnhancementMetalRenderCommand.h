//
//  SCNightModeEnhancementMetalRenderCommand.h
//  Snapchat
//
//  Created by Chao Pang on 12/21/17.
//

#import "SCMetalModule.h"

#import <Foundation/Foundation.h>

/*
 Prepares the command buffer for the SCNightModeEnhancementMetalModule.metal.
 */
@interface SCNightModeEnhancementMetalRenderCommand : SCMetalModule <SCMetalRenderCommand>

@property (nonatomic, readonly) NSString *functionName;

@end
