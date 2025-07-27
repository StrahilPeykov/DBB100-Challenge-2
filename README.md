# SoundSynth

An interactive 3D audio visualization system that transforms sound into immersive visual experiences. SoundSynth analyzes music and voice input in real-time, creating dynamic 3D environments with color-coded visual elements that respond to different aspects of the audio.

## Features

### Audio Analysis
- **Dual Input Modes**: Switch between music files (MP3) and live microphone input
- **Advanced Chord Detection**: Uses music theory and psychoacoustics to identify musical notes and chords
- **Beat Detection**: Spectral flux analysis for responsive beat detection
- **Frequency Band Analysis**: Separates audio into bass, low-mid, mid, and high frequency ranges
- **Echo Effects**: Temporal memory system creates trailing visual effects

### Visual Systems
- **3D Environment**: Immersive camera system with automatic and manual control
- **Multiple Visual Modes**: Rectangular and circular layout patterns with smooth transitions
- **Dual Color Systems**:
  - **Scriabin Mode**: Based on Alexander Scriabin's synesthetic color-to-note associations
  - **Rainbow Mode**: Dynamic color cycling based on audio characteristics
- **Layered Visual Elements**:
  - Background star field that moves toward the viewer
  - Mid-layer entities (spheres, boxes, tetrahedrons) that pulse with frequency bands
  - Wave effects that flow along the sides or in spiral patterns
  - Environment elements that form structural boundaries

### Arduino Integration
- **Physical Controls**: Rotary encoders, joystick, and buttons for real-time parameter adjustment
- **Ultrasonic Distance Sensor**: Control movement speed by moving your hand closer/farther
- **LCD Display**: Real-time feedback on current settings and sensor values
- **RGB LED**: Visual status indicator with rainbow cycling effects

## 🎛Controls

### Keyboard Controls
- **Arrow Keys**: Manual camera rotation and vertical movement
- **Space**: Toggle between rectangular and circular visual modes
- **V**: Switch between voice (microphone) and music (MP3) input
- **M**: Toggle between Scriabin and Rainbow color modes
- **A**: Toggle automatic camera movement
- **R**: Reset camera to center position
- **+/-**: Adjust energy detection threshold
- **D**: Display debug information
- **X**: Force parameter reset

### Arduino Controls
- **Rotary Encoder**: Navigate through settings (Size, Density, Visual Mode, Audio Mode)
- **Encoder Button**: Cycle through parameter selection
- **Joystick**: Control camera rotation (Left/Right/Up/Down)
- **Joystick Button**: Reset camera position
- **Screen Toggle Button**: Switch between LCD display screens
- **Ultrasonic Sensor**: Control movement speed by distance (closer = faster)

## 🔧 Requirements

### Software
- **Processing 3.x** or higher
- **Minim Audio Library** (install via Processing IDE: Tools → Add Tool → Libraries)

### Hardware (Optional Arduino Integration)
- Arduino Uno or compatible microcontroller
- 16x2 LCD Display
- Rotary encoder with button
- Analog joystick module
- HC-SR04 ultrasonic distance sensor
- RGB LED (common cathode)
- Push buttons
- Breadboard and jumper wires

## Installation

