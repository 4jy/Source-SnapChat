//
//  SCManagedVideoScanner.m
//  Snapchat
//
//  Created by Liu Liu on 5/5/15.
//  Copyright (c) 2015 Snapchat, Inc. All rights reserved.
//

#import "SCManagedVideoScanner.h"

#import "SCScanConfiguration.h"

#import <SCFeatureSettings/SCFeatureSettingsManager+Property.h>
#import <SCFoundation/NSData+Base64.h>
#import <SCFoundation/NSString+SCFormat.h>
#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCLog.h>
#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCThreadHelpers.h>
#import <SCFoundation/SCTrace.h>
#import <SCFoundation/UIDevice+Filter.h>
#import <SCLogger/SCLogger.h>
#import <SCScanTweaks/SCScanTweaks.h>
#import <SCScanner/SCMachineReadableCodeResult.h>
#import <SCScanner/SCSnapScanner.h>
#import <SCVisualProductSearchTweaks/SCVisualProductSearchTweaks.h>

// In seconds
static NSTimeInterval const kDefaultScanTimeout = 60;

static const char *kSCManagedVideoScannerQueueLabel = "com.snapchat.scvideoscanningcapturechannel.video.snapcode-scan";

@interface SCManagedVideoScanner ()

@end

@implementation SCManagedVideoScanner {
    SCSnapScanner *_snapScanner;
    dispatch_semaphore_t _activeSemaphore;
    NSTimeInterval _maxFrameDuration; // Used to restrict how many frames the scanner processes
    NSTimeInterval _maxFrameDefaultDuration;
    NSTimeInterval _maxFramePassiveDuration;
    float _restCycleOfBusyCycle;
    NSTimeInterval _scanStartTime;
    BOOL _active;
    BOOL _shouldEmitEvent;
    dispatch_block_t _completionHandler;
    NSTimeInterval _scanTimeout;
    SCManagedCaptureDevicePosition _devicePosition;
    SCQueuePerformer *_performer;
    BOOL _adjustingFocus;
    NSArray *_codeTypes;
    NSArray *_codeTypesOld;
    sc_managed_capturer_scan_results_handler_t _scanResultsHandler;

    SCUserSession *_userSession;
}

- (instancetype)initWithMaxFrameDefaultDuration:(NSTimeInterval)maxFrameDefaultDuration
                        maxFramePassiveDuration:(NSTimeInterval)maxFramePassiveDuration
                                      restCycle:(float)restCycle
{
    SCTraceStart();
    self = [super init];
    if (self) {
        _snapScanner = [SCSnapScanner sharedInstance];
        _performer = [[SCQueuePerformer alloc] initWithLabel:kSCManagedVideoScannerQueueLabel
                                            qualityOfService:QOS_CLASS_UNSPECIFIED
                                                   queueType:DISPATCH_QUEUE_SERIAL
                                                     context:SCQueuePerformerContextCamera];
        _activeSemaphore = dispatch_semaphore_create(0);
        SCAssert(restCycle >= 0 && restCycle < 1, @"rest cycle should be between 0 to 1");
        _maxFrameDefaultDuration = maxFrameDefaultDuration;
        _maxFramePassiveDuration = maxFramePassiveDuration;
        _restCycleOfBusyCycle = restCycle / (1 - restCycle); // Give CPU time to rest
    }
    return self;
}
#pragma mark - Public methods

- (void)startScanAsynchronouslyWithScanConfiguration:(SCScanConfiguration *)configuration
{
    SCTraceStart();
    [_performer perform:^{
        _shouldEmitEvent = YES;
        _completionHandler = nil;
        _scanResultsHandler = configuration.scanResultsHandler;
        _userSession = configuration.userSession;
        _scanTimeout = kDefaultScanTimeout;
        _maxFrameDuration = _maxFrameDefaultDuration;
        _codeTypes = [self _scanCodeTypes];
        _codeTypesOld = @[ @(SCCodeTypeSnapcode18x18Old), @(SCCodeTypeQRCode) ];

        SCTraceStart();
        // Set the scan start time properly, if we call startScan multiple times while it is active,
        // This makes sure we can scan long enough.
        _scanStartTime = CACurrentMediaTime();
        // we are not active, need to send the semaphore to start the scan
        if (!_active) {
            _active = YES;

            // Signal the semaphore that we can start scan!
            dispatch_semaphore_signal(_activeSemaphore);
        }
    }];
}

