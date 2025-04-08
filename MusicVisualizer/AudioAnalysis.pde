/**
 * Contains the core audio analysis system including:
 * - Temporal buffer management for audio memory and echo effects
 * - Musical note and chord detection with synesthetic color mapping
 * - Beat detection using spectral flux algorithm
 * - Frequency band analysis with perceptual weighting
 * - Audio energy pattern recognition for section detection
 * - Dynamic color generation based on audio characteristics
 * 
 * The algorithms integrate concepts from music theory, psychoacoustics,
 * and signal processing to create responsive audio-visual experiences.
 */

/**
 * Updates the echo buffer with current FFT data.
 * Creates a temporal "memory" of recent audio spectra for echo effects.
 */
void updateEchoBuffer() {
  // Store current spectrum in echo buffer
  for (int i = 0; i < fft.specSize(); i++) {
    echoBuffer[echoIndex][i] = fft.getBand(i);
  }
  
  // Update buffer index using circular buffer pattern
  echoIndex = (echoIndex + 1) % ECHO_FRAMES;
}

/**
 * Calculates the echo effect for a specific frequency band.
 * Implements a custom decay algorithm that weights recent samples more heavily.
 * 
 * @param bandIndex The frequency band to calculate echo for
 * @param decayFactor Controls how quickly the echo fades (higher = faster decay)
 * @return The calculated echo value for the specified band
 */
float getEchoValue(int bandIndex, float decayFactor) {
  float echo = 0;
  for (int j = 1; j < ECHO_FRAMES; j++) {
    int pastIndex = (echoIndex - j + ECHO_FRAMES) % ECHO_FRAMES;
    echo += echoBuffer[pastIndex][bandIndex] * (1.0 / (j * decayFactor));
  }
  return echo;
}

// Constants for chord detection based on music theory
final int NUM_OCTAVES = 8;    // Check notes across 8 octaves 
final int NUM_NOTES = 12;     // 12 notes in Western music (C through B)
final float TUNING_A4 = 440;  // Standard tuning reference: A4 = 440 Hz

/**
 * Calibration offsets to correct for frequency detection biases
 * These values compensate for the perceptual importance of different notes
 * and the natural frequency distribution in typical music.
 */
float[] noteCalibration = {
  0.5,   // C    - reduce to prevent over-detection and red bias
  1.5,   // C#   - boost to improve detection
  1.5,   // D    - boost to improve detection
  2.5,   // D#   - significant boost for under-detection
  2.2,   // E    - major boost for under-detection
  0.6,   // F    - reduce to prevent false positives
  1.5,   // F#   - boost to improve detection
  1.2,   // G    - slight boost
  1.5,   // G#   - boost to improve detection
  1.0,   // A    - neutral (reference note)
  1.6,   // A#   - more boost
  2.8    // B    - significant boost for under-detection
};

/**
 * Performs advanced chord detection based on frequency analysis.
 * Uses Scriabin's synesthesia color mapping with calibrated note detection and sustain.
 * 
 * Algorithm:
 * 1. Apply decay to previous note strengths with different rates
 * 2. Calculate frequencies for all notes across octaves
 * 3. Analyze FFT spectrum to identify musical notes
 * 4. Apply calibration and perceptual weighting
 * 5. Identify harmonic relationships for chord detection
 * 6. Apply temporal smoothing for stable chord transitions
 * 7. Determine when to change the dominant note
 * 8. Update the Scriabin color based on the dominant note
 */
