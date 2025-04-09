/**
 * Manages communication with the Arduino controller.
 * 
 * The Arduino provides:
 * - Size and density control via rotary encoder
 * - Visual mode selection
 * - Audio input mode selection (MP3/Voice)
 * - Camera control via joystick
 * - Speed control via ultrasonic distance sensor
 */

/**
 * Initializes serial connection to the Arduino and handles
 * connection errors.
 */
void setupArduinoCommunication() {
  try {
    // List all available serial ports for debugging
    println("Available serial ports:");
    for (int i = 0; i < Serial.list().length; i++) {
      println(i + ": " + Serial.list()[i]);
    }
    
    // Try to connect to the Arduino (may need to adjust the port index)
    String portName = Serial.list()[8]; // 0 is first port in the list
    arduinoPort = new Serial(this, portName, 115200);
    arduinoPort.bufferUntil('\n'); // Buffer until newline character
    arduinoConnected = true;
    println("Connected to Arduino on port: " + portName);
  }
  catch (Exception e) {
    println("Could not connect to Arduino: " + e.getMessage());
    println("Continuing without Arduino control");
  }
}

/**
 * Processes incoming serial data from Arduino.
 * Parses structured messages containing sensor and control values
 * and applies them to visualization parameters.
 * 
 * @param port The Serial port from which data was received
 */
void serialEvent(Serial port) {
  // Read the incoming data
  String inData = port.readStringUntil('\n');
  if (inData != null) {
    inData = trim(inData); // Remove any whitespace/newline
    
    // Check if it's a properly formatted data message
    if (inData.startsWith("DATA:")) {
      // Extract the data portion
      String dataStr = inData.substring(5);
      String[] values = split(dataStr, ',');
      
      // Make sure we have all expected values
      if (values.length >= 7) {
        try {
          // Parse the values
          arduinoSizeControl = int(values[0]);
          arduinoDensityControl = int(values[1]);
          arduinoVisualMode = values[2];
          String audioModeValue = values[3];
          arduinoJoystickPos = values[4];
          arduinoJoystickButton = values[5].equals("1");
          arduinoDistance = int(values[6]);
                    
          // Toggle Voice/Music Input when needed
          if (audioModeValue.equals("MIC") && !useVoiceInput) {
            toggleVoiceInput();
          } else if (audioModeValue.equals("MP3") && useVoiceInput) {
            toggleVoiceInput();
          }
          
          // Apply visual mode change when needed
          if (arduinoVisualMode.equals("CIRCLE") && !isCircularMode && !transitioning) {
            transitioning = true;
          } else if (arduinoVisualMode.equals("RECT") && isCircularMode && !transitioning) {
            transitioning = true;
          }
          
          // Reset camera on joystick button press
          if (arduinoJoystickButton) {
            resetCamera();
          }
          
          // Process joystick for camera rotation
          processJoystickControl();
          
          // Adjust movement speed based on ultrasonic sensor
          processDistanceSensor();
          
          // Update particle count based on density control
          adjustParticleCount();
        }
        catch (Exception e) {
          println("Error parsing Arduino data: " + e.getMessage());
        }
      }
    }
  }
}

/**
 * Applies joystick control to camera rotation.
 * Converts joystick position to camera movement flags.
 */
void processJoystickControl() {
  // Reset rotation flags
  rotateLeft = false;
  rotateRight = false;
  lookUp = false;
  lookDown = false;
  
  // Set flags based on joystick position
  switch(arduinoJoystickPos) {
    case "LE":
      rotateLeft = true;
      break;
    case "RI":
      rotateRight = true;
      break;
    case "UP":
      lookUp = true;
      break;
    case "DO":
      lookDown = true;
      break;
  }
}

/**
 * Processes ultrasonic distance for speed control.
 * Maps distance readings to movement speed with an exponential curve
 * for more intuitive control.
 */
