#include <LiquidCrystal.h>
#include "SR04.h"

// Define pins for the rotary encoder
#define PinCLK 2
#define PinDT 3
#define PinSW 4

// Joystick pins
const int SW_pin = 5;
const int X_pin = A0;
const int Y_pin = A1;

// Ultrasonic sensor pins
#define TRIG_PIN 32
#define ECHO_PIN 31
SR04 sr04 = SR04(ECHO_PIN, TRIG_PIN);
long distance;

// RGB LED pins
#define RED 28
#define GREEN 26
#define BLUE 24

// Initialize LCD (RS, Enable, D4, D5, D6, D7)
LiquidCrystal lcd(8, 9, 10, 11, 12, 13);

// Rotary encoder variables
volatile boolean TurnDetected = false;
volatile boolean rotationdirection;
int selectedValue = 0;
int A = 50, B = 50;  // Scale 0-100 for size and density
int modeIndex = 0;
String modes[] = {"RECT", "CIRCLE"};  

// Joystick movement tracking
String joystickState = "CE";
String prevJoystickState = "CE";

// Button at pin 22 for screen toggle, at 30 doesn't have a function yet
#define SCREEN_TOGGLE_PIN 22  
#define EXTRA_BUTTON_PIN 30
bool showSecondScreen = false;

// RGB color cycle variables
int colorState = 0;
int redValue = 255, greenValue = 0, blueValue = 0;
unsigned long lastRGBUpdate = 0;

// Audio input mode selection
String audioMode = "MP3";
String prevAudioMode = "MP3";

// Serial communication
String inputString = "";
boolean stringComplete = false;

// Communication timing
unsigned long lastSendTime = 0;
const int SEND_INTERVAL = 50;  // Send data every 50ms (20 updates per second)

/**
 * Interrupt service routine for rotary encoder.
 * Detects rotation direction when the encoder is turned.
 */
void isr() {
    delay(4);
    if (digitalRead(PinCLK))
        rotationdirection = digitalRead(PinDT);
    else
        rotationdirection = !digitalRead(PinDT);
    TurnDetected = true;
}

/**
 * Setup function - initializes pins, serial communication, and hardware.
 */
void setup() {
    pinMode(PinCLK, INPUT);
    pinMode(PinDT, INPUT);
    pinMode(PinSW, INPUT_PULLUP);
    pinMode(SW_pin, INPUT);
    digitalWrite(SW_pin, HIGH);
    pinMode(SCREEN_TOGGLE_PIN, INPUT_PULLUP);
    pinMode(EXTRA_BUTTON_PIN, INPUT_PULLUP);
    
    pinMode(RED, OUTPUT);
    pinMode(GREEN, OUTPUT);
    pinMode(BLUE, OUTPUT);
    
    Serial.begin(115200);  // Faster baud rate for smoother communication
    attachInterrupt(digitalPinToInterrupt(PinCLK), isr, FALLING);

    inputString.reserve(50); // Reserve space for incoming commands

    lcd.begin(16, 2);
    updateDisplay();
}

/**
 * Main loop - processes inputs and sends data to Processing.
 */
void loop() {
    // Check if we have received any commands from Processing
    if (stringComplete) {
        processCommand(inputString);
        inputString = "";
        stringComplete = false;
    }

    static bool lastShowSecondScreen = false;
    
    if (digitalRead(SCREEN_TOGGLE_PIN) == LOW) {
        showSecondScreen = !showSecondScreen;
        delay(300);
        lcd.clear(); // Clear LCD on screen switch
    }

    // Read joystick input
    int xValue = analogRead(X_pin);
    int yValue = analogRead(Y_pin);
    bool buttonPressed = digitalRead(SW_pin) == LOW;

    // Determine joystick position
    if (buttonPressed) joystickState = "CE";
    else if (xValue < 300) joystickState = "LE";
    else if (xValue > 700) joystickState = "RI";
    else if (yValue < 300) joystickState = "UP";
    else if (yValue > 700) joystickState = "DO";
    else joystickState = "CE";

    // Get distance from ultrasonic sensor
    distance = sr04.Distance();

    // Handle rotary encoder input
    if (TurnDetected) {
        if (rotationdirection) {
            if (selectedValue == 0) A = max(0, A - 1);
            else if (selectedValue == 1) B = max(0, B - 1);
            else if (selectedValue == 2) modeIndex = (modeIndex + 1) % 2;
            else if (selectedValue == 3) audioMode = (audioMode == "MP3") ? "MIC" : "MP3";  
        } else {
            if (selectedValue == 0) A = min(100, A + 1);
            else if (selectedValue == 1) B = min(100, B + 1);
            else if (selectedValue == 2) modeIndex = (modeIndex + 1) % 2;
            else if (selectedValue == 3) audioMode = (audioMode == "MP3") ? "MIC" : "MP3";  
        }
        TurnDetected = false;
    }

    if (digitalRead(PinSW) == LOW) {
        selectedValue = (selectedValue + 1) % 4;
        delay(300);
    }

    // Send data to Processing only when values change or periodically
    if (millis() - lastSendTime >= SEND_INTERVAL || 
        joystickState != prevJoystickState || 
        audioMode != prevAudioMode) {
        
        // Send structured data to Processing
        Serial.print("DATA:");
        Serial.print(A);
        Serial.print(",");
        Serial.print(B);
        Serial.print(",");
        Serial.print(modes[modeIndex]);
        Serial.print(",");
        Serial.print(audioMode);
        Serial.print(",");
        Serial.print(joystickState);
        Serial.print(",");
        Serial.print(buttonPressed ? "1" : "0");
        Serial.print(",");
        Serial.print(distance);
        Serial.println();
        
        lastSendTime = millis();
        prevJoystickState = joystickState;
        prevAudioMode = audioMode;
    }

    // Update LED color effect
    if (millis() - lastRGBUpdate > 20) {
        rainbowCycle();
        lastRGBUpdate = millis();
    }

    // Update LCD display based on current screen
    if (showSecondScreen) {
        displaySecondScreen();
    } else {
        updateDisplay();
    }
    
    delay(10);
}

