//
//  OpenCVData.h
//  FaceRecognition
//
//  Created by Michael Peterson on 2012-11-16.
//
//

/*
 The MIT License
 
 Copyright (C) 2013, 8457824 Canada Inc.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */


#import <Foundation/Foundation.h>
#import <opencv2/highgui/cap_ios.h>

@interface OpenCVData : NSObject

+ (NSData *)serializeCvMat:(cv::Mat&)cvMat;
+ (cv::Mat)dataToMat:(NSData *)data width:(NSNumber *)width height:(NSNumber *)height;
+ (CGRect)faceToCGRect:(cv::Rect)face;
+ (UIImage *)UIImageFromMat:(cv::Mat)image;
+ (cv::Mat)cvMatFromUIImage:(UIImage *)image;
+ (cv::Mat)cvMatFromUIImage:(UIImage *)image usingColorSpace:(int)outputSpace;
@end
