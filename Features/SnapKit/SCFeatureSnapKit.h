//
//  SCFeatureSnapKit.h
//  SCCamera
//
//  Created by Michel Loenngren on 3/19/18.
//

#import "SCFeature.h"

@class SCCameraDeepLinkMetadata;

@protocol SCFeatureSnapKit <SCFeature>
- (void)setDeepLinkMetadata:(SCCameraDeepLinkMetadata *)metadata;
@end
