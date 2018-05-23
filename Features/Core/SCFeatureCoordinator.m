//
//  SCFeatureCoordinator.m
//  SCCamera
//
//  Created by Kristian Bauer on 1/4/18.
//

#import "SCFeatureCoordinator.h"

#import "SCFeature.h"
#import "SCFeatureProvider.h"

#import <SCFoundation/SCAssertWrapper.h>
#import <SCFoundation/SCTraceODPCompatible.h>

typedef NSString SCFeatureDictionaryKey;

@interface SCFeatureCoordinator ()
@property (nonatomic, weak) UIView<SCFeatureContainerView> *containerView;
@property (nonatomic, strong) id<SCFeatureProvider> provider;
@end

@implementation SCFeatureCoordinator

- (instancetype)initWithFeatureContainerView:(UIView<SCFeatureContainerView> *)containerView
                                    provider:(id<SCFeatureProvider>)provider
{
    SCTraceODPCompatibleStart(2);
    SCAssert(containerView, @"SCFeatureCoordinator containerView must be non-nil");
    SCAssert(provider, @"SCFeatureCoordinator provider must be non-nil");
    self = [super init];
    if (self) {
        _containerView = containerView;
        _provider = provider;
        [self reloadFeatures];
    }
    return self;
}

- (void)reloadFeatures
{
    SCTraceODPCompatibleStart(2);
    [_provider resetInstances];
    NSMutableArray *features = [NSMutableArray array];
    for (id<SCFeature> feature in _provider.supportedFeatures) {
        if ([feature respondsToSelector:@selector(configureWithView:)]) {
            [feature configureWithView:_containerView];
        }
        if (feature) {
            [features addObject:feature];
        }
    }
}

- (void)forwardCameraTimerGesture:(UIGestureRecognizer *)gestureRecognizer
{
    SCTraceODPCompatibleStart(2);
    for (id<SCFeature> feature in _provider.supportedFeatures) {
        if ([feature respondsToSelector:@selector(forwardCameraTimerGesture:)]) {
            [feature forwardCameraTimerGesture:gestureRecognizer];
        }
    }
}

- (void)forwardCameraOverlayTapGesture:(UIGestureRecognizer *)gestureRecognizer
{
    SCTraceODPCompatibleStart(2);
    for (id<SCFeature> feature in _provider.supportedFeatures) {
        if ([feature respondsToSelector:@selector(forwardCameraOverlayTapGesture:)]) {
            [feature forwardCameraOverlayTapGesture:gestureRecognizer];
        }
    }
}

- (void)forwardLongPressGesture:(UIGestureRecognizer *)gestureRecognizer
{
    SCTraceODPCompatibleStart(2);
    for (id<SCFeature> feature in _provider.supportedFeatures) {
        if ([feature respondsToSelector:@selector(forwardLongPressGesture:)]) {
            [feature forwardLongPressGesture:gestureRecognizer];
        }
    }
}

- (void)forwardPinchGesture:(UIPinchGestureRecognizer *)gestureRecognizer
{
    SCTraceODPCompatibleStart(2);
    for (id<SCFeature> feature in _provider.supportedFeatures) {
        if ([feature respondsToSelector:@selector(forwardPinchGesture:)]) {
            [feature forwardPinchGesture:gestureRecognizer];
        }
    }
}

- (void)forwardPanGesture:(UIPanGestureRecognizer *)gestureRecognizer
{
    SCTraceODPCompatibleStart(2);
    for (id<SCFeature> feature in _provider.supportedFeatures) {
        if ([feature respondsToSelector:@selector(forwardPanGesture:)]) {
            [feature forwardPanGesture:gestureRecognizer];
        }
    }
}

- (BOOL)shouldBlockTouchAtPoint:(CGPoint)point
{
    SCTraceODPCompatibleStart(2);
    for (id<SCFeature> feature in _provider.supportedFeatures) {
        if ([feature respondsToSelector:@selector(shouldBlockTouchAtPoint:)] &&
            [feature shouldBlockTouchAtPoint:point]) {
            return YES;
        }
    }
    return NO;
}

@end
