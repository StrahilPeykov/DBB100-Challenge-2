/**
 * Star class for background effects
 * Updated to prevent drift and ensure consistent density
 */
class Star {
  float x, y, z;
  float brightness;
  float size;
  float originalSize; // Store original size to prevent drift
  
  Star() {
    resetPosition();
    brightness = random(150, 255);
    originalSize = random(1, 3);
    size = originalSize;
  }
  
  // Reset star to a new random position
  void resetPosition() {
    x = random(-width*2, width*2);
    y = random(-height*2, height*2);
    z = random(-2500, -100);
  }
  
  void update(float intensity, float speedMultiplier) {
    // Move stars forward with speed influenced by audio and Arduino ultrasonic control
    // Use different base speed for chorus vs regular sections
    float baseSpeed;
    if (highEnergySectionActive) {
      baseSpeed = 2 + (intensity * 0.008);
      baseSpeed *= 2.3; // Make stars much faster during chorus
    } else {
      baseSpeed = 0.9 + (intensity * 0.004); // Slower regular movement
    }
    
    // Apply the Arduino sensor control (make sure this has an impact)
    z += baseSpeed * speedMultiplier;
    
    // Add subtle random variation to movement 
    z += random(-0.5, 0.5);
    
    // Pulse size with intensity but prevent drift with bounds
    float pulseAmount = sin(frameCount * 0.1) * (intensity * 0.0002);
    size = constrain(originalSize + pulseAmount, originalSize * 0.5, originalSize * 1.5);
    
    // Reset when past camera with bounds check to prevent z-drift
    if (z > 100) {
      resetPosition();
      
      // Occasionally refresh brightness
      if (random(1) > 0.7) {
        brightness = random(150, 255);
      }
    }
    
    // Safety check - if z is somehow beyond bounds, reset
    if (z < -3000 || z > 200) {
      resetPosition();
    }
  }
  
  void display() {
    // Calculate apparent brightness based on distance with protection against extreme values
    float apparentBrightness = map(constrain(z, -2500, 100), -2500, 100, brightness * 0.3, brightness);
    
    pushMatrix();
    translate(width/2, height/2);
    fill(apparentBrightness);
    noStroke();
    
    // Position star in 3D space
    translate(x, y, z);
    
    // Draw star as small sphere for closer stars, ellipse for distant ones
    if (z > -500) {
      sphereDetail(4);
      sphere(size);
    } else {
      ellipse(0, 0, size, size);
    }
    
    popMatrix();
  }
}

/**
 * Entity class (formerly Meteor) - visual elements that respond to audio
 * Updated with drift protection and more dynamic movement
 */
class Entity {
  // Position bounds
  final float startingZ = -8000;
  final float maxZ = 800;
  final float minZ = -12000; // Safety bound
  
  // Position and rotation
  float x, y, z;
  float spinX, spinY, spinZ;
  float rotX, rotY, rotZ;
  
  // Visual properties
  float baseSize;
  int shapeType;
  
  // Constructor
  Entity(float x, float y) {
    this.x = x;
    this.y = y;
    this.z = random(startingZ, maxZ);
    
    // Random rotation axes
    spinX = random(-1, 1);
    spinY = random(-1, 1);
    spinZ = random(-1, 1);
    
    rotX = 0;
    rotY = 0;
    rotZ = 0;
    
    // Random base size
    baseSize = random(30, 70);
    
    // Random shape type for variety
    shapeType = int(random(3));
  }
  
