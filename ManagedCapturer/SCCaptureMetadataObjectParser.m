//
//  SCCaptureMetadataObjectParser.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/13/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCCaptureMetadataObjectParser.h"

#import <SCBase/SCMacros.h>

@import UIKit;

@implementation SCCaptureMetadataObjectParser

- (NSDictionary<NSNumber *, NSValue *> *)parseFaceBoundsByFaceIDFromMetadataObjects:
    (NSArray<__kindof AVMetadataObject *> *)metadataObjects
{
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
        [faceBoundsByFaceID setObject:[NSValue valueWithCGRect:faceObject.bounds] forKey:@(faceObject.faceID)];
    }
    return faceBoundsByFaceID;
}

@end
