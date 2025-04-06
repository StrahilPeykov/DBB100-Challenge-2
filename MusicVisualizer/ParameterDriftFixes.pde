/**
 * ParameterDriftFixes.pde
 * 
 * Contains mechanisms to prevent parameter drift and maintain system stability.
 * This module monitors critical parameters, detects when they exceed normal bounds,
 * and applies corrections to prevent visualization artifacts or performance issues.
 * 
 * Key features:
 * - Automatic parameter monitoring and bounds enforcement
 * - Periodic parameter checks and logging
 * - Manual and automatic reset capabilities
 * - Debug utilities for system maintenance
 */

// Global parameter monitoring and reset variables
float originalBaseMovementSpeed;
int frameCountAtLastReset = 0;
boolean needsParameterReset = false;
final int AUTO_RESET_INTERVAL = 60000; // Auto-reset parameters every ~15-20 minutes (at 60fps)

/**
 * Initializes the parameter tracking system.
 * Stores original values of key parameters for later restoration.
 * Should be called at the end of the setup() function.
 */
void initializeParameterTracking() {
  // Store original values of important parameters
  originalBaseMovementSpeed = baseMovementSpeed;
  frameCountAtLastReset = frameCount;
  
  // Log initial state
  println("Parameter tracking initialized");
  println("Base movement speed: " + baseMovementSpeed);
  println("Star count: " + numStars);
  println("Entity count: " + numEntities);
  println("Environment element count: " + numEnvironmentElements);
}

/**
 * Checks for and fixes parameter drift.
 * Should be called at the beginning of the draw() function.
 * Automatically detects and corrects parameter drift.
 */
void checkAndFixParameterDrift() {
  // Check if auto-reset is needed based on elapsed frames
  if (frameCount - frameCountAtLastReset > AUTO_RESET_INTERVAL) {
    needsParameterReset = true;
  }
  
  // Perform reset if needed
  if (needsParameterReset) {
    resetParameters();
    needsParameterReset = false;
  }
  
  // Always enforce parameter bounds
  enforceParameterBounds();
  
  // Periodically log parameter state (every ~10 seconds)
  if (frameCount % 600 == 0) {
    logParameterState();
  }
}

/**
 * Resets all parameters to original values.
 * Restores system to a known good state.
 * Can be called manually with a key press.
 */
void resetParameters() {
  println("Resetting parameters to original values");
  
  // Reset movement speed
  baseMovementSpeed = originalBaseMovementSpeed;
  currentMovementSpeed = baseMovementSpeed;
  
  // Reset star count if it's drifting without Arduino control
  if (!arduinoConnected && numStars != baseNumStars) {
    println("Resetting star count from " + numStars + " to " + baseNumStars);
    numStars = baseNumStars;
    stars = new Star[numStars];
    for (int i = 0; i < numStars; i++) {
      stars[i] = new Star();
    }
  }
  
  // Reset entity parameters
  for (Entity entity : entities) {
    // Reset any entity parameters that might drift
    entity.z = random(entity.startingZ, entity.maxZ);
  }
  
  // Reset environment elements
  for (EnvironmentElement element : elements) {
    // Reset any environment element parameters that might drift
    element.z = random(element.startingZ, element.maxZ);
  }
  
  // Reset progress indicators
  isCircularMode = (transitionProgress > 0.5);
  if (isCircularMode) {
    transitionProgress = 1.0;
  } else {
    transitionProgress = 0.0;
  }
  transitioning = false;
  
  // Update last reset time
  frameCountAtLastReset = frameCount;
}

/**
 * Enforces bounds on parameters to prevent drift.
 * Applies hard limits to critical parameters without
 * fully resetting the system.
 */
void enforceParameterBounds() {
  // Only prevent extreme speed drift when not manually controlled
  if (!manualDistance) {
    // Only enforce absolute bounds, not reset to exact values
    if (currentMovementSpeed > 5.0) currentMovementSpeed = 5.0;
    if (currentMovementSpeed < 0.2) currentMovementSpeed = 0.2;
  }
  
  // Check if stars are disappearing without Arduino control
  if (!arduinoConnected && numStars < baseNumStars * 0.5) {
    println("Star count has drifted too low: " + numStars + " - resetting to " + baseNumStars);
    numStars = baseNumStars;
    stars = new Star[numStars];
    for (int i = 0; i < numStars; i++) {
      stars[i] = new Star();
    }
  }
  
  // Fix transition parameters
  transitionProgress = constrain(transitionProgress, 0, 1);
}

/**
 * Logs current parameter state for debugging.
 * Outputs key system parameters to the console.
 */
void logParameterState() {
  println("---------- PARAMETER STATE ----------");
  println("Frame: " + frameCount);
  println("Movement speed: " + currentMovementSpeed);
  println("Star count: " + numStars);
  println("Transition progress: " + transitionProgress);
  println("Is circular mode: " + isCircularMode);
  println("Is transitioning: " + transitioning);
  println("------------------------------------");
}

/**
 * Handles debug-specific key commands.
 * Called from the keyPressed() function.
 * 
 * @param key The key that was pressed
 */
void handleDebugKeys(int key) {
  if (key == 'd' || key == 'D') {
    // Debug info log
    logParameterState();
  }
  if (key == 'x' || key == 'X') {
    // Force parameter reset
    needsParameterReset = true;
  }
}
