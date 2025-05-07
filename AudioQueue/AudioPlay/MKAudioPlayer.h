//
//  MKAudioPlayer.h
//  Demo
//
//  Created by zhengmiaokai on 2025/4/24.
//

#import <Foundation/Foundation.h>
#import "MKAudioQueueConstants.h"

@interface MKAudioPlayer : NSObject

@property (nonatomic, copy) void(^interruptionHandler)(MKInterruptionType type);

@property (nonatomic, copy) void(^errorHandler)(OSStatus code, NSString *message);

@property (nonatomic, copy) void(^statusHandler)(MKAudioStatus playStatus);

@property (nonatomic, copy) NSArray *pcmDatas; // pcmDatas | filePath

- (void)preparePlaying:(MKAudioQuality)quality;
- (void)preparePlaying:(MKAudioQuality)quality filePath:(NSString *)filePath;

- (void)startPlaying;

- (void)pausePlaying;

- (void)stopPlaying;

@end