void detectChord() {
  // Apply different decay rates to the dominant note vs. other notes
  // This creates a "sustain" effect for the dominant note
  for (int i = 0; i < NUM_NOTES; i++) {
    if (i == dominantNote) {
      // Slower decay for the dominant note - creates note persistence
      noteStrengths[i] = noteStrengths[i] * dominantNoteSustain;
    } else {
      // Faster decay for non-dominant notes - reduces noise and competing notes
      noteStrengths[i] = noteStrengths[i] * otherNoteDecay;
    }
  }
  
  // Pre-calculate noteFrequencies for all notes in all octaves
  // Uses the equal temperament formula: f = 2^(n/12) * reference frequency
  float[][] noteFreqs = new float[NUM_NOTES][NUM_OCTAVES];
  
  // Calculate each note frequency using equal temperament formula
  for (int octave = 0; octave < NUM_OCTAVES; octave++) {
    for (int note = 0; note < NUM_NOTES; note++) {
      // We'll calculate notes from C0 through B7
      // A4 = 440Hz = MIDI note 69 (octave 4, note 9 where C=0)
      int midiNote = 12 * octave + note;
      int distanceFromA4 = midiNote - 69;
      noteFreqs[note][octave] = TUNING_A4 * pow(2, distanceFromA4/12.0);
    }
  }

  // Analyze FFT spectrum in logarithmic frequency bands for better note resolution
  int fftSize = fft.specSize();
  float sampleRate = useVoiceInput ? microphone.sampleRate() : song.sampleRate();
  
  // Create buckets for each note spanning the octaves
  float[] noteBuckets = new float[NUM_NOTES];
  
  // Process FFT data with focus on importance in music perception
  for (int i = 2; i < fftSize; i++) { // Start at 2 to skip DC offset
    float freq = i * sampleRate / fftSize;
    float amplitude = fft.getBand(i);
    
    // Skip very low frequencies and inaudible high frequencies
    if (freq < 20 || freq > 16000) continue;
    
    // More sensitive threshold for lower frequencies
    float amplitudeThreshold = freq < 150 ? 0.08 : 0.15;
    
    // Skip frequencies with negligible energy
    if (amplitude < amplitudeThreshold) continue;
    
    // Find the closest musical note
    int closestNote = -1;
    float minCents = Float.MAX_VALUE;
    
    // Identify the closest note and how many cents away it is
    for (int note = 0; note < NUM_NOTES; note++) {
      for (int octave = 0; octave < NUM_OCTAVES; octave++) {
        float noteFreq = noteFreqs[note][octave];
        if (noteFreq <= 0) continue;
        
        // Calculate cents difference - standard musical interval measure
        // 100 cents = 1 semitone, formula: cents = 1200 * log2(f1/f2)
        float cents = 1200 * log(freq/noteFreq)/log(2);
        float absCents = abs(cents);
        
        if (absCents < minCents) {
          minCents = absCents;
          closestNote = note;
        }
      }
    }
    
    // Only count if we're within a quarter-tone (50 cents) of a note
    // Use wider tolerance (70 cents) for very low frequencies which are harder to detect precisely
    float centsTolerance = freq < 150 ? 70 : 50;
    
    if (closestNote >= 0 && minCents < centsTolerance) {
      // Weight by how close we are to the exact note (less weight if further away)
      float noteWeight = 1.0 - (minCents/centsTolerance) * 0.5;
      
      // Weight by perceptual importance and amplitude
      float perceptualWeight;
      
      // Apply different weights based on frequency ranges
      if (freq < 150) {
        // Very low bass range
        perceptualWeight = amplitude * 1.0;
      } else if (freq < 250) {
        // Bass range
        perceptualWeight = amplitude * 0.9;
      } else if (freq < 1500) {
        // Mid-range (strongest weight - often contains melody & harmony)
        perceptualWeight = amplitude * 1.5;
      } else {
        // High range (medium weight - often contains harmonics)
        perceptualWeight = amplitude * 1.0;
      }
      
      // Apply calibration offset for this note
      perceptualWeight *= noteCalibration[closestNote];
      
      // Special boost for E, B, and D# which are particularly difficult to detect
      if (closestNote == 4 || closestNote == 11) {  // E is 4, B is 11
        // Bias detection toward E and B by boosting harmonics
        perceptualWeight *= 1.3;
        
        // Extra boost for B specifically to counter red bias
        if (closestNote == 11) {
          perceptualWeight *= 1.2;
        }
      }
      else if (closestNote == 3) {  // D# is 3
        // Special boost for D# which seems to be particularly hard to detect
        perceptualWeight *= 1.5;
      }
      
      // Add to the note bucket
      noteBuckets[closestNote] += perceptualWeight * noteWeight;
    }
  }
  
  // Apply harmonic relationships to help detect chords
  // E.g., if we have a strong C and a strong G, boost E (which completes a C major chord)
  float[] harmonicBoost = new float[NUM_NOTES];
  
  // Common chord patterns to detect and enhance
  // Each array contains the three notes that make up a common chord
  int[][] commonChords = {
    {0, 4, 7},    // C major (C-E-G)
    {4, 7, 11},   // E minor (E-G-B)
    {7, 11, 2},   // G major (G-B-D)
    {9, 0, 4},    // A minor (A-C-E)
    {11, 2, 5},   // B minor (B-D-F)
    {2, 6, 9},    // D major (D-F#-A)
    {3, 7, 10},   // D# minor/Eb minor (D#-G-A#)
    {3, 6, 10},   // D# dim/Eb dim (D#-F#-A#)
    {1, 4, 8}     // C# minor/Db minor (C#-E-G#)
  };
  
  // Check for each common chord
  for (int[] chord : commonChords) {
    // Calculate the average strength of notes in this chord
    float chordStrength = 0;
    for (int note : chord) {
      chordStrength += noteBuckets[note];
    }
    chordStrength /= chord.length;
    
    // If we detect a moderate chord presence, boost all its component notes
    if (chordStrength > 0.4) {
      for (int note : chord) {
        harmonicBoost[note] += chordStrength * 0.45;
      }
    }
  }
  
  // Extra boost for D# when it appears in chords
  // This helps because D# has specific context in common harmonies
  if (harmonicBoost[3] > 0) {  // If D# is already getting some harmonic boost
    harmonicBoost[3] *= 1.4;   // Increase its boost by 40%
  }
  
  // Apply harmonic boosts to note buckets
  for (int i = 0; i < NUM_NOTES; i++) {
    noteBuckets[i] += harmonicBoost[i];
  }
  
  // Apply smoothing to the note buckets
  // This makes the system less responsive to momentary fluctuations
  for (int i = 0; i < NUM_NOTES; i++) {
    // Add to accumulated note strengths with smoothing
    noteStrengths[i] = noteStrengths[i] * 0.75 + noteBuckets[i] * 0.25;
  }
  
  // Find the strongest note (but don't necessarily make it dominant yet)
  float maxStrength = 0;
  int strongestNote = dominantNote; // Default to current dominant
  
  for (int i = 0; i < NUM_NOTES; i++) {
    if (noteStrengths[i] > maxStrength) {
      maxStrength = noteStrengths[i];
      strongestNote = i;
    }
  }
  
  // Calculate frames since last chord change
  int framesSinceChange = frameCount - lastChordChangeFrame;
  
  // Logic for determining if we should change dominant note
  boolean shouldChange = false;
  
  // Only consider changing if:
  // 1. We've held the current chord for at least minChordDuration frames
  // 2. The strongest note is different from the current dominant note
  // 3. The sustain countdown is not active
  if (framesSinceChange >= minChordDuration && strongestNote != dominantNote && sustainCountdown <= 0) {
    
    // Case 1: Current dominant note has become very weak - allow change even with moderate confidence
    if (noteStrengths[dominantNote] < noteFadeThreshold) {
      // If the strongest note is significantly stronger, change
      if (noteStrengths[strongestNote] > noteStrengths[dominantNote] * 1.3) {
        shouldChange = true;
      }
    }
    // Case 2: New strongest note is much stronger - change with high confidence
    else if (noteStrengths[strongestNote] > noteStrengths[dominantNote] * 1.7) {
      shouldChange = true;
    }
    // Case 3: Periodic forced re-evaluation with high threshold - but only after long time
    // This is a safety valve to prevent getting stuck
    else if (framesSinceChange > 120 && noteStrengths[strongestNote] > noteStrengths[dominantNote] * 1.5) {
      shouldChange = true;
    }
  }
  
  // Handle transition from silence to new sound
  // If all notes were very quiet and now something is strong, change immediately
  if (noteStrengths[dominantNote] < 0.1 && noteStrengths[strongestNote] > 0.7) {
    shouldChange = true;
  }
  
  // Detect note onsets - when we're starting a new sound after silence
  boolean isNoteOnset = false;
  if (strongestNote != dominantNote) {
    // Calculate overall energy from a few frames ago vs now
    float prevEnergy = 0;
    float currentEnergy = 0;
    
    // Sum up note strengths from 5 frames ago (using echoBuffer for memory)
    int pastIndex = (echoIndex - 5 + ECHO_FRAMES) % ECHO_FRAMES;
    for (int i = 0; i < fft.specSize() * BAND_MID; i++) {
      prevEnergy += echoBuffer[pastIndex][i];
      currentEnergy += fft.getBand(i);
    }
    
    // If there's a significant increase in energy, it might be a note onset
    if (currentEnergy > prevEnergy * 2.0 && currentEnergy > 1.0) {
      isNoteOnset = true;
    }
  }
  
  // If we detect a strong note onset, be more willing to change
  if (isNoteOnset && noteStrengths[strongestNote] > 0.7) {
    shouldChange = true;
  }
  
  // Initialize sustain countdown when a note fades out but we don't have a new one
  if (noteStrengths[dominantNote] < 0.5 && noteStrengths[strongestNote] < 0.7 && sustainCountdown <= 0) {
    // Start a countdown to hold the current chord color even as it fades
    sustainCountdown = 90; // Hold for about 1.5 seconds (90 frames)
  }
  
  // Decrement sustain countdown
  if (sustainCountdown > 0) {
    sustainCountdown--;
  }
  
  // Apply the change if needed
  if (shouldChange) {
    String[] noteNames = {"C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B"};
    
    // Update the dominant note
    dominantNote = strongestNote;
    lastChordChangeFrame = frameCount;
    
    // Reset sustain countdown
    sustainCountdown = 0;
  }
  
  // Get the Scriabin color for the dominant note
  color targetColor = scriabinColors[dominantNote];
  
  // Special case for transition to any new chord - make it faster 
  float finalTransitionSpeed;
  if (shouldChange) {
    // Much faster transition when changing to any new chord
    finalTransitionSpeed = chordChangeSmoothing * 4.0;
  } else {
    // Normal slower transition
    finalTransitionSpeed = chordChangeSmoothing;
  }
  
  // Smoother transition to new color
  if (frameCount == 1) {
    // Initialize on first frame
    currentScriabinColor = targetColor;
  } else {
    // Apply the color transition using linear interpolation
    float r = lerp(red(currentScriabinColor), red(targetColor), finalTransitionSpeed);
    float g = lerp(green(currentScriabinColor), green(targetColor), finalTransitionSpeed);
    float b = lerp(blue(currentScriabinColor), blue(targetColor), finalTransitionSpeed);
    
    currentScriabinColor = color(r, g, b);
  }
}

