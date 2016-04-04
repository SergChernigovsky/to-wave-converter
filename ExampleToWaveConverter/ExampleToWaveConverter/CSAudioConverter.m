//
//  CSAudioConverter.m
//  Pitch Shifter - Slow Downer
//
//  Created by Sergey Chernigovsky on 12.10.15.
//  Copyright © 2015 AM. All rights reserved.
//

#import "CSAudioConverter.h"

@implementation CSAudioConverter

+ (CSAudioConverter*)sharedInstance{
    static CSAudioConverter* _sharedInstance;
    static dispatch_once_t oncePredicate;
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[CSAudioConverter alloc] init];
    });
    return _sharedInstance;
}

typedef struct MyAudioConverterSettings {
    AudioStreamBasicDescription inputFormat;
    AudioStreamBasicDescription outputFormat;
    AudioFileID inputFile;
    AudioFileID outputFile;
    UInt64 inputFilePacketIndex;
    UInt64 inputFilePacketCount;
    UInt32 inputFilePacketMaxSize;
    AudioStreamPacketDescription *inputFilePacketDescriptions;
    void *sourceBuffer;
} MyAudioConverterSettings;

static void CheckError(OSStatus error, const char *operation) {
    if (error == noErr) return;
    char errorString[20];
    // Смотрим, похоже ли на 4-значный код
    *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error);
    if (isprint(errorString[1]) && isprint(errorString[2]) && isprint(errorString[3]) && isprint(errorString[4]))
    {
        errorString[0] = errorString[5] = '\''; errorString[6] = '\0';
    } else
        // Нет, форматируем как целое число
        sprintf(errorString, "%d", (int)error);
    fprintf(stderr, "Ошибка: %s (%s)\n", operation, errorString);
    exit(1);
}

void Convert(MyAudioConverterSettings *mySettings) {
    // Создать объект audioConverter
    AudioConverterRef audioConverter;
    NSLog(@"sizePerPacket = %i", mySettings->inputFormat.mBytesPerPacket);
    CheckError (AudioConverterNew(&mySettings->inputFormat, &mySettings->outputFormat, &audioConverter), "ошибка AudioConveterNew");
    UInt32 packetsPerBuffer = 0;
    UInt32 outputBufferSize = 32 * 1024; // 32 КБ – неплохая отправная точка
    UInt32 sizePerPacket = mySettings->inputFormat.mBytesPerPacket; //0
    if (sizePerPacket == 0)
    {
        UInt32 size = sizeof(sizePerPacket);
        CheckError(AudioConverterGetProperty(audioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &size, &sizePerPacket), "не могу получить kAudioConverterPropertyMaximumOutputPacketSize");
        NSLog(@"sizePerPacket = %i", sizePerPacket);
        if (sizePerPacket > outputBufferSize)
            outputBufferSize = sizePerPacket;
        packetsPerBuffer = outputBufferSize / sizePerPacket;
        // 8 192 = 32 768 / 4
        mySettings->inputFilePacketDescriptions = (AudioStreamPacketDescription*)malloc(sizeof(AudioStreamPacketDescription) * packetsPerBuffer);
    }
    else
    {
        packetsPerBuffer = outputBufferSize / sizePerPacket;
    }
    UInt8 *outputBuffer = (UInt8 *)malloc(sizeof(UInt8) * outputBufferSize);
    UInt32 outputFilePacketPosition = 0;
    int i = 0;
    while(1)
    {
        
        i++;
        AudioBufferList convertedData;
        convertedData.mNumberBuffers = 1;
        convertedData.mBuffers[0].mNumberChannels = mySettings->inputFormat.mChannelsPerFrame;
        convertedData.mBuffers[0].mDataByteSize = outputBufferSize;
        convertedData.mBuffers[0].mData = outputBuffer;
        UInt32 ioOutputDataPackets = packetsPerBuffer;
        OSStatus error = AudioConverterFillComplexBuffer(audioConverter,
                                                         MyAudioConverterCallback,
                                                         mySettings,
                                                         &ioOutputDataPackets,
                                                         &convertedData, (mySettings->inputFilePacketDescriptions ?
                                                                          mySettings->inputFilePacketDescriptions : nil));
        if (error || !ioOutputDataPackets)
        {
            break; // Это условие выхода из цикла
        }
        CheckError (AudioFileWritePackets(mySettings->outputFile, FALSE, ioOutputDataPackets, NULL, outputFilePacketPosition / mySettings->outputFormat.mBytesPerPacket, &ioOutputDataPackets, convertedData.mBuffers[0].mData), "не могу записать пакеты в файл");
        outputFilePacketPosition += (ioOutputDataPackets * mySettings->outputFormat.mBytesPerPacket);
        NSLog(@"шаг = %i", (ioOutputDataPackets * mySettings->outputFormat.mBytesPerPacket)/2);
        NSLog(@"mBytesPerPacket = %i", mySettings->outputFormat.mBytesPerPacket);
        NSLog(@"ioOutputDataPackets = %i", outputFilePacketPosition);
    }
    NSLog(@"i = %i", i);
    AudioConverterDispose(audioConverter);
}

