//
//  SCCapturerBufferedVideoWriter.h
//  Snapchat
//
//  Created by Chao Pang on 12/5/17.
//

#import <SCFoundation/SCQueuePerformer.h>

#import <SCManagedVideoCapturerOutputSettings.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@protocol SCCapturerBufferedVideoWriterDelegate <NSObject>

- (void)videoWriterDidFailWritingWithError:(NSError *)error;

@end

@interface SCCapturerBufferedVideoWriter : NSObject

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithPerformer:(id<SCPerforming>)performer
                        outputURL:(NSURL *)outputURL
                         delegate:(id<SCCapturerBufferedVideoWriterDelegate>)delegate
                            error:(NSError **)error;

- (BOOL)prepareWritingWithOutputSettings:(SCManagedVideoCapturerOutputSettings *)outputSettings;

- (void)startWritingAtSourceTime:(CMTime)sourceTime;

- (void)finishWritingAtSourceTime:(CMTime)sourceTime withCompletionHanlder:(dispatch_block_t)completionBlock;

- (void)cancelWriting;

- (void)appendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)appendAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)cleanUp;

@end
