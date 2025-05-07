//
//  MKAudioPlayer.m
//  Demo
//
//  Created by zhengmiaokai on 2025/4/24.
//

#import "MKAudioPlayer.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

#define BUFFER_SIZE    4096
#define BUFFER_COUNT   3

#define SAMPLE_RATE   44100  // 采样率：8000, 16000, 44100
#define NUM_CHANNELS  2      // 声道数：1, 2
#define BIT_DEPTH     16     // 量化位数：8, 16, 32

@interface MKAudioPlayer () {
    AudioQueueRef        _audioQueue;
    AudioQueueBufferRef  _buffers[BUFFER_COUNT];
    NSInputStream        *_inputStream;
}

@property (nonatomic, assign) MKAudioQuality quality;
@property (nonatomic, assign) MKAudioStatus playStatus;

@property (nonatomic, assign) int bufferIdx;

@end

@implementation MKAudioPlayer

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
        self.playStatus = MKAudioStatusStop;
    }
    return self;
}

#pragma mark - Public -
- (void)preparePlaying:(MKAudioQuality)quality {
    [self preparePlaying:quality filePath:nil];
}

- (void)preparePlaying:(MKAudioQuality)quality filePath:(NSString *)filePath {
    if (self.playStatus != MKAudioStatusStop) {
        [self stopPlaying]; // 销毁音频队列、恢复音频会话
    }
    
    self.quality = quality;
    
    self.playStatus = MKAudioStatusPrepare;
    if (_statusHandler) {
        _statusHandler(MKAudioStatusPrepare);
    }
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        _inputStream = [NSInputStream inputStreamWithURL:[NSURL fileURLWithPath:filePath]];
        [_inputStream open];
    }
    
    // 初始化音频队列
    AudioStreamBasicDescription format = [self getAudioFormat];
    AudioQueueNewOutput(&format,
                       AudioOutputCallback,
                       (__bridge void *)self,
                       NULL,
                       kCFRunLoopCommonModes,
                       0,
                       &_audioQueue);
    
    for (int idx=0; idx<BUFFER_COUNT; idx++) {
        AudioQueueAllocateBuffer(_audioQueue, BUFFER_SIZE, &_buffers[idx]);
    }
    
    if (_inputStream) {
        for (int idx=0; idx<BUFFER_COUNT; idx++) {
            BOOL isContinue = [self fillAudioBuffer:_buffers[idx]];
            if (!isContinue) {
                [self stopPlaying];
                break;
            }
        }
    }
}

- (void)setPcmDatas:(NSArray *)pcmDatas {
    _pcmDatas = [pcmDatas copy];
    self.bufferIdx = 0;
    
    for (int idx=0; idx<BUFFER_COUNT; idx++) {
        if (idx < _pcmDatas.count) {
            NSData *tPcmData = _pcmDatas[idx];
            [self setPcmData:(void * const)tPcmData.bytes dataByteSize:(UInt32)tPcmData.length buffer:_buffers[idx]];
            self.bufferIdx++;
        } else {
            [self stopPlaying];
            break;
        }
    }
}

- (void)startPlaying {
    if (self.playStatus == MKAudioStatusStart) {
        NSLog(@"播放已开始");
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MKAudioPlayStartNotification object:nil];
    [self setAudioSessionActive:YES];
    
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    if (status != noErr) {
        // 销毁音频队列、恢复音频会话
        [self stopPlaying];
        
        if (_errorHandler) {
            _errorHandler(status, @"音频队列启动失败");
        }
    } else {
        self.playStatus = MKAudioStatusStart;
        if (_statusHandler) {
            _statusHandler(MKAudioStatusStart);
        }
    }
}

- (void)pausePlaying {
    if (self.playStatus == MKAudioStatusPause) {
        NSLog(@"播放已暂停");
        return;
    }
    
    AudioQueuePause(_audioQueue);
    
    self.playStatus = MKAudioStatusPause;
    if (_statusHandler) {
        _statusHandler(MKAudioStatusPause);
    }
}

- (void)stopPlaying {
    if (self.playStatus == MKAudioStatusStop) {
        NSLog(@"播放已中止");
        return;
    }
    
    if (_inputStream) {
        [_inputStream close];
        _inputStream = nil;
    }
    
    AudioQueueStop(_audioQueue, true);
    AudioQueueDispose(_audioQueue, true);
    
    [self setAudioSessionActive:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:MKAudioPlayStopNotification object:nil];
    
    self.playStatus = MKAudioStatusStop;
    if (_statusHandler) {
        _statusHandler(MKAudioStatusStop);
    }
}

