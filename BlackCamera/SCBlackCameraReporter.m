//
//  SCBlackCameraReporter.m
//  Snapchat
//
//  Created by Derek Wang on 09/01/2018.
//

#import "SCBlackCameraReporter.h"

#import "SCManiphestTicketCreator.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCLogHelper.h>
#import <SCFoundation/SCZeroDependencyExperiments.h>
#import <SCLogger/SCCameraMetrics.h>
#import <SCLogger/SCLogger.h>

@interface SCBlackCameraReporter ()

@property (nonatomic) id<SCManiphestTicketCreator> ticketCreator;

@end

@implementation SCBlackCameraReporter

- (instancetype)initWithTicketCreator:(id<SCManiphestTicketCreator>)ticketCreator
{
    if (self = [super init]) {
        _ticketCreator = ticketCreator;
    }
    return self;
}

- (NSString *)causeNameFor:(SCBlackCameraCause)cause
{
    switch (cause) {
    case SCBlackCameraStartRunningNotCalled:
        return @"StartRunningNotCalled";
    case SCBlackCameraSessionNotRunning:
        return @"SessionNotRunning";
    case SCBlackCameraRenderingPaused:
        return @"RenderingPause";
    case SCBlackCameraPreviewIsHidden:
        return @"PreviewIsHidden";
    case SCBlackCameraSessionStartRunningBlocked:
        return @"SessionStartRunningBlocked";
    case SCBlackCameraSessionConfigurationBlocked:
        return @"SessionConfigurationBlocked";
    case SCBlackCameraNoOutputData:
        return @"NoOutputData";
    default:
        SCAssert(NO, @"illegate cause");
        break;
    }
    return nil;
}

- (void)reportBlackCameraWithCause:(SCBlackCameraCause)cause
{
    NSString *causeStr = [self causeNameFor:cause];
    SCLogCoreCameraError(@"[BlackCamera] Detected black camera, cause: %@", causeStr);

    NSDictionary *parameters = @{ @"type" : @"DETECTED", @"cause" : causeStr };

    [_ticketCreator createAndFileBetaReport:JSONStringSerializeObjectForLogging(parameters)];

    if (SCExperimentWithBlackCameraReporting()) {
        [[SCLogger sharedInstance] logUnsampledEvent:KSCCameraBlackCamera
                                          parameters:parameters
                                    secretParameters:nil
                                             metrics:nil];
    }
}

- (void)fileShakeTicketWithCause:(SCBlackCameraCause)cause
{
    if (SCExperimentWithBlackCameraExceptionLogging()) {
        // Log exception with auto S2R
        NSString *errMsg =
            [NSString sc_stringWithFormat:@"[BlackCamera] Detected black camera, cause: %@", [self causeNameFor:cause]];
        [_ticketCreator createAndFile:nil creationTime:0 description:errMsg email:nil project:@"Camera" subproject:nil];
    }
}

@end