void processDistanceSensor() {
  // Only update if we have a valid distance reading
  if (arduinoDistance > 0 && arduinoDistance < 300) {
    // Use a steep exponential curve for distance-to-speed mapping
    float targetSpeed;
    
    if (arduinoDistance < 10) {
      // Maximum speed when very close (< 10 cm)
      targetSpeed = 5.0;
    } else if (arduinoDistance > 100) {
      // Minimum speed when far away
      targetSpeed = 0.5;
    } else {
      // Steeper curve for better control at middle distances
      targetSpeed = 5.0 * pow(0.965, arduinoDistance - 10);
    }
    
    // Print current distance and target speed for debugging
    if (frameCount % 30 == 0) {
      println("Distance: " + arduinoDistance + "cm  Target Speed: " + nf(targetSpeed, 1, 2) + "x");
    }
    
    // Smooth the transition
    currentMovementSpeed = lerp(currentMovementSpeed, targetSpeed, 0.15);
    
    // Mark that user is controlling with sensor
    manualDistance = true;
  } else {
    // If distance reading is invalid, gradually return to default speed
    if (manualDistance) {
      currentMovementSpeed = lerp(currentMovementSpeed, baseMovementSpeed, 0.05);
      if (abs(currentMovementSpeed - baseMovementSpeed) < 0.05) {
        manualDistance = false;
      }
    }
  }
}

/**
 * Adjusts particle count based on Arduino density control.
 * Maps density control value to star count with range limits.
 */
void adjustParticleCount() {
  // Map density control (0-100) to desired star count
  int targetStarCount = int(map(arduinoDensityControl, 0, 100, baseNumStars * 0.3, baseNumStars * 2.0));
  
  // Only update if there's a significant change
  if (abs(targetStarCount - numStars) > 5) {
    // Update star count
    if (targetStarCount > numStars) {
      // Add stars
      Star[] newStars = new Star[targetStarCount];
      // Copy existing stars
      for (int i = 0; i < numStars; i++) {
        newStars[i] = stars[i];
      }
      // Add new stars
      for (int i = numStars; i < targetStarCount; i++) {
        newStars[i] = new Star();
      }
      stars = newStars;
    } else {
      // Remove stars - just create a smaller array and copy
      Star[] newStars = new Star[targetStarCount];
      for (int i = 0; i < targetStarCount; i++) {
        newStars[i] = stars[i];
      }
      stars = newStars;
    }
    numStars = targetStarCount;
  }
}

/**
 * Toggles between voice and music input.
 * Handles the transition between microphone and MP3 playback,
 * including FFT reconfiguration and parameter adjustments.
 */
void toggleVoiceInput() {
  // Toggle between voice (microphone) input and music (MP3) input
  useVoiceInput = !useVoiceInput;
  
  // Force high energy to false when switching
  highEnergySectionActive = false;
  highEnergyCounter = 0;
  
  println("SWITCHED TO: " + (useVoiceInput ? "VOICE INPUT" : "MUSIC INPUT"));
  
  // Handle the audio transition
  if (useVoiceInput) {
    // Pause the song when switching to microphone
    if (song.isPlaying()) {
      song.pause();
    }
    
    // Reset FFT for new input source (might have different buffer size)
    fft = new FFT(microphone.bufferSize(), microphone.sampleRate());
  } else {
    // Resume the song when switching back to music mode
    if (!song.isPlaying()) {
      song.play();
    }
    
    // Reset FFT for song
    fft = new FFT(song.bufferSize(), song.sampleRate());
  }
  
  // Reset beat detection variables for the new input source
  prevSpectrum = new float[fft.specSize()];
  spectralFlux = 0;
  averageFlux = 0;
  beatDetected = false;
  beatThreshold = useVoiceInput ? 0.4 : 0.5; // Lower threshold for voice
  
  // Reset energy detection
  sustainedEnergy = 0;
  highEnergySectionActive = false;
  highEnergyCounter = 0;
  
  // Resize and reset echo buffer for new FFT size
  echoBuffer = new float[ECHO_FRAMES][fft.specSize()];
  echoIndex = 0;
  
  // Print current ultrasonic status
  println("Current distance: " + arduinoDistance + "cm");
  println("Current speed multiplier: " + nf(currentMovementSpeed, 1, 1) + "x");
}