  /**
   * Display the entity with audio reactivity and Arduino size control
   */
  void display(float low, float lowMid, float mid, float high, 
               float intensity, float globalIntensity, boolean isBeat, int sizeControl) {
    // Color influenced by frequency bands, energy level, and current color system
    color displayColor;
    
    if (isBeat && random(1) > 0.7) {
      // Bright flash on beat
      displayColor = color(255, 255, 255, intensity * 5);
    } else if (highEnergySectionActive) {
      // Special vibrant colors during chorus/high-energy sections
      if (useScriabinColors) {
        // Using Scriabin color as a base with energetic pulsing
        float energyPulse = sin(frameCount * 0.2) * 30;
        displayColor = color(
          red(currentScriabinColor) + energyPulse + (low * 0.2), 
          green(currentScriabinColor) + (lowMid * 0.3) + (mid * 0.2), 
          blue(currentScriabinColor) + (high * 0.4),
          intensity * 5
        );
      } else {
        // Using Rainbow mode with energy pulse
        color rainbowBase = getRainbowColor(low, lowMid, mid, high, intensity);
        float energyPulse = sin(frameCount * 0.2) * 40;
        displayColor = color(
          red(rainbowBase) + energyPulse,
          green(rainbowBase) + (energyPulse * 0.7),
          blue(rainbowBase) + (energyPulse * 0.5),
          intensity * 5
        );
      }
    } else {
      // Normal color based on audio and selected color system
      if (useScriabinColors) {
        displayColor = color(
          red(currentScriabinColor) * 0.7 + low * 0.3 + high * 0.1, 
          green(currentScriabinColor) * 0.7 + lowMid * 0.2 + mid * 0.2, 
          blue(currentScriabinColor) * 0.7 + mid * 0.1 + high * 0.3, 
          intensity * 5
        );
      } else {
        // Rainbow color mode
        displayColor = getRainbowColor(low, lowMid, mid, high, intensity);
      }
    }
    
    fill(displayColor);
    
    // Edge color
    color strokeColor = color(255, 150 - (25 * intensity));
    stroke(strokeColor);
    strokeWeight(1 + (globalIntensity / 350));
    
    pushMatrix();
    
    // Position in 3D space
    translate(x, y, z);
    
    // Update rotation - more complex formula than original
    rotX += intensity * (spinX / 800.0) + sin(frameCount * 0.01) * 0.01;
    rotY += intensity * (spinY / 800.0) + cos(frameCount * 0.015) * 0.01;
    rotZ += intensity * (spinZ / 800.0);
    
    rotateX(rotX);
    rotateY(rotY);
    rotateZ(rotZ);
    
    // Size affected by intensity and Arduino size control
    // Map Arduino size (0-100) to a scaling factor (0.5-2.0)
    float sizeScale = map(sizeControl, 0, 100, 0.5, 2.0);
    float currentSize = (baseSize + (intensity * 0.3) + sin(frameCount * 0.05) * 5) * sizeScale;
    
    // Draw shape based on shape type
    switch (shapeType) {
      case 0:
        // Sphere - different from original cube
        sphereDetail(6);
        sphere(currentSize / 2);
        break;
      case 1:
        // Box with dynamic stretch
        scale(1 + sin(frameCount * 0.03) * 0.2, 
              1 + cos(frameCount * 0.04) * 0.2, 
              1);
        box(currentSize);
        break;
      case 2:
        // Custom shape - tetrahedron
        drawTetrahedron(currentSize / 1.5);
        break;
    }
    
    popMatrix();
    
    // Update z position with enhanced speed scaling
    float speedMultiplier = currentMovementSpeed;

    // Different scaling for chorus vs regular sections
    if (highEnergySectionActive) {
      // Maintain extreme boost for chorus
      speedMultiplier *= 3.5; 
    } else {
      // Regular sections 40% slower
      speedMultiplier *= 0.45;
    }
    
    // Beat response
    if (isBeat) {
      if (highEnergySectionActive) {
        speedMultiplier *= 1.5 + (beatIntensity * 0.5); // Strong in chorus
      } else {
        speedMultiplier *= 1.2 + (beatIntensity * 0.3); // Gentler in regular sections
      }
    }
    
    // Add random variation
    speedMultiplier *= 0.85 + random(0.3);
    
    // More dramatic response to audio intensity
    float zMovement;
    if (highEnergySectionActive) {
      // Keep chorus sections very fast
      zMovement = speedMultiplier * (1.8 + (intensity / 2.0) + pow(globalIntensity / 140, 1.3));
    } else {
      // Regular sections slower
      zMovement = speedMultiplier * (1.4 + (intensity / 2.5) + pow(globalIntensity / 150, 1.2));
    }
    
    // Allow much higher max speed
    if (zMovement > 160) zMovement = 160;
    if (zMovement < 0.2) zMovement = 0.2;
    
    z += zMovement;
    
    // Reset when past camera
    if (z >= maxZ) {
      float dist = random(100, 300);
      float angle = random(TWO_PI);
      
      // Some centered, some spread out
      if (random(1) > 0.3) {
        // Distributed in a ring pattern
        x = width/2 + cos(angle) * dist;
        y = height/2 + sin(angle) * dist;
      } else {
        // Randomly distributed
        x = random(width);
        y = random(height);
      }
      
      z = startingZ;
      
      // Occasionally change shape type
      if (random(1) > 0.8) {
        shapeType = int(random(3));
      }
    }
    
    // Safety check - if somehow got pushed too far back
    if (z < minZ) {
      z = startingZ;
    }
  }
  
