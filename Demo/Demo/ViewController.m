//
//  ViewController.m
//  Demo
//
//  Created by zhengmiaokai on 2025/4/3.
//

#import "ViewController.h"
#import "MKAudioQueueUtils.h"
#import "MKAudioRecorder.h"
#import "MKAudioPlayer.h"

@interface ViewController ()

@property (nonatomic, strong) MKAudioRecorder *audioRecorder;

@property (nonatomic, strong) MKAudioPlayer *audioPlayer;

@property (nonatomic, strong) NSMutableArray *pcmDatas;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

#pragma mark - Action -
- (IBAction)record:(id)sender {
    self.pcmDatas = [NSMutableArray array];
    
    NSString *filePath = [MKAudioQueueUtils audioFilePathWithAudioId:@"123456"];
    [self.audioRecorder prepareRecording:MKAudioQualityHigh filePath:filePath];
    
    [self.audioRecorder startRecording];
}

- (IBAction)stopRecord:(id)sender {
    [self.audioRecorder stopRecording];
}
 
- (IBAction)playInputStream:(id)sender {
    NSString *filePath = [MKAudioQueueUtils audioFilePathWithAudioId:@"123456"];
    [self.audioPlayer preparePlaying:MKAudioQualityHigh filePath:filePath];
    
    [self.audioPlayer startPlaying];
}

- (IBAction)playPcmDatas:(id)sender {
    [self.audioPlayer preparePlaying:MKAudioQualityHigh];
    
    self.audioPlayer.pcmDatas = self.pcmDatas;
    [self.audioPlayer startPlaying];
}

- (IBAction)stopPlay:(id)sender {
    [self.audioPlayer stopPlaying];
}

#pragma mark - Getter -
- (MKAudioRecorder *)audioRecorder {
    if (!_audioRecorder) {
        _audioRecorder = [[MKAudioRecorder alloc] init];
        
        __weak typeof(self) weakSelf = self;
        [_audioRecorder setTimerHandler:^(NSInteger duration) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            strongSelf.durationLab.text = [NSString stringWithFormat:@"%ld", (long)duration];
        }];
        
        [_audioRecorder setBufferHandler:^(void *const audioData, UInt32 dataByteSize) {
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (dataByteSize > 0) {
                NSData* tAudioData = [NSData dataWithBytes:audioData length:dataByteSize];
                [strongSelf.pcmDatas addObject:tAudioData];
                NSLog(@"%@", tAudioData);
            }
        }];
    }
    return _audioRecorder;
}

- (MKAudioPlayer *)audioPlayer {
    if (!_audioPlayer) {
        _audioPlayer = [[MKAudioPlayer alloc] init];
        
        [_audioPlayer setErrorHandler:^(OSStatus code, NSString *message) {
            NSLog(@"code: %d, message: %@", code, message);
        }];
    }
    return _audioPlayer;
}

@end
