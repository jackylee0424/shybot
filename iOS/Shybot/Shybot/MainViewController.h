//
//  MainViewController.h
//  Shybot
//
//  Created by Jackie Lee on 10/13/13.
//  Copyright (c) 2013 shybot.org. All rights reserved.
//
//  Romo tips: To smoothly run it in debug mode, iPhone/iPod needs to be docked first
//  "before" connecting the charging wire to the Mac and click "ignore" so that it
//  won't launch its default app
//
//  Shybot's social design architecture (adding computational dimensions for exhibiting social behaviors)
//      - extending asimov's laws
//          * augment what we can do as a human - Roz Picard
//          (e.g., with infinite patience and dissemination of information) 
//          * Companion robots could babysit children and develop relationships - Sherry Turkle
//          * inner modalities (float -1~1): (global) arousal / (global) valence / (relative) familiarity
//
//      - primitive social capacities (operating on inner modality)
//          * friendly event (arousal < .5, valence > 0, familiarity ++)
//              causes: gently approach, smile, stable environment
//              expressions: be positive, inviting, approaching, following
//          * strange event (arousal > .5, valence -- , familiarity --)
//              causes: sudden actions, noisy, unstable environment
//              expressions: escaping, avoiding, dissappointing
//          * social tolerance: (relative familiarity)
//
//      - social logging (age 3~5)
//          motorized baby monitor for sharing parents' attention 
//          * contextual/behaviroal data matrics
//              (inspired by Deb Roy's data house, but all the sensing is embedded in shybot)
//              1. language learning (speech and words logging)
//              2. vocabulary evolution
//              3. chances for accelerated learning
//              4. inner state logging
//
//      - programmable social interaction (age 5~7)
//          * personalities of Shybots
//            friend recog workflow (relative familiarity ++)
//              1. find face - opencv face detection
//              2. remember face - save it to sqlite (or save it to a model)
//              3. train face (need a way to refresh its model)
//              4. find new/stranger's face (discriminate from existing faces using confidence value)
//              5. increase familiarity (more history in model) -> increase tolerance
//
//          * swarm behaviors of Shybots
//              1. Resonance by distance^2
//              2. Global sync
//      
//  Shybot's basic consumer rules (abstracting out Romo's motor control with firebase)
//      - find people in 2D space
//          1. guess/detect face/ambient activity (this part needs to be robust)
//          2. turn to that direction
//          3. move forward slowly
//
//      - social distance
//          1. keep a comfortable distance based on relative familiarity
//
//
//  Shybot's industrial design guidelines (to make it work for consumers)
//      - checkout out some related robot movies (walle, indisplicable me for their shapes.
//      - sphere-like durable
//      - safety, no exposed moving parts
//      - sealed full-angle camera view or rotating camera
//      - expressions
//          1. shape/enclosure (kinectic parts)
//          2. graphical (give its users more awareness of what's happening)
//
//  related ideas:
//      - reset face/friend model by using a device (from MIB movie)
//      - behavioral modification toys (inspired by drinking cups with count downs)


#import <UIKit/UIKit.h>
#import <RMCore/RMCore.h>
#import <RMCharacter/RMCharacter.h>
#import <opencv2/highgui/cap_ios.h>
#import "FaceDetector.h"
#import "OpenCVData.h"



using namespace cv;

@interface MainViewController : UIViewController<RMCoreDelegate, CvVideoCameraDelegate>{
    NSMutableDictionary * personality;
    
}

// motor / LED control
@property (nonatomic, strong) RMCoreRobot<DriveProtocol, LEDProtocol> *robot;

// for face detection
@property (nonatomic, strong) CvVideoCamera* videoCamera;
@property (nonatomic, strong) IBOutlet UIImageView * cvcameraview;
@property (nonatomic, strong) FaceDetector *faceDetector;
@property (nonatomic, strong) CALayer *featureLayer;
@property (nonatomic, readwrite) int dnumoffaces;

// debug
@property (nonatomic, strong) IBOutlet UILabel * debug_status;

/*
// romo character (disabled)
@property (nonatomic, strong) RMCharacter *romo; // for romo character
@property (nonatomic, strong) IBOutlet UIImageView * romo_char;
*/

@end
