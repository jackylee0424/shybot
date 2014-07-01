import serial
import time
import sys
from websocket import create_connection
import thread

## connect to local server
ws = create_connection("ws://localhost:8080/hw")

try:
    ser = serial.Serial('/dev/tty.usbmodemfa131', 115200, timeout=5, parity="N", bytesize=8)
except:
    print "find your device first -> $ ls /dev/tty.* "
    sys.exit(0)

print "open serial port..."
time_start=time.time()

def readThermal():
    while 1:
        line = ser.readline()
        try:
            if len(line.split(','))==3:
                ws.send(line.strip())      
        except:
            break
            
    time.sleep(.001)
    ser.flushInput()
    FILE.close()


## use a different thread to send thermal data to server
thread.start_new_thread(readThermal, ())

## receive actions from server
while True:
    time.sleep(.2)
    result = ws.recv()
    print result
    ser.write(result.encode())