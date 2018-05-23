//
//  SCCaptureStateUtil.h
//  Snapchat
//
//  Created by Lin Jia on 10/27/17.
//
//

#import "SCLogger+Camera.h"

#import <SCBase/SCMacros.h>
#import <SCFoundation/SCLog.h>

#import <Foundation/Foundation.h>

#define SCLogCaptureStateMachineInfo(fmt, ...) SCLogCoreCameraInfo(@"[SCCaptureStateMachine] " fmt, ##__VA_ARGS__)
#define SCLogCaptureStateMachineError(fmt, ...) SCLogCoreCameraError(@"[SCCaptureStateMachine] " fmt, ##__VA_ARGS__)

typedef NSNumber SCCaptureStateKey;

typedef NS_ENUM(NSUInteger, SCCaptureStateMachineStateId) {
    SCCaptureBaseStateId = 0,
    SCCaptureUninitializedStateId,
    SCCaptureInitializedStateId,
    SCCaptureImageStateId,
    SCCaptureImageWhileRecordingStateId,
    SCCaptureRunningStateId,
    SCCaptureRecordingStateId,
    SCCaptureScanningStateId,
    SCCaptureStateMachineStateIdCount
};

SC_EXTERN_C_BEGIN

NSString *SCCaptureStateName(SCCaptureStateMachineStateId stateId);

SC_EXTERN_C_END
