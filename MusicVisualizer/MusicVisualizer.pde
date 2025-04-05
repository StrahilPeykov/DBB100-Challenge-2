import ddf.minim.*;
import ddf.minim.analysis.*;
import processing.serial.*; // Add Serial library for Arduino communication

// Global objects
Minim minim;
AudioPlayer song;
AudioInput microphone;
FFT fft;

// Arduino communication
Serial arduinoPort;
boolean arduinoConnected = false;
String serialBuffer = "";

// Arduino control variables
int arduinoSizeControl = 50;    // 0-100 scale from Arduino 'A' value
int arduinoDensityControl = 50; // 0-100 scale from Arduino 'B' value
String arduinoVisualMode = "CIRCLE"; // Matches modes[] in Arduino code
String arduinoJoystickPos = "CE"; // Center by default
boolean arduinoJoystickButton = false;
int arduinoDistance = 100; // Default mid-range distance
boolean manualDistance = false; // Flag to track if user is controlling with sensor

// Input mode selection
boolean useVoiceInput = false;

// Frequency band divisions - using different percentages and more bands
final float BAND_LOW = 0.05;      // 5% for bass (changed from 3%)
final float BAND_LOW_MID = 0.15;  // 15% for low-mids (new band)
final float BAND_MID = 0.25;      // 25% for mids (changed from 12.5%)
final float BAND_HIGH = 0.40;     // 40% for highs (changed from 20%)

// Scores for each frequency band
float scoreLow = 0;
float scoreLowMid = 0; // New score for low-mids
float scoreMid = 0;
float scoreHigh = 0;

// Previous scores for smoothing
float prevScoreLow = 0;
float prevScoreLowMid = 0;
float prevScoreMid = 0;
float prevScoreHigh = 0;

// Smoothing rate - changed from constant to adaptive
float smoothingFactor = 0.3;
float decayRate = 15; // Changed from 25

// Beat detection variables
float[] prevSpectrum;
float spectralFlux = 0;
float averageFlux = 0;
boolean beatDetected = false;
float beatThreshold = 0.5;
float beatTimer = 0;
float beatInterval = 0;
float beatIntensity = 0; // Store how strong the beat is

// Audio memory/echo effect
final int ECHO_FRAMES = 10;
float[][] echoBuffer;
int echoIndex = 0;

// Camera variables
float cameraAngle = 0;
float verticalAngle = 0;
float rotationSpeed = 0.04; // Changed from 0.05
boolean rotateLeft = false;
boolean rotateRight = false;
boolean lookUp = false;
boolean lookDown = false;
boolean autoMode = false; // Auto rotation/movement mode toggle

// Visual elements
int numEntities;
Entity[] entities;

// Environment elements (renamed from walls)
int numEnvironmentElements = 450; // Changed from 500
EnvironmentElement[] elements;

// Star field
Star[] stars;
int numStars = 350; // Changed from 400
int baseNumStars = 350; // Store the base number for Arduino control

// Visual mode
boolean isCircularMode = false;
float transitionProgress = 0.0;
boolean transitioning = false;
final float TRANSITION_SPEED = 0.025; // Changed from 0.03

// Color systems
// 1. Scriabin's synesthesia color system
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

// NEW Rainbow mode variables
boolean useRainbowMode = false;  // New variable (replacing hybridColorMode and palette)
float rainbowSpeed = 0.5;        // Controls how fast the rainbow cycles
float rainbowOffset = 0.0;       // Current position in the rainbow cycle
float rainbowWidth = 120.0;      // Width of the spectrum used (higher = more color variety)
float rainbowFreqInfluence = 0.6; // How much frequencies affect the rainbow

// Color system toggle
boolean useScriabinColors = true; // True for Scriabin, False for Rainbow

// Variables for chord detection with sustain
float[] noteStrengths = new float[12]; // Strength of each of the 12 notes
int dominantNote = 0;                  // Most prominent note (0=C, 1=C#, etc)
float chordChangeSmoothing = 0.1;      // How quickly colors change between chords
color currentScriabinColor;            // Current color based on Scriabin system
int lastChordChangeFrame = 0;          // When we last changed the dominant note
int minChordDuration = 15;             // Minimum frames to hold a chord
float dominantNoteSustain = 0.99;      // Very slow decay for dominant note (was 0.98)
float otherNoteDecay = 0.85;           // Much faster decay for non-dominant notes (was 0.93)
float noteFadeThreshold = 0.1;         // How low a note can fade before allowing change (was 0.3)
int sustainCountdown = 0;              // Counter for extended sustain after note release

// Energy detection variables for chorus/high-energy sections
float sustainedEnergy = 0;
float energyThreshold = 200;
boolean highEnergySectionActive = false;
int highEnergyCounter = 0;

