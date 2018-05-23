//
//  SCCaptureCoreImageFaceDetector.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/27/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class is intended to detect faces in Camera. It receives CMSampleBuffer, process the face detection using
//  CIDetector, and announce the bounds and faceIDs.

#import "SCCaptureFaceDetector.h"

#import <SCBase/SCMacros.h>
#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>

#import <Foundation/Foundation.h>

@interface SCCaptureCoreImageFaceDetector : NSObject <SCCaptureFaceDetector, SCManagedVideoDataSourceListener>

SC_INIT_AND_NEW_UNAVAILABLE;

@end
