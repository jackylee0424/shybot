//
//  FaceDetector.mm
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

#import "FaceDetector.h"

NSString * const kFaceCascadeFilename = @"haarcascade_frontalface_alt2";
const int kHaarOptions =  CV_HAAR_FIND_BIGGEST_OBJECT | CV_HAAR_DO_ROUGH_SEARCH;

@implementation FaceDetector

- (id)init
{
    self = [super init];
    if (self) {
        NSString *faceCascadePath = [[NSBundle mainBundle] pathForResource:kFaceCascadeFilename
                                                                    ofType:@"xml"];
        
        if (!_faceCascade.load([faceCascadePath UTF8String])) {
            NSLog(@"Could not load face cascade: %@", faceCascadePath);
        }
    }
    
    return self;
}

- (std::vector<cv::Rect>)facesFromImage:(cv::Mat&)image
{
    std::vector<cv::Rect> faces;
    _faceCascade.detectMultiScale(image, faces, 1.1, 2, kHaarOptions, cv::Size(60, 60));
    
    return faces;
}

@end
