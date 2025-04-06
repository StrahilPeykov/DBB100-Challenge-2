/**
 * VisualClasses.pde
 * 
 * Contains the core visualization entities that form the visual representation
 * of audio data. Each class responds to audio analysis data in unique ways,
 * creating a layered, dynamic visualization system.
 * 
 * The visualization consists of three main element types:
 * - Stars: Background elements creating a sense of movement through space
 * - Entities: Mid-layer objects that respond directly to frequency bands
 * - EnvironmentElements: Structural elements that form walls/boundaries
 */

/**
 * Star class for background effects.
 * Creates a 3D star field that responds to audio intensity and moves
 * toward the viewer to create depth and motion.
 */
class Star {
  // Position in 3D space
  private float x, y, z;
  
  // Visual properties
  private float brightness;
  private float size;
  private float originalSize; // Store original size to prevent drift
  
  // Movement bounds
  private final float MIN_Z = -2500;
  private final float MAX_Z = 100;
  
  /**
   * Constructor - Creates a new star with random position and properties
   */
  Star() {
    resetPosition();
    brightness = random(150, 255);
    originalSize = random(1, 3);
    size = originalSize;
  }
  
  /**
   * Resets star to a new random position.
   * Stars are distributed in a volume around the viewer.
   */
  void resetPosition() {
    x = random(-width*2, width*2);
    y = random(-height*2, height*2);
    z = random(MIN_Z, -100);
  }
  
  /**
   * Updates star position and properties based on audio and control input.
   * 
   * @param intensity Overall audio intensity value
   * @param speedMultiplier Movement speed multiplier (from Arduino)
   */
  void update(float intensity, float speedMultiplier) {
    // Calculate base movement speed with different behavior for chorus sections
    float baseSpeed;
    if (highEnergySectionActive) {
      baseSpeed = 2 + (intensity * 0.008);
      baseSpeed *= 2.3; // Faster during high energy sections
    } else {
      baseSpeed = 0.5 + (intensity * 0.003); // Normal speed
    }
    
    // Apply the Arduino speed control
    z += baseSpeed * speedMultiplier;
    
    // Add subtle random variation for natural movement
    z += random(-0.5, 0.5);
    
    // Pulse size with intensity but prevent drift with constraints
    float pulseAmount = sin(frameCount * 0.1) * (intensity * 0.0002);
    size = constrain(originalSize + pulseAmount, originalSize * 0.5, originalSize * 1.5);
    
    // Reset when past camera with bounds check to prevent z-drift
    if (z > MAX_Z) {
      resetPosition();
      
      // Occasionally refresh brightness
      if (random(1) > 0.7) {
        brightness = random(150, 255);
      }
    }
    
    // Safety check - reset if position is outside expected bounds
    if (z < MIN_Z || z > MAX_Z + 100) {
      resetPosition();
    }
  }
  
