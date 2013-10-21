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
#import "FaceDetector.h"
#import "OpenCVData.h"

using namespace cv;

@interface MainViewController : UIViewController<RMCoreDelegate, CvVideoCameraDelegate>{
    //CvVideoCamera * videoCamera;
    //IBOutlet UIImageView
    
}
@property (nonatomic, strong) IBOutlet UIImageView * cvcameraview;
@property (nonatomic, strong) RMCoreRobot<DriveProtocol, LEDProtocol> *robot;
//@property (nonatomic, strong) RMCharacter *romo; // for romo character
@property (nonatomic, strong) CvVideoCamera* videoCamera;
//@property (nonatomic, strong) IBOutlet UIImageView * romo_char;
@property (nonatomic, strong) FaceDetector *faceDetector;
@property (nonatomic, strong) CALayer *featureLayer;
@property (nonatomic, retain) IBOutlet UILabel * debug_status;
@end
