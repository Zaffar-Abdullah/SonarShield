/*
  ================================================
   SonarShield GUI - Processing Sketch (Layout v2)
  ================================================
  Layout:
   - Header (top strip): project title only, nothing else here
   - Left side: radar (fading trail + red detection wedge)
   - Right side: single panel with all system/environment info
     PLUS the Mute Buzzer / Light Mode buttons
   - Footer (bottom strip): live status (left) + team credit (right)

  Serial packet format expected from Arduino:
    angle,distance,lightSensorDark,lightOn,lightMode,buzzerOn,muted.

  ⚠️ IMPORTANT: change COM_PORT to match your Arduino's port.
*/

import processing.serial.*;

String COM_PORT = "COM6";  // <-- বদলাও নিজের পোর্ট নাম্বার দিয়ে
int BAUD_RATE = 9600;

String PROJECT_NAME = "SonarShield";
String TEAM_CREDIT = "Zikratul-Asl | #DIUICE";

Serial myPort;
boolean portConnected = false;

// ---------- Parsed values ----------
int iAngle = 90;
int iDistance = 400;
int iLightDark = 0;
int iLightOn = 0;
int iLightMode = 0;
int iBuzzerOn = 0;
int iMuted = 0;

String data = "";

// ---------- Colors ----------
color radarGreen = color(98, 245, 31);
color alertRed = color(255, 40, 40);
color panelBg = color(10, 25, 10);
color panelBorder = color(60, 120, 50);
color buttonBg = color(20, 45, 20);
color buttonBgActive = color(40, 90, 40);

// ---------- Radar geometry (left side) ----------
int radarX0, radarY0, radarX1, radarY1;
int radarCx, radarCy, radarR;

// ---------- Right panel geometry ----------
int panelX, panelY, panelW, panelH;

// ---------- Buttons (inside right panel) ----------
int btnX, btnW, btnH = 40;
int btnMuteY, btnLightY;

int blinkTimer = 0;
boolean blinkOn = true;

void setup() {
  size(1200, 700);
  smooth();
  background(0);

  // Radar occupies the left ~54% of the width, below the header, above the footer
  radarX0 = 20;
  radarY0 = 80;
  radarX1 = 650;
  radarY1 = 630;
  radarCx = (radarX0 + radarX1) / 2;
  radarCy = radarY1;
  radarR = min((radarX1 - radarX0) / 2, radarY1 - radarY0) - 10;

  // Right panel fills the remaining space
  panelX = 670;
  panelY = 80;
  panelW = 510;
  panelH = 550;

  btnX = panelX + 20;
  btnW = panelW - 40;
  btnMuteY = panelY + 420;
  btnLightY = panelY + 472;

  try {
    myPort = new Serial(this, COM_PORT, BAUD_RATE);
    myPort.bufferUntil('.');
    portConnected = true;
  } catch (Exception e) {
    println("Serial port open korte parlam na. COM_PORT thik ache kina check koro.");
    println("Available ports:");
    printArray(Serial.list());
  }
}

void draw() {
  drawHeader();
  drawRadarArea();
  drawRightPanel();
  drawFooter();

  blinkTimer++;
  if (blinkTimer > 20) {
    blinkOn = !blinkOn;
    blinkTimer = 0;
  }
}

// ---------- Serial parsing ----------
void serialEvent(Serial myPort) {
  data = myPort.readStringUntil('.');
  if (data == null) return;
  data = data.substring(0, data.length() - 1);

  String[] parts = split(data, ',');
  if (parts.length < 7) return;

  try {
    iAngle     = int(parts[0]);
    iDistance  = int(parts[1]);
    iLightDark = int(parts[2]);
    iLightOn   = int(parts[3]);
    iLightMode = int(parts[4]);
    iBuzzerOn  = int(parts[5]);
    iMuted     = int(parts[6]);
  } catch (Exception e) {
    return;
  }
}

// ---------- Header: title ONLY, kept clear of everything else ----------
void drawHeader() {
  fill(0);
  noStroke();
  rect(0, 0, width, 80);
  fill(radarGreen);
  textSize(30);
  textAlign(CENTER);
  text(PROJECT_NAME, width / 2, 34);
  textSize(13);
  fill(150, 220, 130);
  text("Smart Sonar Radar & Safety Alert System", width / 2, 56);
  textAlign(LEFT);
  stroke(panelBorder);
  strokeWeight(0.5);
  line(0, 80, width, 80);
}

// ---------- Radar (left side) - fading trail + red detection wedge ----------
void drawRadarArea() {
  noStroke();
  fill(0, 12);
  rect(radarX0, radarY0, radarX1 - radarX0, radarY1 - radarY0);

  pushMatrix();
  translate(radarCx, radarCy);

  noFill();
  stroke(radarGreen, 160);
  strokeWeight(1.5);
  for (int i = 1; i <= 4; i++) {
    arc(0, 0, radarR * 2 * i / 4.0, radarR * 2 * i / 4.0, PI, TWO_PI);
  }

  stroke(radarGreen, 90);
  for (int a = 0; a <= 180; a += 30) {
    line(0, 0, -radarR * cos(radians(a)), -radarR * sin(radians(a)));
  }

  stroke(radarGreen);
  strokeWeight(3);
  line(0, 0, radarR * cos(radians(iAngle)), -radarR * sin(radians(iAngle)));

  if (iDistance < 40) {
    float pixDist = map(iDistance, 0, 40, 0, radarR);
    stroke(alertRed);
    strokeWeight(6);
    line(pixDist * cos(radians(iAngle)), -pixDist * sin(radians(iAngle)),
         radarR * cos(radians(iAngle)), -radarR * sin(radians(iAngle)));
  }

  fill(radarGreen);
  textSize(12);
  textAlign(CENTER);
  for (int i = 1; i <= 4; i++) {
    text((i * 10) + "cm", -radarR + radarR * 2 * i / 4.0, 18);
  }
  textAlign(LEFT);

  popMatrix();
}

