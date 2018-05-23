//
//  SCRecordingMetadata.m
//  Snapchat
//

#import "SCManagedCapturerSampleMetadata.h"

NS_ASSUME_NONNULL_BEGIN

@implementation SCManagedCapturerSampleMetadata

- (instancetype)initWithPresentationTimestamp:(CMTime)presentationTimestamp fieldOfView:(float)fieldOfView
{
    self = [super init];
    if (self) {
        _presentationTimestamp = presentationTimestamp;
        _fieldOfView = fieldOfView;
    }
    return self;
}

@end

NS_ASSUME_NONNULL_END
