//
//  SCManagedCaptureFaceDetectionAdjustingPOIResource.m
//  Snapchat
//
//  Created by Jiyang Zhu on 3/7/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCaptureFaceDetectionAdjustingPOIResource.h"

#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@implementation SCManagedCaptureFaceDetectionAdjustingPOIResource {
    CGPoint _defaultPointOfInterest;
}

#pragma mark - Public Methods

- (instancetype)initWithDefaultPointOfInterest:(CGPoint)pointOfInterest
               shouldTargetOnFaceAutomatically:(BOOL)shouldTargetOnFaceAutomatically
{
    if (self = [super init]) {
        _pointOfInterest = pointOfInterest;
        _defaultPointOfInterest = pointOfInterest;
        _shouldTargetOnFaceAutomatically = shouldTargetOnFaceAutomatically;
    }
    return self;
}

- (void)reset
{
    SCTraceODPCompatibleStart(2);
    self.adjustingPOIMode = SCManagedCaptureFaceDetectionAdjustingPOIModeNone;
    self.targetingFaceID = nil;
    self.targetingFaceBounds = CGRectZero;
    self.faceBoundsByFaceID = nil;
    self.pointOfInterest = _defaultPointOfInterest;
}

- (CGPoint)updateWithNewProposedPointOfInterest:(CGPoint)proposedPoint fromUser:(BOOL)fromUser
{
    SCTraceODPCompatibleStart(2);
    if (fromUser) {
        NSNumber *faceID =
            [self _getFaceIDOfFaceBoundsContainingPoint:proposedPoint fromFaceBounds:self.faceBoundsByFaceID];
        if (faceID && [faceID integerValue] >= 0) {
            CGPoint point = [self _getPointOfInterestWithFaceID:faceID fromFaceBounds:self.faceBoundsByFaceID];
            if ([self _isPointOfInterestValid:point]) {
                [self _setPointOfInterest:point
                          targetingFaceID:faceID
                         adjustingPOIMode:SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithFace];
            } else {
                [self _setPointOfInterest:proposedPoint
                          targetingFaceID:nil
                         adjustingPOIMode:SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithoutFace];
            }
        } else {
            [self _setPointOfInterest:proposedPoint
                      targetingFaceID:nil
                     adjustingPOIMode:SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithoutFace];
        }
    } else {
        [self _setPointOfInterest:proposedPoint
                  targetingFaceID:nil
                 adjustingPOIMode:SCManagedCaptureFaceDetectionAdjustingPOIModeNone];
    }
    return self.pointOfInterest;
}

- (CGPoint)updateWithNewDetectedFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCTraceODPCompatibleStart(2);
    self.faceBoundsByFaceID = faceBoundsByFaceID;
    switch (self.adjustingPOIMode) {
    case SCManagedCaptureFaceDetectionAdjustingPOIModeNone: {
        if (self.shouldTargetOnFaceAutomatically) {
            [self _focusOnPreferredFaceInFaceBounds:self.faceBoundsByFaceID];
        }
    } break;
    case SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithFace: {
        BOOL isFocusingOnCurrentTargetingFaceSuccess =
            [self _focusOnFaceWithTargetFaceID:self.targetingFaceID inFaceBounds:self.faceBoundsByFaceID];
        if (!isFocusingOnCurrentTargetingFaceSuccess && self.shouldTargetOnFaceAutomatically) {
            // If the targeted face has disappeared, and shouldTargetOnFaceAutomatically is YES, automatically target on
            // the next preferred face.
            [self _focusOnPreferredFaceInFaceBounds:self.faceBoundsByFaceID];
        }
    } break;
    case SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithoutFace:
        // The point of interest should be fixed at a non-face point where user tapped before.
        break;
    }
    return self.pointOfInterest;
}

#pragma mark - Internal Methods

- (BOOL)_focusOnPreferredFaceInFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCTraceODPCompatibleStart(2);
    NSNumber *preferredFaceID = [self _getPreferredFaceIDFromFaceBounds:faceBoundsByFaceID];
    return [self _focusOnFaceWithTargetFaceID:preferredFaceID inFaceBounds:faceBoundsByFaceID];
}

- (BOOL)_focusOnFaceWithTargetFaceID:(NSNumber *)preferredFaceID
                        inFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN_VALUE(preferredFaceID, NO);
    NSValue *faceBoundsValue = [faceBoundsByFaceID objectForKey:preferredFaceID];
    if (faceBoundsValue) {
        CGRect faceBounds = [faceBoundsValue CGRectValue];
        CGPoint proposedPoint = CGPointMake(CGRectGetMidX(faceBounds), CGRectGetMidY(faceBounds));
        if ([self _isPointOfInterestValid:proposedPoint]) {
            if ([self _shouldChangeToNewPoint:proposedPoint withNewFaceID:preferredFaceID newFaceBounds:faceBounds]) {
                [self _setPointOfInterest:proposedPoint
                          targetingFaceID:preferredFaceID
                         adjustingPOIMode:SCManagedCaptureFaceDetectionAdjustingPOIModeFixedOnPointWithFace];
            }
            return YES;
        }
    }
    [self reset];
    return NO;
}

