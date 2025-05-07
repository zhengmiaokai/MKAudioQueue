//
//  MKSourceTimer.h
//  Demo
//
//  Created by zhengmiaokai on 2021/9/7.
//

#import <Foundation/Foundation.h>

@interface MKSourceTimer : NSObject

/* 方法参数说明
 * timeInterval: 定时间隔
 * repeats：是否重复
 * timeBlock：定时回调
 * immediately：是否马上启动（默认为NO）
 */
- (instancetype)initWithTimeInterval:(NSTimeInterval)timeInterval repeats:(BOOL)repeats timerBlock:(void(^)(void))timerBlock;
- (instancetype)initWithTimeInterval:(NSTimeInterval)timeInterval repeats:(BOOL)repeats timerBlock:(void(^)(void))timerBlock immediately:(BOOL)immediately;

/* 方法参数说明
 * timeInterval: 定时间隔
 * repeats：是否重复
 * timeBlock：定时回调
 * timerQueue：执行定时的队列
 * blockQueue：执行回调的队列
 * immediately：是否马上启动（默认为NO）
 */
- (instancetype)initWithTimeInterval:(NSTimeInterval)timeInterval repeats:(BOOL)repeats timerBlock:(void(^)(void))timerBlock timerQueue:(dispatch_queue_t)timerQueue blockQueue:(dispatch_queue_t)blockQueue immediately:(BOOL)immediately;

- (instancetype)init UNAVAILABLE_ATTRIBUTE;

- (void)pauseTimer; // 挂起与恢复必须平衡，不然会crash

- (void)resumeTimer;

- (void)stopTimer; // 不能在挂起的状态cancel，需要恢复定时器再cancel

@end

/* 示例
 ----------------------------------------------------------------------------
 _timer = [[MKGCDSource alloc] initWithTimeInterval:3 repeats:YES timerBlock:^{
     // do something
 }];

 [_timer pauseTimer];
 [_timer resumeTimer];
 [_timer stopTimer];
 ----------------------------------------------------------------------------
 */
