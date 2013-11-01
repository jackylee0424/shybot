//
//  MainViewController.m
//  Shybot
//
//  Created by Jackie Lee on 10/13/13.
//  Copyright (c) 2013 shybot.org. All rights reserved.
//
//  Warning! Not fully functioning yet!
//

#import "MainViewController.h"

#define CAPTURE_FPS 30

@interface MainViewController ()

@end

@implementation MainViewController
@synthesize debug_status;

#pragma mark - Protocol CvVideoCameraDelegate
#ifdef __cplusplus
- (void)processImage:(cv::Mat&)image;
{
    
    // Only process every CAPTURE_FPS'th frame (every 1s)
    if (self.frameNum == CAPTURE_FPS) {
        [self parseFaces:[self.faceDetector facesFromImage:image] forImage:image];
        self.frameNum = 0;
    }
    self.frameNum++;
    
    // face interaction
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

- (bool)learnFace:(const std::vector<cv::Rect> &)faces forImage:(cv::Mat&)image personID:(int)pid
{

    if (faces.size() != 1) {
        return 0;
    }
    
    cv::Rect face = faces[0];
    [self.faceRecognizer learnFace:face ofPersonID:pid fromImage:image]; // need to find a way to make new IDs
    NSLog(@"learn a face");
    
    return YES;
}

- (void)parseFaces:(const std::vector<cv::Rect> &)faces forImage:(cv::Mat&)image
{
    if (faces.size() != 1) {
        return;
    }

    cv::Rect face = faces[0];

    CGColor *highlightColor = [[UIColor redColor] CGColor];
    
    if (self.modelAvailable) {
        NSDictionary *match = [self.faceRecognizer recognizeFace:face inImage:image];
        
        if ([match objectForKey:@"personID"] != [NSNumber numberWithInt:-1]) {
            
            NSLog(@"%@: %.2f", [match objectForKey:@"personName"], [[match objectForKey:@"confidence"]floatValue]);
            
            // confidence < thresold
            if ([[match objectForKey:@"confidence"]floatValue]<2400){
                highlightColor = [[UIColor greenColor] CGColor];
            
            }else{
                // low confidence
                NSLog(@"low confidence face recog");
                [self learnFace:faces forImage:image personID:10];
            }
            
        }else{
            // no match
            NSLog(@"no match. learn this new face.");
            [self learnFace:faces forImage:image personID:10];
        }
    
    }else{
        
        // no model, need to build one
        // need some alone time to build the model
        
        self.newfaceNumbers++;
        int pid = [self.faceRecognizer newPersonWithName:[NSString stringWithFormat:@"human%d",0]];
        
        if (self.newfaceNumbers<10){
            [self learnFace:faces forImage:image personID:pid];
        }else{
            // save 10 images then build a model
            self.modelAvailable = [self.faceRecognizer trainModel];
        }
        
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
    
    self.modelAvailable = [self.faceRecognizer trainModel]; // need to decide when to re-train the model

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

-(void) setupCamera{
    self.videoCamera = [[CvVideoCamera alloc] initWithParentView:self.cvcameraview];
    self.videoCamera.delegate = self;
    self.videoCamera.defaultAVCaptureDevicePosition = AVCaptureDevicePositionFront;
    self.videoCamera.defaultAVCaptureSessionPreset = AVCaptureSessionPresetLow;
    self.videoCamera.defaultAVCaptureVideoOrientation = AVCaptureVideoOrientationPortrait;
    self.videoCamera.defaultFPS = CAPTURE_FPS;
    self.videoCamera.grayscaleMode = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    self.faceDetector = [[FaceDetector alloc] init];
    self.faceRecognizer = [[CustomFaceRecognizer alloc] initWithEigenFaceRecognizer];
    
    NSLog(@"all people: %@",[self.faceRecognizer getAllPeople]);
    
    // personality setup (need to move to a new class)
    personality = [[NSMutableDictionary alloc] init];
    [personality setObject:[NSNumber numberWithInt: 55] forKey:@"face_size_uneasy"];
    [personality setObject:[NSNumber numberWithInt: 70] forKey:@"face_size_nervous"];
    [personality setObject:[NSNumber numberWithFloat: .1] forKey:@"arousal"];
    [personality setObject:[NSNumber numberWithFloat: .1] forKey:@"valence"];
    [personality setObject:[NSNumber numberWithFloat: 0.0] forKey:@"familiarity_to_all_users"]; //familiarity_to_IDs
    
    [self setupCamera];
    
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