/**
 * Updates beat detection based on spectral flux.
 * 
 * Algorithm overview:
 * 1. Calculate spectral flux (sum of positive energy changes across spectrum)
 * 2. Apply smoothing to reduce false positives
 * 3. Track average flux with slow adaptation for threshold adjustment
 * 4. Detect beats when flux exceeds dynamic threshold
 * 5. Calculate beat intensity for visual effects
 */
void updateBeatDetection() {
  // Calculate spectral flux (sum of positive changes across spectrum)
  float currentFlux = 0;
  for (int i = 0; i < fft.specSize(); i++) {
    float bandDiff = fft.getBand(i) - prevSpectrum[i];
    currentFlux += bandDiff > 0 ? bandDiff : 0; // Only count increases in energy
    prevSpectrum[i] = fft.getBand(i);
  }
  
  // Apply smoothing to flux
  spectralFlux = 0.4 * currentFlux + 0.6 * spectralFlux;
  
  // Update average flux with slow adaptation
  averageFlux = 0.99 * averageFlux + 0.01 * spectralFlux;
  
  // Reset beat detection flag
  beatDetected = false;
  beatIntensity = 0;
  
  // Adjust beat threshold based on input mode
  // Voice input typically needs a more sensitive threshold
  float effectiveThreshold = useVoiceInput ? beatThreshold * 0.7 : beatThreshold;
  
  // Detect beats when flux exceeds threshold and average
  if (spectralFlux > effectiveThreshold && 
      spectralFlux > (useVoiceInput ? 1.3 : 1.5) * averageFlux && 
      millis() - beatTimer > beatInterval) {
    
    beatDetected = true;
    beatTimer = millis();
    
    // Store beat intensity (how much it exceeds the threshold)
    beatIntensity = spectralFlux / (effectiveThreshold * 1.5);
    beatIntensity = constrain(beatIntensity, 0, 3); // Cap at 3x threshold
    
    // Dynamically adjust beat interval based on recent detections and input mode
    beatInterval = useVoiceInput ? 300 : 250; // Slightly longer for voice to prevent rapid triggers
  }
}

