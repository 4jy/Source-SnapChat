//
//  SCCameraSettingUtils.m
//  Snapchat
//
//  Created by Pinlin Chen on 12/09/2017.
//

#import "SCCameraSettingUtils.h"

#import <SCFoundation/SCLog.h>

#import <ImageIO/CGImageProperties.h>

NSNumber *retrieveExposureTimeFromEXIFAttachments(CFDictionaryRef exifAttachments)
{
    if (!exifAttachments) {
        return nil;
    }
    id value = CFDictionaryGetValue(exifAttachments, kCGImagePropertyExifExposureTime);
    // Fetching exposure time from the sample buffer
    if ([value isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)value;
    }
    return nil;
}

NSNumber *retrieveBrightnessFromEXIFAttachments(CFDictionaryRef exifAttachments)
{
    if (!exifAttachments) {
        return nil;
    }
    id value = CFDictionaryGetValue(exifAttachments, kCGImagePropertyExifBrightnessValue);
    if ([value isKindOfClass:[NSNumber class]]) {
        return (NSNumber *)value;
    }
    return nil;
}

NSNumber *retrieveISOSpeedRatingFromEXIFAttachments(CFDictionaryRef exifAttachments)
{
    if (!exifAttachments) {
        return nil;
    }
    NSArray *ISOSpeedRatings = CFDictionaryGetValue(exifAttachments, kCGImagePropertyExifISOSpeedRatings);
    if ([ISOSpeedRatings respondsToSelector:@selector(count)] &&
        [ISOSpeedRatings respondsToSelector:@selector(firstObject)] && ISOSpeedRatings.count > 0) {
        id value = [ISOSpeedRatings firstObject];
        if ([value isKindOfClass:[NSNumber class]]) {
            return (NSNumber *)value;
        }
    }
    return nil;
}

void retrieveSampleBufferMetadata(CMSampleBufferRef sampleBuffer, SampleBufferMetadata *metadata)
{
    CFDictionaryRef exifAttachments = CMGetAttachment(sampleBuffer, kCGImagePropertyExifDictionary, NULL);
    if (exifAttachments == nil) {
        SCLogCoreCameraWarning(@"SampleBuffer exifAttachment is nil");
    }
    // Fetching exposure time from the sample buffer
    NSNumber *currentExposureTimeNum = retrieveExposureTimeFromEXIFAttachments(exifAttachments);
    if (currentExposureTimeNum) {
        metadata->exposureTime = [currentExposureTimeNum floatValue];
    }
    NSNumber *currentISOSpeedRatingNum = retrieveISOSpeedRatingFromEXIFAttachments(exifAttachments);
    if (currentISOSpeedRatingNum) {
        metadata->isoSpeedRating = (int)[currentISOSpeedRatingNum integerValue];
    }
    NSNumber *currentBrightnessNum = retrieveBrightnessFromEXIFAttachments(exifAttachments);
    if (currentBrightnessNum) {
        float currentBrightness = [currentBrightnessNum floatValue];
        if (isfinite(currentBrightness)) {
            metadata->brightness = currentBrightness;
        } else {
            metadata->brightness = 0;
        }
    }
}
