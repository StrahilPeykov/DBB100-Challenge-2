/**
 * CameraVisualMethods.pde
 * 
 * Manages camera control and visual rendering of the 3D environment.
 * These methods handle the initialization, updating, and display of visual elements,
 * as well as camera movement, transitions between visual modes, and user input handling.
 * 
 * The visualization system uses layers of elements (stars, entities, environment elements)
 * that move through 3D space while responding to audio analysis and user input.
 */

/**
 * Initializes visual entities with different spawn patterns.
 * Creates a non-uniform distribution of visual elements in 3D space.
 */
void initializeEntities() {
  for (int i = 0; i < numEntities; i++) {
    // Distribute entities in a non-uniform pattern
    float dist = random(100, 300);
    float angle = random(TWO_PI);
    
    // Some centered, some spread out for visual variety
    float x, y;
    if (random(1) > 0.3) {
      // Distributed in a ring pattern
      x = width/2 + cos(angle) * dist;
      y = height/2 + sin(angle) * dist;
    } else {
      // Randomly distributed
      x = random(width);
      y = random(height);
    }
    
    entities[i] = new Entity(x, y);
  }
}

/**
 * Initializes environment elements with different patterns.
 * Creates structural elements around the edges and within the visualization space.
 */
void initializeEnvironment() {
  // Create elements with a mix of behaviors
  for (int i = 0; i < numEnvironmentElements; i++) {
    float angle = map(i, 0, numEnvironmentElements, 0, TWO_PI);
    
    int positionType = i % 5; // Five different position types
    float x = 0, y = 0;
    float sizeX = 0, sizeY = 0;
    
    // Position and size based on element type
    switch (positionType) {
      case 0: // Left wall elements
        x = 0;
        y = height/2 + sin(angle * 3) * (height/4);
        sizeX = 8 + sin(angle * 2) * 4;
        sizeY = 100 + cos(angle) * 20;
        break;
      case 1: // Right wall elements
        x = width;
        y = height/2 + sin(angle * 3) * (height/4);
        sizeX = 8 + sin(angle * 2) * 4;
        sizeY = 100 + cos(angle) * 20;
        break;
      case 2: // Bottom wall elements
        x = width/2 + sin(angle * 3) * (width/4);
        y = height;
        sizeX = 100 + cos(angle) * 20;
        sizeY = 8 + sin(angle * 2) * 4;
        break;
      case 3: // Top wall elements
        x = width/2 + sin(angle * 3) * (width/4);
        y = 0;
        sizeX = 100 + cos(angle) * 20;
        sizeY = 8 + sin(angle * 2) * 4;
        break;
      case 4: // Floating elements
        x = width/2 + cos(angle) * (width/3);
        y = height/2 + sin(angle) * (height/3);
        sizeX = 20 + sin(angle * 7) * 10;
        sizeY = 20 + cos(angle * 5) * 10;
        break;
    }
    
    elements[i] = new EnvironmentElement(x, y, sizeX, sizeY, angle);
  }
}

/**
 * Resets camera position to default.
 * Called when user presses reset button or joystick button.
 */
void resetCamera() {
  cameraAngle = 0;
  verticalAngle = 0;
}

/**
 * Updates camera with Arduino joystick input and audio reactivity.
 * 
 * @param globalIntensity Overall audio intensity for subtle camera movement
 */
