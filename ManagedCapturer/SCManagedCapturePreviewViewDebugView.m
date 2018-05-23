//
//  SCManagedCapturePreviewViewDebugView.m
//  Snapchat
//
//  Created by Jiyang Zhu on 1/19/18.
//  Copyright © 2018 Snapchat, Inc. All rights reserved.
//

#import "SCManagedCapturePreviewViewDebugView.h"

#import "SCManagedCapturer.h"
#import "SCManagedCapturerListener.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/UIFont+AvenirNext.h>

@import CoreText;

static CGFloat const kSCManagedCapturePreviewViewDebugViewCrossHairLineWidth = 1.0;
static CGFloat const kSCManagedCapturePreviewViewDebugViewCrossHairWidth = 20.0;

@interface SCManagedCapturePreviewViewDebugView () <SCManagedCapturerListener>

@property (assign, nonatomic) CGPoint focusPoint;
@property (assign, nonatomic) CGPoint exposurePoint;
@property (strong, nonatomic) NSDictionary<NSNumber *, NSValue *> *faceBoundsByFaceID;

@end

@implementation SCManagedCapturePreviewViewDebugView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        _focusPoint = [self _convertPointOfInterest:CGPointMake(0.5, 0.5)];
        _exposurePoint = [self _convertPointOfInterest:CGPointMake(0.5, 0.5)];
        [[SCManagedCapturer sharedInstance] addListener:self];
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();

    if (self.focusPoint.x > 0 || self.focusPoint.y > 0) {
        [self _drawCrossHairAtPoint:self.focusPoint inContext:context withColor:[UIColor greenColor] isXShaped:YES];
    }

    if (self.exposurePoint.x > 0 || self.exposurePoint.y > 0) {
        [self _drawCrossHairAtPoint:self.exposurePoint inContext:context withColor:[UIColor yellowColor] isXShaped:NO];
    }

    if (self.faceBoundsByFaceID.count > 0) {
        [self.faceBoundsByFaceID
            enumerateKeysAndObjectsUsingBlock:^(NSNumber *_Nonnull key, NSValue *_Nonnull obj, BOOL *_Nonnull stop) {
                CGRect faceRect = [obj CGRectValue];
                NSInteger faceID = [key integerValue];
                [self _drawRectangle:faceRect
                                text:[NSString sc_stringWithFormat:@"ID: %@", key]
                           inContext:context
                           withColor:[UIColor colorWithRed:((faceID % 3) == 0)
                                                     green:((faceID % 3) == 1)
                                                      blue:((faceID % 3) == 2)
                                                     alpha:1.0]];
            }];
    }
}

- (void)dealloc
{
    [[SCManagedCapturer sharedInstance] removeListener:self];
}

/**
 Draw a crosshair with center point, context, color and shape.

 @param isXShaped "X" or "+"
 */
- (void)_drawCrossHairAtPoint:(CGPoint)center
                    inContext:(CGContextRef)context
                    withColor:(UIColor *)color
                    isXShaped:(BOOL)isXShaped
{
    CGFloat width = kSCManagedCapturePreviewViewDebugViewCrossHairWidth;

    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, kSCManagedCapturePreviewViewDebugViewCrossHairLineWidth);
    CGContextBeginPath(context);

    if (isXShaped) {
        CGContextMoveToPoint(context, center.x - width / 2, center.y - width / 2);
        CGContextAddLineToPoint(context, center.x + width / 2, center.y + width / 2);
        CGContextMoveToPoint(context, center.x + width / 2, center.y - width / 2);
        CGContextAddLineToPoint(context, center.x - width / 2, center.y + width / 2);
    } else {
        CGContextMoveToPoint(context, center.x - width / 2, center.y);
        CGContextAddLineToPoint(context, center.x + width / 2, center.y);
        CGContextMoveToPoint(context, center.x, center.y - width / 2);
        CGContextAddLineToPoint(context, center.x, center.y + width / 2);
    }

    CGContextStrokePath(context);
}

/**
 Draw a rectangle, with a text on the top left.
 */