/**
 * Calculates weighted scores for different frequency bands.
 * 
 * Divides the audio spectrum into frequency bands and applies
 * custom weighting to emphasize different characteristics:
 * - Low (bass): 0-5% of spectrum with emphasis on very low frequencies
 * - Low-Mid: 5-15% of spectrum with bell curve weighting
 * - Mid: 15-25% of spectrum with bell curve weighting
 * - High: 25-40% of spectrum with emphasis on higher frequencies
 */
void updateScores() {
  // Store previous scores
  prevScoreLow = scoreLow;
  prevScoreLowMid = scoreLowMid;
  prevScoreMid = scoreMid;
  prevScoreHigh = scoreHigh;

  // Reset scores for new calculations
  scoreLow = 0;
  scoreLowMid = 0;
  scoreMid = 0;
  scoreHigh = 0;
  
  // Calculate scores with weighting
  float weight;
  
  // Low (bass) with more weight to very low frequencies
  for (int i = 0; i < fft.specSize() * BAND_LOW; i++) {
    weight = 1.0 - (i / (fft.specSize() * BAND_LOW));
    scoreLow += fft.getBand(i) * (1.0 + weight);
  }
  
  // Low-mids with linear weighting
  for (int i = (int)(fft.specSize() * BAND_LOW); i < fft.specSize() * BAND_LOW_MID; i++) {
    float position = (i - fft.specSize() * BAND_LOW) / (fft.specSize() * (BAND_LOW_MID - BAND_LOW));
    weight = 0.5 + 0.5 * sin(position * PI); // Bell curve weighting
    scoreLowMid += fft.getBand(i) * weight;
  }
  
  // Mids with bell curve weighting
  for (int i = (int)(fft.specSize() * BAND_LOW_MID); i < fft.specSize() * BAND_MID; i++) {
    float position = (i - fft.specSize() * BAND_LOW_MID) / (fft.specSize() * (BAND_MID - BAND_LOW_MID));
    weight = 0.5 + 0.5 * sin(position * PI); // Bell curve
    scoreMid += fft.getBand(i) * weight;
  }
  
  // Highs with increasing weight for higher frequencies
  for (int i = (int)(fft.specSize() * BAND_MID); i < fft.specSize() * BAND_HIGH; i++) {
    weight = (i - fft.specSize() * BAND_MID) / (fft.specSize() * (BAND_HIGH - BAND_MID));
    scoreHigh += fft.getBand(i) * (1.0 + weight * 0.5);
  }
  
  // Apply echo effect to add "memory" to the scores
  for (int i = 0; i < fft.specSize() * BAND_LOW; i++) {
    scoreLow += getEchoValue(i, 3.0) * 0.2;
  }
  
  for (int i = (int)(fft.specSize() * BAND_LOW_MID); i < fft.specSize() * BAND_MID; i++) {
    scoreMid += getEchoValue(i, 2.5) * 0.15;
  }
  
  // Apply adaptive smoothing based on beat detection
  float currentSmoothing = beatDetected ? 0.5 : smoothingFactor;
  
  // Smooth the scores
  scoreLow = lerp(prevScoreLow, scoreLow, currentSmoothing);
  scoreLowMid = lerp(prevScoreLowMid, scoreLowMid, currentSmoothing);
  scoreMid = lerp(prevScoreMid, scoreMid, currentSmoothing);
  scoreHigh = lerp(prevScoreHigh, scoreHigh, currentSmoothing);
  
  // Apply decay if current score is lower than previous
  if (prevScoreLow > scoreLow) scoreLow = max(scoreLow, prevScoreLow - decayRate);
  if (prevScoreLowMid > scoreLowMid) scoreLowMid = max(scoreLowMid, prevScoreLowMid - decayRate);
  if (prevScoreMid > scoreMid) scoreMid = max(scoreMid, prevScoreMid - decayRate);
  if (prevScoreHigh > scoreHigh) scoreHigh = max(scoreHigh, prevScoreHigh - decayRate);
}