void updateCamera(float globalIntensity) {
  // Handle manual rotation input (from keyboard or Arduino joystick)
  if (rotateLeft) {
    cameraAngle -= rotationSpeed;
  }
  if (rotateRight) {
    cameraAngle += rotationSpeed;
  }
  if (lookUp) {
    verticalAngle = max(verticalAngle - rotationSpeed/2, -PI/4);
  }
  if (lookDown) {
    verticalAngle = min(verticalAngle + rotationSpeed/2, PI/4);
  }
  
  // Only apply automatic movements in auto mode
  if (autoMode) {
    // Very gentle auto-rotation
    float baseRotation = 0.0005;
    
    // Add extremely subtle movement based on audio
    float audioSway = sin(frameCount * 0.003) * (globalIntensity * 0.00002);
    
    // Combine base rotation with audio influence
    cameraAngle += baseRotation + audioSway;
    
    // Use gentle vertical movement
    float baseVertical = sin(frameCount * 0.001) * 0.0005;
    verticalAngle = constrain(verticalAngle + baseVertical, -0.1, 0.1); // Limited range
    
    // Add minimal camera response on strong beats
    if (beatDetected) {
      // Small camera adjustment based on beat intensity
      float beatResponse = map(beatIntensity, 0, 3, 0.0005, 0.002);
      verticalAngle += beatResponse * sin(frameCount * 0.03);
    }
  }

  // Set up camera position
  float camX = width/2; 
  float camY = height/2;
  float camZ = 500;
  
  // Calculate look direction
  float lookX = camX;
  float lookY = camY + sin(verticalAngle) * 100;
  float lookZ = camZ - 500 + cos(verticalAngle) * 100;
  
  // Rotate up vector for roll effect
  float upX = sin(cameraAngle);
  float upY = cos(cameraAngle);
  float upZ = 0;
  
  // Apply camera transformation
  camera(camX, camY, camZ, lookX, lookY, lookZ, upX, upY, upZ);
}

/**
 * Draws the background with subtle color variations based on audio.
 * Creates a color backdrop that responds to frequency bands.
 * 
 * @param low Low frequency band value
 * @param lowMid Low-mid frequency band value
 * @param mid Mid frequency band value
 * @param high High frequency band value
 */
void drawBackground(float low, float lowMid, float mid, float high) {
  float r, g, b;
  
  if (useScriabinColors) {
    // Scriabin color system background
    r = (low / 120) * 0.5 + red(currentScriabinColor) * 0.02;
    g = (lowMid / 120) * 0.7 + green(currentScriabinColor) * 0.02;
    b = (mid / 120) * 0.3 + blue(currentScriabinColor) * 0.02;
  } else {
    // Rainbow mode background
    color rainbowBg = getRainbowColor(low, lowMid, mid, high, 40);
    r = red(rainbowBg) * 0.02;
    g = green(rainbowBg) * 0.02;
    b = blue(rainbowBg) * 0.02;
    
    // Add subtle frequency influence
    r += (low / 100) * 0.5;
    g += (lowMid / 100) * 0.7;
    b += (mid / 100) * 0.3;
  }
  
  // Set the background color
  background(r, g, b);
}

/**
 * Draws status indicators with Arduino information.
 * Provides visual feedback on system state, sensors, and controls.
 * 
 * @param globalIntensity Overall audio intensity for status indicators
 */
