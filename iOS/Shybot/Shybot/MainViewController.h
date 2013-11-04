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
#import "WebSocket/WebSocket.h"

using namespace cv;

@interface MainViewController : UIViewController<   RMCoreDelegate,
                                                    CvVideoCameraDelegate,
                                                    WebSocketDelegate
                                                >
{
    NSMutableDictionary * personality;
    NSString * uuid;
    
    // websocket
    BOOL ws_connected;
    BOOL ws_failed;
    BOOL ws_connecting;
    
    // motion detection
    
}

// motor / LED control
@property (nonatomic, strong) RMCoreRobot<DriveProtocol, LEDProtocol> *robot;

// for face detection
@property (nonatomic, strong) CvVideoCamera* videoCamera;
@property (nonatomic, strong) IBOutlet UIImageView * cvcameraview;
@property (nonatomic, strong) IBOutlet UIImageView * cvroiview;
@property (nonatomic, strong) IBOutlet UIImageView * cvmotionview;
@property (nonatomic, strong) FaceDetector *faceDetector;
@property (nonatomic, strong) CustomFaceRecognizer *faceRecognizer;
@property (nonatomic, strong) CALayer *featureLayer;
@property (nonatomic, readwrite) int dnumoffaces;
@property (nonatomic) NSInteger frameNum;
@property (nonatomic) BOOL modelAvailable;
@property (nonatomic) BOOL isLearning; // is it a good time/environment to learn?
@property (nonatomic) NSInteger newfaceNumbers;
@property (nonatomic) NSInteger currentTarget; // current target to learn from

@property (nonatomic, strong) WebSocket* webSocket;

// debug
@property (nonatomic, strong) IBOutlet UILabel * debug_status;

/*
// romo character (disabled)
@property (nonatomic, strong) RMCharacter *romo; // for romo character
@property (nonatomic, strong) IBOutlet UIImageView * romo_char;
*/

@end
