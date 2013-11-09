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
    // environment condition
    /*
     do something to setup a good learning atmosphere
     */
    if (!motion_init) {
        NSLog(@"%d x %d", image.cols ,image.rows);

        image.copyTo(prev_frame);
        motion_init = TRUE;
    }
    
    cv::absdiff(prev_frame, image, curr_frame);
    
    float env_now = cv::mean(curr_frame)[0];
   
    if (env_now < env_learn) {
        
        self.isLearning = TRUE;
        //NSLog(@"env motion: %f", env_now);
    
    }else{
        self.isLearning = FALSE;
    }
    

    // send video frames to remote server
    if ([self.webSocket connected]){
        // need to dispatch to main thread for sending ws packets
        dispatch_sync(dispatch_get_main_queue(), ^{
            //NSLog(@"ws connected. try sending packets");
            NSData * imageData = UIImageJPEGRepresentation([OpenCVData UIImageFromMat:curr_frame],.5);
            NSString * img64str = [imageData base64Encoding];
            [self.webSocket send:[NSString stringWithFormat:@"{\"base64ImageDataUrl\":\"data:image/jpeg;charset=utf-8;base64,%@\"}",img64str]];
        });
    }
    
    // face recog and face learning (every 1s)
    self.frameNum++;
    if (self.frameNum == CAPTURE_FPS) {
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self parseFaces:[self.faceDetector facesFromImage:image] forImage:image];
            
            // also re-connect every sec
            if (![self.webSocket connected]) {
                [self checkWSConnection];
            }
        });
        self.frameNum = 0;
    }
    
    // face interaction (reaction to drive motors, running in every frame)
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
    
    /// put current image into history
    image.copyTo(prev_frame);
}

- (bool)learnFace:(const std::vector<cv::Rect> &)faces forImage:(cv::Mat&)image personID:(int)pid
{

    if (faces.size() != 1) {
        return 0;
    }
    
    cv::Rect face = faces[0];
    [self.faceRecognizer learnFace:face ofPersonID:pid fromImage:image]; // need to find a way to make new IDs
    NSLog(@"learnt a new face");
    
    return YES;
}

- (void)parseFaces:(const std::vector<cv::Rect> &)faces forImage:(cv::Mat&)image
{
    if (faces.size() != 1) {
        return;
    }

    cv::Rect face = faces[0];

    //CGColor *highlightColor = [[UIColor redColor] CGColor];
    
    if (self.modelAvailable) {
        
        NSDictionary *match = [self.faceRecognizer recognizeFace:face inImage:image];
        
        if ([match objectForKey:@"personID"] != [NSNumber numberWithInt:-1]) {
            
            NSLog(@"matching %@: %.2f", [match objectForKey:@"personName"], [[match objectForKey:@"confidence"]floatValue]);
            
            // confidence < thresold
            if ([[match objectForKey:@"confidence"]floatValue]<2400){
                //highlightColor = [[UIColor greenColor] CGColor];
            
            }else{
                // low confidence
                NSLog(@"low confidence face recog");
                
                //[self learnFace:faces forImage:image personID:10];
            }
            
        }else{
            
            // no match
            NSLog(@"no match. learn this new face.");
            total_known_faces++;
            [self learnFace:faces forImage:image personID:total_known_faces];
        }
    
    }else{
        NSLog(@"no face model saved");
        
        // no model, need to build one
        // need some alone time to build the model
        
        if (self.isLearning) {
            NSLog(@"gentle stranger face found, start learning...");
            
            if (self.newfaceNumbers<1)
            {
                self.currentTarget = [self.faceRecognizer newPersonWithName:[NSString stringWithFormat:@"human%d",total_known_faces]];
            }
            else
            {
                if (self.newfaceNumbers<10){
                    [self learnFace:faces forImage:image personID:self.currentTarget];
                }else{
                    // save 10 images then build a model
                    self.modelAvailable = [self.faceRecognizer trainModel];
                    self.newfaceNumbers = 0;
                }
            }
            
            self.newfaceNumbers++;
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
    
    self.webSocket = [[WebSocket alloc] initWithURLString:@"wss://app.shybot.org:443/wsb" delegate:self];
    [self.webSocket open];
    
    self.faceDetector = [[FaceDetector alloc] init]; // use every frame
    self.faceRecognizer = [[CustomFaceRecognizer alloc] initWithEigenFaceRecognizer]; //use ever second
    
    NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
    uuid = [defaults objectForKey:@"uuid"];
    
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

    
    [NSTimer scheduledTimerWithTimeInterval:1.0f target:self selector:@selector(check_environment) userInfo:nil repeats:YES];
    
    self.dnumoffaces = 0; // reset numbers of faces
    self.newfaceNumbers = 0; // reset learning at start
    motion_init = FALSE;
    
    // learning thresold for env noise
    env_learn = 30;
    
    total_known_faces = [[self.faceRecognizer getAllPeople] count];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/* websocket */

-(void)webSocketDidClose:(WebSocket *)ws {
    NSLog(@"Connection closed");
    ws_connected = false;
    ws_failed = true;
    ws_connecting=false;
}

-(void)webSocket:(WebSocket *)ws didFailWithError:(NSError *)error {
    if (error.code == WebSocketErrorConnectionFailed) {
        NSLog(@"Connection failed");
        ws_failed=true;
        ws_connecting=false;
    } else if (error.code == WebSocketErrorHandshakeFailed) {
        NSLog(@"Handshake failed");
    } else {
        NSLog(@"Error");
    }
}

-(void)webSocket:(WebSocket *)ws didReceiveMessage:(NSString*)message {
    //NSLog(@"Received: %@", message);
    //NSLog(@"ws packet received");
    
    /*
     // Convert json base64 message to image
     NSDictionary *result = [message JSONValue];
     NSDictionary *base64body = [result objectForKey:@"body"];
     NSString *base64un = [base64body objectForKey:@"base64ImageDataUrl"];
     NSString *base64img = [base64un stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
     
     NSLog(@"Received json: %@", base64img);
     /////////
     //NSString *base64img =@"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==";
     
     NSURL *url = [NSURL URLWithString:base64img];
     NSData *imageData = [NSData dataWithContentsOfURL:url];
     UIImage *ret = [UIImage imageWithData:imageData];
     self.view.image=ret;
     */
    
}

-(void)webSocketDidOpen:(WebSocket *)ws {
    NSLog(@"Connected");
    ws_connected=true;
    ws_failed=false;
    ws_connecting=false;
    
    // test red dot
    //[ws send:@"{\"base64ImageDataUrl\": \"data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAUAAAAFCAYAAACNbyblAAAAHElEQVQI12P4//8/w38GIAXDIBKE0DHxgljNBAAO9TXL0Y4OHwAAAABJRU5ErkJggg==\"}"];
}

-(void)webSocketDidSendMessage:(WebSocket *)ws {
    //NSLog(@"Did send message");
}

-(void)reConnectWS:(WebSocket *)ws{
    [ws open];
    NSLog(@"reconnecting again");
    ws_connecting=true;
}

-(void)checkWSConnection{
    
    if (ws_connected&!ws_failed){
        bool authorized = TRUE;
        if (!authorized) {
            NSLog(@"not authorized. bye!");
        }else{
            // ready to send data
            NSLog(@"ws connected!!");
        }
    } else if (ws_failed&!ws_connecting){
        
        //auto reconnecting to server
        [self reConnectWS:self.webSocket];
        
    } else {
        NSLog(@"wait for server response.");
    }
}


@end
