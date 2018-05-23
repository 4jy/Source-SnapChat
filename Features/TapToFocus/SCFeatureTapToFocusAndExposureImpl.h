//
//  SCFeatureTapToFocusAndExposureImpl.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/5/18.
//

#import "SCFeatureTapToFocusAndExposure.h"

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>

@protocol SCCapturer;

/**
 Protocol describing unique camera commands to run when the user taps on screen. These could be focus, exposure or tap
 to portrait mode.
 */
@protocol SCFeatureCameraTapCommand <NSObject>
- (void)execute:(CGPoint)pointOfInterest capturer:(id<SCCapturer>)capturer;
@end

/**
 This is the default implementation of SCFeatureTapToFocusAndExposure allowing the user to tap on the camera overlay
 view in order to adjust focus and exposure.
 */
@interface SCFeatureTapToFocusAndExposureImpl : NSObject <SCFeatureTapToFocusAndExposure>
SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithCapturer:(id<SCCapturer>)capturer commands:(NSArray<id<SCFeatureCameraTapCommand>> *)commands;
@end

/**
 Adjust focus on tap.
 */
@interface SCFeatureCameraFocusTapCommand : NSObject <SCFeatureCameraTapCommand>
@end

/**
 Adjust exposure on tap.
 */
@interface SCFeatureCameraExposureTapCommand : NSObject <SCFeatureCameraTapCommand>
@end

/**
 Adjust portrait mode point of interest on tap.
 */
@interface SCFeatureCameraPortraitTapCommand : NSObject <SCFeatureCameraTapCommand>
@end