/**
 * Processes commands received from Processing.
 * Parses incoming commands and updates state accordingly.
 * 
 * @param command The command string to process
 */
void processCommand(String command) {
    // Trim any whitespace
    command.trim();
    
    // Check for visual mode commands
    if (command.startsWith("MODE:")) {
        String modeValue = command.substring(5); // Extract the mode value
        
        if (modeValue == "CIRCLE") {
            modeIndex = 0; // Set to CIRCLE mode
        }
        else if (modeValue == "RECT") {
            modeIndex = 1; // Set to RECT mode
        }
        
        // Update the display immediately
        if (!showSecondScreen) {
            updateDisplay();
        }
    }
    // Check for audio mode commands
    else if (command.startsWith("AUDIO:")) {
        String audioValue = command.substring(6); // Extract the audio value
        
        if (audioValue == "MP3") {
            audioMode = "MP3";
        }
        else if (audioValue == "MIC") {
            audioMode = "MIC";
        }
        
        // Update the display immediately
        if (!showSecondScreen) {
            updateDisplay();
        }
    }
}

/**
 * Updates the main LCD display.
 * Shows size, density, visual mode, and audio mode.
 */
void updateDisplay() {
    lcd.clear();
    lcd.setCursor(0, 0);
    String strA = (A < 10) ? "  " + String(A) : (A < 100) ? " " + String(A) : String(A);
    String strB = (B < 10) ? "  " + String(B) : (B < 100) ? " " + String(B) : String(B);
    
    if (selectedValue == 0) lcd.print(">A:");
    else lcd.print(" A:");
    lcd.print(strA);
    
    if (selectedValue == 1) lcd.print(" >B:");
    else lcd.print("  B:");
    lcd.print(strB);
    
    lcd.setCursor(8, 1);
    if (selectedValue == 2) lcd.print(">");
    else lcd.print(" ");
    lcd.print(modes[modeIndex]);

    lcd.setCursor(0, 1);
    if (selectedValue == 3) lcd.print(">"); else lcd.print(" ");
    lcd.print(audioMode);
}

/**
 * Displays the second LCD screen.
 * Shows joystick position and ultrasonic distance.
 */
void displaySecondScreen() {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("JOY: ");
    lcd.print(joystickState);
    
    lcd.setCursor(0, 1);
    lcd.print("DIST: ");
    lcd.print(distance);
    lcd.print("cm");
}

/**
 * Sets the RGB LED color.
 * 
 * @param r Red value (0-255)
 * @param g Green value (0-255)
 * @param b Blue value (0-255)
 */
void setColor(int r, int g, int b) {
    analogWrite(RED, r);
    analogWrite(GREEN, g);
    analogWrite(BLUE, b);
}

/**
 * Creates a smooth rainbow cycle effect on the RGB LED.
 * Transitions through red > yellow > green > cyan > blue > magenta > red.
 */
void rainbowCycle() {
    switch (colorState) {
        case 0: greenValue += 5; if (greenValue >= 255) { greenValue = 255; colorState = 1; } break; 
        case 1: redValue -= 5; if (redValue <= 0) { redValue = 0; colorState = 2; } break; 
        case 2: blueValue += 5; if (blueValue >= 255) { blueValue = 255; colorState = 3; } break; 
        case 3: greenValue -= 5; if (greenValue <= 0) { greenValue = 0; colorState = 4; } break; 
        case 4: redValue += 5; if (redValue >= 255) { redValue = 255; colorState = 5; } break; 
        case 5: blueValue -= 5; if (blueValue <= 0) { blueValue = 0; colorState = 0; } break; 
    }
    setColor(redValue, greenValue, blueValue);
}

/**
 * Serial event handler.
 * Accumulates incoming characters into a string until a newline is received.
 */
void serialEvent() {
    while (Serial.available()) {
        char inChar = (char)Serial.read();
        
        // Add character to input string
        if (inChar != '\n') {
            inputString += inChar;
        }
        // End of command when newline is received
        else {
            stringComplete = true;
        }
    }
}