/**
 * Calculates overall audio intensity with custom weighting.
 * Enhanced for more dramatic response during high-energy sections.
 * 
 * Uses different algorithms for voice vs. music input to account for
 * their different characteristics:
 * - Voice: Higher amplification, faster energy tracking, lower thresholds
 * - Music: Stronger emphasis on RMS, more extreme boost during high-energy sections
 * 
 * @param rms Root Mean Square amplitude of the current audio frame
 * @return The calculated global intensity value for visual scaling
 */
float calculateGlobalIntensity(float rms) {
  // For voice input, we need to adjust the intensity calculation
  if (useVoiceInput) {
    // Voice input typically needs some amplification
    // Apply a scaling factor to make visualizations more responsive
    float voiceAmplification = 1.7;
    
    // Calculate adjusted weights for voice frequencies
    float globalIntensity = 1.2 * scoreLow + 1.3 * scoreLowMid +
                            1.2 * scoreMid + 0.9 * scoreHigh;
    globalIntensity *= voiceAmplification;
    
    // For voice, emphasize RMS less to prevent over-reaction to constant sound
    globalIntensity += (rms * 220);
    
    // Track sustained energy with faster adaptation for voice
    sustainedEnergy = lerp(sustainedEnergy, globalIntensity, 0.12);
    
    // Use a lower energy threshold for voice input
    float voiceEnergyThreshold = energyThreshold * 0.7;
    
    // Detect high-energy sections (like loud speech or singing)
    if (sustainedEnergy > voiceEnergyThreshold) {
      highEnergyCounter += 2; // Count up faster
      if (highEnergyCounter > 15) {
        highEnergySectionActive = true;
      }
    } else {
      highEnergyCounter = max(0, highEnergyCounter - 3); // Faster decay for voice
      if (highEnergyCounter < 8) {
        highEnergySectionActive = false;
      }
    }
    
    // More moderate boost for voice high-energy sections
    if (highEnergySectionActive) {
      globalIntensity *= 1.5;
    }
    
    // Stronger beat reaction for voice to make it more responsive
    if (beatDetected) {
      globalIntensity *= 1.45;
    }
    
    return globalIntensity;
  } 
  else {
    // Original music calculation with enhanced response
    float globalIntensity = 0.9 * scoreLow + 1.0 * scoreLowMid + 
                           1.1 * scoreMid + 0.95 * scoreHigh;
    
    // More emphasis on overall volume (RMS) for chorus sections
    globalIntensity += (rms * 400);
    
    // Track sustained energy for chorus detection
    sustainedEnergy = lerp(sustainedEnergy, globalIntensity, 0.12);
    
    // Detect high-energy sections (like choruses)
    if (sustainedEnergy > energyThreshold * 0.8) {
      highEnergyCounter += 2;
      if (highEnergyCounter > 15) {
        highEnergySectionActive = true;
      }
    } else {
      highEnergyCounter = max(0, highEnergyCounter - 1); // Slower decay
      if (highEnergyCounter < 8) {
        highEnergySectionActive = false;
      }
    }
    
    // Boost during high-energy sections
    if (highEnergySectionActive) {
      globalIntensity *= 1.8;
    }
    
    // Stronger beat response
    if (beatDetected) {
      globalIntensity *= 1.6;
    }
    
    return globalIntensity;
  }
}