void drawStatusIndicators(float globalIntensity) {
  pushMatrix();
  hint(DISABLE_DEPTH_TEST); // Ensure text displays on top
  textAlign(LEFT);
  textSize(15);
  
  // Auto mode indicator
  if (autoMode) {
    fill(255, 150);
    text("AUTO MODE (GENTLE)", 20, 30);
  }
  
  // Voice input indicator with live level meter
  if (useVoiceInput) {
    float micLevel = microphone.mix.level() * 100; // Scale for visibility
    fill(50, 255, 100, 180);
    text("VOICE INPUT", 20, 60);
    
    // Draw a simple level meter
    stroke(50, 255, 100, 180);
    noFill();
    rect(120, 45, 100, 20);
    fill(50, 255, 100, 180);
    rect(120, 45, constrain(micLevel * 100, 0, 100), 20);
    
    // Display mic level
    fill(255);
    text(nf(micLevel, 1, 2), 225, 60);
  } else {
    fill(150, 150, 255, 150);
    text("MUSIC INPUT", 20, 60);
  }
  
  // Ultrasonic sensor status display
  if (arduinoConnected) {
    // Show ultrasonic sensor status
    fill(50, 200, 255, 220);
    textSize(14);
    text("ULTRASONIC:", 20, 90);
    text(arduinoDistance + " cm", 120, 90);
    
    // Visual indicator of speed multiplier
    fill(50, 200, 255, 180);
    float speedBarWidth = map(currentMovementSpeed, 0.6, 6.0, 10, 150);
    rect(120, 95, speedBarWidth, 5);
    
    // Show current speed
    text("Speed: " + nf(currentMovementSpeed, 1, 1) + "x", 120, 110);
    textSize(15); // reset size
  }
  
  // High energy indicator
  if (highEnergySectionActive) {
    fill(255, 180, 50, 200);
    textSize(18);
    text("HIGH ENERGY", width - 140, 30);
    textSize(15);
    
    // Add energy meter
    fill(255, 180, 50, 150);
    float energyRatio = sustainedEnergy / energyThreshold;
    rect(width - 140, 35, 120 * constrain(energyRatio, 0, 1.5), 5);
  }
  
  // Arduino connection status
  if (arduinoConnected) {
    fill(0, 255, 0, 180);
    text("ARDUINO CONNECTED", width - 180, height - 80);
    
    // Show Arduino control values
    fill(200, 200, 200, 180);
    text("SIZE: " + arduinoSizeControl + "%", width - 180, height - 60);
    text("DENSITY: " + arduinoDensityControl + "%", width - 180, height - 40);
    
    // Show distance and speed multiplier
    float speedDisplay = round(currentMovementSpeed * 10) / 10.0;
    text("DISTANCE: " + arduinoDistance + "cm  SPEED: " + nf(speedDisplay, 1, 1) + "x", width - 180, height - 20);
  } else {
    fill(255, 100, 100, 180);
    text("ARDUINO DISCONNECTED", width - 200, height - 80);
    text("KEYBOARD CONTROLS ACTIVE", width - 200, height - 60);
  }
  
  // Help text
  fill(150, 150, 150);
  text("Press 'V' to toggle Voice/Music input", 20, height - 20);
  text("Press 'M' to toggle color modes", 20, height - 40);
  text("Press SPACE to switch visual mode", 20, height - 60);
  
  // Show color system info
  if (useScriabinColors) {
    // Show Scriabin note name and color
    String[] noteNames = {"C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"};
    fill(currentScriabinColor);
    rect(width - 50, 50, 30, 30);
    fill(255);
    text("SCRIABIN COLOR MODE", width - 180, 70);
    text("CHORD: " + noteNames[dominantNote], width - 180, 90);
  } else {
    // Show Rainbow mode info
    color sampleColor = getRainbowColor(scoreLow, scoreLowMid, scoreMid, scoreHigh, 50);
    fill(sampleColor);
    rect(width - 50, 50, 30, 30);
    fill(255);
    text("RAINBOW COLOR MODE", width - 180, 70);
    text("SPEED: " + nf(rainbowSpeed, 1, 1), width - 180, 90);
  }
  
  hint(ENABLE_DEPTH_TEST);
  popMatrix();
}

/**
 * Draws and updates stars.
 * Renders the background star field with audio reactivity.
 * 
 * @param globalIntensity Overall audio intensity
 */
void drawStars(float globalIntensity) {
  for (Star s : stars) {
    s.update(globalIntensity, currentMovementSpeed);
    s.display();
  }
}

/**
 * Draws entities (foreground objects).
 * Renders the mid-layer visual objects that respond to audio.
 * 
 * @param low Low frequency band value
 * @param lowMid Low-mid frequency band value
 * @param mid Mid frequency band value
 * @param high High frequency band value
 * @param globalIntensity Overall audio intensity
 */
void drawEntities(float low, float lowMid, float mid, float high, float globalIntensity) {
  for (int i = 0; i < numEntities; i++) {
    // Get the corresponding frequency band value
    float bandValue = fft.getBand(i % (int)(fft.specSize() * BAND_HIGH));
    
    // Add some echo to create trailing effect
    float echo = getEchoValue(i % (int)(fft.specSize() * BAND_HIGH), 2.0) * 0.3;
    bandValue = bandValue * 0.7 + echo;
    
    // Display the entity with size influenced by Arduino control
    entities[i].display(low, lowMid, mid, high, bandValue, globalIntensity, beatDetected, arduinoSizeControl);
  }
}

