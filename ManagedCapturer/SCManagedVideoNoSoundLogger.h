//
//  SCManagedVideoNoSoundLogger.h
//  Snapchat
//
//  Created by Pinlin Chen on 15/07/2017.
//
//

#import <SCBase/SCMacros.h>

#import <AVFoundation/AVFoundation.h>
#import <Foundation/Foundation.h>

@protocol SCManiphestTicketCreator;

@interface SCManagedVideoNoSoundLogger : NSObject

@property (nonatomic, strong) NSError *audioSessionError;
@property (nonatomic, strong) NSError *audioQueueError;
@property (nonatomic, strong) NSError *assetWriterError;
@property (nonatomic, assign) BOOL retryAudioQueueSuccess;
@property (nonatomic, assign) BOOL retryAudioQueueSuccessSetDataSource;
@property (nonatomic, strong) NSString *brokenMicCodeType;
@property (nonatomic, assign) BOOL lenseActiveWhileRecording;
@property (nonatomic, strong) NSString *activeLensId;
@property (nonatomic, assign) CMTime firstWrittenAudioBufferDelay;
@property (nonatomic, assign) BOOL audioQueueStarted;

SC_INIT_AND_NEW_UNAVAILABLE
- (instancetype)initWithTicketCreator:(id<SCManiphestTicketCreator>)ticketCreator;

/* Use to counting how many no sound issue we have fixed */
// Call at the place where we have fixed the AVPlayer leak before
+ (void)startCountingVideoNoSoundHaveBeenFixed;

/* Use to report the detail of new no sound issue */
// Reset all the properties of recording error
- (void)resetAll;
// Log if the audio track is empty
- (void)checkVideoFileAndLogIfNeeded:(NSURL *)videoURL;
// called by AVCameraViewController when lense resume audio
- (void)managedLensesProcessorDidCallResumeAllSounds;

@end
