//
//  SCCaptureFaceDetectionParser.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/13/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class offers methods to parse face bounds from raw data, e.g., AVMetadataObject, CIFeature.

#import <SCBase/SCMacros.h>

#import <AVFoundation/AVFoundation.h>
#import <CoreImage/CoreImage.h>

@interface SCCaptureFaceDetectionParser : NSObject

SC_INIT_AND_NEW_UNAVAILABLE;

- (instancetype)initWithFaceBoundsAreaThreshold:(CGFloat)minimumArea;

/**
 Parse face bounds from AVMetadataObject.

 @param metadataObjects An array of AVMetadataObject.
 @return A dictionary, value is faceBounds: CGRect, key is faceID: NSString.
 */
- (NSDictionary<NSNumber *, NSValue *> *)parseFaceBoundsByFaceIDFromMetadataObjects:
    (NSArray<__kindof AVMetadataObject *> *)metadataObjects;

/**
 Parse face bounds from CIFeature.

 @param features An array of CIFeature.
 @param imageSize Size of the image, where the feature are detected from.
 @param imageOrientation Orientation of the image.
 @return A dictionary, value is faceBounds: CGRect, key is faceID: NSString.
 */
- (NSDictionary<NSNumber *, NSValue *> *)parseFaceBoundsByFaceIDFromCIFeatures:(NSArray<__kindof CIFeature *> *)features
                                                                 withImageSize:(CGSize)imageSize
                                                              imageOrientation:
                                                                  (CGImagePropertyOrientation)imageOrientation;

@end
