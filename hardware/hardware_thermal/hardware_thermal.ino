/*
 2-16-2013
 Spark Fun Electronics
 Nathan Seidle
 
 This code is heavily based on maxbot's and IlBaboomba's code: http://arduino.cc/forum/index.php?topic=126244
 They didn't have a license on it so I'm hoping it's public domain.
 
 This example shows how to read and calculate the 64 temperatures for the 64 pixels of the MLX90620 thermopile sensor.
 
 alpha_ij array is specific to every sensor and needs to be calculated separately. Please see the 
 'MLX90620_alphaCalculator' sketch to get these values. If you choose not to calculate these values
 this sketch will still work but the temperatures shown will be very inaccurate.
 
 Don't get confused by the bottom view of the device! The GND pin is connected to the housing.
 
 To get this code to work, attached a MLX90620 to an Arduino Uno using the following pins:
 A5 to 330 ohm to SCL
 A4 to 330 ohm to SDA
 3.3V to VDD
 GND to VSS
 
 I used the internal pull-ups on the SDA/SCL lines. Normally you should use ~4.7k pull-ups for I2C.

 */
#include <Servo.h>                           // Include servo library
#include <i2cmaster.h>
//i2cmaster comes from here: http://www.cheap-thermocam.bplaced.net/software/I2Cmaster.rar

#include "MLX90620_registers.h"

Servo servoHead;
Servo servoLeft;                             // Declare left and right servos
Servo servoRight;

int refreshRate = 16; //Set this value to your desired refresh frequency
int headAngle = 1400;


//Global variables
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
int irData[64]; //Contains the raw IR data from the sensor
float temperatures[64]; //Contains the calculated temperatures of each pixel in the array
float Tambient; //Tracks the changing ambient temperature of the sensor
byte eepromData[256]; //Contains the full EEPROM reading from the MLX (Slave 0x50)

//These are constants calculated from the calibration data stored in EEPROM
//See varInitialize and section 7.3 for more information
int v_th, a_cp, b_cp, tgc, b_i_scale;
float k_t1, k_t2, emissivity;
int a_ij[64], b_ij[64];

//These values are calculated using equation 7.3.3.2
//They are constants and can be calculated using the MLX90620_alphaCalculator sketch
float alpha_ij[64] = {

  1.78597E-8, 1.82090E-8, 1.82090E-8, 1.64628E-8, 1.97806E-8, 2.09448E-8, 2.11776E-8, 1.90239E-8, 

  2.19343E-8, 2.30984E-8, 2.27492E-8, 2.07701E-8, 2.30984E-8, 2.50775E-8, 2.46700E-8, 2.25164E-8, 

  2.43208E-8, 2.62417E-8, 2.58924E-8, 2.39133E-8, 2.52521E-8, 2.72312E-8, 2.66491E-8, 2.50775E-8, 

  2.56596E-8, 2.76386E-8, 2.76386E-8, 2.56596E-8, 2.56596E-8, 2.80461E-8, 2.80461E-8, 2.62417E-8, 

  2.50775E-8, 2.78133E-8, 2.79879E-8, 2.60670E-8, 2.50775E-8, 2.78133E-8, 2.79879E-8, 2.62417E-8, 

  2.50775E-8, 2.70566E-8, 2.70566E-8, 2.62417E-8, 2.40880E-8, 2.64745E-8, 2.66491E-8, 2.54850E-8, 

  2.30984E-8, 2.60670E-8, 2.60670E-8, 2.44954E-8, 2.17597E-8, 2.44954E-8, 2.46700E-8, 2.35059E-8, 

  2.05955E-8, 2.29238E-8, 2.33313E-8, 2.23417E-8, 1.87911E-8, 2.11776E-8, 2.17597E-8, 2.09448E-8, 

};

byte loopCount = 0; //Used in main loop
//-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=


//Begin Program code

void setup()
{
  Serial.begin(115200);
  //Serial.println("MLX90620 Example");
  
  servoHead.attach(10);
  servoHead.writeMicroseconds(1400);
  delay(1000);
  
  servoHead.writeMicroseconds(1700);
  delay(1000);
  servoHead.writeMicroseconds(1400);
  delay(1000);
  servoHead.writeMicroseconds(1100);
  delay(1000);
  servoHead.writeMicroseconds(1400);
  delay(1000);
  
  servoHead.detach();

  i2c_init(); //Init the I2C pins
  PORTC = (1 << PORTC4) | (1 << PORTC5); //Enable pull-ups

  delay(5); //Init procedure calls for a 5ms delay after power-on

  read_EEPROM_MLX90620(); //Read the entire EEPROM

  setConfiguration(refreshRate); //Configure the MLX sensor with the user's choice of refresh rate

  calculate_TA(); //Calculate the current Tambient
}