/**
 * Draws 3D wave effects.
 * Creates flowing wave patterns that respond to audio.
 * 
 * @param low Low frequency band value
 * @param lowMid Low-mid frequency band value
 * @param mid Mid frequency band value
 * @param high High frequency band value
 * @param globalIntensity Overall audio intensity
 */
void drawWaveEffects(float low, float lowMid, float mid, float high, float globalIntensity) {
  // Base amplitude affected by global intensity
  float baseAmp = 120 + (globalIntensity * 0.6);
  float waveFreq = 0.012;
  float waveSpeed = 0.04;
  
  int segments = 70;
  int depth = 5000;
  
  strokeWeight(1.5 + (globalIntensity / 180.0));
  noFill();
  
  // Handle transition between modes
  if (transitionProgress < 1.0) {
    // Calculate opacity for rectangular mode elements
    float rectOpacity = map(transitionProgress, 0, 0.5, 1.0, 0.0);
    
    if (rectOpacity > 0) {
      // Draw wave on left side with variation
      drawCustomWave(20, baseAmp, segments, depth, waveFreq, waveSpeed, 
                    lowMid, high, rectOpacity, globalIntensity);
      
      // Draw wave on right side with different parameters
      drawCustomWave(width - 20, baseAmp * 0.8, segments, depth, waveFreq * 1.2, waveSpeed * 0.9, 
                    low, mid, rectOpacity, globalIntensity);
    }
  }
  
  // In circular mode or during transition, draw spiral waves
  if (transitionProgress > 0.0) {
    float radius = lerp(min(width, height) * 0.35, min(width, height) * 0.55, 0.03) + 
                  globalIntensity * 0.02;
    
    float circularOpacity = map(transitionProgress, 0.6, 1.0, 0.0, 0.9);
    
    if (circularOpacity > 0) {
      drawSpiralWaves(radius, baseAmp, lowMid, high, circularOpacity, globalIntensity);
    }
  }
}

/**
 * Draws a custom wave pattern - modified version of sine wave.
 * Creates dynamic wave patterns along the sides of the visualization.
 * 
 * @param xPos X position of the wave
 * @param baseAmp Base amplitude
 * @param segments Number of segments in the wave
 * @param depth Z-depth of the wave
 * @param waveFreq Wave frequency
 * @param waveSpeed Wave speed
 * @param freqLow Low frequency value for color
 * @param freqHigh High frequency value for color
 * @param opacity Opacity multiplier for transition
 * @param globalIntensity Overall audio intensity
 */
