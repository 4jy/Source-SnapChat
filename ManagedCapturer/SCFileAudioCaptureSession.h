//
//  SCFileAudioCaptureSession.h
//  Snapchat
//
//  Created by Xiaomu Wu on 2/2/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "SCAudioCaptureSession.h"

#import <Foundation/Foundation.h>

@interface SCFileAudioCaptureSession : NSObject <SCAudioCaptureSession>

// Linear PCM is required.
// To best mimic `SCAudioCaptureSession`, use an audio file recorded from it.
- (void)setFileURL:(NSURL *)fileURL;

@end
