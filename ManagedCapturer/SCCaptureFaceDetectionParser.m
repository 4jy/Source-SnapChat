//
//  SCCaptureFaceDetectionParser.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/13/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCCaptureFaceDetectionParser.h"

#import <SCFoundation/NSArray+Helpers.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@implementation SCCaptureFaceDetectionParser {
    CGFloat _minimumArea;
}

- (instancetype)initWithFaceBoundsAreaThreshold:(CGFloat)minimumArea
{
    self = [super init];
    if (self) {
        _minimumArea = minimumArea;
    }
    return self;
}

- (NSDictionary<NSNumber *, NSValue *> *)parseFaceBoundsByFaceIDFromMetadataObjects:
    (NSArray<__kindof AVMetadataObject *> *)metadataObjects
{
    SCTraceODPCompatibleStart(2);
    NSMutableArray *faceObjects = [NSMutableArray array];
    [metadataObjects
        enumerateObjectsUsingBlock:^(__kindof AVMetadataObject *_Nonnull obj, NSUInteger idx, BOOL *_Nonnull stop) {
            if ([obj isKindOfClass:[AVMetadataFaceObject class]]) {
                [faceObjects addObject:obj];
            }
        }];

    SC_GUARD_ELSE_RETURN_VALUE(faceObjects.count > 0, nil);

    NSMutableDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID =
        [NSMutableDictionary dictionaryWithCapacity:faceObjects.count];
    for (AVMetadataFaceObject *faceObject in faceObjects) {
        CGRect bounds = faceObject.bounds;
        if (CGRectGetWidth(bounds) * CGRectGetHeight(bounds) >= _minimumArea) {
            [faceBoundsByFaceID setObject:[NSValue valueWithCGRect:bounds] forKey:@(faceObject.faceID)];
        }
    }
    return faceBoundsByFaceID;
}

- (NSDictionary<NSNumber *, NSValue *> *)parseFaceBoundsByFaceIDFromCIFeatures:(NSArray<__kindof CIFeature *> *)features
                                                                 withImageSize:(CGSize)imageSize
                                                              imageOrientation:
                                                                  (CGImagePropertyOrientation)imageOrientation
{
    SCTraceODPCompatibleStart(2);
    NSArray<CIFaceFeature *> *faceFeatures = [features filteredArrayUsingBlock:^BOOL(id _Nonnull evaluatedObject) {
        return [evaluatedObject isKindOfClass:[CIFaceFeature class]];
    }];

    SC_GUARD_ELSE_RETURN_VALUE(faceFeatures.count > 0, nil);

    NSMutableDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID =
        [NSMutableDictionary dictionaryWithCapacity:faceFeatures.count];
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    SCLogGeneralInfo(@"Face feature count:%d", faceFeatures.count);
    for (CIFaceFeature *faceFeature in faceFeatures) {
        SCLogGeneralInfo(@"Face feature: hasTrackingID:%d, bounds:%@", faceFeature.hasTrackingID,
                         NSStringFromCGRect(faceFeature.bounds));
        if (faceFeature.hasTrackingID) {
            CGRect transferredBounds;
            // Somehow the detected bounds for back camera is mirrored.
            if (imageOrientation == kCGImagePropertyOrientationRight) {
                transferredBounds = CGRectMake(
                    CGRectGetMinX(faceFeature.bounds) / width, 1 - CGRectGetMaxY(faceFeature.bounds) / height,
                    CGRectGetWidth(faceFeature.bounds) / width, CGRectGetHeight(faceFeature.bounds) / height);
            } else {
                transferredBounds = CGRectMake(
                    CGRectGetMinX(faceFeature.bounds) / width, CGRectGetMinY(faceFeature.bounds) / height,
                    CGRectGetWidth(faceFeature.bounds) / width, CGRectGetHeight(faceFeature.bounds) / height);
            }
            if (CGRectGetWidth(transferredBounds) * CGRectGetHeight(transferredBounds) >= _minimumArea) {
                [faceBoundsByFaceID setObject:[NSValue valueWithCGRect:transferredBounds]
                                       forKey:@(faceFeature.trackingID)];
            }
        }
    }
    return faceBoundsByFaceID;
}

@end
