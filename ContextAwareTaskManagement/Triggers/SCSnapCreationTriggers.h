//
//  SCSnapCreationTriggers.h
//  Snapchat
//
//  Created by Cheng Jiang on 4/1/18.
//

#import <Foundation/Foundation.h>

@interface SCSnapCreationTriggers : NSObject

- (void)markSnapCreationStart;

- (void)markSnapCreationPreviewAnimationFinish;

- (void)markSnapCreationPreviewImageSetupFinish;

- (void)markSnapCreationPreviewVideoFirstFrameRenderFinish;

- (void)markSnapCreationEndWithContext:(NSString *)context;

@end
