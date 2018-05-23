//
//  SCRecordingMetadata.h
//  Snapchat
//

#import <SCBase/SCMacros.h>

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCManagedCapturerSampleMetadata : NSObject

SC_INIT_AND_NEW_UNAVAILABLE

- (instancetype)initWithPresentationTimestamp:(CMTime)presentationTimestamp
                                  fieldOfView:(float)fieldOfView NS_DESIGNATED_INITIALIZER;

@property (nonatomic, readonly) CMTime presentationTimestamp;

@property (nonatomic, readonly) float fieldOfView;

@end

NS_ASSUME_NONNULL_END
