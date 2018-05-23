//
//  SCCaptureCommon.h
//  Snapchat
//
//  Created by Lin Jia on 9/29/17.
//
//

#import "SCManagedCaptureDevice.h"
#import "SCManagedDeviceCapacityAnalyzerListener.h"
#import "SCVideoCaptureSessionInfo.h"

#import <SCCameraFoundation/SCManagedVideoDataSourceListener.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@class SCManagedCapturerState;
@class SCManagedLensesProcessor;
@class SCManagedVideoDataSource;
@class SCManagedVideoCapturerOutputSettings;
@class SCLens;
@class SCLensCategory;
@class SCLookseryFilterFactory;
@class SCSnapScannedData;
@class SCCraftResourceManager;
@class SCScanConfiguration;
@class SCCapturerToken;
@class SCProcessingPipeline;
@class SCTimedTask;
@protocol SCManagedSampleBufferDisplayController;

typedef void (^sc_managed_capturer_capture_still_image_completion_handler_t)(UIImage *fullScreenImage,
                                                                             NSDictionary *metadata, NSError *error,
                                                                             SCManagedCapturerState *state);

typedef void (^sc_managed_capturer_capture_video_frame_completion_handler_t)(UIImage *image);

typedef void (^sc_managed_capturer_start_recording_completion_handler_t)(SCVideoCaptureSessionInfo session,
                                                                         NSError *error);

typedef void (^sc_managed_capturer_convert_view_coordniates_completion_handler_t)(CGPoint pointOfInterest);

typedef void (^sc_managed_capturer_unsafe_changes_t)(AVCaptureSession *session, AVCaptureDevice *front,
                                                     AVCaptureDeviceInput *frontInput, AVCaptureDevice *back,
                                                     AVCaptureDeviceInput *backInput, SCManagedCapturerState *state);

typedef void (^sc_managed_capturer_stop_running_completion_handler_t)(BOOL succeed);

typedef void (^sc_managed_capturer_scan_results_handler_t)(NSObject *resultObject);

typedef void (^sc_managed_lenses_processor_category_point_completion_handler_t)(SCLensCategory *category,
                                                                                NSInteger categoriesCount);
extern CGFloat const kSCManagedCapturerAspectRatioUnspecified;

extern CGFloat const kSCManagedCapturerDefaultVideoActiveFormatWidth;

extern CGFloat const kSCManagedCapturerDefaultVideoActiveFormatHeight;

extern CGFloat const kSCManagedCapturerVideoActiveFormatWidth1080p;

extern CGFloat const kSCManagedCapturerVideoActiveFormatHeight1080p;

extern CGFloat const kSCManagedCapturerNightVideoHighResActiveFormatWidth;

extern CGFloat const kSCManagedCapturerNightVideoHighResActiveFormatHeight;

extern CGFloat const kSCManagedCapturerNightVideoDefaultResActiveFormatWidth;

extern CGFloat const kSCManagedCapturerNightVideoDefaultResActiveFormatHeight;

extern CGFloat const kSCManagedCapturerLiveStreamingVideoActiveFormatWidth;

extern CGFloat const kSCManagedCapturerLiveStreamingVideoActiveFormatHeight;
