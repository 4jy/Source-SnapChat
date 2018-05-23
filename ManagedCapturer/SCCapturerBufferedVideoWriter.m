//
//  SCCapturerBufferedVideoWriter.m
//  Snapchat
//
//  Created by Chao Pang on 12/5/17.
//

#import "SCCapturerBufferedVideoWriter.h"

#import "SCAudioCaptureSession.h"
#import "SCCaptureCommon.h"
#import "SCManagedCapturerUtils.h"

#import <SCBase/SCMacros.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCDeviceName.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCTrace.h>

#import <FBKVOController/FBKVOController.h>

@implementation SCCapturerBufferedVideoWriter {
    SCQueuePerformer *_performer;
    __weak id<SCCapturerBufferedVideoWriterDelegate> _delegate;
    FBKVOController *_observeController;

    AVAssetWriter *_assetWriter;
    AVAssetWriterInput *_audioWriterInput;
    AVAssetWriterInput *_videoWriterInput;
    AVAssetWriterInputPixelBufferAdaptor *_pixelBufferAdaptor;
    CVPixelBufferPoolRef _defaultPixelBufferPool;
    CVPixelBufferPoolRef _nightPixelBufferPool;
    CVPixelBufferPoolRef _lensesPixelBufferPool;
    CMBufferQueueRef _videoBufferQueue;
    CMBufferQueueRef _audioBufferQueue;
}

- (instancetype)initWithPerformer:(id<SCPerforming>)performer
                        outputURL:(NSURL *)outputURL
                         delegate:(id<SCCapturerBufferedVideoWriterDelegate>)delegate
                            error:(NSError **)error
{
    self = [super init];
    if (self) {
        _performer = performer;
        _delegate = delegate;
        _observeController = [[FBKVOController alloc] initWithObserver:self];
        CMBufferQueueCreate(kCFAllocatorDefault, 0, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(),
                            &_videoBufferQueue);
        CMBufferQueueCreate(kCFAllocatorDefault, 0, CMBufferQueueGetCallbacksForUnsortedSampleBuffers(),
                            &_audioBufferQueue);
        _assetWriter = [[AVAssetWriter alloc] initWithURL:outputURL fileType:AVFileTypeMPEG4 error:error];
        if (*error) {
            self = nil;
            return self;
        }
    }
    return self;
}