// Movement speed variables for ultrasonic sensor control
float baseMovementSpeed = 0.6; // Reduced from 1.0 to make regular sections slower
float currentMovementSpeed = 0.6; // Start at base speed
float movementSpeedTransition = 0.95; // Smooth transition between speed changes

/**
 * Updated main loop with dramatically enhanced speed during chorus sections
 * This file has the setup(), draw(), and key handling functions
 */

/**
 * Updated main loop with dramatically enhanced speed during chorus sections
 * This file has the setup(), draw(), and key handling functions
 */

void setup() {
  // Lower energy threshold to detect chorus sections more easily
  energyThreshold = 180; // Reduced from 200
  
  // Set initial speed values
  baseMovementSpeed = 0.7;
  currentMovementSpeed = 0.7;
  
  // Display in 3D, fullscreen
  fullScreen(P3D);
  
  // Initialize Minim
  minim = new Minim(this);
  
  // Load song
  song = minim.loadFile("song.mp3");
  
  // Set up microphone input (will be used when voice mode is active)
  microphone = minim.getLineIn(Minim.STEREO, 1024);
  
  // Initially create FFT for song (we'll switch between song and mic as needed)
  fft = new FFT(song.bufferSize(), song.sampleRate());
  
  // Initialize beat detection
  prevSpectrum = new float[fft.specSize()];
  
  // Initialize echo buffer
  echoBuffer = new float[ECHO_FRAMES][fft.specSize()];
  
  // Determine number of visual elements to display
  numEntities = (int)(fft.specSize() * BAND_HIGH / 2); // Using fewer entities
  entities = new Entity[numEntities];
  
  // Create environment elements
  elements = new EnvironmentElement[numEnvironmentElements];
  
  // Initialize visual elements
  initializeEntities();
  initializeEnvironment();
  
  // Create star field
  stars = new Star[numStars];
  for (int i = 0; i < numStars; i++) {
    stars[i] = new Star();
  }

  // Set background
  background(0);
  
  // Initialize Scriabin color
  currentScriabinColor = scriabinColors[dominantNote];
  
  // Start playing the song
  song.play(0);
  
  // Initialize Arduino communication
  setupArduinoCommunication();
  
  // Initialize parameter tracking
  initializeParameterTracking();
  
  // Force ultrasonic sensor debugging on startup
  if (arduinoConnected) {
    println("Ultrasonic sensor enabled - Distance: " + arduinoDistance + "cm");
    println("Initial speed multiplier: " + nf(currentMovementSpeed, 1, 1) + "x");
  }
  
  // Log energy threshold 
  println("Energy threshold set to: " + energyThreshold);
  println("Starting in SCRIABIN COLOR MODE");
}

void draw() {
  // Check for and fix parameter drift
  checkAndFixParameterDrift();
  
  // Analyze current audio source based on input mode
  if (useVoiceInput) {
    fft.forward(microphone.mix);
  } else {
    fft.forward(song.mix);
  }
  
  // Update audio memory
  updateEchoBuffer();
  
  // Calculate spectral flux and detect beats
  updateBeatDetection();
  
  // If using Scriabin colors, detect the dominant chord/note
  if (useScriabinColors) {
    detectChord();
  } else {
    // For Rainbow mode, update rainbow offset
    rainbowOffset += 0.01 * rainbowSpeed;
    if (rainbowOffset > 360) rainbowOffset = 0;
  }
  
  // Calculate and smooth scores for frequency bands
  updateScores();
  
  // Calculate global intensity value based on current audio source
  float rms = useVoiceInput ? microphone.mix.level() : song.mix.level();
  float globalIntensity = calculateGlobalIntensity(rms);
  
  // Handle camera movement - now influenced by Arduino joystick
  updateCamera(globalIntensity);
  
  // Set background color based on audio
  drawBackground(scoreLow, scoreLowMid, scoreMid, scoreHigh);
  
  // Display indicators
  drawStatusIndicators(globalIntensity);
  
  // Draw stars
  drawStars(globalIntensity);
  
  // Draw entities
  drawEntities(scoreLow, scoreLowMid, scoreMid, scoreHigh, globalIntensity);
  
  // Draw 3D wave effects
  drawWaveEffects(scoreLow, scoreLowMid, scoreMid, scoreHigh, globalIntensity);
  
  // Draw environment elements
  drawEnvironment(scoreLow, scoreLowMid, scoreMid, scoreHigh, globalIntensity);
  
  // Handle visual mode transitions
  updateTransition();
  
  // Debug: Print high energy status periodically to confirm detection
  if (frameCount % 60 == 0) {
    // Print to confirm activation
    if (highEnergySectionActive) {
      println("HIGH ENERGY SECTION ACTIVE! Counter: " + highEnergyCounter + 
              " Energy: " + nf(sustainedEnergy, 1, 1) + 
              " Threshold: " + nf(energyThreshold, 1, 1));
    }
  }
}
