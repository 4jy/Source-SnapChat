//
//  SCMetalUtils.m
//  Snapchat
//
//  Created by Michel Loenngren on 8/16/17.
//
//

#import "SCMetalUtils.h"

#import <SCFoundation/SCTrace.h>

id<MTLDevice> SCGetManagedCaptureMetalDevice(void)
{
#if !TARGET_IPHONE_SIMULATOR
    SCTraceStart();
    static dispatch_once_t onceToken;
    static id<MTLDevice> device;
    dispatch_once(&onceToken, ^{
        device = MTLCreateSystemDefaultDevice();
    });
    return device;
#endif
    return nil;
}
