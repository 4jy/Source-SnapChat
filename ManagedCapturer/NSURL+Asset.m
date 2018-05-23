//
//  NSURL+NSURL_Asset.m
//  Snapchat
//
//  Created by Michel Loenngren on 4/30/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import "NSURL+Asset.h"

#import <SCBase/SCMacros.h>

@import AVFoundation;

@implementation NSURL (Asset)

- (void)reloadAssetKeys
{
    AVAsset *videoAsset = [AVAsset assetWithURL:self];
    [videoAsset loadValuesAsynchronouslyForKeys:@[ @keypath(videoAsset.duration) ] completionHandler:nil];
}

@end
