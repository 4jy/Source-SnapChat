//
//  SCCaptureSessionFixer.m
//  Snapchat
//
//  Created by Derek Wang on 05/12/2017.
//

#import "SCCaptureSessionFixer.h"

#import "SCCameraTweaks.h"

@implementation SCCaptureSessionFixer

- (void)detector:(SCBlackCameraNoOutputDetector *)detector didDetectBlackCamera:(id<SCCapturer>)capture
{
    if (SCCameraTweaksBlackCameraRecoveryEnabled()) {
        [capture recreateAVCaptureSession];
    }
}

@end