// ---------- Right panel: all info + controls ----------
void drawRightPanel() {
  drawPanelBox(panelX, panelY, panelW, panelH, "SYSTEM INFORMATION");

  int ty = panelY + 55;
  drawLabelValue(panelX + 20, ty, "Current Angle", iAngle + "°"); ty += 46;
  drawLabelValue(panelX + 20, ty, "Distance", iDistance + " cm"); ty += 46;
  drawLabelValue(panelX + 20, ty, "Object", (iDistance < 40 ? "Detected" : "None")); ty += 60;

  fill(radarGreen);
  noStroke();
  textSize(14);
  text("ENVIRONMENT", panelX + 20, ty);
  ty += 8;
  stroke(panelBorder);
  strokeWeight(0.5);
  line(panelX + 20, ty, panelX + panelW - 20, ty);
  ty += 32;

  String modeTxt = (iLightMode == 0) ? "AUTO" : (iLightMode == 1 ? "FORCED ON" : "FORCED OFF");
  drawLabelValue(panelX + 20, ty, "Environment Light Status", (iLightDark == 1 ? "BRIGHT" : "DARK")); ty += 46;
  drawLabelValue(panelX + 20, ty, "Light LED", (iLightOn == 1 ? "ON" : "OFF") + "  (" + modeTxt + ")"); ty += 46;
  drawLabelValue(panelX + 20, ty, "Buzzer", (iBuzzerOn == 1 ? "SOUNDING" : (iMuted == 1 ? "MUTED" : "Silent"))); ty += 30;

  fill(radarGreen);
  noStroke();
  textSize(14);
  text("CONTROLS", panelX + 20, btnMuteY - 20);
  stroke(panelBorder);
  line(panelX + 20, btnMuteY - 12, panelX + panelW - 20, btnMuteY - 12);

  drawButton(btnX, btnMuteY, btnW, btnH, (iMuted == 1 ? "Unmute Buzzer" : "Mute Buzzer"), iMuted == 1);
  String lightLabel = (iLightMode == 0) ? "Light Mode: AUTO" : (iLightMode == 1 ? "Light Mode: ON" : "Light Mode: OFF");
  drawButton(btnX, btnLightY, btnW, btnH, lightLabel, iLightMode != 0);
}

void drawButton(int x, int y, int w, int h, String label, boolean active) {
  fill(active ? buttonBgActive : buttonBg);
  stroke(panelBorder);
  strokeWeight(1.5);
  rect(x, y, w, h, 6);
  fill(radarGreen);
  noStroke();
  textSize(15);
  textAlign(CENTER);
  text(label, x + w / 2, y + h / 2 + 5);
  textAlign(LEFT);
}

void mousePressed() {
  if (!portConnected) return;

  if (mouseX > btnX && mouseX < btnX + btnW && mouseY > btnMuteY && mouseY < btnMuteY + btnH) {
    myPort.write('M');
  }
  if (mouseX > btnX && mouseX < btnX + btnW && mouseY > btnLightY && mouseY < btnLightY + btnH) {
    myPort.write('L');
  }
}

// ---------- Shared helpers ----------
void drawPanelBox(float x, float y, float w, float h, String title) {
  fill(panelBg);
  stroke(panelBorder);
  strokeWeight(1.5);
  rect(x, y, w, h, 8);
  fill(radarGreen);
  noStroke();
  textSize(16);
  text(title, x + 20, y + 28);
  stroke(panelBorder);
  strokeWeight(0.5);
  line(x + 20, y + 38, x + w - 20, y + 38);
}

void drawLabelValue(float x, float y, String label, String value) {
  fill(120, 180, 100);
  textSize(12);
  text(label, x, y);
  fill(230, 255, 220);
  textSize(20);
  text(value, x, y + 22);
}

// ---------- Footer: live status (left) + team credit (right) ----------
void drawFooter() {
  int y = 630;
  fill(0);
  noStroke();
  rect(0, y, width, height - y);
  stroke(panelBorder);
  strokeWeight(0.5);
  line(0, y, width, y);

  fill(radarGreen);
  textSize(14);
  String status = "Scanning Sector " + iAngle + "°   |   " +
                   (iDistance < 40 ? "Target Range " + iDistance + " cm" : "No Target") +
                   "   |   USB Connected";
  text(status, 20, y + 38);

  textAlign(RIGHT);
  fill(150, 220, 130);
  text(TEAM_CREDIT, width - 20, y + 38);
  textAlign(LEFT);
}
