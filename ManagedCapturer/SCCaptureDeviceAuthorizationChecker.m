//
//  SCCaptureDeviceAuthorizationChecker.m
//  Snapchat
//
//  Created by Sun Lei on 15/03/2018.
//

#import "SCCaptureDeviceAuthorizationChecker.h"

#import <SCFoundation/SCQueuePerformer.h>
#import <SCFoundation/SCTraceODPCompatible.h>

@import AVFoundation;

@interface SCCaptureDeviceAuthorizationChecker () {
    SCQueuePerformer *_performer;
    BOOL _videoCaptureAuthorizationCachedValue;
}
@end

@implementation SCCaptureDeviceAuthorizationChecker

- (instancetype)initWithPerformer:(SCQueuePerformer *)performer
{
    SCTraceODPCompatibleStart(2);
    self = [super init];
    if (self) {
        _performer = performer;
        _videoCaptureAuthorizationCachedValue = NO;
    }
    return self;
}

- (void)preloadVideoCaptureAuthorization
{
    SCTraceODPCompatibleStart(2);
    [_performer perform:^{
        SCTraceODPCompatibleStart(2);
        _videoCaptureAuthorizationCachedValue = [self authorizedForMediaType:AVMediaTypeVideo];
    }];
}

- (BOOL)authorizedForVideoCapture
{
    SCTraceODPCompatibleStart(2);
    // Cache authorizedForVideoCapture for low devices if it's YES
    // [AVCaptureDevice authorizationStatusForMediaType:] is expensive on low devices like iPhone4
    if (_videoCaptureAuthorizationCachedValue) {
        // If the user authorizes and then unauthorizes, iOS would SIGKILL the app.
        // When the user opens the app, a pop-up tells the user to allow camera access in settings.
        // So 'return YES' makes sense here.
        return YES;
    } else {
        @weakify(self);
        [_performer performAndWait:^{
            @strongify(self);
            SC_GUARD_ELSE_RETURN(self);
            if (!_videoCaptureAuthorizationCachedValue) {
                _videoCaptureAuthorizationCachedValue = [self authorizedForMediaType:AVMediaTypeVideo];
            }
        }];
        return _videoCaptureAuthorizationCachedValue;
    }
}

- (BOOL)authorizedForMediaType:(NSString *)mediaType
{
    return [AVCaptureDevice authorizationStatusForMediaType:mediaType] == AVAuthorizationStatusAuthorized;
}

@end