void drawCustomWave(float xPos, float baseAmp, int segments, int depth, 
                  float waveFreq, float waveSpeed, float freqLow, float freqHigh, 
                  float opacity, float globalIntensity) {
  
  // Apply strict bounds to amplitude
  baseAmp = constrain(baseAmp, 50, 200);
  
  // Constrain the wave frequency and speed
  waveFreq = constrain(waveFreq, 0.005, 0.03);
  waveSpeed = constrain(waveSpeed, 0.01, 0.1);
  
  for (int j = 0; j < 2; j++) {  // Draw fewer layers
    float layerOffset = j * 0.4;
    
    beginShape();
    for (int i = 0; i <= segments; i++) {
      float z = map(i, 0, segments, -depth, 50);
      float fade = map(z, -depth, 50, 40, 255);
      
      // Modified shrink factor - exponential instead of linear
      float shrink = pow(map(z, -depth, 50, 1.0, 0.1), 1.2);
      
      // Different x-factor calculation
      float xFactor = pow(map(abs(xPos - width/2), 0, width/2, 0.6, 1.0), 1.2);
      
      // Apply strict bounds to wave amplitude
      float waveAmp = constrain(baseAmp * shrink * xFactor, 0, 300);
      
      // Modified waveform - triple sine wave
      float waveformInfluence = 0;
      if (useVoiceInput && microphone.bufferSize() > 0) {
        int sampleIndex = constrain((int)map(z, -depth, 50, 0, microphone.bufferSize() - 1), 0, microphone.bufferSize() - 1);
        waveformInfluence = microphone.mix.get(sampleIndex) * 30;
      } else if (!useVoiceInput && song.bufferSize() > 0) {
        int sampleIndex = constrain((int)map(z, -depth, 50, 0, song.bufferSize() - 1), 0, song.bufferSize() - 1);
        waveformInfluence = song.mix.get(sampleIndex) * 30;
      }
      
      // Different wave function - combines sine and cosine
      float depthFactor = map(z, -depth, 50, 0.4, 1.2);
      
      // Apply consistent timescale to avoid accumulated drift
      float timeComponent = (frameCount % 10000) * waveSpeed + layerOffset;
      
      float y = height/2 + 
                waveAmp * sin(z * waveFreq * depthFactor + timeComponent) * 0.7 +
                waveAmp * 0.3 * cos(z * waveFreq * 2 * depthFactor + timeComponent * 1.5) +
                waveformInfluence;
      
      // Calculate color based on audio and current color system
      if (useScriabinColors) {
        stroke(
          red(currentScriabinColor) * 0.5 + 255 * 0.5, 
          green(currentScriabinColor) * 0.4 + (110 + freqLow * 0.6) * 0.6, 
          blue(currentScriabinColor) * 0.4 + (160 + freqHigh * 0.6) * 0.6, 
          fade * opacity
        );
      } else {
        // Rainbow color mode
        color rainbowColor = getRainbowColor(freqLow/2, freqLow, freqHigh/2, freqHigh, 40);
        stroke(
          red(rainbowColor) * 0.4 + 255 * 0.6, 
          green(rainbowColor) * 0.4 + (110 + freqLow * 0.6) * 0.6, 
          blue(rainbowColor) * 0.4 + (160 + freqHigh * 0.6) * 0.6, 
          fade * opacity
        );
      }
      
      vertex(xPos, y, z);
    }
    endShape();
  }
}

/**
 * Draws spiral waves.
 * Creates spiral wave patterns for circular mode.
 * 
 * @param radius Base radius of the spiral
 * @param baseAmp Base amplitude
 * @param freqMid Mid frequency value for color
 * @param freqHigh High frequency value for color
 * @param opacity Opacity multiplier for transition
 * @param globalIntensity Overall audio intensity
 */
void drawSpiralWaves(float radius, float baseAmp, float freqMid, float freqHigh, 
                     float opacity, float globalIntensity) {
  int numSpirals = 2;
  int points = 90;
  
  float[] depths = {-600, -1800, -3500};  // Different depths
  
  for (int layer = 0; layer < numSpirals; layer++) {
    float layerOffset = layer * 0.15;
    float layerOpacity = opacity * 0.8;
    
    for (int d = 0; d < depths.length; d++) {
      float z = depths[d];
      float shrink = map(z, 0, -4000, 1.0, 0.35);
      float currentRadius = radius * shrink;
      float fade = map(z, 0, -4000, 190, 40);
      
      // Spiral modulation with different parameters
      float waveHeight = baseAmp * 0.06 * shrink;
      float timeFactor = frameCount * 0.025;
      float spiralFactor = 3 + layer * 2; // Varies by layer
      
      beginShape();
      for (int i = 0; i <= points; i++) {
        float angle = map(i, 0, points, 0, TWO_PI);
        
        // Spiral modulation - different formula
        float modulation = (sin(angle * spiralFactor + z * 0.0003 + timeFactor + layerOffset) * 
                          cos(angle * 2 + timeFactor * 0.7)) * waveHeight;
                          
        // Audio influence - handle both input sources
        float audioModulation = 0;
        if (useVoiceInput && microphone.bufferSize() > 0) {
          audioModulation = microphone.mix.get(i % microphone.bufferSize()) * 15 * shrink;
        } else if (!useVoiceInput && song.bufferSize() > 0) {
          audioModulation = song.mix.get(i % song.bufferSize()) * 15 * shrink;
        }
        
        // Calculate spiral coordinates
        float spiralRadius = currentRadius + modulation + audioModulation;
        float x = width/2 + cos(angle) * spiralRadius;
        float y = height/2 + sin(angle) * spiralRadius;
        
        // Color based on frequencies and selected color system
        if (useScriabinColors) {
          stroke(
            red(currentScriabinColor) * 0.5 + 255 * 0.5, 
            green(currentScriabinColor) * 0.4 + (110 + freqMid * 0.6) * 0.6, 
            blue(currentScriabinColor) * 0.4 + (160 + freqHigh * 0.6) * 0.6, 
            fade * layerOpacity
          );
        } else {
          // Rainbow color mode
          color rainbowColor = getRainbowColor(freqMid/2, freqMid, freqHigh/2, freqHigh, 40);
          stroke(
            red(rainbowColor) * 0.4 + 255 * 0.6, 
            green(rainbowColor) * 0.4 + (110 + freqMid * 0.6) * 0.6, 
            blue(rainbowColor) * 0.4 + (160 + freqHigh * 0.6) * 0.6, 
            fade * layerOpacity
          );
        }
        
        strokeWeight(1 + (globalIntensity / 350.0));
        vertex(x, y, z);
      }
      endShape(CLOSE);
    }
  }
}

