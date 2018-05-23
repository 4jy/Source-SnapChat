//
//  SCManagedCaptureFaceDetectionAdjustingPOIResource.h
//  Snapchat
//
//  Created by Jiyang Zhu on 3/7/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//
//  This class is used to keep several properties for face detection and focus/exposure. It provides methods to help
//  FaceDetectionAutoFocusHandler and FaceDetectionAutoExposureHandler to deal with the point of interest setting events
//  from user taps, subject area changes, and face detection, by updating itself and return the actual point of
//  interest.

#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SCManagedCaptureFaceDetectionAdjustingPOIMode) {
    SCManagedCaptureFaceDetectionAdjustingPOIModeNone = 0,
    SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithFace,
    SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithoutFace,
};

@interface SCManagedCaptureFaceDetectionAdjustingPOIResource : NSObject

@property (nonatomic, assign) CGPoint pointOfInterest;

@property (nonatomic, strong) NSDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID;
@property (nonatomic, assign) SCManagedCaptureFaceDetectionAdjustingPOIMode adjustingPOIMode;
@property (nonatomic, assign) BOOL shouldTargetOnFaceAutomatically;
@property (nonatomic, strong) NSNumber *targetingFaceID;
@property (nonatomic, assign) CGRect targetingFaceBounds;

- (instancetype)initWithDefaultPointOfInterest:(CGPoint)pointOfInterest
               shouldTargetOnFaceAutomatically:(BOOL)shouldTargetOnFaceAutomatically;

- (void)reset;

/**
 Update SCManagedCaptureFaceDetectionAdjustingPOIResource when a new POI adjustment comes. It will find the face that
 the proposedPoint belongs to, return the center of the face, if the adjustingPOIMode and fromUser meets the
 requirements.

 @param proposedPoint
 The point of interest that upper level wants to set.
 @param fromUser
 Whether the setting is from user's tap or not.
 @return
 The actual point of interest that should be applied.
 */
- (CGPoint)updateWithNewProposedPointOfInterest:(CGPoint)proposedPoint fromUser:(BOOL)fromUser;

/**
 Update SCManagedCaptureFaceDetectionAdjustingPOIResource when new detected face bounds comes.

 @param faceBoundsByFaceID
 A dictionary. Key: FaceID as NSNumber. Value: FaceBounds as CGRect.
 @return
 The actual point of interest that should be applied.
 */
- (CGPoint)updateWithNewDetectedFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID;

@end
