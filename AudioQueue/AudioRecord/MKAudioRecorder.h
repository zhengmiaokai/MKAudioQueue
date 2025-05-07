//
//  MKAudioRecorder.h
//  Demo
//
//  Created by zhengmiaokai on 2025/4/3.
//

#import <Foundation/Foundation.h>
#import "MKAudioQueueConstants.h"

@interface MKAudioRecorder : NSObject

@property (nonatomic, copy) void(^timerHandler)(NSInteger duration);

@property (nonatomic, copy) void(^interruptionHandler)(MKInterruptionType type);

@property (nonatomic, copy) void(^errorHandler)(OSStatus code, NSString *message);

@property (nonatomic, copy) void(^statusHandler)(MKAudioStatus recordStatus);

@property (nonatomic, copy) void(^bufferHandler)(void * const pcmData, UInt32 dataByteSize);

- (void)prepareRecording:(MKAudioQuality)quality;
- (void)prepareRecording:(MKAudioQuality)quality filePath:(NSString *)filePath;

- (void)startRecording;

- (void)pauseRecording;

- (void)stopRecording;

@end
