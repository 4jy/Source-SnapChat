//
//  SCCapturerDefines.h
//  Snapchat
//
//  Created by Chao Pang on 12/20/17.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, SCCapturerLightingConditionType) {
    SCCapturerLightingConditionTypeNormal = 0,
    SCCapturerLightingConditionTypeDark,
    SCCapturerLightingConditionTypeExtremeDark,
};

typedef struct SampleBufferMetadata {
    int isoSpeedRating;
    float exposureTime;
    float brightness;
} SampleBufferMetadata;
