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

@interface MainViewController : UIViewController<RMCoreDelegate>

@property (nonatomic, strong) RMCoreRobot<DriveProtocol, LEDProtocol> *robot;
@property (nonatomic, strong) RMCharacter *romo; // for romo character

@end
