
#import "UIScreen+Debug.h"

#import <SCFoundation/SCAppEnvironment.h>
#import <SCFoundation/SCLog.h>

#import <objc/runtime.h>

@implementation UIScreen (Debug)
+ (void)load
{
    if (SCIsPerformanceLoggingEnabled()) {
        static dispatch_once_t once_token;
        dispatch_once(&once_token, ^{
            SEL setBrightnessSelector = @selector(setBrightness:);
            SEL setBrightnessLoggerSelector = @selector(logged_setBrightness:);
            Method originalMethod = class_getInstanceMethod(self, setBrightnessSelector);
            Method extendedMethod = class_getInstanceMethod(self, setBrightnessLoggerSelector);
            method_exchangeImplementations(originalMethod, extendedMethod);
        });
    }
}
- (void)logged_setBrightness:(CGFloat)brightness
{
    SCLogGeneralInfo(@"Setting brightness from %f to %f", self.brightness, brightness);
    [self logged_setBrightness:brightness];
}
@end
