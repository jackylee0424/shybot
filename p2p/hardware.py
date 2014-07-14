#!/usr/bin/env python

## python client for capturing faces and send them to server

import cv2
import cv2.cv as cv
import sys
import os
import numpy as np
import time
from websocket import create_connection
import base64
import json

import serial
import thread

## connect to local server
ws_hw = create_connection("ws://localhost:8080/hw")

try:
    ## on raspi
    #ser = serial.Serial('/dev/ttyACM0', 115200, timeout=5, parity="N", bytesize=8)
    
    ## on mac
    ser = serial.Serial('/dev/tty.usbmodemfd141', 115200, timeout=5, parity="N", bytesize=8)
    print "open serial port..."
except:
    print "find your device first -> $ ls /dev/tty.* "
    sys.exit(0)

ts = 0
tracked_faces=[]
fps=0
face_counter = 0
profile_mode = ""
result_recog = None
resetLED = True
training_counter = 0

## connect to local server
ws = create_connection("ws://localhost:8080/ws")
mode = 1  # -1: training, 1: detecting

def readThermal():
    while 1:
        line = ser.readline()
        try:
            if len(line.split(','))==3:
                try:
                    thermal = [float(i) for i in line.split(',')]
                    ws_hw.send(json.dumps(dict(thermal=thermal)))
                except:
                    pass
                
        except:
            break
            
    time.sleep(.001)
    ser.flushInput()
    FILE.close()

def sendToHW():
    global mode, training_counter
    ## receive actions from server
    while True:
        time.sleep(.2)
        result = ws_hw.recv()
        if result == 'T':
            training_counter += 1
            if training_counter < 8:
                mode = -1
            else:
                mode = 1
        else:
            training_counter = 0
            ser.write(result.encode())
            mode = 1

def receiveRecog():
    global result_recog
    ## receive actions from server
    while True:
        time.sleep(.2)
        result_recog = json.loads(ws.recv())
        if result_recog:
            score = result_recog["computed"].values()[0]
            if score > .75:
                ser.write("Y")
            elif score < .4:
                ser.write("D")

## use a different thread to send thermal data to server
thread.start_new_thread(readThermal, ())
thread.start_new_thread(sendToHW, ())
thread.start_new_thread(receiveRecog, ())

## face class for multi-face processing
class Face:
    def __init__(self, age, rect, n):
        self.age = age
        self.rect = rect
        self.name = "ID"+str(n)
        self.life = 0
        self.face_id = n
        self.fx = []
        self.fy = []
        self.cx = -300
        self.cy = -300
        self.faceROI = None
        self.fixed = False
        self.state = ""
        self.face_list=[]
        self.timer = time.time()
        
    def updateFace(self, rect):
        if self.age < 45:
            self.age += 3
        else:
            self.age = 45
        self.rect = rect
        self.life = 0

    def fadeFace(self):
        self.age -= 4
        self.life = 0

    def updateName(self, name):
        self.name = name

    def updateLife(self):
        self.life += 1

    def isTooOld(self):
        if (self.life>1) or self.age<0:
            return True
        else:
            return False

## draw face and related info
def draw_faces(img, faces, c):
    global resetLED, mode
    if len(faces)>0:
        resetLED = True
        for f in faces:
            x1, y1, x2, y2  = f.rect

            # cv2.imshow("roi", img[y1:y2, x1:x2])
            _, data = cv2.imencode('.png', img[y1:y2, x1:x2])
            png_base64 = "data:image/png;base64," + base64.b64encode(data.tostring())
            if c % 20 == 19:
                ws.send(json.dumps(dict(label="known", mode=mode, base64Data=png_base64)))
            # draw duration bar
            if (f.age<=40):
                cv2.rectangle(img, (x1+5, y1+5), (((x2-5)-(x1+5))/40*f.age+x1+5, y1+10), (255, 55,0), 1)
            else:
                cv2.rectangle(img, (x1+5, y1+5), (x2-5, y1+10), (255, 55,0), 1)

            # draw face rectangle
            cv2.rectangle(img, (x1, y1), (x2, y2), (255, 55,0), 1)
            if (f.age>10):
                if x1 < 140:
                    ser.write("Q")
                if x1 > 170:
                    ser.write("W")
            break
    else:
        if resetLED:
            ser.write("C")
            resetLED = False