  /**
   * Draw a tetrahedron shape
   */
  void drawTetrahedron(float s) {
    // Define vertices of tetrahedron
    float v = s/2;
    
    beginShape(TRIANGLES);
    
    // Bottom face
    vertex(-v, v, -v);
    vertex(v, v, -v);
    vertex(0, -v, v);
    
    // Front face
    vertex(-v, v, -v);
    vertex(0, -v, v);
    vertex(0, v, v);
    
    // Right face
    vertex(v, v, -v);
    vertex(0, v, v);
    vertex(0, -v, v);
    
    // Back face
    vertex(-v, v, -v);
    vertex(v, v, -v);
    vertex(0, v, v);
    
    endShape();
  }
}

/**
 * EnvironmentElement class (formerly Wall)
 * Updated with drift protection and extreme speed enhancements
 */
class EnvironmentElement {
  // Position bounds
  final float startingZ = -9000; // Now a constant
  final float maxZ = 100;        // Now a constant
  final float minZ = -15000;     // Added minimum bound to catch extreme values
  
  // Position and dimensions
  float x, y, z;
  float sizeX, sizeY;
  float targetX, targetY;
  float targetSizeX, targetSizeY;
  
  // Original values to prevent drift
  float originalSizeX, originalSizeY;
  
  // Movement and rotation parameters
  float moveSpeed;
  float angle;
  float targetAngle;
  float tiltAngle;
  float pulseRate;
  
  // Element lifecycle tracking
  int frameCreated;
  int resetCount = 0;
  
  // Constructors
  EnvironmentElement(float x, float y, float sizeX, float sizeY, float angle) {
    this.x = x;
    this.y = y;
    this.z = random(startingZ, maxZ);
    
    this.sizeX = sizeX;
    this.sizeY = sizeY;
    this.originalSizeX = sizeX;
    this.originalSizeY = sizeY;
    this.targetSizeX = sizeX;
    this.targetSizeY = sizeY;
    
    this.targetX = x;
    this.targetY = y;
    
    this.angle = angle;
    this.targetAngle = angle;
    this.tiltAngle = random(-0.15, 0.15);
    
    this.moveSpeed = random(0.6, 1.8); // Different speed range
    this.pulseRate = random(0.03, 0.08);
    
    this.frameCreated = frameCount;
  }
  
  // Constructor for backward compatibility
  EnvironmentElement(float x, float y, float sizeX, float sizeY) {
    this(x, y, sizeX, sizeY, 0);
  }
  
  /**
   * Update position smoothly
   */
  void updatePosition(float newX, float newY, float newAngle) {
    this.targetX = newX;
    this.targetY = newY;
    this.targetAngle = newAngle;
    
    // Smoother transition with different lerp factor
    this.x = lerp(this.x, targetX, 0.04);
    this.y = lerp(this.y, targetY, 0.04);
    this.angle = lerp(this.angle, targetAngle, 0.04);
    
    // Dynamic tilt angle based on sine wave
    this.tiltAngle = sin(frameCount * 0.008 + angle) * 0.12;
  }
  
  /**
   * Update size smoothly with drift protection
   */
  void updateSize(float newSizeX, float newSizeY) {
    // Store original size for safe reset if needed
    if (frameCount - frameCreated < 10) {
      this.originalSizeX = newSizeX;
      this.originalSizeY = newSizeY;
    }
    
    this.targetSizeX = newSizeX;
    this.targetSizeY = newSizeY;
    
    // Smooth transition
    this.sizeX = lerp(this.sizeX, targetSizeX, 0.04);
    this.sizeY = lerp(this.sizeY, targetSizeY, 0.04);
    
    // Protect against extreme size values that could cause elements to effectively disappear
    if (this.sizeX < 1 || this.sizeY < 1 || this.sizeX > 500 || this.sizeY > 500) {
      resetSize();
    }
  }
  
  /**
   * Reset to original size values
   */
  void resetSize() {
    this.sizeX = this.originalSizeX;
    this.sizeY = this.originalSizeY;
    this.targetSizeX = this.originalSizeX;
    this.targetSizeY = this.originalSizeY;
  }
  
  /**
   * Reset element to new starting position
   */
  void resetElement() {
    this.z = random(startingZ, startingZ * 0.8); // Start further back
    resetCount++;
  }
  