void headLeft()
{
  if (headAngle < 1700){
    headAngle += 20;
  }else{
    headAngle = 1700;
  }
}

void headCenter()
{
  headAngle = 1400;
}

void headRight(){
  if (headAngle > 1100){
    headAngle -= 20;
  }else{
    headAngle = 1100;
  }
}

void moveForward(){
  servoLeft.attach(13);                      // Attach left signal to P13 
  servoRight.attach(12);                     // Attach right signal to P12
                                             // Full speed forward
  servoLeft.writeMicroseconds(1600);         // Left wheel counterclockwise
  servoRight.writeMicroseconds(1400);        // Right wheel clockwise
  delay(200);                               // ...for 1 second
  
  servoLeft.detach();
  servoRight.detach();  
}

void moveBackward(){
  servoLeft.attach(13);                      // Attach left signal to P13 
  servoRight.attach(12);                     // Attach right signal to P12
                                             // Full speed forward
  servoLeft.writeMicroseconds(1400);         // Left wheel counterclockwise
  servoRight.writeMicroseconds(1600);        // Right wheel clockwise
  delay(200);                               // ...for 1 second
  
  servoLeft.detach();
  servoRight.detach();  
}

void turnRight(){
  servoLeft.attach(13);                      // Attach left signal to P13 
  //servoRight.attach(12);                     // Attach right signal to P12
                                             // Full speed forward
  servoLeft.writeMicroseconds(1700);         // Left wheel counterclockwise
  //servoRight.writeMicroseconds(100);        // Right wheel clockwise
  delay(200);                               // ...for 1 second
  
  servoLeft.detach();   
}

void turnLeft(){
  //servoLeft.attach(13);                      // Attach left signal to P13 
  servoRight.attach(12);                     // Attach right signal to P12
                                             // Full speed forward
  //servoLeft.writeMicroseconds(700);         // Left wheel counterclockwise
  servoRight.writeMicroseconds(1300);        // Right wheel clockwise
  delay(200);                               // ...for 1 second
  
  servoRight.detach();   
}

void loop()
{
  if (Serial.available()){
    char c = Serial.read();
    if (c=='L'){
      turnLeft();
    }else if(c=='R'){
      turnRight();
    }else if(c=='F'){
      moveForward();
    }else if(c=='M'){
      headCenter();
    }else if(c=='W'){
      headLeft();
    }else if(c=='Q'){
      headRight();
    }else if(c=='B'){
      moveBackward();
    }else if(c=='D'){
      digitalWrite(9, HIGH);
      digitalWrite(11, LOW);
    }else if(c=='Y'){
      digitalWrite(11, HIGH);
      digitalWrite(9, LOW);
    }else if(c=='C'){
      digitalWrite(11, LOW);
      digitalWrite(9, LOW);
    }
    
  }
  
  if ((headAngle < 1450) && (headAngle > 1350)){
  }else{
    servoHead.attach(10);
    servoHead.writeMicroseconds(headAngle);
    delay(50);
    servoHead.detach();
  }
  
  /*
  if(loopCount++ == 16) //Tambient changes more slowly than the pixel readings. Update TA only every 16 loops.
  { 
    calculate_TA(); //Calculate the new Tambient

    if(checkConfig_MLX90620()) //Every 16 readings check that the POR flag is not set
    {
      Serial.println("POR Detected!");
      setConfiguration(refreshRate); //Re-write the configuration bytes to the MLX
    }

    loopCount = 0; //Reset count
  }

  readIR_MLX90620(); //Get the 64 bytes of raw pixel data into the irData array

  calculate_TO(); //Run all the large calculations to get the temperature data for each pixel

  //prettyPrintTemperatures(); //Print the array in a 4 x 16 pattern
  rawPrintTemperatures(); //Print the entire array so it can more easily be read by Processing app
  delay(100);
  */
}

//From the 256 bytes of EEPROM data, initialize 
void varInitialization(byte calibration_data[])
{
  v_th = 256 * calibration_data[VTH_H] + calibration_data[VTH_L];
  k_t1 = (256 * calibration_data[KT1_H] + calibration_data[KT1_L]) / 1024.0; //2^10 = 1024
  k_t2 = (256 * calibration_data[KT2_H] + calibration_data[KT2_L]) / 1048576.0; //2^20 = 1,048,576
  emissivity = ((unsigned int)256 * calibration_data[CAL_EMIS_H] + calibration_data[CAL_EMIS_L]) / 32768.0;
  
  a_cp = calibration_data[CAL_ACP];
  if(a_cp > 127) a_cp -= 256; //These values are stored as 2's compliment. This coverts it if necessary.

  b_cp = calibration_data[CAL_BCP];
  if(b_cp > 127) b_cp -= 256;

  tgc = calibration_data[CAL_TGC];
  if(tgc > 127) tgc -= 256;

  b_i_scale = calibration_data[CAL_BI_SCALE];

  for(int i = 0 ; i < 64 ; i++)
  {
    //Read the individual pixel offsets
    a_ij[i] = calibration_data[i]; 
    if(a_ij[i] > 127) a_ij[i] -= 256; //These values are stored as 2's compliment. This coverts it if necessary.

    //Read the individual pixel offset slope coefficients
    b_ij[i] = calibration_data[0x40 + i]; //Bi(i,j) begins 64 bytes into EEPROM at 0x40
    if(b_ij[i] > 127) b_ij[i] -= 256;
  }
  
}