/**
 * Generates a rainbow color based on audio analysis.
 * Maps low frequencies to position in rainbow, uses mid and high for variations.
 * 
 * Algorithm details:
 * 1. Calculate base hue from rainbow cycle position and bass frequencies
 * 2. Apply spreading effect based on mid frequencies
 * 3. Adjust saturation based on high frequencies
 * 4. Modulate brightness based on overall intensity and beat detection
 * 5. Apply special effects for high energy sections
 * 
 * @param low Low frequency band score
 * @param lowMid Low-mid frequency band score
 * @param mid Mid frequency band score
 * @param high High frequency band score
 * @param intensity Global intensity value
 * @return The calculated rainbow color
 */
color getRainbowColor(float low, float lowMid, float mid, float high, float intensity) {
  // Base hue determined by rainbow cycle position and bass frequencies
  float bassInfluence = map(low, 0, 200, 0, 60) * rainbowFreqInfluence;
  float baseHue = (rainbowOffset + bassInfluence) % 360;
  
  // Create a spreading effect based on mid frequencies
  float spreadAmount = map(mid, 0, 150, 0, 30) * rainbowFreqInfluence;
  
  // Saturation affected by high frequencies (more high = more white added)
  float saturation = 100 - map(high, 0, 150, 0, 50) * rainbowFreqInfluence;
  
  // Brightness affected by overall intensity and boosted on beats
  float brightness = map(intensity, 0, 300, 60, 100);
  if (beatDetected) brightness = min(brightness + 20, 100);
  
  // Special effect for high energy sections - more vivid colors
  if (highEnergySectionActive) {
    saturation = min(saturation + 20, 100);
    brightness = min(brightness + 10, 100);
  }
  
  // Use HSB color model for rainbow generation
  colorMode(HSB, 360, 100, 100, 255);
  
  // Generate the rainbow color
  color rainbowColor = color(baseHue, saturation, brightness, intensity * 5);
  
  // Switch back to RGB mode for compatibility with rest of the code
  colorMode(RGB, 255, 255, 255, 255);
  
  return rainbowColor;
}
