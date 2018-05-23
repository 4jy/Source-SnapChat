//
//  SCVideoCaptureSessionInfo.h
//  Snapchat
//
//  Created by Michel Loenngren on 3/27/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <SCFoundation/NSString+SCFormat.h>

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SCManagedVideoCapturerInfoType) {
    SCManagedVideoCapturerInfoAudioQueueError,
    SCManagedVideoCapturerInfoAssetWriterError,
    SCManagedVideoCapturerInfoAudioSessionError,
    SCManagedVideoCapturerInfoAudioQueueRetrySuccess,
    SCManagedVideoCapturerInfoAudioQueueRetryDataSourceSuccess_audioQueue,
    SCManagedVideoCapturerInfoAudioQueueRetryDataSourceSuccess_hardware
};

typedef u_int32_t sc_managed_capturer_recording_session_t;

/*
 Container object holding information about the
 current recording session.
 */
typedef struct {
    CMTime startTime;
    CMTime endTime;
    CMTime duration;
    sc_managed_capturer_recording_session_t sessionId;
} SCVideoCaptureSessionInfo;

static inline SCVideoCaptureSessionInfo SCVideoCaptureSessionInfoMake(CMTime startTime, CMTime endTime,
                                                                      sc_managed_capturer_recording_session_t sessionId)
{
    SCVideoCaptureSessionInfo session;
    session.startTime = startTime;
    session.endTime = endTime;
    if (CMTIME_IS_VALID(startTime) && CMTIME_IS_VALID(endTime)) {
        session.duration = CMTimeSubtract(endTime, startTime);
    } else {
        session.duration = kCMTimeInvalid;
    }
    session.sessionId = sessionId;
    return session;
}

static inline NSTimeInterval SCVideoCaptureSessionInfoGetCurrentDuration(SCVideoCaptureSessionInfo sessionInfo)
{
    if (CMTIME_IS_VALID(sessionInfo.startTime)) {
        if (CMTIME_IS_VALID(sessionInfo.endTime)) {
            return CMTimeGetSeconds(sessionInfo.duration);
        }
        return CACurrentMediaTime() - CMTimeGetSeconds(sessionInfo.startTime);
    }
    return 0;
}

static inline NSString *SCVideoCaptureSessionInfoGetDebugString(CMTime time, NSString *label)
{
    if (CMTIME_IS_VALID(time)) {
        return [NSString sc_stringWithFormat:@"%@: %f", label, CMTimeGetSeconds(time)];
    } else {
        return [NSString sc_stringWithFormat:@"%@: Invalid", label];
    }
}

static inline NSString *SCVideoCaptureSessionInfoGetDebugDescription(SCVideoCaptureSessionInfo sessionInfo)
{
    NSMutableString *description = [NSMutableString new];
    [description appendString:SCVideoCaptureSessionInfoGetDebugString(sessionInfo.startTime, @"StartTime")];
    [description appendString:@", "];
    [description appendString:SCVideoCaptureSessionInfoGetDebugString(sessionInfo.endTime, @"EndTime")];
    [description appendString:@", "];
    [description appendString:SCVideoCaptureSessionInfoGetDebugString(sessionInfo.duration, @"Duration")];
    [description appendString:@", "];
    [description appendString:[NSString sc_stringWithFormat:@"Id: %u", sessionInfo.sessionId]];

    return [description copy];
}
