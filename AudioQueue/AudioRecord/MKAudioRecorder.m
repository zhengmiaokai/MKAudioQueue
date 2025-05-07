//
//  MKAudioRecorder.m
//  Demo
//
//  Created by zhengmiaokai on 2025/4/3.
//

#import "MKAudioRecorder.h"
#import "AVFoundation/AVFoundation.h"
#import <AudioToolbox/AudioToolbox.h>
#import "MKSourceTimer.h"

#define BUFFER_COUNT   3
#define BUFFER_SIZE    4096

#define SAMPLE_RATE   44100  // 采样率：8000, 16000, 44100
#define NUM_CHANNELS  2      // 声道数：1, 2
#define BIT_DEPTH     16     // 量化位数：8, 16, 32

@interface MKAudioRecorder () {
    AudioQueueRef     _audioQueue;
    FILE              *_file;
}

@property (nonatomic, strong) MKSourceTimer *recordTimer;
@property (nonatomic, assign) NSInteger duration;
@property (nonatomic, assign) MKAudioQuality quality;
@property (nonatomic, assign) MKAudioStatus recordStatus;

@end

@implementation MKAudioRecorder

- (instancetype)init {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleAudioInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
        self.recordStatus = MKAudioStatusStop;
    }
    return self;
}

#pragma mark - Public -
- (void)prepareRecording:(MKAudioQuality)quality {
    [self prepareRecording:quality filePath:nil];
}

- (void)prepareRecording:(MKAudioQuality)quality filePath:(NSString *)filePath {
    if (self.recordStatus != MKAudioStatusStop) {
        [self stopRecording]; // 销毁音频队列、lame、定时器、恢复音频会话
    }
    
    self.quality = quality;
    
    self.recordStatus = MKAudioStatusPrepare;
    if (_statusHandler) {
        _statusHandler(MKAudioStatusPrepare);
    }
    
    if (filePath) {
        _file = fopen([filePath cStringUsingEncoding:NSUTF8StringEncoding], "wb");
    }
    
    // 创建音频队列
    AudioStreamBasicDescription format = [self getAudioFormat];
    AudioQueueNewInput(&format,
                      AudioInputCallback,
                      (__bridge void *)self,
                      NULL,
                      kCFRunLoopCommonModes,
                      0,
                      &_audioQueue);
    
    // 分配缓冲区
    for (int i = 0; i < BUFFER_COUNT; i++) {
        AudioQueueBufferRef buffer;
        AudioQueueAllocateBuffer(_audioQueue, BUFFER_SIZE, &buffer);
        AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
    }
}

- (void)startRecording {
    if (self.recordStatus == MKAudioStatusStart) {
        NSLog(@"录音已开始");
        return;
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:MKAudioRecordStartNotification object:nil];
    [self setAudioSessionActive:YES];
    
    OSStatus status = AudioQueueStart(_audioQueue, NULL);
    if (status != noErr) {
        // 销毁音频队列、lame、定时器、恢复音频会话
        [self stopRecording];
        
        if (_errorHandler) {
            _errorHandler(status, @"音频队列启动失败");
        }
    } else {
        if (self.recordTimer) {
            [self.recordTimer resumeTimer];
        } else {
            [self initializateTimer];
        }
        
        self.recordStatus = MKAudioStatusStart;
        if (_statusHandler) {
            _statusHandler(MKAudioStatusStart);
        }
    }
}

- (void)pauseRecording {
    if (self.recordStatus == MKAudioStatusPause) {
        NSLog(@"录音已暂停");
        return;
    }
    
    AudioQueuePause(_audioQueue);
    
    [self.recordTimer pauseTimer];
    
    self.recordStatus = MKAudioStatusPause;
    if (_statusHandler) {
        _statusHandler(MKAudioStatusPause);
    }
}

- (void)stopRecording {
    if (self.recordStatus == MKAudioStatusStop) {
        NSLog(@"录音已中止");
        return;
    }
    
    AudioQueueStop(_audioQueue, true);
    AudioQueueDispose(_audioQueue, true);
    
    if (_file != NULL) {
        fclose(_file);
        _file = NULL;
    }
    
    [self destroyTimer];
    [self setAudioSessionActive:NO];
    [[NSNotificationCenter defaultCenter] postNotificationName:MKAudioRecordStopNotification object:nil];
    
    self.recordStatus = MKAudioStatusStop;
    if (_statusHandler) {
        _statusHandler(MKAudioStatusStop);
    }
}

#pragma mark - Audio Callback -
static void AudioInputCallback(void *inUserData,
                              AudioQueueRef inAQ,
                              AudioQueueBufferRef inBuffer,
                              const AudioTimeStamp *inStartTime,
                              UInt32 inNumPackets,
                              const AudioStreamPacketDescription *inPacketDesc) {
    MKAudioRecorder *recorder = (__bridge MKAudioRecorder *)inUserData;
    [recorder processAudioBuffer:inBuffer];
}

- (void)processAudioBuffer:(AudioQueueBufferRef)buffer {
    if (_bufferHandler) {
        _bufferHandler(buffer->mAudioData, buffer->mAudioDataByteSize);
    }
    
    if (_file != NULL && buffer->mAudioDataByteSize > 0) {
        fwrite(buffer->mAudioData, 1, buffer->mAudioDataByteSize, _file);
    }
    
    AudioQueueEnqueueBuffer(_audioQueue, buffer, 0, NULL);
}

#pragma mark - Timer -
- (void)initializateTimer {
    [self destroyTimer];
    
    __weak typeof(self) weakSelf = self;
    self.recordTimer = [[MKSourceTimer alloc] initWithTimeInterval:1 repeats:YES timerBlock:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf recordingTimer];
    }];
}

- (void)recordingTimer {
    self.duration++;
    
    if (_timerHandler) {
        _timerHandler(_duration);
    }
}

- (void)destroyTimer {
    self.duration = 0;
    
    if (self.recordTimer) {
        [self.recordTimer stopTimer];
        self.recordTimer = nil;
    }
}

#pragma mark - AudioSession -
- (void)setAudioSessionActive:(BOOL)active {
    if (active) {
        NSError *error = nil;
        /* 录音与后台音乐共存 - 录音文件较小
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord withOptions:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionAllowBluetooth error:&error];
         */
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryRecord error:&error];
        
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
    NSDictionary *info = notification.userInfo;
    AVAudioSessionInterruptionType type = [info[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    
    if (type == AVAudioSessionInterruptionTypeBegan) {
        // 暂停录音
        [self pauseRecording];
        
        if (_interruptionHandler) {
            _interruptionHandler(MKInterruptionTypeBegin);
        }
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        
        AVAudioSessionInterruptionOptions options = [info[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (options & AVAudioSessionInterruptionOptionShouldResume) {
            // 恢复录音
            [self startRecording];
            
            if (_interruptionHandler) {
                _interruptionHandler(MKInterruptionTypeEnd);
            }
        }
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopRecording];
}

@end
