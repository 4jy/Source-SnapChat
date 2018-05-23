//
//  SCCaptureMetadataObjectParser.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/13/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class offers class methods to parse AVMetadataObject.

#import <AVFoundation/AVFoundation.h>

@interface SCCaptureMetadataObjectParser : NSObject

/**
 Parse face bounds from AVMetadataObject.

 @param metadataObjects An array of AVMetadataObject.
 @return A dictionary, value is faceBounds: CGRect, key is faceID: NSString.
 */
- (NSDictionary<NSNumber *, NSValue *> *)parseFaceBoundsByFaceIDFromMetadataObjects:
    (NSArray<__kindof AVMetadataObject *> *)metadataObjects;

@end