- (void)stopScanAsynchronously
{
    SCTraceStart();
    [_performer perform:^{
        SCTraceStart();
        if (_active) {
            SCLogScanDebug(@"VideoScanner:stopScanAsynchronously turn off from active");
            _active = NO;
            _scanStartTime = 0;
            _scanResultsHandler = nil;
            _userSession = nil;
        } else {
            SCLogScanDebug(@"VideoScanner:stopScanAsynchronously off already");
        }
    }];
}

#pragma mark - Private Methods

- (void)_handleSnapScanResult:(SCSnapScannedData *)scannedData
{
    if (scannedData.hasScannedData) {
        if (scannedData.codeType == SCCodeTypeSnapcode18x18 || scannedData.codeType == SCCodeTypeSnapcodeBitmoji ||
            scannedData.codeType == SCCodeTypeSnapcode18x18Old) {
            NSString *data = [scannedData.rawData base64EncodedString];
            NSString *version = [NSString sc_stringWithFormat:@"%i", scannedData.codeTypeMeta];
            [[SCLogger sharedInstance] logEvent:@"SNAPCODE_18x18_SCANNED_FROM_CAMERA"
                                     parameters:@{
                                         @"version" : version
                                     }
                               secretParameters:@{
                                   @"data" : data
                               }];

            if (_completionHandler != nil) {
                runOnMainThreadAsynchronously(_completionHandler);
                _completionHandler = nil;
            }
        } else if (scannedData.codeType == SCCodeTypeBarcode) {
            if (!_userSession || !_userSession.featureSettingsManager.barCodeScanEnabled) {
                return;
            }
            NSString *data = scannedData.data;
            NSString *type = [SCSnapScannedData stringFromBarcodeType:scannedData.codeTypeMeta];
            [[SCLogger sharedInstance] logEvent:@"BARCODE_SCANNED_FROM_CAMERA"
                                     parameters:@{
                                         @"type" : type
                                     }
                               secretParameters:@{
                                   @"data" : data
                               }];
        } else if (scannedData.codeType == SCCodeTypeQRCode) {
            if (!_userSession || !_userSession.featureSettingsManager.qrCodeScanEnabled) {
                return;
            }
            NSURL *url = [NSURL URLWithString:scannedData.data];
            [[SCLogger sharedInstance] logEvent:@"QR_CODE_SCANNED_FROM_CAMERA"
                                     parameters:@{
                                         @"type" : (url) ? @"url" : @"other"
                                     }
                               secretParameters:@{}];
        }

        if (_shouldEmitEvent) {
            sc_managed_capturer_scan_results_handler_t scanResultsHandler = _scanResultsHandler;
            runOnMainThreadAsynchronously(^{
                if (scanResultsHandler != nil && scannedData) {
                    SCMachineReadableCodeResult *result =
                        [SCMachineReadableCodeResult machineReadableCodeResultWithScannedData:scannedData];
                    scanResultsHandler(result);
                }
            });
        }
    }
}

- (NSArray *)_scanCodeTypes
{
    // Scan types are defined by codetypes. SnapScan will scan the frame based on codetype.
    NSMutableArray *codeTypes = [[NSMutableArray alloc]
        initWithObjects:@(SCCodeTypeSnapcode18x18), @(SCCodeTypeQRCode), @(SCCodeTypeSnapcodeBitmoji), nil];
    if (SCSearchEnableBarcodeProductSearch()) {
        [codeTypes addObject:@(SCCodeTypeBarcode)];
    }
    return [codeTypes copy];
}

#pragma mark - SCManagedVideoDataSourceListener

