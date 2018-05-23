//
//  SCFeatureImageCaptureImpl.h
//  SCCamera
//
//  Created by Kristian Bauer on 4/18/18.
//

#import "AVCameraViewEnums.h"
#import "SCFeatureImageCapture.h"

#import <SCBase/SCMacros.h>

@protocol SCCapturer;
@class SCLogger;

@interface SCFeatureImageCaptureImpl : NSObject <SCFeatureImageCapture>
SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithCapturer:(id<SCCapturer>)capturer
                          logger:(SCLogger *)logger
                  cameraViewType:(AVCameraViewType)cameraViewType NS_DESIGNATED_INITIALIZER;
@end
