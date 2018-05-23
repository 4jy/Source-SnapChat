//
//  SCFeatureShazam.h
//  SCCamera
//
//  Created by Xiaokang Liu on 2018/4/18.
//

#import "SCFeature.h"

@class SCLens;
@protocol SCFeatureShazam;

@protocol SCFeatureShazamDelegate <NSObject>
- (void)featureShazam:(id<SCFeatureShazam>)featureShazam didFinishWithResult:(NSObject *)result;
- (void)featureShazamDidSubmitSearchRequest:(id<SCFeatureShazam>)featureShazam;
- (SCLens *)filterLensForFeatureShazam:(id<SCFeatureShazam>)featureShazam;
@end

@protocol SCFeatureShazam <SCFeature>
@property (nonatomic, weak) id<SCFeatureShazamDelegate> delegate;
- (void)stopAudioRecordingAsynchronously;
- (void)resetInfo;
@end