- (BOOL)prepareWritingWithOutputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    SCAssert(outputSettings, @"empty output setting");
    // Audio
    SCTraceSignal(@"Derive audio output setting");
    NSDictionary *audioOutputSettings = @{
        AVFormatIDKey : @(kAudioFormatMPEG4AAC),
        AVNumberOfChannelsKey : @(1),
        AVSampleRateKey : @(kSCAudioCaptureSessionDefaultSampleRate),
        AVEncoderBitRateKey : @(outputSettings.audioBitRate)
    };
    _audioWriterInput =
        [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    _audioWriterInput.expectsMediaDataInRealTime = YES;

    // Video
    SCTraceSignal(@"Derive video output setting");
    size_t outputWidth = outputSettings.width;
    size_t outputHeight = outputSettings.height;
    SCAssert(outputWidth > 0 && outputHeight > 0 && (outputWidth % 2 == 0) && (outputHeight % 2 == 0),
             @"invalid output size");
    NSDictionary *videoCompressionSettings = @{
        AVVideoAverageBitRateKey : @(outputSettings.videoBitRate),
        AVVideoMaxKeyFrameIntervalKey : @(outputSettings.keyFrameInterval)
    };
    NSDictionary *videoOutputSettings = @{
        AVVideoCodecKey : AVVideoCodecH264,
        AVVideoWidthKey : @(outputWidth),
        AVVideoHeightKey : @(outputHeight),
        AVVideoScalingModeKey : AVVideoScalingModeResizeAspectFill,
        AVVideoCompressionPropertiesKey : videoCompressionSettings
    };
    _videoWriterInput =
        [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoOutputSettings];
    _videoWriterInput.expectsMediaDataInRealTime = YES;
    CGAffineTransform transform = CGAffineTransformMakeTranslation(outputHeight, 0);
    _videoWriterInput.transform = CGAffineTransformRotate(transform, M_PI_2);
    _pixelBufferAdaptor = [[AVAssetWriterInputPixelBufferAdaptor alloc]
           initWithAssetWriterInput:_videoWriterInput
        sourcePixelBufferAttributes:@{
            (NSString *)
            kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), (NSString *)
            kCVPixelBufferWidthKey : @(outputWidth), (NSString *)
            kCVPixelBufferHeightKey : @(outputHeight)
        }];

    SCTraceSignal(@"Setup video writer input");
    if ([_assetWriter canAddInput:_videoWriterInput]) {
        [_assetWriter addInput:_videoWriterInput];
    } else {
        return NO;
    }

    SCTraceSignal(@"Setup audio writer input");
    if ([_assetWriter canAddInput:_audioWriterInput]) {
        [_assetWriter addInput:_audioWriterInput];
    } else {
        return NO;
    }

    return YES;
}

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    SCAssert([_performer isCurrentPerformer], @"");
    SC_GUARD_ELSE_RETURN(sampleBuffer);
    if (!CMBufferQueueIsEmpty(_videoBufferQueue)) {
        // We need to drain the buffer queue in this case
        while (_videoWriterInput.readyForMoreMediaData) { // TODO: also need to break out in case of errors
            CMSampleBufferRef dequeuedSampleBuffer =
                (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(_videoBufferQueue);
            if (dequeuedSampleBuffer == NULL) {
                break;
            }
            [self _appendVideoSampleBuffer:dequeuedSampleBuffer];
            CFRelease(dequeuedSampleBuffer);
        }
    }
    // Fast path, just append this sample buffer if ready
    if (_videoWriterInput.readyForMoreMediaData) {
        [self _appendVideoSampleBuffer:sampleBuffer];
    } else {
        // It is not ready, queuing the sample buffer
        CMBufferQueueEnqueue(_videoBufferQueue, sampleBuffer);
    }
}

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    SCAssert([_performer isCurrentPerformer], @"");
    SC_GUARD_ELSE_RETURN(sampleBuffer);
    if (!CMBufferQueueIsEmpty(_audioBufferQueue)) {
        // We need to drain the buffer queue in this case
        while (_audioWriterInput.readyForMoreMediaData) {
            CMSampleBufferRef dequeuedSampleBuffer =
                (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(_audioBufferQueue);
            if (dequeuedSampleBuffer == NULL) {
                break;
            }
            [_audioWriterInput appendSampleBuffer:sampleBuffer];
            CFRelease(dequeuedSampleBuffer);
        }
    }
    // fast path, just append this sample buffer if ready
    if ((_audioWriterInput.readyForMoreMediaData)) {
        [_audioWriterInput appendSampleBuffer:sampleBuffer];
    } else {
        // it is not ready, queuing the sample buffer
        CMBufferQueueEnqueue(_audioBufferQueue, sampleBuffer);
    }
}

- (void)startWritingAtSourceTime:(CMTime)sourceTime
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    // To observe the status change on assetWriter because when assetWriter errors out, it only changes the
    // status, no further delegate callbacks etc.
    [_observeController observe:_assetWriter
                        keyPath:@keypath(_assetWriter, status)
                        options:NSKeyValueObservingOptionNew
                         action:@selector(assetWriterStatusChanged:)];
    [_assetWriter startWriting];
    [_assetWriter startSessionAtSourceTime:sourceTime];
}

- (void)cancelWriting
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");
    CMBufferQueueReset(_videoBufferQueue);
    CMBufferQueueReset(_audioBufferQueue);
    [_assetWriter cancelWriting];
}

