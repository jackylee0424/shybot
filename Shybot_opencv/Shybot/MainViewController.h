//
//  MainViewController.h
//  Shybot
//
//  Created by Jackie Lee on 10/13/13.
//  Copyright (c) 2013 shybot.org. All rights reserved.
//
//  Important note: To smoothly run it in debug mode, iPhone/iPod needs to be docked first
//  "before" connecting the charging wire to the Mac.

#import <UIKit/UIKit.h>
#import <RMCore/RMCore.h>
#import <RMCharacter/RMCharacter.h>
#import <opencv2/highgui/cap_ios.h>
using namespace cv;

@interface MainViewController : UIViewController<RMCoreDelegate, CvVideoCameraDelegate>{
    CvVideoCamera * videoCamera;
    IBOutlet UIImageView * cvcameraview;
}

@property (nonatomic, strong) RMCoreRobot<DriveProtocol, LEDProtocol> *robot;
@property (nonatomic, strong) RMCharacter *romo; // for romo character
@property (nonatomic, retain) CvVideoCamera* videoCamera;
@property (nonatomic, retain) IBOutlet UIImageView * romo_char;

@end
