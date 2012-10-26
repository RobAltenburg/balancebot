/* 
 * balancebot I
 *
 * Sparkfun SEN-09268   
 * IDG500 Gyroscope & ADXL335 Accelerometer
 *
 */

/**************************************************
 * Per the data sheets:
 * xRate is 2.0mV/deg/sec to a max of 500 deg/sec
 * xOut is 360mV/g @ 3.6V & 195mV/g @ 2V ~330 mV/g @ 3.3
 *
 * Hardware Connections
 * AREF <---> 3.3V
 * A0	<---> pin 7 of JP1 on the SEN-0928
 * A1	<---> pin 2 of JP1 on the SEN-0928 (the y-axis according to the datasheet)
 *
 *************************************************/

#define STANDBY  // comment out to power motors

// gyro sensitivity
// analog read 3.3v / 1024 = 3.322 mV per step
// 3.322 / 2.0 mV/deg/sec = 1.611 deg/sec or  .02812 rad/sec/step
// High frequency cutoff = 140 Hz

// Tuning parameters 
// ------------------------------------------------

// Zero out the gyro and accelerometer
int xGyroOffset = 327; //334; 
const int xAccelOffset = 500;

// motor output = kP * angle + kD * rate 
float kP = 250.0; 
float kD = 250.0;

// ------------------------------------------------

unsigned long time;
unsigned long oldtime;

// Mapping for the analog pins
const byte xRate = A0;
const byte xOut = A1;

// Mapping for the digital pins
const byte standby = 12;
const byte pulseLeft = 11;
const byte pulseRight = 10;
const byte ledPin = 13;

const byte aIn1 = 9;
const byte aIn2 = 8;
const byte bIn1 = 7;
const byte bIn2 = 6;

float xGyroRPS;
float xAccelG;
float angle = 0.0;
float dt = 0;

int motorLeft;
int motorRight;
boolean oldLeftFwd;
boolean oldRightFwd;


// ------------------------------- Setup
void setup() {
  long offset = 0L;
  
  Serial.begin(9600);

  analogReference(EXTERNAL);  // ADC based on AREF

  // set all the digital pins to OUTPUT
  for (int i = 6; i <= 13; i++) {
    pinMode(i, OUTPUT);
  }

#ifdef STANDBY
  digitalWrite(standby, LOW);
#else
  digitalWrite(standby, HIGH); 
#endif

  // set the motor controller for forward
  oldLeftFwd = true;
  oldRightFwd = true;
  digitalWrite(aIn1, HIGH);
  digitalWrite(aIn2, LOW);
  digitalWrite(bIn2, HIGH);
  digitalWrite(bIn1, LOW);

  //record the time
  oldtime = millis();

}

// ------------------------------- Loop
void loop() {

  // read the raw rate and calculate the radians per second
  xGyroRPS = (analogRead(xRate) - xGyroOffset) * 0.02812; 

  // calculate g from accelerometer
  // for small angles, this will also be ~ the tilt in radians
  // assuming the tilt is a small angle
  xAccelG = (analogRead(xOut) - xAccelOffset) * 0.01;

  time = millis();
  dt = ((int) (time - oldtime));
  oldtime = time;

  // combine the gyro and accel with a complementary filter. 
  angle = (0.8 * ( angle + ( xGyroRPS * ( dt / 1000.0)))) +  (0.2 * xAccelG);
  //  angle = (0.98 * angle) +  (0.02 * xAccelG);

  // Calculate the power to the motors.  (value can be -255 to 255)
  motorLeft = (int) ((angle * kP) + (xGyroRPS * kD));
  motorRight = (int) ((angle * kP) + (xGyroRPS * kD));

  // the above code executes in 350 uS, but the gyro only operates at 140Hz (once per 7mS)
  delay(7);  // todo... benchmark the rest of the code and adjust
  
  //benchmark = micros() - benchmark;
  
  motorPWM(motorLeft, motorRight, oldLeftFwd, oldRightFwd);

  oldLeftFwd = isPositive(motorLeft);
  oldRightFwd = isPositive(motorRight); 

  // Serial.print(analogRead(xOut));
  // Serial.print(", ");
  Serial.print(xAccelG);
  Serial.print(", ");
  Serial.print(xGyroRPS);
  Serial.print(", ");
  Serial.print(angle);
  Serial.print(", ");
  Serial.println(motorLeft);
  delay(75);
  
}

boolean isPositive(int num) {
  boolean retvar;
  if (num < 0) {
    retvar = false;
  } 
  else {
    retvar = true;
  }
  return retvar;
}

/*** Send values to motor controller ***/
void motorPWM(int motorL, int motorR, boolean oldL, boolean oldR) {


  //Serial.println(motorLeft);
  //delay(25);
  //
  //if (abs(motorLeft) == 255) {
  //  digitalWrite(ledPin, HIGH);
  //} else {
  // digitalWrite(ledPin, LOW);
  //}


  // if the direction changed from the last pass,
  // set the direction pins for each motor

  if (isPositive(motorL) != oldL) {
    if (motorL > 0) {
      digitalWrite(aIn1, HIGH);
      digitalWrite(aIn2, LOW);
    } 
    else {
      digitalWrite(aIn1, LOW);
      digitalWrite(aIn2, HIGH);
    }
  }


  if (isPositive(motorR) != oldR) {
    if (motorR > 0) {
      digitalWrite(bIn2, HIGH);
      digitalWrite(bIn1, LOW);
    } 
    else {
      digitalWrite(bIn2, LOW);
      digitalWrite(bIn1, HIGH);
    }
  }

  // set the power to the motors
  analogWrite(pulseLeft, min(abs(motorL), 255));
  analogWrite(pulseRight, min(abs(motorR), 255));

}