//Receives the refresh rate for sensor scanning
//Sets the two byte configuration registers
//This function overwrites what is currently in the configuration registers
//The MLX doesn't seem to mind this (flags are read only)
void setConfiguration(int irRefreshRateHZ)
{
  byte Hz_LSB;

  switch(irRefreshRateHZ)
  {
  case 0:
    Hz_LSB = 0b00001111;
    break;
  case 1:
    Hz_LSB = 0b00001110;
    break;
  case 2:
    Hz_LSB = 0b00001101;
    break;
  case 4:
    Hz_LSB = 0b00001100;
    break;
  case 8:
    Hz_LSB = 0b00001011;
    break;
  case 16:
    Hz_LSB = 0b00001010;
    break;
  case 32:
    Hz_LSB = 0b00001001;
    break;
  default:
    Hz_LSB = 0b00001110;
  }

  byte defaultConfig_H = 0b01110100; // x111.01xx, Assumes NA = 0, ADC low reference enabled, Ta Refresh rate of 2Hz

  i2c_start_wait(MLX90620_WRITE);
  i2c_write(0x03); //Command = configuration value
  i2c_write((byte)Hz_LSB - 0x55);
  i2c_write(Hz_LSB);
  i2c_write(defaultConfig_H - 0x55); //Assumes NA = 0, ADC low reference enabled, Ta Refresh rate of 2Hz
  i2c_write(defaultConfig_H);
  i2c_stop();
}

//Read the 256 bytes from the MLX EEPROM and setup the various constants (*lots* of math)
//Note: The EEPROM on the MLX has a different I2C address from the MLX. I've never seen this before.
void read_EEPROM_MLX90620()
{
  i2c_start_wait(MLX90620_EEPROM_WRITE);
  i2c_write(0x00); //EEPROM info starts at location 0x00
  i2c_rep_start(MLX90620_EEPROM_READ);

  //Read all 256 bytes from the sensor's EEPROM
  for(int i = 0 ; i <= 255 ; i++)
    eepromData[i] = i2c_readAck();

  i2c_stop(); //We're done talking

  varInitialization(eepromData); //Calculate a bunch of constants from the EEPROM data

  writeTrimmingValue(eepromData[OSC_TRIM_VALUE]);
}

//Given a 8-bit number from EEPROM (Slave address 0x50), write value to MLX sensor (Slave address 0x60)
void writeTrimmingValue(byte val)
{
  i2c_start_wait(MLX90620_WRITE); //Write to the sensor
  i2c_write(0x04); //Command = write oscillator trimming value
  i2c_write((byte)val - 0xAA);
  i2c_write(val);
  i2c_write(0x56); //Always 0x56
  i2c_write(0x00); //Always 0x00
  i2c_stop();
}

//Gets the latest PTAT (package temperature ambient) reading from the MLX
//Then calculates a new Tambient
//Many of these values (k_t1, v_th, etc) come from varInitialization and EEPROM reading
//This has been tested to match example 7.3.2
void calculate_TA(void)
{
  unsigned int ptat = readPTAT_MLX90620();

  Tambient = (-k_t1 + sqrt(square(k_t1) - (4 * k_t2 * (v_th - (float)ptat)))) / (2*k_t2) + 25; //it's much more simple now, isn't it? :)
}

//Reads the PTAT data from the MLX
//Returns an unsigned int containing the PTAT
unsigned int readPTAT_MLX90620()
{
  i2c_start_wait(MLX90620_WRITE);
  i2c_write(CMD_READ_REGISTER); //Command = read PTAT
  i2c_write(0x90); //Start address is 0x90
  i2c_write(0x00); //Address step is 0
  i2c_write(0x01); //Number of reads is 1
  i2c_rep_start(MLX90620_READ);

  byte ptatLow = i2c_readAck(); //Grab the lower and higher PTAT bytes
  byte ptatHigh = i2c_readAck();

  i2c_stop();
  
  return( (unsigned int)(ptatHigh << 8) | ptatLow); //Combine bytes and return
}

