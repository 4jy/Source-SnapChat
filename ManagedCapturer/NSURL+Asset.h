//
//  NSURL+NSURL_Asset.h
//  Snapchat
//
//  Created by Michel Loenngren on 4/30/17.
//  Copyright © 2017 Snapchat, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSURL (Asset)

/**
 In case the media server is reset while recording AVFoundation
 gets in a weird state. Even though we reload our AVFoundation
 object we still need to reload the assetkeys on the
 outputfile. If we don't the AVAssetWriter will fail when started.
 */
- (void)reloadAssetKeys;

@end