/**
 * Draws environment elements with transition support.
 * Renders the structural elements of the visualization.
 * 
 * @param low Low frequency band value
 * @param lowMid Low-mid frequency band value
 * @param mid Mid frequency band value
 * @param high High frequency band value
 * @param globalIntensity Overall audio intensity
 */
void drawEnvironment(float low, float lowMid, float mid, float high, float globalIntensity) {
  // Update transition progress if transitioning
  if (transitioning) {
    updateTransition();
  }
  
  // Calculate parameters for circular mode
  float dynamicRadius = lerp(min(width, height) * 0.38, min(width, height) * 0.58, 0.03) + 
                        globalIntensity * 0.015;
  float timeFactor = millis() * 0.001;
  
  for (int i = 0; i < numEnvironmentElements; i++) {
    int positionType = i % 5;
    float angle = map(i, 0, numEnvironmentElements, 0, TWO_PI);
    
    // Calculate circular position
    float wobble = sin(angle * 3 + timeFactor) * 8 * (mid / 140.0);
    float circX = width/2 + cos(angle) * dynamicRadius + random(-1.5, 1.5) * transitionProgress;
    float circY = height/2 + sin(angle) * dynamicRadius + wobble * transitionProgress;
    float circSizeX = 15 + sin(angle * 7) * 5;
    float circSizeY = 90 + cos(angle * 5) * 10;
    
    // Calculate rectangular position
    float rectX, rectY, rectSizeX, rectSizeY;
    
    switch (positionType) {
      case 0: // Left
        rectX = 0;
        rectY = height/2 + sin(angle * 3) * (height/4);
        rectSizeX = 8 + sin(angle * 2) * 4;
        rectSizeY = 90 + cos(angle) * 20;
        break;
      case 1: // Right
        rectX = width;
        rectY = height/2 + sin(angle * 3) * (height/4);
        rectSizeX = 8 + sin(angle * 2) * 4;
        rectSizeY = 90 + cos(angle) * 20;
        break;
      case 2: // Bottom
        rectX = width/2 + sin(angle * 3) * (width/4);
        rectY = height;
        rectSizeX = 90 + cos(angle) * 20;
        rectSizeY = 8 + sin(angle * 2) * 4;
        break;
      case 3: // Top
        rectX = width/2 + sin(angle * 3) * (width/4);
        rectY = 0;
        rectSizeX = 90 + cos(angle) * 20;
        rectSizeY = 8 + sin(angle * 2) * 4;
        break;
      default: // Floating elements
        rectX = width/2 + cos(angle) * (width/3);
        rectY = height/2 + sin(angle) * (height/3);
        rectSizeX = 20 + sin(angle * 7) * 10;
        rectSizeY = 20 + cos(angle * 5) * 10;
        break;
    }
    
    // Interpolate between modes based on transition progress
    float finalX = lerp(rectX, circX, transitionProgress);
    float finalY = lerp(rectY, circY, transitionProgress);
    float finalSizeX = lerp(rectSizeX, circSizeX, transitionProgress);
    float finalSizeY = lerp(rectSizeY, circSizeY, transitionProgress);
    
    // Apply smooth rotation 
    float finalAngle = angle * transitionProgress;
    
    // Update element position and size
    elements[i].updatePosition(finalX, finalY, finalAngle);
    elements[i].updateSize(finalSizeX, finalSizeY);
    
    // Get corresponding frequency band value
    float intensity = fft.getBand(i % (int)(fft.specSize() * BAND_HIGH));
    
    // Add echo effect
    float echo = getEchoValue(i % (int)(fft.specSize() * BAND_HIGH), 2.0) * 0.3;
    intensity = intensity * 0.7 + echo;
    
    // Display the element with Arduino size scaling and speed control
    elements[i].display(low, lowMid, mid, high, intensity, globalIntensity, beatDetected, 
                        arduinoSizeControl, currentMovementSpeed);
  }
}

