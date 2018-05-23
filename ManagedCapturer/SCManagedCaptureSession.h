//
//  SCManagedCaptureSession.h
//  Snapchat
//
//  Created by Derek Wang on 02/03/2018.
//

#import <SCBase/SCMacros.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

/**
 `SCManagedCaptureSession` is a wrapper class of `AVCaptureSession`. The purpose of this class is to provide additional
 functionalities to `AVCaptureSession`.
 For example, for black camera detection, we need to monitor when some method is called. Another example is that we can
 treat it as a more stable version of `AVCaptureSession` by moving some `AVCaptureSession` fixing logic to this class,
 and it provides reliable interfaces to the outside. That would be the next step.
 It also tries to mimic the `AVCaptureSession` by implmenting some methods in `AVCaptureSession`. The original methods
 in `AVCaptureSession` should not be used anymore
 */

@class SCBlackCameraDetector;

NS_ASSUME_NONNULL_BEGIN
@interface SCManagedCaptureSession : NSObject

/**
 Expose avSession property
 */
@property (nonatomic, strong, readonly) AVCaptureSession *avSession;

/**
 Expose avSession isRunning property for convenience.
 */
@property (nonatomic, readonly, assign) BOOL isRunning;

/**
 Wrap [AVCaptureSession startRunning] method. Monitor startRunning method. [AVCaptureSession startRunning] should not be
 called
 */
- (void)startRunning;
/**
 Wrap [AVCaptureSession stopRunning] method. Monitor stopRunning method. [AVCaptureSession stopRunning] should not be
 called
 */
- (void)stopRunning;

/**
 Wrap [AVCaptureSession beginConfiguration]. Monitor beginConfiguration method
 */
- (void)beginConfiguration;
/**
 Wrap [AVCaptureSession commitConfiguration]. Monitor commitConfiguration method
 */
- (void)commitConfiguration;
/**
 Configurate internal AVCaptureSession with block
 @params block. configuration block with AVCaptureSession as parameter
 */
- (void)performConfiguration:(void (^)(void))block;

- (instancetype)initWithBlackCameraDetector:(SCBlackCameraDetector *)detector NS_DESIGNATED_INITIALIZER;
SC_INIT_AND_NEW_UNAVAILABLE

@end
NS_ASSUME_NONNULL_END
