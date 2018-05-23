//
//  SCManagedCapturerGLViewManagerAPI.h
//  SCCamera
//
//  Created by Michel Loenngren on 4/11/18.
//

#import <Looksery/LSAGLView.h>

#import <Foundation/Foundation.h>

@class SCCaptureResource;

/**
 Bridging protocol for providing a glViewManager to capture core.
 */
@protocol SCManagedCapturerGLViewManagerAPI <NSObject>

@property (nonatomic, readonly, strong) LSAGLView *view;

- (void)configureWithCaptureResource:(SCCaptureResource *)captureResource;

- (void)setLensesActive:(BOOL)active;

- (void)prepareViewIfNecessary;

@end
