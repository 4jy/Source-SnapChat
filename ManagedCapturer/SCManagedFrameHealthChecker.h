//
//  SCManagedFrameHealthChecker.h
//  Snapchat
//
//  Created by Pinlin Chen on 30/08/2017.
//

#import <SCBase/SCMacros.h>
#import <SCFeatureGating/SCExperimentManager.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@interface SCManagedFrameHealthChecker : NSObject

+ (SCManagedFrameHealthChecker *)sharedInstance;
/*! @abstract Use sharedInstance instead. */
SC_INIT_AND_NEW_UNAVAILABLE;

/* Utility method */
- (NSMutableDictionary *)metadataForSampleBuffer:(CMSampleBufferRef)sampleBuffer extraInfo:(NSDictionary *)extraInfo;
- (NSMutableDictionary *)metadataForSampleBuffer:(CMSampleBufferRef)sampleBuffer
                            photoCapturerEnabled:(BOOL)photoCapturerEnabled
                                     lensEnabled:(BOOL)lensesEnabled
                                          lensID:(NSString *)lensID;
- (NSMutableDictionary *)metadataForMetadata:(NSDictionary *)metadata
                        photoCapturerEnabled:(BOOL)photoCapturerEnabled
                                 lensEnabled:(BOOL)lensesEnabled
                                      lensID:(NSString *)lensID;
- (NSMutableDictionary *)getPropertiesFromAsset:(AVAsset *)asset;

/* Image snap */
- (void)checkImageHealthForCaptureFrameImage:(UIImage *)image
                             captureSettings:(NSDictionary *)captureSettings
                            captureSessionID:(NSString *)captureSessionID;
- (void)checkImageHealthForPreTranscoding:(UIImage *)image
                                 metadata:(NSDictionary *)metadata
                         captureSessionID:(NSString *)captureSessionID;
- (void)checkImageHealthForPostTranscoding:(NSData *)imageData
                                  metadata:(NSDictionary *)metadata
                          captureSessionID:(NSString *)captureSessionID;

/* Video snap */
- (void)checkVideoHealthForCaptureFrameImage:(UIImage *)image
                                    metedata:(NSDictionary *)metadata
                            captureSessionID:(NSString *)captureSessionID;
- (void)checkVideoHealthForOverlayImage:(UIImage *)image
                               metedata:(NSDictionary *)metadata
                       captureSessionID:(NSString *)captureSessionID;
- (void)checkVideoHealthForPostTranscodingThumbnail:(UIImage *)image
                                           metedata:(NSDictionary *)metadata
                                         properties:(NSDictionary *)properties
                                   captureSessionID:(NSString *)captureSessionID;

- (void)reportFrameHealthCheckForCaptureSessionID:(NSString *)captureSessionID;

@end