- (void)_setPointOfInterest:(CGPoint)pointOfInterest
            targetingFaceID:(NSNumber *)targetingFaceID
           adjustingPOIMode:(SCManagedCaptureFaceDetectionAdjustingPOIMode)adjustingPOIMode
{
    SCTraceODPCompatibleStart(2);
    self.pointOfInterest = pointOfInterest;
    self.targetingFaceID = targetingFaceID;
    if (targetingFaceID) { // If targetingFaceID exists, record the current face bounds.
        self.targetingFaceBounds = [[self.faceBoundsByFaceID objectForKey:targetingFaceID] CGRectValue];
    } else { // Otherwise, reset targetingFaceBounds to zero.
        self.targetingFaceBounds = CGRectZero;
    }
    self.adjustingPOIMode = adjustingPOIMode;
}

- (BOOL)_isPointOfInterestValid:(CGPoint)pointOfInterest
{
    return (pointOfInterest.x >= 0 && pointOfInterest.x <= 1 && pointOfInterest.y >= 0 && pointOfInterest.y <= 1);
}

- (NSNumber *)_getPreferredFaceIDFromFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCTraceODPCompatibleStart(2);
    SC_GUARD_ELSE_RETURN_VALUE(faceBoundsByFaceID.count > 0, nil);

    // Find out the bounds with the max area.
    __block NSNumber *preferredFaceID = nil;
    __block CGFloat maxArea = 0;
    [faceBoundsByFaceID
        enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull key, NSValue *_Nonnull obj, BOOL *_Nonnull stop) {
            CGRect faceBounds = [obj CGRectValue];
            CGFloat area = CGRectGetWidth(faceBounds) * CGRectGetHeight(faceBounds);
            if (area > maxArea) {
                preferredFaceID = key;
                maxArea = area;
            }
        }];

    return preferredFaceID;
}

- (CGPoint)_getPointOfInterestWithFaceID:(NSNumber *)faceID
                          fromFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCTraceODPCompatibleStart(2);
    NSValue *faceBoundsValue = [faceBoundsByFaceID objectForKey:faceID];
    if (faceBoundsValue) {
        CGRect faceBounds = [faceBoundsValue CGRectValue];
        CGPoint point = CGPointMake(CGRectGetMidX(faceBounds), CGRectGetMidY(faceBounds));
        return point;
    } else {
        return CGPointMake(-1, -1); // An invalid point.
    }
}

/**
 Setting a new focus/exposure point needs high CPU usage, so we only set a new POI when we have to. This method is to
 return whether setting this new point if necessary.
 If not, there is no need to change the POI.
 */
- (BOOL)_shouldChangeToNewPoint:(CGPoint)newPoint
                  withNewFaceID:(NSNumber *)newFaceID
                  newFaceBounds:(CGRect)newFaceBounds
{
    SCTraceODPCompatibleStart(2);
    BOOL shouldChange = NO;
    if (!newFaceID || !self.targetingFaceID ||
        ![newFaceID isEqualToNumber:self.targetingFaceID]) { // Return YES if it is a new face.
        shouldChange = YES;
    } else if (CGRectEqualToRect(self.targetingFaceBounds, CGRectZero) ||
               !CGRectContainsPoint(self.targetingFaceBounds,
                                    newPoint)) { // Return YES if the new point if out of the current face bounds.
        shouldChange = YES;
    } else {
        CGFloat currentBoundsArea =
            CGRectGetWidth(self.targetingFaceBounds) * CGRectGetHeight(self.targetingFaceBounds);
        CGFloat newBoundsArea = CGRectGetWidth(newFaceBounds) * CGRectGetHeight(newFaceBounds);
        if (newBoundsArea >= currentBoundsArea * 1.2 ||
            newBoundsArea <=
                currentBoundsArea *
                    0.8) { // Return YES if the area of new bounds if over 20% more or 20% less than the current one.
            shouldChange = YES;
        }
    }
    return shouldChange;
}

- (NSNumber *)_getFaceIDOfFaceBoundsContainingPoint:(CGPoint)point
                                     fromFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SC_GUARD_ELSE_RETURN_VALUE(faceBoundsByFaceID.count > 0, nil);
    __block NSNumber *faceID = nil;
    [faceBoundsByFaceID
        enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull key, NSValue *_Nonnull obj, BOOL *_Nonnull stop) {
            CGRect faceBounds = [obj CGRectValue];
            if (CGRectContainsPoint(faceBounds, point)) {
                faceID = key;
                *stop = YES;
            }
        }];
    return faceID;
}

@end