## face detection setup
def detectFaces(img, cascade):
    global tracked_faces, face_counter
    if face_counter>8:
        face_counter = 0

    # update tracked_faces, remove inactive ones
    for f in tracked_faces:
        f.updateLife()
        if(f.isTooOld()):
            tracked_faces.remove(f)

    # convert to gray color to save some processing time
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # opencv face detect
    rects = cascade.detectMultiScale(gray, scaleFactor=1.3, minNeighbors=4, minSize=(40, 40), flags = cv.CV_HAAR_FIND_BIGGEST_OBJECT)

    # if there is no faces found, use the previous detected faces saved in global list
    if len(rects) == 0:
        # no faces found by opencv
        #return [] ## if no face found, clear all faces, this is too rigid.

        # make faces decay and fade overtime if no detection
        for f in tracked_faces:
            f.fadeFace()
    else:
        # format the rectangles
        rects[:,2:] += rects[:,:2]

        # & found faces in rects
        for r in rects:
            matchedFace = False;
            
            # if there are faces stored
            if len(tracked_faces)>0:

                    # check if the new rect within the old face within tolerance
                    for f in tracked_faces:
                        movement = sum(abs(np.array(f.rect)-np.array(r)))
                        if movement < 250 and movement > 120:
                            matchedFace = True
                            r =  map(lambda x: int(x),np.array(f.rect)*.80+np.array(r)*.2)
                            f.updateFace(r)
                        elif movement < 120:
                            matchedFace = True
                            r =  map(lambda x: int(x),np.array(f.rect)*.95+np.array(r)*.05)
                            f.updateFace(r)
                            break
                        
                    if (matchedFace == False):
                        face_counter +=1
                        newface = Face(0,r, face_counter)
                        tracked_faces.append(newface)
                        
            else:
                # if current no recognized faces
                # & found faces in rects
                # add faces
                face_counter +=1
                newface = Face(0,r, face_counter)
                tracked_faces.append(newface)
          
        return tracked_faces

if __name__ == '__main__':

    cascade = cv2.CascadeClassifier(os.path.join("xml","haarcascade_frontalface_alt.xml"))

    camera_id = 0
    if len(sys.argv)>1:
        try:
            camera_id = int(sys.argv[1])
            cam = cv2.VideoCapture(camera_id)
        except:
            print "camera error"
            sys.exit(0)
    else:
        cam = cv2.VideoCapture(0)
    
    if len(sys.argv)>2:
        profile_mode =sys.argv[2] 
        if profile_mode =="HD":
            cam.set(cv.CV_CAP_PROP_FRAME_WIDTH,1280)
            cam.set(cv.CV_CAP_PROP_FRAME_HEIGHT,720)
            cam.set(cv.CV_CAP_PROP_FPS,30) 
    else:
        cam.set(cv.CV_CAP_PROP_FRAME_WIDTH,320) 
        cam.set(cv.CV_CAP_PROP_FRAME_HEIGHT,240)
        cam.set(cv.CV_CAP_PROP_FPS,30)

    ## start timestamp
    start = time.time()

    ## frame counter
    fc = 0

    winName = 'cv2'
    
    while True:

        ## get frame from camera
        ret, img = cam.read()

        ## run face detection once every 3 frames
        if fc % 3 == 0:
            detectFaces(img, cascade)

        ## draw face rectangles
        draw_faces(img, tracked_faces, fc)

        ## increase frame counter
        fc += 1

        ## print out instantenous fps
        fps = (fc/(time.time() - start))
        
        ## display camera view
        cv2.imshow(winName, img)

        ## keyboard interrupt
        key = cv2.waitKey(10)

        if key == 27: ## esc key
           cv2.destroyWindow(winName)
           break

    sys.exit()


