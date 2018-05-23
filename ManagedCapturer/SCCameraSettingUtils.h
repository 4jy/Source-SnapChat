//
//  SCCameraSettingUtils.h
//  Snapchat
//
//  Created by Pinlin Chen on 12/09/2017.
//

#import <SCBase/SCMacros.h>

#import <SCCapturerDefines.h>

#import <CoreMedia/CoreMedia.h>
#import <Foundation/Foundation.h>

SC_EXTERN_C_BEGIN

// Return the value if metadata attribute is found; otherwise, return nil
extern NSNumber *retrieveExposureTimeFromEXIFAttachments(CFDictionaryRef exifAttachments);
extern NSNumber *retrieveBrightnessFromEXIFAttachments(CFDictionaryRef exifAttachments);
extern NSNumber *retrieveISOSpeedRatingFromEXIFAttachments(CFDictionaryRef exifAttachments);
extern void retrieveSampleBufferMetadata(CMSampleBufferRef sampleBuffer, SampleBufferMetadata *metadata);

SC_EXTERN_C_END
