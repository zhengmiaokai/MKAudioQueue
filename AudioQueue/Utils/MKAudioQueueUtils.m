//
//  MKAudioQueueUtils.m
//  Demo
//
//  Created by zhengmiaokai on 2025/4/8.
//

#import "MKAudioQueueUtils.h"
#import "MKAudioQueueConstants.h"

@implementation MKAudioQueueUtils

+ (NSString *)audioFilePathWithAudioId:(NSString *)audioId {
    NSString* documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *directory = [self _forderPathWithFolderName:kAudioQueueFolderName directoriesPath:documentPath];
    
    NSString* filePath = [self _pathWithFileName:[NSString stringWithFormat:@"audio_%@.pcm", audioId] foldPath:directory];
    return filePath;
}

#pragma mark - Private -
+ (NSString *)_forderPathWithFolderName:(NSString*)folderName directoriesPath:(NSString *)directoriesPath {
    NSString* folderPath = [directoriesPath stringByAppendingPathComponent:folderName];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL isDir = NO;
    BOOL isDirExist = [fileManager fileExistsAtPath:folderPath isDirectory:&isDir];
    if(!(isDirExist && isDir)) {
        BOOL bCreateDir = [fileManager createDirectoryAtPath:folderPath withIntermediateDirectories:YES attributes:nil error:nil];
        if(!bCreateDir){
            NSLog(@"Create Audio Directory Failed.");
        }
    }
    return folderPath;
}

+ (NSString*)_pathWithFileName:(NSString*)fileName foldPath:(NSString*)folderPath {
    NSString* filePath = [folderPath stringByAppendingPathComponent:fileName];
    return filePath;
}

@end

