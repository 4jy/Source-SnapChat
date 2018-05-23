//
//  SCManagedCaptureDeviceDefaultZoomHandler_Private.h
//  Snapchat
//
//  Created by Joe Qiao on 04/01/2018.
//

#import "SCManagedCaptureDeviceDefaultZoomHandler.h"

@interface SCManagedCaptureDeviceDefaultZoomHandler ()

@property (nonatomic, weak) SCCaptureResource *captureResource;
@property (nonatomic, weak) SCManagedCaptureDevice *currentDevice;

- (void)_setZoomFactor:(CGFloat)zoomFactor forManagedCaptureDevice:(SCManagedCaptureDevice *)device;

@end