### Processing Setup
1. Install Processing from [processing.org](https://processing.org/)
2. Install the Minim library:
   - Open Processing IDE
   - Go to Tools → Add Tool → Libraries
   - Search for "Minim" and install

3. Clone or download this repository
4. Place your audio file as `song.mp3` in the `data/` folder
5. Open `SoundSynth.pde` in Processing
6. Run the sketch

### Arduino Setup (Optional)
1. Install the Arduino IDE
2. Install required libraries:
   - LiquidCrystal (built-in)
   - SR04 (for ultrasonic sensor)
3. Connect hardware according to the wiring diagram below
4. Upload `SoundSynth_Arduino.ino` to your Arduino
5. Connect Arduino to computer via USB
6. Run the Processing sketch - it will automatically detect the Arduino

## Arduino Wiring

```
LCD Display:
- VSS → GND
- VDD → 5V
- V0 → 10kΩ potentiometer (contrast)
- RS → Pin 8
- Enable → Pin 9
- D4 → Pin 10
- D5 → Pin 11
- D6 → Pin 12
- D7 → Pin 13

Rotary Encoder:
- CLK → Pin 2 (interrupt)
- DT → Pin 3
- SW → Pin 4
- VCC → 5V
- GND → GND

Joystick:
- VRx → A0
- VRy → A1
- SW → Pin 5
- VCC → 5V
- GND → GND

Ultrasonic Sensor (HC-SR04):
- VCC → 5V
- GND → GND
- Trig → Pin 32
- Echo → Pin 31

RGB LED:
- Red → Pin 28 (with 220Ω resistor)
- Green → Pin 26 (with 220Ω resistor)
- Blue → Pin 24 (with 220Ω resistor)
- Common Cathode → GND

Buttons:
- Screen Toggle → Pin 22 (with pullup)
- Extra Button → Pin 30 (with pullup)
```

## Color Systems

### Scriabin Synesthetic Colors
Based on composer Alexander Scriabin's synesthetic associations:
- **C**: Red
- **C#/Db**: Orange
- **D**: Yellow
- **D#/Eb**: Steel with metallic sheen
- **E**: Green
- **F**: Deep Red
- **F#/Gb**: Bright Blue
- **G**: Orange-Pink
- **G#/Ab**: Purple-Violet
- **A**: Green
- **A#/Bb**: Steel-like bluish grey
- **B**: Bluish-White

### Technical Implementation
- Real-time chord detection across 8 octaves
- Calibrated note detection with perceptual weighting
- Harmonic relationship analysis for improved chord recognition
- Temporal smoothing for stable color transitions

## 🔬 Technical Details

### Audio Analysis Pipeline
1. **FFT Analysis**: Fast Fourier Transform on incoming audio
2. **Frequency Band Separation**: Bass, low-mid, mid, high frequency analysis
3. **Chord Detection**: Musical note identification using equal temperament tuning
4. **Beat Detection**: Spectral flux analysis with adaptive thresholds
5. **Energy Analysis**: Sustained energy tracking for chorus detection

### Performance Optimizations
- Parameter drift prevention system
- Automatic bounds checking and correction
- Efficient 3D rendering with depth testing
- Circular buffer implementation for echo effects
- Smooth interpolation for all parameter changes

### Communication Protocol
Arduino sends structured data to Processing:
```
DATA:size,density,visualMode,audioMode,joystickPos,buttonState,distance
```

## Usage Tips

- **For Music**: Use high-quality audio files for best chord detection
- **For Voice**: Speak clearly or sing into the microphone for responsive visualization
- **Distance Control**: Hold your hand 10-30cm from the ultrasonic sensor for optimal speed control
- **High Energy Sections**: The system automatically detects choruses and increases visual intensity
- **Beat Response**: Strong beats trigger enhanced visual effects and camera movement

## Troubleshooting

**Arduino Not Detected**:
- Check serial port in Arduino IDE (Tools → Port)
- Verify baud rate is set to 115200
- Ensure proper USB connection

**No Audio Response**:
- Check microphone permissions
- Verify audio file is in `data/song.mp3`
- Try toggling between voice and music input (V key)

**Performance Issues**:
- Reduce star count or entity count in code
- Close other applications using audio
- Check if Arduino is sending too much serial data

## Contributing

Contributions are welcome! Areas for improvement:
- Additional color systems
- New visual effects and patterns
- Extended Arduino sensor support
- Performance optimizations
- Documentation and examples

## License

This project is open source. Feel free to modify and redistribute.

## Acknowledgments

- **Alexander Scriabin** - For the synesthetic color system
- **Processing Foundation** - For the creative coding framework
- **Minim Library** - For audio processing capabilities
- **Arduino Community** - For hardware integration examples

---

*Transform your music into visual art with SoundSynth*
