//
//  SCSnapCreationTriggers.m
//  Snapchat
//
//  Created by Cheng Jiang on 3/30/18.
//

#import "SCSnapCreationTriggers.h"

#import "SCContextAwareSnapCreationThrottleRequest.h"

#import <SCBase/SCMacros.h>
#import <SCFoundation/SCContextAwareThrottleRequester.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>

@implementation SCSnapCreationTriggers {
    BOOL _snapCreationStarted;
    BOOL _previewAnimationFinished;
    BOOL _previewImageSetupFinished;
    BOOL _previewVideoFirstFrameRendered;
}

- (void)markSnapCreationStart
{
    SC_GUARD_ELSE_RUN_AND_RETURN(
        !_snapCreationStarted,
        SCLogCoreCameraWarning(@"markSnapCreationStart skipped because previous SnapCreation session is not complete"));
    @synchronized(self)
    {
        _snapCreationStarted = YES;
    }
    [[SCContextAwareThrottleRequester shared] submitSuspendRequest:[SCContextAwareSnapCreationThrottleRequest new]];
}

- (void)markSnapCreationPreviewAnimationFinish
{
    @synchronized(self)
    {
        _previewAnimationFinished = YES;
        if (_previewImageSetupFinished || _previewVideoFirstFrameRendered) {
            [self markSnapCreationEndWithContext:@"markSnapCreationPreviewAnimationFinish"];
        }
    }
}

- (void)markSnapCreationPreviewImageSetupFinish
{
    @synchronized(self)
    {
        _previewImageSetupFinished = YES;
        if (_previewAnimationFinished) {
            [self markSnapCreationEndWithContext:@"markSnapCreationPreviewImageSetupFinish"];
        }
    }
}

- (void)markSnapCreationPreviewVideoFirstFrameRenderFinish
{
    @synchronized(self)
    {
        _previewVideoFirstFrameRendered = YES;
        if (_previewAnimationFinished) {
            [self markSnapCreationEndWithContext:@"markSnapCreationPreviewVideoFirstFrameRenderFinish"];
        }
    }
}

- (void)markSnapCreationEndWithContext:(NSString *)context
{
    SC_GUARD_ELSE_RETURN(_snapCreationStarted);
    SCLogCoreCameraInfo(@"markSnapCreationEnd triggered with context: %@", context);
    @synchronized(self)
    {
        _snapCreationStarted = NO;
        _previewAnimationFinished = NO;
        _previewImageSetupFinished = NO;
        _previewVideoFirstFrameRendered = NO;
    }
    [[SCContextAwareThrottleRequester shared] submitResumeRequest:[SCContextAwareSnapCreationThrottleRequest new]];
}

@end
