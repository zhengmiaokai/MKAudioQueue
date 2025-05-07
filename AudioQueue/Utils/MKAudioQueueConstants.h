//
//  MKAudioRecordConstants.h
//  Demo
//
//  Created by zhengmiaokai on 2025/4/9.
//

#ifndef MKAudioRecordConstants_h
#define MKAudioRecordConstants_h

#import <Foundation/Foundation.h>

#define kAudioQueueFolderName    @"AudioQueue"

static NSString * const MKAudioRecordStartNotification = @"AudioRecordStartNotification";
static NSString * const MKAudioRecordStopNotification  = @"AudioRecordStopNotification";

static NSString * const MKAudioPlayStartNotification = @"AudioPlayStartNotification";
static NSString * const MKAudioPlayStopNotification  = @"AudioPlayStopNotification";

typedef NS_ENUM(NSUInteger, MKAudioQuality) {
    MKAudioQualityLow     = 1,
    MKAudioQualityMiddle  = 2,
    MKAudioQualityHigh    = 3
};

typedef NS_ENUM(NSUInteger, MKAudioStatus) {
    MKAudioStatusStop    = 0,
    MKAudioStatusPrepare = 1,
    MKAudioStatusStart   = 2,
    MKAudioStatusPause   = 3
};

typedef NS_ENUM(NSUInteger, MKInterruptionType) {
    MKInterruptionTypeBegin  = 1,
    MKInterruptionTypeEnd    = 2
};

#endif /* MKAudioRecordConstants */
