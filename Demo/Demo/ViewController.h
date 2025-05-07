//
//  ViewController.h
//  Demo
//
//  Created by zhengmiaokai on 2025/4/3.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

@property (strong, nonatomic) IBOutlet UILabel *durationLab;

- (IBAction)record:(id)sender;

- (IBAction)stopRecord:(id)sender;

- (IBAction)playInputStream:(id)sender;

- (IBAction)playPcmDatas:(id)sender;

- (IBAction)stopPlay:(id)sender;

@end

