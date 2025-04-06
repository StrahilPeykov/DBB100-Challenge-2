/**
 * Music Visualizer - Main Program
 * 
 * An interactive audio visualization system that responds to both music and voice input,
 * integrated with Arduino sensors for physical control. The system creates an immersive
 * audio-visual experience with 3D visualization that reacts to music characteristics.
 * 
 * Core Features:
 * - Dual input modes: MP3 music playback and microphone input for voice
 * - Real-time FFT audio analysis with multiple frequency band processing
 * - Advanced beat detection and chord recognition algorithms
 * - Synesthetic color mapping based on musical notes (Scriabin system)
 * - Dynamic 3D visualization with responsive particle systems
 * - Physical control interface through Arduino sensors
 * - Interactive camera system for exploring the 3D environment
 * 
 * Required Libraries:
 * - Minim (audio processing)
 * - Serial (Arduino communication)
 */

import ddf.minim.*;
import ddf.minim.analysis.*;
import processing.serial.*; // Serial library for Arduino communication

// ================ GLOBAL AUDIO OBJECTS ================

Minim minim;
AudioPlayer song;
AudioInput microphone;
FFT fft;

// ================ ARDUINO COMMUNICATION ================

Serial arduinoPort;
boolean arduinoConnected = false;
String serialBuffer = "";

// Arduino control variables
int arduinoSizeControl = 50;    // Size control value (0-100) from Arduino
int arduinoDensityControl = 50; // Density control value (0-100) from Arduino
String arduinoVisualMode = "CIRCLE"; // Visual mode from Arduino
String arduinoJoystickPos = "CE"; // Joystick position (CE = center)
boolean arduinoJoystickButton = false; // Joystick button state
int arduinoDistance = 100; // Distance from ultrasonic sensor (cm)
boolean manualDistance = false; // Flag to track if user is controlling with sensor

// ================ AUDIO ANALYSIS PARAMETERS ================

// Input mode selection
boolean useVoiceInput = false;

// Frequency band divisions
final float BAND_LOW = 0.05;      // 5% for bass frequencies
final float BAND_LOW_MID = 0.15;  // 15% for low-mid frequencies
final float BAND_MID = 0.25;      // 25% for mid frequencies
final float BAND_HIGH = 0.40;     // 40% for high frequencies

// Scores for each frequency band
float scoreLow = 0;
float scoreLowMid = 0;
float scoreMid = 0;
float scoreHigh = 0;

// Previous scores for smoothing
float prevScoreLow = 0;
float prevScoreLowMid = 0;
float prevScoreMid = 0;
float prevScoreHigh = 0;

// Smoothing and decay parameters
float smoothingFactor = 0.3; // Controls transition smoothness between frames
float decayRate = 15; // Controls how quickly scores decrease when audio fades

// ================ BEAT DETECTION VARIABLES ================

float[] prevSpectrum;
float spectralFlux = 0;
float averageFlux = 0;
boolean beatDetected = false;
float beatThreshold = 0.5;
float beatTimer = 0;
float beatInterval = 0;
float beatIntensity = 0; // Strength of detected beat (0.0-3.0)

// ================ AUDIO MEMORY/ECHO EFFECT ================

final int ECHO_FRAMES = 10; // Number of frames to store for echo effect
float[][] echoBuffer;
int echoIndex = 0;

// ================ CAMERA CONTROL ================

float cameraAngle = 0;
float verticalAngle = 0;
float rotationSpeed = 0.04;
boolean rotateLeft = false;
boolean rotateRight = false;
boolean lookUp = false;
boolean lookDown = false;
boolean autoMode = false; // Auto rotation/movement mode toggle

// ================ VISUAL ELEMENTS ================

// Visual entities (foreground objects)
int numEntities;
Entity[] entities;

// Environment elements (background structures)
int numEnvironmentElements = 450;
EnvironmentElement[] elements;

// Star field (deep background)
Star[] stars;
int numStars = 350;
int baseNumStars = 350; // Store base number for Arduino density control

// ================ VISUAL MODE PARAMETERS ================

boolean isCircularMode = false;
float transitionProgress = 0.0;
boolean transitioning = false;
final float TRANSITION_SPEED = 0.025;

// ================ COLOR SYSTEMS ================

// 1. Scriabin's synesthesia color system
// Maps musical notes to specific colors based on Alexander Scriabin's synesthetic associations
color[] scriabinColors = {
  color(255, 0, 0),       // C: Red
  color(255, 80, 0),      // C#/Db: Orange
  color(255, 255, 0),     // D: Yellow
  color(126, 211, 33),    // D#/Eb: Steel with metallic sheen (yellowish-green)
  color(0, 255, 0),       // E: Green
  color(220, 0, 0),       // F: Deep Red
  color(0, 130, 255),     // F#/Gb: Bright Blue
  color(255, 170, 100),   // G: Orange-Pink (salmon)
  color(130, 0, 130),     // G#/Ab: Purple-Violet
  color(0, 255, 100),     // A: Green
  color(130, 130, 180),   // A#/Bb: Steel-like (bluish grey)
  color(150, 210, 255)    // B: Bluish-White
};

// 2. Rainbow color mode variables
boolean useRainbowMode = false;
float rainbowSpeed = 0.5;        // Controls how fast the rainbow cycles
float rainbowOffset = 0.0;       // Current position in the rainbow cycle
float rainbowWidth = 120.0;      // Width of the spectrum used
float rainbowFreqInfluence = 0.6; // How much frequencies affect the rainbow

