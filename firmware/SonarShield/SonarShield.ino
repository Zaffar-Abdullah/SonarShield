/*
  ================================================
   SonarShield - Sonar Radar with Light & Buzzer Alert
  ================================================
  Based on the classic Sciencex radar sweep (15-190 deg,
  continuous sweep, no tracking/lock-on logic) + our
  own additions: LDR light sensor, LCD, and bidirectional
  UI control for the light and buzzer.

  Components:
   - HC-SR04 Ultrasonic Sensor (radar distance / object detection)
   - SG90 Servo Motor (radar rotation - plain continuous sweep)
   - LDR (Light Sensor) - detects dark/bright environment
   - 16x2 I2C LCD (0x27)
   - Light LED  (auto ON in dark, or manually forced via UI)
   - Red LED    (ON whenever an object is within 40cm)
   - Active Buzzer (ON only when object is within 15cm, mutable via UI)

  ---------------- Serial Packet Format ----------------
  Sent continuously (every ~30ms, matching servo step delay):
    angle,distance,lightSensorDark,lightOn,lightMode,buzzerOn,muted.
  Example -> 76,24,1,1,0,0,0.

    angle           : current servo angle
    distance        : cm from HC-SR04 (400 = out of range / no echo)
    lightSensorDark : 1 = LDR reads dark, 0 = bright (raw sensor reading)
    lightOn         : 1 = light LED is actually ON right now
    lightMode       : 0 = AUTO (follows LDR), 1 = FORCED ON, 2 = FORCED OFF
    buzzerOn        : 1 = buzzer is actually sounding right now
    muted           : 1 = buzzer manually muted by user

  ---------------- Serial Commands (from GUI to Arduino) ----------------
    'M' or 'm' -> toggle buzzer mute on/off
    'L' or 'l' -> cycle light mode: AUTO -> FORCED ON -> FORCED OFF -> AUTO
*/

#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <Servo.h>

// ---------- Pin Map ----------
#define TRIG_PIN   9
#define ECHO_PIN   10
#define SERVO_PIN  6
#define LIGHT_LED  2   // was GREEN_LED - now the light-sensor-driven LED
#define RED_LED    3
#define BUZZER     4
#define LDR_PIN    A0

LiquidCrystal_I2C lcd(0x27, 16, 2);
Servo myServo;

// ---------- Sensor / output state ----------
long duration;
int distance = 0;
int lightSensorDark = 0; // raw LDR reading: 1 = dark, 0 = bright
bool lightOn = false;
bool buzzerOn = false;

// ---------- Thresholds (tune after testing your hardware) ----------
const int OBJECT_RANGE = 40;        // cm - Red LED turns on within this range
const int DANGER_DISTANCE = 15;     // cm - Buzzer turns on within this range
int LDR_DARK_THRESHOLD = 500;       // analogRead value - tune based on your LDR wiring

// ---------- User-controllable states (via serial commands) ----------
bool buzzerMuted = false;
int lightMode = 0; // 0 = AUTO, 1 = FORCED ON, 2 = FORCED OFF

void setup() {
  Serial.begin(9600);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(LIGHT_LED, OUTPUT);
  pinMode(RED_LED, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  myServo.attach(SERVO_PIN);

  lcd.init();
  lcd.backlight();
  lcd.setCursor(0, 0);
  lcd.print(" SonarShield ");
  delay(1500);
  lcd.clear();
}

// ---------- Ultrasonic distance ----------
int calculateDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);
  duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout so it never hangs
  int d = duration * 0.034 / 2;
  if (d == 0) d = 400; // no echo = out of range
  return d;
}

// ---------- Read commands sent from the Processing GUI ----------
void handleSerialCommands() {
  while (Serial.available() > 0) {
    char c = Serial.read();
    if (c == 'M' || c == 'm') {
      buzzerMuted = !buzzerMuted;
    } else if (c == 'L' || c == 'l') {
      lightMode = (lightMode + 1) % 3; // AUTO -> ON -> OFF -> AUTO
    }
  }
}

// ---------- Decide Red LED + Buzzer from distance ----------
void updateProximityOutputs() {
  bool detected = (distance < OBJECT_RANGE);
  digitalWrite(RED_LED, detected ? HIGH : LOW);

  bool closeEnough = (distance < DANGER_DISTANCE);
  buzzerOn = closeEnough && !buzzerMuted;
  digitalWrite(BUZZER, buzzerOn ? HIGH : LOW);
}

// ---------- Decide Light LED from LDR + manual mode ----------
void updateLight() {
  int ldrValue = analogRead(LDR_PIN);
  lightSensorDark = (ldrValue > LDR_DARK_THRESHOLD) ? 1 : 0;

  if (lightMode == 1) {
    lightOn = true;              // forced ON
  } else if (lightMode == 2) {
    lightOn = false;             // forced OFF
  } else {
    lightOn = (lightSensorDark == 0); // AUTO: follow the sensor (inverted for this board's LDR wiring)
  }
  digitalWrite(LIGHT_LED, lightOn ? HIGH : LOW);
}

// ---------- LCD status ----------
void updateLCD() {
  lcd.setCursor(0, 0);
  if (distance < OBJECT_RANGE) {
    lcd.print("Object: ");
    lcd.print(distance);
    lcd.print("cm   ");
  } else {
    lcd.print("Area is Empty  ");
  }

  lcd.setCursor(0, 1);
  lcd.print("L:");
  lcd.print(lightOn ? "ON " : "OFF");
  lcd.print(" B:");
  lcd.print(buzzerMuted ? "MUTE" : "norm");
}

// ---------- Serial packet to Processing ----------
void sendPacket(int angle) {
  Serial.print(angle);            Serial.print(",");
  Serial.print(distance);         Serial.print(",");
  Serial.print(lightSensorDark);  Serial.print(",");
  Serial.print(lightOn ? 1 : 0);  Serial.print(",");
  Serial.print(lightMode);        Serial.print(",");
  Serial.print(buzzerOn ? 1 : 0); Serial.print(",");
  Serial.print(buzzerMuted ? 1 : 0);
  Serial.print(".");
}

// ---------- One tick: read distance, decide outputs, report ----------
void doTick(int angle) {
  handleSerialCommands();
  distance = calculateDistance();
  updateProximityOutputs();
  updateLight();
  updateLCD();
  sendPacket(angle);
}

void loop() {
  // Sweep 15 -> 190 (exactly like the sample project)
  for (int i = 15; i <= 190; i++) {
    myServo.write(i);
    delay(30);
    doTick(i);
  }
  // Sweep 190 -> 15
  for (int i = 190; i > 15; i--) {
    myServo.write(i);
    delay(30);
    doTick(i);
  }
}