/**
 * Updates transition between rectangular and circular modes.
 * Handles smooth transition between visual modes.
 */
void updateTransition() {
  if (transitioning) {
    if (isCircularMode) {
      // Transition to rectangular
      transitionProgress -= TRANSITION_SPEED;
      if (transitionProgress <= 0) {
        transitionProgress = 0;
        isCircularMode = false;
        transitioning = false;
      }
    } else {
      // Transition to circular
      transitionProgress += TRANSITION_SPEED;
      if (transitionProgress >= 1) {
        transitionProgress = 1;
        isCircularMode = true;
        transitioning = false;
      }
    }
    
    // Safety timeout - never let transitions take more than 2 seconds
    if (frameCount % 120 == 0 && transitioning) { // After 2 seconds (at 60fps)
      // Force completion of stuck transition
      if (isCircularMode) {
        transitionProgress = 1.0;
      } else {
        transitionProgress = 0.0;
      }
      transitioning = false;
      println("Transition safety timeout - forced completion");
    }
  }
}

/**
 * Handles keyboard input.
 * Process key presses for camera and visualization control.
 */
void keyPressed() {
  // Camera rotation controls using arrow keys
  if (keyCode == LEFT) {
    rotateLeft = true;
  }
  if (keyCode == RIGHT) {
    rotateRight = true;
  }
  if (keyCode == UP) {
    lookUp = true;
  }
  if (keyCode == DOWN) {
    lookDown = true;
  }
  
  // Letter key controls
  if (key == 'a' || key == 'A') {
    // Toggle auto mode for camera movement
    autoMode = !autoMode;
    println(autoMode ? "AUTO MODE ENABLED" : "AUTO MODE DISABLED");
  }
  if (key == ' ') {
    transitioning = true;
    println("TRANSITIONING VISUAL MODE");
  }
  if (key == 'v' || key == 'V') {
    // Toggle between voice (microphone) input and music (MP3) input
    toggleVoiceInput();
  }
  if (key == 'm' || key == 'M') {
    // Toggle between two color modes
    useScriabinColors = !useScriabinColors;
    useRainbowMode = !useScriabinColors;
    
    println("SWITCHED TO: " + (useScriabinColors ? "SCRIABIN COLOR MODE" : "RAINBOW COLOR MODE"));
  }
  if (key == 'r' || key == 'R') {
    // Reset camera
    resetCamera();
    println("CAMERA RESET");
  }
  
  // Add threshold adjustment for testing
  if (key == '+' || key == '=') {
    energyThreshold += 10;
    println("Energy threshold increased to: " + energyThreshold);
  }
  if (key == '-' || key == '_') {
    energyThreshold = max(10, energyThreshold - 10);
    println("Energy threshold decreased to: " + energyThreshold);
  }
  
  // Debug keys
  handleDebugKeys(key);
}

/**
 * Handles keyboard release.
 * Process key releases for camera control.
 */
void keyReleased() {
  if (keyCode == LEFT) {
    rotateLeft = false;
  }
  if (keyCode == RIGHT) {
    rotateRight = false;
  }
  if (keyCode == UP) {
    lookUp = false;
  }
  if (keyCode == DOWN) {
    lookDown = false;
  }
}