#pragma mark - Callback -
static void AudioOutputCallback(void *inUserData,
                                     AudioQueueRef inAQ,
                                     AudioQueueBufferRef inBuffer) {
    MKAudioPlayer *player = (__bridge MKAudioPlayer *)inUserData;
    [player processAudioBuffer:inBuffer];
}

- (void)processAudioBuffer:(AudioQueueBufferRef)buffer {
    if (_inputStream) {
        BOOL isContinue = [self fillAudioBuffer:buffer];
        if (!isContinue) {
            [self stopPlaying];
        }
    } else {
        if (self.bufferIdx < self.pcmDatas.count) {
            NSData *tPcmData = self.pcmDatas[self.bufferIdx];
            [self setPcmData:(void * const)tPcmData.bytes dataByteSize:(UInt32)tPcmData.length buffer:buffer];
            self.bufferIdx++;
        } else {
            [self stopPlaying];
        }
    }
}

#pragma mark - Private -
- (BOOL)fillAudioBuffer:(AudioQueueBufferRef)buffer {
    uint8_t pcmData[BUFFER_SIZE];
    NSInteger dataByteSize = [_inputStream read:pcmData maxLength:BUFFER_SIZE];
    
    BOOL isContinue = (dataByteSize > 0);
    if (isContinue) {
        [self setPcmData:(void * const )pcmData dataByteSize:(UInt32)dataByteSize buffer:buffer];
    }
    return isContinue;
}

- (void)setPcmData:(void * const)pcmData dataByteSize:(UInt32)dataByteSize buffer:(AudioQueueBufferRef)buffer {
    if (pcmData == NULL || dataByteSize == 0) {
        NSLog(@"音频数据为空");
        return;
    }
    
    if (buffer != NULL) {
        // 填充音频队列缓冲区
        memcpy(buffer->mAudioData, pcmData, dataByteSize);
        buffer->mAudioDataByteSize = dataByteSize;
        AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
    }
}

#pragma mark - Getter -
- (AudioStreamBasicDescription)getAudioFormat {
    AudioStreamBasicDescription audioFormat;
    audioFormat.mSampleRate = [self getSampleRate];
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = NUM_CHANNELS;
    audioFormat.mBitsPerChannel = BIT_DEPTH;
    audioFormat.mBytesPerPacket = audioFormat.mBytesPerFrame = NUM_CHANNELS * BIT_DEPTH / 8;
    audioFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked;
    return audioFormat;
}

- (Float64)getSampleRate {
    Float64 sampleRate = SAMPLE_RATE;
    switch (self.quality) {
        case MKAudioQualityLow:
            sampleRate = 8000;
            break;
            
        case MKAudioQualityMiddle:
            sampleRate = 16000;
            break;
            
        case MKAudioQualityHigh:
            sampleRate = 44100;
            break;
            
        default:
            break;
    }
    return sampleRate;
}

#pragma mark - AudioSession -
- (void)setAudioSessionActive:(BOOL)active {
    if (active) {
        NSError *error;
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionMixWithOthers error:&error];
        [[AVAudioSession sharedInstance] setActive:YES error:&error];
        
        if (error) {
            NSLog(@"Error creating session: %@", [error description]);
        } else {
            [[AVAudioSession sharedInstance] setActive:active error:&error];
        }
    } else {
        NSError *error = nil;
        [[AVAudioSession sharedInstance] setActive:active withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    }
}

// 音频中断处理
- (void)handleAudioInterruption:(NSNotification *)notification {
    AVAudioSessionInterruptionType type = [notification.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    
    if (type == AVAudioSessionInterruptionTypeBegan) {
        // 暂停播放
        [self pausePlaying];
        
        if (_interruptionHandler) {
            _interruptionHandler(MKInterruptionTypeBegin);
        }
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        AVAudioSessionInterruptionOptions options = [notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        
        if (options & AVAudioSessionInterruptionOptionShouldResume) {
            // 恢复播放
            [self startPlaying];
            
            if (_interruptionHandler) {
                _interruptionHandler(MKInterruptionTypeEnd);
            }
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopPlaying];
}

@end
