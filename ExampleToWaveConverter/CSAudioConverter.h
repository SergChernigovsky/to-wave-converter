//
//  CSAudioConverter.h
//  Pitch Shifter - Slow Downer
//
//  Created by Sergey Chernigovsky on 12.10.15.
//  Copyright © 2015 AM. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@interface CSAudioConverter : NSObject

+ (CSAudioConverter*)sharedInstance;
- (void) convertInput: (NSString*) myFile toOutput: (NSString*) newFile;

@end