  /**
   * Display the element with audio reactivity
   * Added Arduino size control and extreme speed control parameters
   */
  void display(float low, float lowMid, float mid, float high, 
               float intensity, float globalIntensity, boolean isBeat,
               int sizeControl, float speedMultiplier) {
    // Get the main wall color based on selected color system
    color displayColor;
    
    if (isBeat && random(1) > 0.8) {
      // Occasional flash on beat
      displayColor = color(255, 255, 255, globalIntensity);
    } else {
      // Color based on audio and selected color system
      if (useScriabinColors) {
        // Scriabin color system
        displayColor = color(
          red(currentScriabinColor) * 0.6 + low * 0.3 + high * 0.1, 
          green(currentScriabinColor) * 0.6 + lowMid * 0.2 + mid * 0.2, 
          blue(currentScriabinColor) * 0.6 + mid * 0.1 + high * 0.3, 
          globalIntensity
        );
      } else {
        // Rainbow color mode
        color rainbowColor = getRainbowColor(low, lowMid, mid, high, globalIntensity/10);
        displayColor = color(
          red(rainbowColor) * 0.5 + low * 0.3 + high * 0.2, 
          green(rainbowColor) * 0.5 + lowMid * 0.3 + mid * 0.2, 
          blue(rainbowColor) * 0.5 + mid * 0.2 + high * 0.3, 
          globalIntensity
        );
      }
    }
    
    // Pulsing movement based on audio (with bounds checking)
    float offsetX = sin(frameCount * 0.01 * moveSpeed) * (constrain(sizeX, 5, 100) / 3);
    float offsetY = cos(frameCount * 0.015 * moveSpeed) * (constrain(sizeY, 5, 100) / 3);
    
    // Create fading effect based on distance
    float fadeMultiplier = ((globalIntensity - 5) / 1000.0) * (255 + (z / 25.0));
    fadeMultiplier = constrain(fadeMultiplier, 0, 255);
    
    fill(displayColor, fadeMultiplier);
    noStroke();
    
    pushMatrix();
    
    // Position in 3D space with offset
    translate(x + offsetX, y + offsetY, z);
    
    // Apply rotation
    rotateZ(angle);
    rotateX(tiltAngle);
    
    // Pulse size with audio (with bounds checking)
    float pulseX = sin(frameCount * pulseRate) * intensity * 0.1;
    float pulseY = cos(frameCount * pulseRate) * intensity * 0.1;
    
    // Map Arduino size control (0-100) to a scaling factor (0.5-2.0)
    float sizeScale = map(sizeControl, 0, 100, 0.5, 2.0);
    
    // Dynamic shape based on mode transition with Arduino size influence
    float boxSizeX = constrain(sizeX * (1 + pulseX), 1, 500) * sizeScale;
    float boxSizeY = constrain(sizeY * (1 + pulseY), 1, 500) * sizeScale;
    float boxSizeZ = constrain((10 + intensity * 0.2), 1, 50) * sizeScale;
    
    // Create box
    box(boxSizeX, boxSizeY, boxSizeZ);
    
    popMatrix();
    
    // SUPER-BOOSTED SPEED CALCULATION - Much closer to original
    // But with lower base speed for non-chorus sections
    float baseSpeed;
    
    // Use different base calculation for chorus vs normal sections
    if (highEnergySectionActive) {
      // Maintain extremely fast chorus speed
      baseSpeed = pow(globalIntensity / 140.0, 1.4);
      
      // Ultra boost during chorus
      baseSpeed *= 3.3; // Increased from 3.0 to 3.3
    } else {
      // Slower base speed for regular sections
      baseSpeed = pow(globalIntensity / 150.0, 1.35) * 0.6; // 40% reduction for regular sections
    }
    
    // Apply user control through Arduino (ultrasonic sensor)
    float envSpeed = baseSpeed * speedMultiplier; 
    
    // Stronger beat response for dramatic movement
    if (isBeat) {
      if (highEnergySectionActive) {
        envSpeed *= 1.6 + (beatIntensity * 0.5); // Maintain strong beat boost in chorus
      } else {
        envSpeed *= 1.3 + (beatIntensity * 0.3); // Slightly reduced for regular sections
      }
    }
    
    // Add randomness for varied movement
    envSpeed *= 0.85 + random(0.3);
    
    // Allow MUCH higher speed limit
    if (envSpeed > 200) envSpeed = 200;
    if (envSpeed < 0.1) envSpeed = 0.1;
    
    // Apply speed
    z += envSpeed;
    
    // Reset when past camera
    if (z >= maxZ) {
      resetElement();
      
      // Occasionally change movement parameters
      if (random(1) > 0.7) {
        moveSpeed = random(0.6, 1.8);
        pulseRate = random(0.03, 0.08);
      }
    }
    
    // Safety check: If an element somehow gets too far back, reset it
    if (z < minZ) {
      z = startingZ;
    }
  }
}
