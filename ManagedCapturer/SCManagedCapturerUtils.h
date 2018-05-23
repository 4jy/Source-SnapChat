//
//  SCManagedCapturerUtils.h
//  Snapchat
//
//  Created by Chao Pang on 10/4/17.
//

#import <SCBase/SCMacros.h>

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

SC_EXTERN_C_BEGIN

extern const CGFloat kSCIPhoneXCapturedImageVideoCropRatio;

extern CGFloat SCManagedCapturedImageAndVideoAspectRatio(void);

extern CGSize SCManagedCapturerAllScreenSize(void);

extern CGSize SCAsyncImageCapturePlaceholderViewSize(void);

extern CGFloat SCAdjustedAspectRatio(UIImageOrientation orientation, CGFloat aspectRatio);

extern UIImage *SCCropImageToTargetAspectRatio(UIImage *image, CGFloat targetAspectRatio);

extern void SCCropImageSizeToAspectRatio(size_t inputWidth, size_t inputHeight, UIImageOrientation orientation,
                                         CGFloat aspectRatio, size_t *outputWidth, size_t *outputHeight);

extern BOOL SCNeedsCropImageToAspectRatio(CGImageRef image, UIImageOrientation orientation, CGFloat aspectRatio);

extern CGRect SCCalculateRectToCrop(size_t imageWidth, size_t imageHeight, size_t croppedWidth, size_t croppedHeight);

extern CGImageRef SCCreateCroppedImageToAspectRatio(CGImageRef image, UIImageOrientation orientation,
                                                    CGFloat aspectRatio);
SC_EXTERN_C_END
