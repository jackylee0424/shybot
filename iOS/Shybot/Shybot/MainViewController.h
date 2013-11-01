//
//  MainViewController.h
//  Shybot
//
//  Created by Jackie Lee on 10/13/13.
//  Copyright (c) 2013 shybot.org. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <RMCore/RMCore.h>
#import <RMCharacter/RMCharacter.h>
#import <opencv2/highgui/cap_ios.h>
#import "FaceDetector.h"
#import "OpenCVData.h"
#import "CustomFaceRecognizer.h"

using namespace cv;

@interface MainViewController : UIViewController<RMCoreDelegate, CvVideoCameraDelegate>{
    NSMutableDictionary * personality;
}

// motor / LED control
@property (nonatomic, strong) RMCoreRobot<DriveProtocol, LEDProtocol> *robot;

// for face detection
@property (nonatomic, strong) CvVideoCamera* videoCamera;
@property (nonatomic, strong) IBOutlet UIImageView * cvcameraview;
@property (nonatomic, strong) IBOutlet UIImageView * cvroiview;
@property (nonatomic, strong) FaceDetector *faceDetector;
@property (nonatomic, strong) CustomFaceRecognizer *faceRecognizer;
@property (nonatomic, strong) CALayer *featureLayer;
@property (nonatomic, readwrite) int dnumoffaces;
@property (nonatomic) NSInteger frameNum;
@property (nonatomic) BOOL modelAvailable;
@property (nonatomic) NSInteger newfaceNumbers;

// debug
@property (nonatomic, strong) IBOutlet UILabel * debug_status;

/*
// romo character (disabled)
@property (nonatomic, strong) RMCharacter *romo; // for romo character
@property (nonatomic, strong) IBOutlet UIImageView * romo_char;
*/

@end
