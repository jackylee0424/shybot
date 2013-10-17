//
//  MainViewController.m
//  Shybot
//
//  Created by Jackie Lee on 10/13/13.
//  Copyright (c) 2013 shybot.org. All rights reserved.
//

#import "MainViewController.h"

@interface MainViewController ()

@end

@implementation MainViewController

#pragma mark - Protocol CvVideoCameraDelegate
#ifdef __cplusplus
- (void)processImage:(cv::Mat&)image;
{
    const std::vector<cv::Rect> faces = [self.faceDetector facesFromImage:image];
    if (faces.size()>0){
        NSLog(@"face: %d, %d, %d, %d",faces[0].x,faces[0].y,faces[0].width,faces[0].height);
        // All changes to the UI have to happen on the main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self highlightFace:[OpenCVData faceToCGRect:faces[0]] withColor:[[UIColor cyanColor] CGColor]];
        });
    }
    else
    {
        [self noFaceToDisplay];
    }
}
#endif

- (void)noFaceToDisplay
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.featureLayer.hidden = YES;
    });
}

- (void)highlightFace:(CGRect)faceRect withColor:(CGColor *)color
{
    if (self.featureLayer == nil) {
        self.featureLayer = [[CALayer alloc] init];
        self.featureLayer.borderWidth = 1.0;
    }
    
    [self.cvcameraview.layer addSublayer:self.featureLayer];
    
    self.featureLayer.hidden = NO;
    self.featureLayer.borderColor = color;
    self.featureLayer.frame = faceRect;
}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    [self.videoCamera start];
}

- (void)robotDidConnect:(RMCoreRobot *)robot
{
    // Currently the only kind of robot is Romo3, which supports all of these
    //  protocols, so this is just future-proofing
    if (robot.isDrivable && robot.isHeadTiltable && robot.isLEDEquipped) {
        self.robot = (RMCoreRobot<DriveProtocol, LEDProtocol> *) robot;
        
        // When we plug Romo in, he get's excited!
        //self.romo.expression = RMCharacterExpressionExcited;
        NSLog(@"connected!");
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.robot) {
        self.robot = nil;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    // Add Romo's face to self.view whenever the view will appear
    //[self.romo addToSuperview:self.romo_char];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.faceDetector = [[FaceDetector alloc] init];
    
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:self.cvcameraview];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetLow;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = YES;
    
    
    [RMCore setDelegate:self];
    
    // Grab a shared instance of the Romo character
    //self.romo = [RMCharacter Romo];
    
    

    
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