OSStatus MyAudioConverterCallback(AudioConverterRef inAudioConverter,
                                  UInt32 *ioDataPacketCount,
                                  AudioBufferList *ioData,
                                  AudioStreamPacketDescription **outDataPacketDescription,
                                  void *inUserData){
    MyAudioConverterSettings *audioConverterSettings = (MyAudioConverterSettings *)inUserData;
    ioData->mBuffers[0].mData = NULL;
    ioData->mBuffers[0].mDataByteSize = 0;
    if (audioConverterSettings->inputFilePacketIndex + *ioDataPacketCount > audioConverterSettings->inputFilePacketCount)
        *ioDataPacketCount = (audioConverterSettings->inputFilePacketCount - audioConverterSettings->inputFilePacketIndex);
    if (*ioDataPacketCount == 0)
        return noErr;
    if (audioConverterSettings->sourceBuffer != NULL)
    {
        free(audioConverterSettings->sourceBuffer);
        audioConverterSettings->sourceBuffer = NULL;
    }
    audioConverterSettings->sourceBuffer = (void *)calloc(1, *ioDataPacketCount * audioConverterSettings->inputFilePacketMaxSize);
    UInt32 outByteCount = 0;
    OSStatus result = AudioFileReadPackets(audioConverterSettings->inputFile,true, &outByteCount, audioConverterSettings->inputFilePacketDescriptions, audioConverterSettings->inputFilePacketIndex, ioDataPacketCount, audioConverterSettings->sourceBuffer);

    if (result == eofErr && *ioDataPacketCount)
        result = noErr;
    else if (result != noErr)
        return result;
    audioConverterSettings->inputFilePacketIndex += *ioDataPacketCount;
    ioData->mBuffers[0].mData = audioConverterSettings->sourceBuffer;
    ioData->mBuffers[0].mDataByteSize = outByteCount;
    if (outDataPacketDescription)
        *outDataPacketDescription = audioConverterSettings->inputFilePacketDescriptions;
    return result;
}

- (void) convertInput: (NSString*) myFile toOutput: (NSString*) newFile{
    MyAudioConverterSettings audioConverterSettings = {0};
    CFStringRef inputFile = (__bridge CFStringRef)myFile;
    CFURLRef inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, inputFile, kCFURLPOSIXPathStyle,false);
    CheckError (AudioFileOpenURL(inputFileURL, kAudioFileReadPermission, 0, &audioConverterSettings.inputFile), "ошибка AudioFileOpenURL");
    CFRelease(inputFileURL);
    UInt32 propSize = sizeof(audioConverterSettings.inputFormat);
    CheckError (AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyDataFormat, &propSize, &audioConverterSettings.inputFormat),"не могу получить формат данных в файле");
    // получить полное число пакетов в файле
    propSize = sizeof(audioConverterSettings.inputFilePacketCount);
    CheckError (AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyAudioDataPacketCount, &propSize, &audioConverterSettings.inputFilePacketCount), "не могу получить количество пакетов в файле");
    // получить размер максимально возможного пакета
    propSize = sizeof(audioConverterSettings.inputFilePacketMaxSize);
    CheckError(AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyMaximumPacketSize, &propSize, &audioConverterSettings.inputFilePacketMaxSize), "не могу получить размер максимального пакета");
    
    // WAVE
        audioConverterSettings.outputFormat.mSampleRate = 44100.0;
        audioConverterSettings.outputFormat.mFormatID = kAudioFormatLinearPCM;
        audioConverterSettings.outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        audioConverterSettings.outputFormat.mBytesPerPacket = 4;
        audioConverterSettings.outputFormat.mFramesPerPacket = 1;
        audioConverterSettings.outputFormat.mBytesPerFrame = 4;
        audioConverterSettings.outputFormat.mChannelsPerFrame = 2;
        audioConverterSettings.outputFormat.mBitsPerChannel = 16;
     
        CFStringRef outputFile = (__bridge CFStringRef)newFile;
        CFURLRef outputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, outputFile, kCFURLPOSIXPathStyle, false);
        CheckError (AudioFileCreateWithURL(outputFileURL, kAudioFileWAVEType, &audioConverterSettings.outputFormat, kAudioFileFlags_EraseFile, &audioConverterSettings.outputFile),"ошибка AudioFileCreateWithURL");
        CFRelease(outputFileURL);

    fprintf(stdout, "Идет преобразование в lpcm...\n");
    
    Convert(&audioConverterSettings);
cleanup:
    AudioFileClose(audioConverterSettings.inputFile);
    AudioFileClose(audioConverterSettings.outputFile);
    fprintf(stdout, "Преобразование в lpcm завершено!");
}

- (AudioStreamBasicDescription) getASBD: (NSString*) myFile{
    MyAudioConverterSettings audioConverterSettings = {0};
    CFURLRef inputFileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, (CFStringRef)myFile, kCFURLPOSIXPathStyle,false);
    CheckError (AudioFileOpenURL(inputFileURL, kAudioFileReadPermission, 0, &audioConverterSettings.inputFile), "ошибка AudioFileOpenURL");
    CFRelease(inputFileURL);
    UInt32 propSize = sizeof(audioConverterSettings.inputFormat);
    CheckError (AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyDataFormat, &propSize, &audioConverterSettings.inputFormat),"не могу получить формат данных в файле");
    // получить полное число пакетов в файле
    propSize = sizeof(audioConverterSettings.inputFilePacketCount);
    CheckError (AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyAudioDataPacketCount, &propSize, &audioConverterSettings.inputFilePacketCount), "не могу получить количество пакетов в файле");
    // получить размер максимально возможного пакета
    propSize = sizeof(audioConverterSettings.inputFilePacketMaxSize);
    CheckError(AudioFileGetProperty(audioConverterSettings.inputFile, kAudioFilePropertyMaximumPacketSize, &propSize, &audioConverterSettings.inputFilePacketMaxSize), "не могу получить размер максимального пакета");
    return audioConverterSettings.inputFormat;
}

@end
