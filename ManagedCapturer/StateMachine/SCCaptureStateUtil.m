//
//  SCCaptureStateUtil.m
//  Snapchat
//
//  Created by Lin Jia on 10/27/17.
//
//

#import "SCCaptureStateUtil.h"

#import <SCFoundation/SCAppEnvironment.h>
#import <SCFoundation/SCAssertWrapper.h>

NSString *SCCaptureStateName(SCCaptureStateMachineStateId stateId)
{
    switch (stateId) {
    case SCCaptureBaseStateId:
        return @"SCCaptureBaseStateId";
    case SCCaptureUninitializedStateId:
        return @"SCCaptureUninitializedStateId";
    case SCCaptureInitializedStateId:
        return @"SCCaptureInitializedStateId";
    case SCCaptureImageStateId:
        return @"SCCaptureImageStateId";
    case SCCaptureImageWhileRecordingStateId:
        return @"SCCaptureImageWhileRecordingStateId";
    case SCCaptureRunningStateId:
        return @"SCCaptureRunningStateId";
    case SCCaptureRecordingStateId:
        return @"SCCaptureRecordingStateId";
    case SCCaptureScanningStateId:
        return @"SCCaptureScanningStateId";
    default:
        SCCAssert(NO, @"illegate state id");
        break;
    }
    return @"SCIllegalStateId";
}
