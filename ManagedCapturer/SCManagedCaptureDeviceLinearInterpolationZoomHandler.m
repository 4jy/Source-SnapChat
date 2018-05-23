//
//  SCManagedCaptureDeviceLinearInterpolationZoomHandler.m
//  Snapchat
//
//  Created by Joe Qiao on 03/01/2018.
//

#import "SCManagedCaptureDeviceLinearInterpolationZoomHandler.h"

#import "SCCameraTweaks.h"
#import "SCManagedCaptureDeviceDefaultZoomHandler_Private.h"
#import "SCManagedCapturerLogging.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCMathUtils.h>

@interface SCManagedCaptureDeviceLinearInterpolationZoomHandler ()

@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, assign) double timestamp;
@property (nonatomic, assign) float targetFactor;
@property (nonatomic, assign) float intermediateFactor;
@property (nonatomic, assign) int trend;
@property (nonatomic, assign) float stepLength;

@end

@implementation SCManagedCaptureDeviceLinearInterpolationZoomHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super initWithCaptureResource:captureResource];
    if (self) {
        _timestamp = -1.0;
        _targetFactor = 1.0;
        _intermediateFactor = _targetFactor;
        _trend = 1;
        _stepLength = 0.0;
    }

    return self;
}

- (void)dealloc
{
    [self _invalidate];
}

- (void)setZoomFactor:(CGFloat)zoomFactor forDevice:(SCManagedCaptureDevice *)device immediately:(BOOL)immediately
{
    if (self.currentDevice != device) {
        if (_displayLink) {
            // if device changed, interupt smoothing process
            // and reset to target zoom factor immediately
            [self _resetToZoomFactor:_targetFactor];
        }
        self.currentDevice = device;
        immediately = YES;
    }

    if (immediately) {
        [self _resetToZoomFactor:zoomFactor];
    } else {
        [self _addTargetZoomFactor:zoomFactor];
    }
}

#pragma mark - Configurable
// smoothen if the update time interval is greater than the threshold
- (double)_thresholdTimeIntervalToSmoothen
{
    return SCCameraTweaksSmoothZoomThresholdTime();
}

- (double)_thresholdFactorDiffToSmoothen
{
    return SCCameraTweaksSmoothZoomThresholdFactor();
}

- (int)_intermediateFactorFramesPerSecond
{
    return SCCameraTweaksSmoothZoomIntermediateFramesPerSecond();
}

- (double)_delayTolerantTime
{
    return SCCameraTweaksSmoothZoomDelayTolerantTime();
}

// minimum step length between two intermediate factors,
// the greater the better as long as could provide a 'smooth experience' during smoothing process
- (float)_minimumStepLength
{
    return SCCameraTweaksSmoothZoomMinStepLength();
}

#pragma mark - Private methods
- (void)_addTargetZoomFactor:(float)factor
{
    SCAssertMainThread();

    SCLogCapturerInfo(@"Smooth Zoom - [1] t=%f zf=%f", CACurrentMediaTime(), factor);
    if (SCFloatEqual(factor, _targetFactor)) {
        return;
    }
    _targetFactor = factor;

    float diff = _targetFactor - _intermediateFactor;
    if ([self _isDuringSmoothingProcess]) {
        // during smoothing, only update data
        [self _updateDataWithDiff:diff];
    } else {
        double curTimestamp = CACurrentMediaTime();
        if (!SCFloatEqual(_timestamp, -1.0) && (curTimestamp - _timestamp) > [self _thresholdTimeIntervalToSmoothen] &&
            ABS(diff) > [self _thresholdFactorDiffToSmoothen]) {
            // need smoothing
            [self _updateDataWithDiff:diff];
            if ([self _nextStep]) {
                // use timer to interpolate intermediate factors to avoid sharp jump
                _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_nextStep)];
                _displayLink.preferredFramesPerSecond = [self _intermediateFactorFramesPerSecond];
                [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
            }
        } else {
            _timestamp = curTimestamp;
            _intermediateFactor = factor;

            SCLogCapturerInfo(@"Smooth Zoom - [2] t=%f zf=%f", CACurrentMediaTime(), _intermediateFactor);
            [self _setZoomFactor:_intermediateFactor forManagedCaptureDevice:self.currentDevice];
        }
    }
}

- (void)_resetToZoomFactor:(float)factor
{
    [self _invalidate];

    _timestamp = -1.0;
    _targetFactor = factor;
    _intermediateFactor = _targetFactor;

    [self _setZoomFactor:_intermediateFactor forManagedCaptureDevice:self.currentDevice];
}

- (BOOL)_nextStep
{
    _timestamp = CACurrentMediaTime();
    _intermediateFactor += (_trend * _stepLength);

    BOOL hasNext = YES;
    if (_trend < 0.0) {
        _intermediateFactor = MAX(_intermediateFactor, _targetFactor);
    } else {
        _intermediateFactor = MIN(_intermediateFactor, _targetFactor);
    }

    SCLogCapturerInfo(@"Smooth Zoom - [3] t=%f zf=%f", CACurrentMediaTime(), _intermediateFactor);
    [self _setZoomFactor:_intermediateFactor forManagedCaptureDevice:self.currentDevice];

    if (SCFloatEqual(_intermediateFactor, _targetFactor)) {
        // finish smoothening
        [self _invalidate];
        hasNext = NO;
    }

    return hasNext;
}

- (void)_invalidate
{
    [_displayLink invalidate];
    _displayLink = nil;
    _trend = 1;
    _stepLength = 0.0;
}

- (void)_updateDataWithDiff:(CGFloat)diff
{
    _trend = diff < 0.0 ? -1 : 1;
    _stepLength =
        MAX(_stepLength, MAX([self _minimumStepLength],
                             ABS(diff) / ([self _delayTolerantTime] * [self _intermediateFactorFramesPerSecond])));
}

- (BOOL)_isDuringSmoothingProcess
{
    return (_displayLink ? YES : NO);
}

@end
