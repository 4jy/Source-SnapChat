//
//  SCCaptureMetadataOutputDetector.h
//  Snapchat
//
//  Created by Jiyang Zhu on 12/21/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//
//  This class is intended to detect faces in Camera. It receives AVMetadataFaceObjects, and announce the bounds and
//  faceIDs.

#import "SCCaptureFaceDetector.h"

#import <SCBase/SCMacros.h>

@interface SCCaptureMetadataOutputDetector : NSObject <SCCaptureFaceDetector>

SC_INIT_AND_NEW_UNAVAILABLE;

@end
