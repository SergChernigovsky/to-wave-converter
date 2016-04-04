//
//  ViewController.m
//  ExampleToWaveConverter
//
//  Created by Sergey Chernigovsky on 04.04.16.
//  Copyright © 2016 My. All rights reserved.
//

#import "ViewController.h"

@implementation ViewController

{
@protected NSURL* urlInput;
@protected NSURL* urlOutput;
@protected NSURL* urlOutputFile;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

- (IBAction)open:(id)sender {
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    // Свойства диалога
    [openDlg setCanChooseFiles:YES];
    [openDlg setCanChooseDirectories:NO];
    [openDlg setAllowsMultipleSelection:NO];
    [openDlg setAllowedFileTypes:[NSArray arrayWithObjects:
                                  @"mp3",
                                  @"aif",
                                  @"aiff",
                                  @"aifc",
                                  @"cda",
                                  @"cdda",
                                  @"caf",
                                  @"m4v",
                                  @"mp4",
                                  @"m4a",
                                  @"mov",
                                  @"qt",
                                  @"wav",
                                  @"wave",
                                  @"bwf",
                                  @"amr",
                                  @"ac3",
                                  @"au",
                                  @"snd",
                                  nil]];
    // Если запуск вернул нажатие кнопки OK - обработать выбранные файлы
    if ( [openDlg runModal] == NSFileHandlingPanelOKButton ) {
        urlInput = [openDlg URL];
        _textInput.string = urlInput.path;
        _buttonOpen.enabled = YES;
        _buttonOutput.enabled = YES;
    }
}

- (IBAction)convert:(id)sender {
    urlOutputFile = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/output.wav", urlOutput.path]];
    if ([self symbolCheck]) {
        
        {[[CSAudioConverter sharedInstance] convertInput:urlInput.path
                                                toOutput:[NSString stringWithFormat:@"%@/output.wav", urlOutput.path]];}
        [self showUrl:urlOutputFile];
    }
}

- (IBAction)show:(id)sender {
    if (urlOutputFile)
        [self showUrl:urlOutputFile];
    else
        [self showUrl:urlOutput];
}
- (IBAction)output:(id)sender {
    NSOpenPanel *openDlg = [NSOpenPanel openPanel];
    // Свойства диалога
    [openDlg setCanChooseFiles:NO];
    [openDlg setCanChooseDirectories:YES];
    [openDlg setAllowsMultipleSelection:NO];
    // Если запуск вернул нажатие кнопки OK - обработать выбранные файлы
    if ( [openDlg runModal] == NSFileHandlingPanelOKButton ) {
        urlOutput = [openDlg URL];
        _textOutput.string = urlOutput.path;
        _buttonConvert.enabled = YES;
        _buttonShow.enabled = YES;
    }
}

-(BOOL) symbolCheck{
    if ([urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"#"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@";"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@">"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"<"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"^"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"{"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"}"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"|"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"?"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"\\"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"`"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"§"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"±"].length > 0 ||
        [urlInput.path.lastPathComponent.stringByDeletingPathExtension rangeOfString:@"№"].length > 0)
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:@"The file name can not contain these sybmols «#», «;», «<», «>», «^», «{», «}», «|», «?», «\\», «`», «§», «±», and «№»!"];
        [alert setAlertStyle:2];
        [alert runModal];
        return NO;
    }else{
        return YES;
    }
}

-(void) showUrl:(NSURL*) url{
    NSArray *fileURLs = [NSArray arrayWithObjects:urlOutputFile, nil];
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

@end
