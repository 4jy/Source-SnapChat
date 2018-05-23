//
//  SCFeatureTapToFocusAndExposure.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/5/18.
//

#import "SCFeature.h"

/**
 This SCFeature allows the user to tap on the screen to adjust focus and exposure.
 */
@protocol SCFeatureTapToFocusAndExposure <SCFeature>

- (void)reset;

@end