- (void)finishWritingAtSourceTime:(CMTime)sourceTime withCompletionHanlder:(dispatch_block_t)completionBlock
{
    SCTraceStart();
    SCAssert([_performer isCurrentPerformer], @"");

    while (_audioWriterInput.readyForMoreMediaData && !CMBufferQueueIsEmpty(_audioBufferQueue)) {
        CMSampleBufferRef audioSampleBuffer = (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(_audioBufferQueue);
        if (audioSampleBuffer == NULL) {
            break;
        }
        [_audioWriterInput appendSampleBuffer:audioSampleBuffer];
        CFRelease(audioSampleBuffer);
    }
    while (_videoWriterInput.readyForMoreMediaData && !CMBufferQueueIsEmpty(_videoBufferQueue)) {
        CMSampleBufferRef videoSampleBuffer = (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(_videoBufferQueue);
        if (videoSampleBuffer == NULL) {
            break;
        }
        [_videoWriterInput appendSampleBuffer:videoSampleBuffer];
        CFRelease(videoSampleBuffer);
    }

    dispatch_block_t finishWritingBlock = ^() {
        [_assetWriter endSessionAtSourceTime:sourceTime];
        [_audioWriterInput markAsFinished];
        [_videoWriterInput markAsFinished];
        [_assetWriter finishWritingWithCompletionHandler:^{
            if (completionBlock) {
                completionBlock();
            }
        }];
    };

    if (CMBufferQueueIsEmpty(_audioBufferQueue) && CMBufferQueueIsEmpty(_videoBufferQueue)) {
        finishWritingBlock();
    } else {
        // We need to drain the samples from the queues before finish writing
        __block BOOL isAudioDone = NO;
        __block BOOL isVideoDone = NO;
        // Audio
        [_audioWriterInput
            requestMediaDataWhenReadyOnQueue:_performer.queue
                                  usingBlock:^{
                                      if (!CMBufferQueueIsEmpty(_audioBufferQueue) &&
                                          _assetWriter.status == AVAssetWriterStatusWriting) {
                                          CMSampleBufferRef audioSampleBuffer =
                                              (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(_audioBufferQueue);
                                          if (audioSampleBuffer) {
                                              [_audioWriterInput appendSampleBuffer:audioSampleBuffer];
                                              CFRelease(audioSampleBuffer);
                                          }
                                      } else if (!isAudioDone) {
                                          isAudioDone = YES;
                                      }
                                      if (isAudioDone && isVideoDone) {
                                          finishWritingBlock();
                                      }
                                  }];

        // Video
        [_videoWriterInput
            requestMediaDataWhenReadyOnQueue:_performer.queue
                                  usingBlock:^{
                                      if (!CMBufferQueueIsEmpty(_videoBufferQueue) &&
                                          _assetWriter.status == AVAssetWriterStatusWriting) {
                                          CMSampleBufferRef videoSampleBuffer =
                                              (CMSampleBufferRef)CMBufferQueueDequeueAndRetain(_videoBufferQueue);
                                          if (videoSampleBuffer) {
                                              [_videoWriterInput appendSampleBuffer:videoSampleBuffer];
                                              CFRelease(videoSampleBuffer);
                                          }
                                      } else if (!isVideoDone) {
                                          isVideoDone = YES;
                                      }
                                      if (isAudioDone && isVideoDone) {
                                          finishWritingBlock();
                                      }
                                  }];
    }
}

- (void)cleanUp
{
    _assetWriter = nil;
    _videoWriterInput = nil;
    _audioWriterInput = nil;
    _pixelBufferAdaptor = nil;
}

- (void)dealloc
{
    CFRelease(_videoBufferQueue);
    CFRelease(_audioBufferQueue);
    CVPixelBufferPoolRelease(_defaultPixelBufferPool);
    CVPixelBufferPoolRelease(_nightPixelBufferPool);
    CVPixelBufferPoolRelease(_lensesPixelBufferPool);
    [_observeController unobserveAll];
}

- (void)assetWriterStatusChanged:(NSDictionary *)change
{
    SCTraceStart();
    if (_assetWriter.status == AVAssetWriterStatusFailed) {
        SCTraceSignal(@"Asset writer status failed %@, error %@", change, _assetWriter.error);
        [_delegate videoWriterDidFailWritingWithError:[_assetWriter.error copy]];
    }
}

#pragma - Private methods

- (CVImageBufferRef)_croppedPixelBufferWithInputPixelBuffer:(CVImageBufferRef)inputPixelBuffer
{
    SCAssertTrue([SCDeviceName isIphoneX]);
    const size_t inputBufferWidth = CVPixelBufferGetWidth(inputPixelBuffer);
    const size_t inputBufferHeight = CVPixelBufferGetHeight(inputPixelBuffer);
    const size_t croppedBufferWidth = (size_t)(inputBufferWidth * kSCIPhoneXCapturedImageVideoCropRatio) / 2 * 2;
    const size_t croppedBufferHeight =
        (size_t)(croppedBufferWidth * SCManagedCapturedImageAndVideoAspectRatio()) / 2 * 2;
    const size_t offsetPointX = inputBufferWidth - croppedBufferWidth;
    const size_t offsetPointY = (inputBufferHeight - croppedBufferHeight) / 4 * 2;

    SC_GUARD_ELSE_RUN_AND_RETURN_VALUE((inputBufferWidth >= croppedBufferWidth) &&
                                           (inputBufferHeight >= croppedBufferHeight) && (offsetPointX % 2 == 0) &&
                                           (offsetPointY % 2 == 0) &&
                                           (inputBufferWidth >= croppedBufferWidth + offsetPointX) &&
                                           (inputBufferHeight >= croppedBufferHeight + offsetPointY),
                                       SCLogGeneralError(@"Invalid cropping configuration"), NULL);

    CVPixelBufferRef croppedPixelBuffer = NULL;
    CVPixelBufferPoolRef pixelBufferPool =
        [self _pixelBufferPoolWithInputSize:CGSizeMake(inputBufferWidth, inputBufferHeight)
                                croppedSize:CGSizeMake(croppedBufferWidth, croppedBufferHeight)];

    if (pixelBufferPool) {
        CVReturn result = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferPool, &croppedPixelBuffer);
        if ((result != kCVReturnSuccess) || (croppedPixelBuffer == NULL)) {
            SCLogGeneralError(@"[SCCapturerVideoWriterInput] Error creating croppedPixelBuffer");
            return NULL;
        }
    } else {
        SCAssertFail(@"[SCCapturerVideoWriterInput] PixelBufferPool is NULL with inputBufferWidth:%@, "
                     @"inputBufferHeight:%@, croppedBufferWidth:%@, croppedBufferHeight:%@",
                     @(inputBufferWidth), @(inputBufferHeight), @(croppedBufferWidth), @(croppedBufferHeight));
        return NULL;
    }
    CVPixelBufferLockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferLockBaseAddress(croppedPixelBuffer, 0);

    const size_t planesCount = CVPixelBufferGetPlaneCount(inputPixelBuffer);
    for (int planeIndex = 0; planeIndex < planesCount; planeIndex++) {
        size_t inPlaneHeight = CVPixelBufferGetHeightOfPlane(inputPixelBuffer, planeIndex);
        size_t inPlaneBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(inputPixelBuffer, planeIndex);
        uint8_t *inPlaneAdress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(inputPixelBuffer, planeIndex);

        size_t croppedPlaneHeight = CVPixelBufferGetHeightOfPlane(croppedPixelBuffer, planeIndex);
        size_t croppedPlaneBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(croppedPixelBuffer, planeIndex);
        uint8_t *croppedPlaneAdress = (uint8_t *)CVPixelBufferGetBaseAddressOfPlane(croppedPixelBuffer, planeIndex);

        // Note that inPlaneBytesPerRow is not strictly 2x of inPlaneWidth for some devices (e.g. iPhone X).
        // However, since UV are packed together in memory, we can use offsetPointX for all planes
        size_t offsetPlaneBytesX = offsetPointX;
        size_t offsetPlaneBytesY = offsetPointY * inPlaneHeight / inputBufferHeight;

        inPlaneAdress = inPlaneAdress + offsetPlaneBytesY * inPlaneBytesPerRow + offsetPlaneBytesX;
        size_t bytesToCopyPerRow = MIN(inPlaneBytesPerRow - offsetPlaneBytesX, croppedPlaneBytesPerRow);
        for (int i = 0; i < croppedPlaneHeight; i++) {
            memcpy(croppedPlaneAdress, inPlaneAdress, bytesToCopyPerRow);
            inPlaneAdress += inPlaneBytesPerRow;
            croppedPlaneAdress += croppedPlaneBytesPerRow;
        }
    }
    CVPixelBufferUnlockBaseAddress(inputPixelBuffer, kCVPixelBufferLock_ReadOnly);
    CVPixelBufferUnlockBaseAddress(croppedPixelBuffer, 0);
    return croppedPixelBuffer;
}

- (CVPixelBufferPoolRef)_pixelBufferPoolWithInputSize:(CGSize)inputSize croppedSize:(CGSize)croppedSize
{
    if (CGSizeEqualToSize(inputSize, [SCManagedCaptureDevice defaultActiveFormatResolution])) {
        if (_defaultPixelBufferPool == NULL) {
            _defaultPixelBufferPool = [self _newPixelBufferPoolWithWidth:croppedSize.width height:croppedSize.height];
        }
        return _defaultPixelBufferPool;
    } else if (CGSizeEqualToSize(inputSize, [SCManagedCaptureDevice nightModeActiveFormatResolution])) {
        if (_nightPixelBufferPool == NULL) {
            _nightPixelBufferPool = [self _newPixelBufferPoolWithWidth:croppedSize.width height:croppedSize.height];
        }
        return _nightPixelBufferPool;
    } else {
        if (_lensesPixelBufferPool == NULL) {
            _lensesPixelBufferPool = [self _newPixelBufferPoolWithWidth:croppedSize.width height:croppedSize.height];
        }
        return _lensesPixelBufferPool;
    }
}

- (CVPixelBufferPoolRef)_newPixelBufferPoolWithWidth:(size_t)width height:(size_t)height
{
    NSDictionary *attributes = @{
        (NSString *) kCVPixelBufferIOSurfacePropertiesKey : @{}, (NSString *)
        kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), (NSString *)
        kCVPixelBufferWidthKey : @(width), (NSString *)
        kCVPixelBufferHeightKey : @(height)
    };
    CVPixelBufferPoolRef pixelBufferPool = NULL;
    CVReturn result = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL,
                                              (__bridge CFDictionaryRef _Nullable)(attributes), &pixelBufferPool);
    if (result != kCVReturnSuccess) {
        SCLogGeneralError(@"[SCCapturerBufferredVideoWriter] Error creating pixel buffer pool %i", result);
        return NULL;
    }

    return pixelBufferPool;
}

- (void)_appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    SCAssert([_performer isCurrentPerformer], @"");
    CMTime presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    CVImageBufferRef inputPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if ([SCDeviceName isIphoneX]) {
        CVImageBufferRef croppedPixelBuffer = [self _croppedPixelBufferWithInputPixelBuffer:inputPixelBuffer];
        if (croppedPixelBuffer) {
            [_pixelBufferAdaptor appendPixelBuffer:croppedPixelBuffer withPresentationTime:presentationTime];
            CVPixelBufferRelease(croppedPixelBuffer);
        }
    } else {
        [_pixelBufferAdaptor appendPixelBuffer:inputPixelBuffer withPresentationTime:presentationTime];
    }
}

@end