// Color system toggle
boolean useScriabinColors = true; // True for Scriabin, False for Rainbow

// ================ CHORD DETECTION VARIABLES ================

float[] noteStrengths = new float[12]; // Strength of each of the 12 notes (C through B)
int dominantNote = 0;                  // Most prominent note (0=C, 1=C#, etc)
float chordChangeSmoothing = 0.1;      // How quickly colors change between chords
color currentScriabinColor;            // Current color based on Scriabin system
int lastChordChangeFrame = 0;          // When we last changed the dominant note
int minChordDuration = 15;             // Minimum frames to hold a chord
float dominantNoteSustain = 0.99;      // Decay rate for dominant note
float otherNoteDecay = 0.85;           // Decay rate for non-dominant notes
float noteFadeThreshold = 0.1;         // Threshold for note fading
int sustainCountdown = 0;              // Counter for extended sustain after note release

// ================ ENERGY DETECTION VARIABLES ================

float sustainedEnergy = 0;
float energyThreshold = 1200;
boolean highEnergySectionActive = false;
int highEnergyCounter = 0;

// ================ MOVEMENT SPEED VARIABLES ================

float baseMovementSpeed = 0.35; // Base movement speed multiplier
float currentMovementSpeed = 0.35; // Current movement speed multiplier
float movementSpeedTransition = 0.95; // Smooth transition between speed changes

/**
 * Setup - Initialize audio, visual elements, and communication
 * Sets up all system components and prepares for visualization
 */
void setup() {
  // Set initial energy threshold for chorus detection
  energyThreshold = 800;
  
  // Set initial speed values
  baseMovementSpeed = 0.45;
  currentMovementSpeed = 0.45;
  
  // Display in 3D, fullscreen
  fullScreen(P3D);
  
  // Initialize Minim audio library
  minim = new Minim(this);
  
  // Load song for music mode
  song = minim.loadFile("song.mp3");
  
  // Set up microphone input for voice mode
  microphone = minim.getLineIn(Minim.STEREO, 1024);
  
  // Initially create FFT for song (we'll switch between song and mic as needed)
  fft = new FFT(song.bufferSize(), song.sampleRate());
  
  // Initialize beat detection
  prevSpectrum = new float[fft.specSize()];
  
  // Initialize echo buffer for audio memory effects
  echoBuffer = new float[ECHO_FRAMES][fft.specSize()];
  
  // Determine number of visual entities based on FFT bands
  numEntities = (int)(fft.specSize() * BAND_HIGH / 2);
  entities = new Entity[numEntities];
  
  // Create environment elements array
  elements = new EnvironmentElement[numEnvironmentElements];
  
  // Initialize visual elements
  initializeEntities();
  initializeEnvironment();
  
  // Create star field
  stars = new Star[numStars];
  for (int i = 0; i < numStars; i++) {
    stars[i] = new Star();
  }

  // Set initial background
  background(0);
  
  // Initialize Scriabin color
  currentScriabinColor = scriabinColors[dominantNote];
  
  // Start playing the song
  song.play(0);
  
  // Initialize Arduino communication
  setupArduinoCommunication();
  
  // Initialize parameter tracking for drift prevention
  initializeParameterTracking();
  
  // Log initial system state
  if (arduinoConnected) {
    println("Ultrasonic sensor enabled - Distance: " + arduinoDistance + "cm");
    println("Initial speed multiplier: " + nf(currentMovementSpeed, 1, 1) + "x");
  }
  
  println("Energy threshold set to: " + energyThreshold);
  println("Starting in SCRIABIN COLOR MODE");
}

/**
 * Main draw loop - Process audio and update visualization
 * This is the heart of the system, called continuously to update the visualization
 */
void draw() {
  // Check for and fix parameter drift
  checkAndFixParameterDrift();
  
  // Analyze current audio source based on input mode
  if (useVoiceInput) {
    fft.forward(microphone.mix);
  } else {
    fft.forward(song.mix);
  }
  
  // Update audio memory for echo effects
  updateEchoBuffer();
  
  // Calculate spectral flux and detect beats
  updateBeatDetection();
  
  // Update color system
  if (useScriabinColors) {
    // Detect the dominant chord/note for Scriabin colors
    detectChord();
  } else {
    // For Rainbow mode, update the rainbow cycle position
    rainbowOffset += 0.01 * rainbowSpeed;
    if (rainbowOffset > 360) rainbowOffset = 0;
  }
  
  // Calculate and smooth scores for frequency bands
  updateScores();
  
  // Calculate global intensity value based on current audio source
  float rms = useVoiceInput ? microphone.mix.level() : song.mix.level();
  float globalIntensity = calculateGlobalIntensity(rms);
  
  // Handle camera movement
  updateCamera(globalIntensity);
  
  // Set background color based on audio
  drawBackground(scoreLow, scoreLowMid, scoreMid, scoreHigh);
  
  // Display status indicators
  drawStatusIndicators(globalIntensity);
  
  // Draw visualization elements in order from background to foreground
  drawStars(globalIntensity);
  drawEntities(scoreLow, scoreLowMid, scoreMid, scoreHigh, globalIntensity);
  drawWaveEffects(scoreLow, scoreLowMid, scoreMid, scoreHigh, globalIntensity);
  drawEnvironment(scoreLow, scoreLowMid, scoreMid, scoreHigh, globalIntensity);
  
  // Handle visual mode transitions
  updateTransition();
}
