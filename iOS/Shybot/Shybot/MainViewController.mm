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
@synthesize debug_status;

#pragma mark - Protocol CvVideoCameraDelegate
#ifdef __cplusplus
- (void)processImage:(cv::Mat&)image;
{
    const std::vector<cv::Rect> faces = [self.faceDetector facesFromImage:image];
    if (faces.size()>0){
        self.dnumoffaces =1;
        
        // dispatch to main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self highlightFace:[OpenCVData faceToCGRect:faces[0]] withColor:[[UIColor cyanColor] CGColor]];
            [self.debug_status setText:[NSString stringWithFormat:@"face:(%d, %d), size: %d",faces[0].x,faces[0].y,faces[0].width]];
            
            // show face ROI
            cv::Rect myROI(faces[0].x,faces[0].y,faces[0].width,faces[0].height);
            cv::Mat croppedImage;
            cv::Mat(image, myROI).copyTo(croppedImage);
            self.cvroiview.image = [OpenCVData UIImageFromMat:croppedImage];
            
            // speed up shybot's heart rate
            [self.robot.LEDs pulseWithPeriod:.8 direction:RMCoreLEDPulseDirectionUpAndDown];
            
            if (faces[0].height>[[personality objectForKey:@"face_size_uneasy"]intValue]){
                
                // speed up shybot's heart rate more
                [self.robot.LEDs pulseWithPeriod:0.3 direction:RMCoreLEDPulseDirectionUpAndDown];
                [self.debug_status setText:@"it's too close!"];
                
                if (faces[0].height>[[personality objectForKey:@"face_size_nervous"]intValue]){
                    // make shybot run backward
                    if (!self.robot.isDriving) {
                        [self.robot driveBackwardWithSpeed:.5];
                        self.debug_status.text = @"way too close!!";
                    }else{
                        self.debug_status.text = @"running away~~";
                    }
                }
                
            }else{
                // in good distance, be curious
                if (self.robot.isDriving)
                    [self.robot stopDriving];
                //[self.robot driveForwardWithSpeed:.2];
                self.debug_status.text = @"who r u?";
            }

        });
    }
    else
    {
        
        self.dnumoffaces =0;
        // dispatch to main thread
        dispatch_sync(dispatch_get_main_queue(), ^{
            self.featureLayer.hidden = YES;
            // in a distance, recovered, start be curious
            [self.robot.LEDs pulseWithPeriod:5.0 direction:RMCoreLEDPulseDirectionUpAndDown];
            //if (self.robot.isDriving)[self.robot stopDriving];
        });
         
    }
}
#endif

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

    // init Romo
    if (robot.isDrivable && robot.isHeadTiltable && robot.isLEDEquipped) {
        self.robot = (RMCoreRobot<DriveProtocol, LEDProtocol> *) robot;
    
        NSLog(@"Romo dock connected!");
        [self.robot.LEDs pulseWithPeriod:5.0 direction:RMCoreLEDPulseDirectionUpAndDown];
    }
}

- (void)robotDidDisconnect:(RMCoreRobot *)robot
{
    if (robot == self.robot) {
        self.robot = nil;
        NSLog(@"Romo dock disconnected");
        [self.robot.LEDs turnOff];
    }
}

- (void)viewWillAppear:(BOOL)animated
{

}

- (void)check_environment{
    
    // if nothing happening (aka no faces), be curious, move forward
    if (self.dnumoffaces<1){
        if (!self.robot.isDriving)
            [self.robot driveForwardWithSpeed:.2];
        else
            [self.robot stopDriving];
            
        self.debug_status.text = @"what's happening?";
    }
    /*
    else{
        [self.robot stopDriving];
    }*/
    
    
    
    
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    /*
    // got some problem of duplicate symbols.
    // Create firebase data repo
    f = [[Firebase alloc] initWithUrl:@"https://shybot.firebaseIO.com/"];
    
    // Write data to Firebase
    [f setValue:@"connected" forKey:@"state"];
    
    // Read data and react to changes
    [f observeEventType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        NSLog(@"%@ -> %@", snapshot.name, snapshot.value);
    }];*/
    
    // personality setup (need to move to a new class)
    personality = [[NSMutableDictionary alloc] init];
    [personality setObject:[NSNumber numberWithInt: 55] forKey:@"face_size_uneasy"];
    [personality setObject:[NSNumber numberWithInt: 70] forKey:@"face_size_nervous"];
    [personality setObject:[NSNumber numberWithFloat: .1] forKey:@"arousal"];
    [personality setObject:[NSNumber numberWithFloat: .1] forKey:@"valence"];
    [personality setObject:[NSNumber numberWithFloat: 0.0] forKey:@"familiarity_to_all_users"]; //familiarity_to_IDs
    
    self.faceDetector = [[FaceDetector alloc] init];
    
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:self.cvcameraview];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetLow;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = 30;
    self.videoCamera.grayscaleMode = YES;
    
    [RMCore setDelegate:self];

    self.dnumoffaces = 0;
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(check_environment) userInfo:nil repeats:YES];
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