  /**
   * Displays the star at its current position.
   * Uses different rendering methods based on distance.
   */
  void display() {
    // Calculate apparent brightness based on distance
    float apparentBrightness = map(
      constrain(z, MIN_Z, MAX_Z), 
      MIN_Z, MAX_Z, 
      brightness * 0.3, brightness
    );
    
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
 * Entity class - Audio-reactive visual elements.
 * These mid-layer objects respond to specific frequency bands and
 * display different geometric shapes that pulse with the music.
 */
class Entity {
  // Position bounds
  final float startingZ = -8000;
  final float maxZ = 800;
  final float minZ = -12000; // Safety bound
  
  // Position and rotation
  float x, y, z;
  private float spinX, spinY, spinZ;
  private float rotX, rotY, rotZ;
  
  // Visual properties
  private float baseSize;
  private int shapeType;
  
  /**
   * Constructor - Creates a new entity at the specified position.
   * 
   * @param x X coordinate
   * @param y Y coordinate
   */
  Entity(float x, float y) {
    this.x = x;
    this.y = y;
    this.z = random(startingZ, maxZ);
    
    // Random rotation axes for 3D movement
    spinX = random(-1, 1);
    spinY = random(-1, 1);
    spinZ = random(-1, 1);
    
    rotX = 0;
    rotY = 0;
    rotZ = 0;
    
    // Random base size
    baseSize = random(30, 70);
    
    // Random shape type for visual variety
    shapeType = int(random(3));
  }
  
  /**
   * Displays the entity with audio reactivity.
   * Shape, size, color and movement are all influenced by audio analysis.
   * 
   * @param low Low frequency band value
   * @param lowMid Low-mid frequency band value
   * @param mid Mid frequency band value
   * @param high High frequency band value
   * @param intensity Band-specific intensity value
   * @param globalIntensity Overall audio intensity
   * @param isBeat True if a beat was detected in current frame
   * @param sizeControl Size multiplier from Arduino (0-100)
   */
  void display(float low, float lowMid, float mid, float high, 
               float intensity, float globalIntensity, boolean isBeat, int sizeControl) {
    // Determine color based on audio, energy level, and current color system
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
    
    // Update rotation with audio-reactive movement
    rotX += intensity * (spinX / 800.0) + sin(frameCount * 0.01) * 0.01;
    rotY += intensity * (spinY / 800.0) + cos(frameCount * 0.015) * 0.01;
    rotZ += intensity * (spinZ / 800.0);
    
    rotateX(rotX);
    rotateY(rotY);
    rotateZ(rotZ);
    
    // Calculate size with audio reactivity and Arduino control
    // Map Arduino size (0-100) to a scaling factor (0.5-2.0)
    float sizeScale = map(sizeControl, 0, 100, 0.5, 2.0);
    float currentSize = (baseSize + (intensity * 0.3) + sin(frameCount * 0.05) * 5) * sizeScale;
    
    // Draw shape based on shape type for visual variety
    switch (shapeType) {
      case 0:
        // Sphere
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
    
    // Update z position with audio-reactive speed
    float speedMultiplier = currentMovementSpeed;

    // Different scaling for chorus vs regular sections
    if (highEnergySectionActive) {
      // Maintain extreme boost for chorus
      speedMultiplier *= 3.5; 
    } else {
      // Regular sections slower
      speedMultiplier *= 0.3;
    }
    
    // Enhanced movement on beats
    if (isBeat) {
      if (highEnergySectionActive) {
        speedMultiplier *= 1.5 + (beatIntensity * 0.5); // Strong in chorus
      } else {
        speedMultiplier *= 1.2 + (beatIntensity * 0.3); // Gentler in regular sections
      }
    }
    
    // Add random variation for organic movement
    speedMultiplier *= 0.85 + random(0.3);
    
    // Calculate final z movement with audio intensity
    float zMovement;
    if (highEnergySectionActive) {
      // Keep chorus sections very fast
      zMovement = speedMultiplier * (1.8 + (intensity / 2.0) + pow(globalIntensity / 140, 1.3));
    } else {
      // Regular sections slower
      zMovement = speedMultiplier * (1.4 + (intensity / 2.5) + pow(globalIntensity / 150, 1.2));
    }
    
    // Apply speed limits for stability
    if (zMovement > 160) zMovement = 160;
    if (zMovement < 0.2) zMovement = 0.2;
    
    // Apply movement
    z += zMovement;
    
    // Reset when past camera
    if (z >= maxZ) {
      float dist = random(100, 300);
      float angle = random(TWO_PI);
      
      // Some centered, some spread out for visual variety
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
    
    // Safety check for z-position
    if (z < minZ) {
      z = startingZ;
    }
  }
  
  /**
   * Draws a tetrahedron shape.
   * Creates a custom 3D shape for visual variety.
   * 
   * @param s Size of the tetrahedron
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
 * EnvironmentElement class - Structural elements that form the visualizer environment.
 * These elements create the walls, boundaries or circular structures that
 * contain the visualization, reacting to audio with color and movement.
 */
class EnvironmentElement {
  // Position bounds
  final float startingZ = -9000;
  final float maxZ = 100;
  final float minZ = -15000;  // Safety bound for extreme values
  
  // Position and dimensions
  float x, y, z;
  private float sizeX, sizeY;
  private float targetX, targetY;
  private float targetSizeX, targetSizeY;
  
  // Original values to prevent drift
  private float originalSizeX, originalSizeY;
  
  // Movement and rotation parameters
  private float moveSpeed;
  private float angle;
  private float targetAngle;
  private float tiltAngle;
  private float pulseRate;
  
  // Element lifecycle tracking
  private int frameCreated;
  private int resetCount = 0;
  
  /**
   * Constructor - Creates a new environment element with position, size and angle.
   * 
   * @param x X coordinate
   * @param y Y coordinate
   * @param sizeX Width
   * @param sizeY Height
   * @param angle Initial rotation angle
   */
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
    
    this.moveSpeed = random(0.6, 1.8);
    this.pulseRate = random(0.03, 0.08);
    
    this.frameCreated = frameCount;
  }
  
  /**
   * Alternative constructor for backward compatibility.
   */
  EnvironmentElement(float x, float y, float sizeX, float sizeY) {
    this(x, y, sizeX, sizeY, 0);
  }
  
  /**
   * Updates position smoothly.
   * Creates smooth transitions when moving between positions or modes.
   * 
   * @param newX Target X coordinate
   * @param newY Target Y coordinate
   * @param newAngle Target rotation angle
   */
  void updatePosition(float newX, float newY, float newAngle) {
    this.targetX = newX;
    this.targetY = newY;
    this.targetAngle = newAngle;
    
    // Smooth position transition
    this.x = lerp(this.x, targetX, 0.04);
    this.y = lerp(this.y, targetY, 0.04);
    this.angle = lerp(this.angle, targetAngle, 0.04);
    
    // Dynamic tilt animation
    this.tiltAngle = sin(frameCount * 0.008 + angle) * 0.12;
  }
  
  /**
   * Updates size smoothly with drift protection.
   * 
   * @param newSizeX Target width
   * @param newSizeY Target height
   */
  void updateSize(float newSizeX, float newSizeY) {
    // Store original size for safe reset if needed
    if (frameCount - frameCreated < 10) {
      this.originalSizeX = newSizeX;
      this.originalSizeY = newSizeY;
    }
    
    this.targetSizeX = newSizeX;
    this.targetSizeY = newSizeY;
    
    // Smooth size transition
    this.sizeX = lerp(this.sizeX, targetSizeX, 0.04);
    this.sizeY = lerp(this.sizeY, targetSizeY, 0.04);
    
    // Protect against extreme size values
    if (this.sizeX < 1 || this.sizeY < 1 || this.sizeX > 500 || this.sizeY > 500) {
      resetSize();
    }
  }
  
  /**
   * Resets to original size values.
   * Prevents drift and ensures elements remain visible.
   */
  void resetSize() {
    this.sizeX = this.originalSizeX;
    this.sizeY = this.originalSizeY;
    this.targetSizeX = this.originalSizeX;
    this.targetSizeY = this.originalSizeY;
  }
  
  /**
   * Resets element to new starting position.
   * Called when element passes beyond view or needs repositioning.
   */
  void resetElement() {
    this.z = random(startingZ, startingZ * 0.8);
    resetCount++;
  }
  
  /**
   * Displays the element with audio reactivity.
   * Creates visual representation with color and size influenced by audio.
   * 
   * @param low Low frequency band value
   * @param lowMid Low-mid frequency band value
   * @param mid Mid frequency band value
   * @param high High frequency band value
   * @param intensity Band-specific intensity value
   * @param globalIntensity Overall audio intensity
   * @param isBeat True if a beat was detected in current frame
   * @param sizeControl Size multiplier from Arduino (0-100)
   * @param speedMultiplier Movement speed multiplier
   */
  void display(float low, float lowMid, float mid, float high, 
               float intensity, float globalIntensity, boolean isBeat,
               int sizeControl, float speedMultiplier) {
    // Determine color based on audio and selected color system
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
    
    // Create pulsing movement based on audio
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
    
    // Pulse size with audio
    float pulseX = sin(frameCount * pulseRate) * intensity * 0.1;
    float pulseY = cos(frameCount * pulseRate) * intensity * 0.1;
    
    // Apply Arduino size control (0-100) to scaling factor (0.5-2.0)
    float sizeScale = map(sizeControl, 0, 100, 0.5, 2.0);
    
    // Calculate final dimensions
    float boxSizeX = constrain(sizeX * (1 + pulseX), 1, 500) * sizeScale;
    float boxSizeY = constrain(sizeY * (1 + pulseY), 1, 500) * sizeScale;
    float boxSizeZ = constrain((10 + intensity * 0.2), 1, 50) * sizeScale;
    
    // Create box
    box(boxSizeX, boxSizeY, boxSizeZ);
    
    popMatrix();
    
    // Calculate movement speed with different behavior for high-energy sections
    float baseSpeed;
    
    if (highEnergySectionActive) {
      // Fast speed during chorus
      baseSpeed = pow(globalIntensity / 140.0, 1.4);
      baseSpeed *= 3.3;
    } else {
      // Slower speed during regular sections
      baseSpeed = pow(globalIntensity / 150.0, 1.35) * 0.4;
    }
    
    // Apply Arduino control multiplier
    float envSpeed = baseSpeed * speedMultiplier; 
    
    // Enhance speed on beats
    if (isBeat) {
      if (highEnergySectionActive) {
        envSpeed *= 1.6 + (beatIntensity * 0.5); // Strong in chorus
      } else {
        envSpeed *= 1.3 + (beatIntensity * 0.3); // Gentler in regular sections
      }
    }
    
    // Add randomness for variety
    envSpeed *= 0.85 + random(0.3);
    
    // Apply speed limits
    if (envSpeed > 200) envSpeed = 200;
    if (envSpeed < 0.1) envSpeed = 0.1;
    
    // Apply movement
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
    
    // Safety check for extreme z positions
    if (z < minZ) {
      z = startingZ;
    }
  }
}
