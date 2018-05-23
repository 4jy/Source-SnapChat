//
//  SCManagedCaptureDeviceSavitzkyGolayZoomHandler.m
//  Snapchat
//
//  Created by Yu-Kuan Lai on 4/12/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//  https://en.wikipedia.org/wiki/Savitzky%E2%80%93Golay_filter
//

#import "SCManagedCaptureDeviceSavitzkyGolayZoomHandler.h"

#import "SCManagedCaptureDevice.h"
#import "SCManagedCaptureDeviceDefaultZoomHandler_Private.h"

#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>

static NSUInteger const kSCSavitzkyGolayWindowSize = 9;
static CGFloat const kSCUpperSharpZoomThreshold = 1.15;

@interface SCManagedCaptureDeviceSavitzkyGolayZoomHandler ()

@property (nonatomic, strong) NSMutableArray *zoomFactorHistoryArray;

@end

@implementation SCManagedCaptureDeviceSavitzkyGolayZoomHandler

- (instancetype)initWithCaptureResource:(SCCaptureResource *)captureResource
{
    self = [super initWithCaptureResource:captureResource];
    if (self) {
        _zoomFactorHistoryArray = [[NSMutableArray alloc] init];
    }

    return self;
}

- (void)setZoomFactor:(CGFloat)zoomFactor forDevice:(SCManagedCaptureDevice *)device immediately:(BOOL)immediately
{
    if (self.currentDevice != device) {
        // reset if device changed
        self.currentDevice = device;
        [self _resetZoomFactor:zoomFactor forDevice:self.currentDevice];
        return;
    }

    if (immediately || zoomFactor == 1 || _zoomFactorHistoryArray.count == 0) {
        // reset if zoomFactor is 1 or this is the first data point
        [self _resetZoomFactor:zoomFactor forDevice:device];
        return;
    }

    CGFloat lastVal = [[_zoomFactorHistoryArray lastObject] floatValue];
    CGFloat upperThreshold = lastVal * kSCUpperSharpZoomThreshold;
    if (zoomFactor > upperThreshold) {
        // sharp change in zoomFactor, reset
        [self _resetZoomFactor:zoomFactor forDevice:device];
        return;
    }

    [_zoomFactorHistoryArray addObject:@(zoomFactor)];
    if ([_zoomFactorHistoryArray count] > kSCSavitzkyGolayWindowSize) {
        [_zoomFactorHistoryArray removeObjectAtIndex:0];
    }

    float filteredZoomFactor =
        SC_CLAMP([self _savitzkyGolayFilteredZoomFactor], kSCMinVideoZoomFactor, kSCMaxVideoZoomFactor);
    [self _setZoomFactor:filteredZoomFactor forManagedCaptureDevice:device];
}

- (CGFloat)_savitzkyGolayFilteredZoomFactor
{
    if ([_zoomFactorHistoryArray count] == kSCSavitzkyGolayWindowSize) {
        CGFloat filteredZoomFactor =
            59 * [_zoomFactorHistoryArray[4] floatValue] +
            54 * ([_zoomFactorHistoryArray[3] floatValue] + [_zoomFactorHistoryArray[5] floatValue]) +
            39 * ([_zoomFactorHistoryArray[2] floatValue] + [_zoomFactorHistoryArray[6] floatValue]) +
            14 * ([_zoomFactorHistoryArray[1] floatValue] + [_zoomFactorHistoryArray[7] floatValue]) -
            21 * ([_zoomFactorHistoryArray[0] floatValue] + [_zoomFactorHistoryArray[8] floatValue]);
        filteredZoomFactor /= 231;
        return filteredZoomFactor;
    } else {
        return [[_zoomFactorHistoryArray lastObject] floatValue]; // use zoomFactor directly if we have less than 9
    }
}

- (void)_resetZoomFactor:(CGFloat)zoomFactor forDevice:(SCManagedCaptureDevice *)device
{
    [_zoomFactorHistoryArray removeAllObjects];
    [_zoomFactorHistoryArray addObject:@(zoomFactor)];
    [self _setZoomFactor:zoomFactor forManagedCaptureDevice:device];
}

@end