//Calculate the temperatures seen for each pixel
//Relies on the raw irData array
//Returns an 64-int array called temperatures
void calculate_TO()
{
  float v_ir_off_comp;
  float v_ir_tgc_comp;
  float v_ir_comp;

  //Calculate the offset compensation for the one compensation pixel
  //This is a constant in the TO calculation, so calculate it here.
  int cpix = readCPIX_MLX90620(); //Go get the raw data of the compensation pixel
  float v_cp_off_comp = (float)cpix - (a_cp + (b_cp/pow(2, b_i_scale)) * (Tambient - 25)); 

  for (int i = 0 ; i < 64 ; i++)
  {
    v_ir_off_comp = irData[i] - (a_ij[i] + (float)(b_ij[i]/pow(2, b_i_scale)) * (Tambient - 25)); //#1: Calculate Offset Compensation 

    v_ir_tgc_comp = v_ir_off_comp - ( ((float)tgc/32) * v_cp_off_comp); //#2: Calculate Thermal Gradien Compensation (TGC)

    v_ir_comp = v_ir_tgc_comp / emissivity; //#3: Calculate Emissivity Compensation

    temperatures[i] = sqrt( sqrt( (v_ir_comp/alpha_ij[i]) + pow(Tambient + 273.15, 4) )) - 273.15;
  }
}

//Reads 64 bytes of pixel data from the MLX
//Loads the data into the irData array
void readIR_MLX90620()
{
  i2c_start_wait(MLX90620_WRITE);
  i2c_write(CMD_READ_REGISTER); //Command = read a register
  i2c_write(0x00); //Start address = 0x00
  i2c_write(0x01); //Address step = 1
  i2c_write(0x40); //Number of reads is 64
  i2c_rep_start(MLX90620_READ);

  for(int i = 0 ; i < 64 ; i++)
  {
    byte pixelDataLow = i2c_readAck();
    byte pixelDataHigh = i2c_readAck();
    irData[i] = (int)(pixelDataHigh << 8) | pixelDataLow;
  }

  i2c_stop();
}

//Read the compensation pixel 16 bit data
int readCPIX_MLX90620()
{
  i2c_start_wait(MLX90620_WRITE);
  i2c_write(CMD_READ_REGISTER); //Command = read register
  i2c_write(0x91);
  i2c_write(0x00);
  i2c_write(0x01);
  i2c_rep_start(MLX90620_READ);

  byte cpixLow = i2c_readAck(); //Grab the two bytes
  byte cpixHigh = i2c_readAck();
  i2c_stop();

  return ( (int)(cpixHigh << 8) | cpixLow);
}

//Reads the current configuration register (2 bytes) from the MLX
//Returns two bytes
unsigned int readConfig_MLX90620()
{
  i2c_start_wait(MLX90620_WRITE); //The MLX configuration is in the MLX, not EEPROM
  i2c_write(CMD_READ_REGISTER); //Command = read configuration register
  i2c_write(0x92); //Start address
  i2c_write(0x00); //Address step of zero
  i2c_write(0x01); //Number of reads is 1

    i2c_rep_start(MLX90620_READ);

  byte configLow = i2c_readAck(); //Grab the two bytes
  byte configHigh = i2c_readAck();

  i2c_stop();

  return( (unsigned int)(configHigh << 8) | configLow); //Combine the configuration bytes and return as one unsigned int
}

//Poll the MLX for its current status
//Returns true if the POR/Brown out bit is set
boolean checkConfig_MLX90620()
{
  if ( (readConfig_MLX90620() & (unsigned int)1<<POR_TEST) == 0)
    return true;
  else
    return false;
}

//Prints the temperatures in a way that's more easily viewable in the terminal window
void prettyPrintTemperatures()
{
  Serial.println();
  for(int i = 0 ; i < 64 ; i++)
  {
    if(i % 16 == 0) Serial.println();
    Serial.print(convertToFahrenheit(temperatures[i]));
    //Serial.print(irData[i]);
    Serial.print(", ");
  }
}

//Prints the temperatures in a way that's more easily parsed by a Processing app
//Each line starts with '$' and ends with '*'
void rawPrintTemperatures()
{
  Serial.print("$");
  for(int i = 0 ; i < 64 ; i++)
  {
    Serial.print(convertToFahrenheit(temperatures[i]));
    if (i!=63){
      Serial.print(","); //Don't print comma on last temperature
    }
  }
  Serial.println("*");
}

//Given a Celsius float, converts to Fahrenheit
float convertToFahrenheit (float Tc)
{
  float Tf = (9/5) * Tc + 32;

  return(Tf);
}