- (void)managedVideoDataSource:(id<SCManagedVideoDataSource>)managedVideoDataSource
         didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
                devicePosition:(SCManagedCaptureDevicePosition)devicePosition
{
    SCTraceStart();
    _devicePosition = devicePosition;

    if (!_active) {
        SCLogScanDebug(@"VideoScanner: Scanner is not active");
        return;
    }
    SCLogScanDebug(@"VideoScanner: Scanner is active");

    // If we have the semaphore now, enqueue a new buffer, otherwise drop the buffer
    if (dispatch_semaphore_wait(_activeSemaphore, DISPATCH_TIME_NOW) == 0) {
        CFRetain(sampleBuffer);
        NSTimeInterval startTime = CACurrentMediaTime();
        [_performer perform:^{
            SCTraceStart();
            CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            SCLogScanInfo(@"VideoScanner: Scanner will scan a frame");
            SCSnapScannedData *scannedData;

            SCLogScanInfo(@"VideoScanner:Use new scanner without false alarm check");
            scannedData = [_snapScanner scanPixelBuffer:pixelBuffer forCodeTypes:_codeTypes];

            if ([UIDevice shouldLogPerfEvents]) {
                NSInteger loadingMs = (CACurrentMediaTime() - startTime) * 1000;
                // Since there are too many unsuccessful scans, we will only log 1/10 of them for now.
                if (scannedData.hasScannedData || (!scannedData.hasScannedData && arc4random() % 10 == 0)) {
                    [[SCLogger sharedInstance] logEvent:@"SCAN_SINGLE_FRAME"
                                             parameters:@{
                                                 @"time_span" : @(loadingMs),
                                                 @"has_scanned_data" : @(scannedData.hasScannedData),
                                             }];
                }
            }

            [self _handleSnapScanResult:scannedData];
            // If it is not turned off, we will continue to scan if result is not presetn
            if (_active) {
                _active = !scannedData.hasScannedData;
            }

            // Clean up if result is reported for scan
            if (!_active) {
                _scanResultsHandler = nil;
                _completionHandler = nil;
            }

            CFRelease(sampleBuffer);

            NSTimeInterval currentTime = CACurrentMediaTime();
            SCLogScanInfo(@"VideoScanner:Scan time %f maxFrameDuration:%f timeout:%f", currentTime - startTime,
                          _maxFrameDuration, _scanTimeout);
            // Haven't found the scanned data yet, haven't reached maximum scan timeout yet, haven't turned this off
            // yet, ready for the next frame
            if (_active && currentTime < _scanStartTime + _scanTimeout) {
                // We've finished processing current sample buffer, ready for next one, but before that, we need to rest
                // a bit (if possible)
                if (currentTime - startTime >= _maxFrameDuration && _restCycleOfBusyCycle < FLT_MIN) {
                    // If we already reached deadline (used too much time) and don't want to rest CPU, give the signal
                    // now to grab the next frame
                    SCLogScanInfo(@"VideoScanner:Signal to get next frame for snapcode scanner");
                    dispatch_semaphore_signal(_activeSemaphore);
                } else {
                    NSTimeInterval afterTime = MAX((currentTime - startTime) * _restCycleOfBusyCycle,
                                                   _maxFrameDuration - (currentTime - startTime));
                    // If we need to wait more than 0 second, then do that, otherwise grab the next frame immediately
                    if (afterTime > 0) {
                        [_performer perform:^{
                            SCLogScanInfo(
                                @"VideoScanner:Waited and now signaling to get next frame for snapcode scanner");
                            dispatch_semaphore_signal(_activeSemaphore);
                        }
                                      after:afterTime];
                    } else {
                        SCLogScanInfo(@"VideoScanner:Now signaling to get next frame for snapcode scanner");
                        dispatch_semaphore_signal(_activeSemaphore);
                    }
                }
            } else {
                // We are not active, and not going to be active any more.
                SCLogScanInfo(@"VideoScanner:not active anymore");
                _active = NO;
                _scanResultsHandler = nil;
                _completionHandler = nil;
            }
        }];
    }
}

#pragma mark - SCManagedDeviceCapacityAnalyzerListener

- (void)managedDeviceCapacityAnalyzer:(SCManagedDeviceCapacityAnalyzer *)managedDeviceCapacityAnalyzer
              didChangeAdjustingFocus:(BOOL)adjustingFocus
{
    [_performer perform:^{
        _adjustingFocus = adjustingFocus;
    }];
}

@end