- (void)_drawRectangle:(CGRect)rect text:(NSString *)text inContext:(CGContextRef)context withColor:(UIColor *)color
{
    CGContextSetStrokeColorWithColor(context, color.CGColor);
    CGContextSetLineWidth(context, kSCManagedCapturePreviewViewDebugViewCrossHairLineWidth);
    CGContextBeginPath(context);

    CGContextMoveToPoint(context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextAddLineToPoint(context, CGRectGetMinX(rect), CGRectGetMaxY(rect));
    CGContextAddLineToPoint(context, CGRectGetMaxX(rect), CGRectGetMaxY(rect));
    CGContextAddLineToPoint(context, CGRectGetMaxX(rect), CGRectGetMinY(rect));
    CGContextAddLineToPoint(context, CGRectGetMinX(rect), CGRectGetMinY(rect));

    NSMutableParagraphStyle *textStyle = [[NSMutableParagraphStyle alloc] init];
    textStyle.alignment = NSTextAlignmentLeft;
    NSDictionary *attributes = @{
        NSFontAttributeName : [UIFont boldSystemFontOfSize:16],
        NSForegroundColorAttributeName : color,
        NSParagraphStyleAttributeName : textStyle
    };

    [text drawInRect:rect withAttributes:attributes];

    CGContextStrokePath(context);
}

- (CGPoint)_convertPointOfInterest:(CGPoint)point
{
    SCAssertMainThread();
    CGPoint convertedPoint =
        CGPointMake((1 - point.y) * CGRectGetWidth(self.bounds), point.x * CGRectGetHeight(self.bounds));
    if ([[SCManagedCapturer sharedInstance] isVideoMirrored]) {
        convertedPoint.x = CGRectGetWidth(self.bounds) - convertedPoint.x;
    }
    return convertedPoint;
}

- (NSDictionary<NSNumber *, NSValue *> *)_convertFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    SCAssertMainThread();
    NSMutableDictionary<NSNumber *, NSValue *> *convertedFaceBoundsByFaceID =
        [NSMutableDictionary dictionaryWithCapacity:faceBoundsByFaceID.count];
    for (NSNumber *key in faceBoundsByFaceID.allKeys) {
        CGRect faceBounds = [[faceBoundsByFaceID objectForKey:key] CGRectValue];
        CGRect convertedBounds = CGRectMake(CGRectGetMinY(faceBounds) * CGRectGetWidth(self.bounds),
                                            CGRectGetMinX(faceBounds) * CGRectGetHeight(self.bounds),
                                            CGRectGetHeight(faceBounds) * CGRectGetWidth(self.bounds),
                                            CGRectGetWidth(faceBounds) * CGRectGetHeight(self.bounds));
        if (![[SCManagedCapturer sharedInstance] isVideoMirrored]) {
            convertedBounds.origin.x = CGRectGetWidth(self.bounds) - CGRectGetMaxX(convertedBounds);
        }
        [convertedFaceBoundsByFaceID setObject:[NSValue valueWithCGRect:convertedBounds] forKey:key];
    }
    return convertedFaceBoundsByFaceID;
}

#pragma mark - SCManagedCapturerListener
- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeExposurePoint:(CGPoint)exposurePoint
{
    runOnMainThreadAsynchronouslyIfNecessary(^{
        self.exposurePoint = [self _convertPointOfInterest:exposurePoint];
        [self setNeedsDisplay];
    });
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeFocusPoint:(CGPoint)focusPoint
{
    runOnMainThreadAsynchronouslyIfNecessary(^{
        self.focusPoint = [self _convertPointOfInterest:focusPoint];
        [self setNeedsDisplay];
    });
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer
    didDetectFaceBounds:(NSDictionary<NSNumber *, NSValue *> *)faceBoundsByFaceID
{
    runOnMainThreadAsynchronouslyIfNecessary(^{
        self.faceBoundsByFaceID = [self _convertFaceBounds:faceBoundsByFaceID];
        [self setNeedsDisplay];
    });
}

- (void)managedCapturer:(id<SCCapturer>)managedCapturer didChangeCaptureDevicePosition:(SCManagedCapturerState *)state
{
    runOnMainThreadAsynchronouslyIfNecessary(^{
        self.faceBoundsByFaceID = nil;
        self.focusPoint = [self _convertPointOfInterest:CGPointMake(0.5, 0.5)];
        self.exposurePoint = [self _convertPointOfInterest:CGPointMake(0.5, 0.5)];
        [self setNeedsDisplay];
    });
}

@end
