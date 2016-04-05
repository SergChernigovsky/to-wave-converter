//
//  ViewController.h
//  ExampleToWaveConverter
//
//  Created by Sergey Chernigovsky on 04.04.16.
//  Copyright © 2016 My. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CSAudioConverter.h"

@interface ViewController : NSViewController

@property (weak) IBOutlet NSButton *buttonOpen;
@property (weak) IBOutlet NSButton *buttonConvert;
@property (weak) IBOutlet NSButton *buttonOutput;
@property (weak) IBOutlet NSButton *buttonShow;
@property (unsafe_unretained) IBOutlet NSTextView *textInput;
@property (unsafe_unretained) IBOutlet NSTextView *textOutput;
@property (weak) IBOutlet NSVisualEffectView *viewBlur;
@property (weak) IBOutlet NSProgressIndicator *spin;

@end

