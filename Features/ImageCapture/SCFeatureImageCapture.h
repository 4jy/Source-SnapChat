//
//  SCFeatureImageCapture.h
//  SCCamera
//
//  Created by Kristian Bauer on 4/18/18.
//

#import "SCFeature.h"

#import <SCFoundation/SCFuture.h>

@protocol SCFeatureImageCapture;

@protocol SCFeatureImageCaptureDelegate <NSObject>
- (void)featureImageCapture:(id<SCFeatureImageCapture>)featureImageCapture willCompleteWithImage:(UIImage *)image;
- (void)featureImageCapture:(id<SCFeatureImageCapture>)featureImageCapture didCompleteWithError:(NSError *)error;
- (void)featureImageCapturedDidComplete:(id<SCFeatureImageCapture>)featureImageCapture;
@end

/**
 SCFeature protocol for capturing an image.
 */
@protocol SCFeatureImageCapture <SCFeature>
@property (nonatomic, weak, readwrite) id<SCFeatureImageCaptureDelegate> delegate;
@property (nonatomic, strong, readonly) SCPromise<UIImage *> *imagePromise;
- (void)captureImage:(NSString *)captureSessionID;
@end
