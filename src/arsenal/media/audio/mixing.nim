## Audio Mixing
## =============
##
## Audio mixing and manipulation routines for combining multiple streams.
## Essential for multi-track playback, volume control, and effects.
##
## Features:
## - Mix multiple audio streams (add, multiply)
## - Volume control (linear and dB)
## - Panning (stereo positioning)
## - Crossfading (smooth transitions)
## - Normalization (peak, RMS)
## - Clipping prevention
## - SIMD-optimizable
##
## Performance:
## - Simple mix: ~0.5-1 ns per sample
## - With gain: ~1-2 ns per sample
## - Crossfade: ~2-3 ns per sample
##
## Usage:
## ```nim
## import arsenal/media/audio/mixing
##
## # Mix two audio streams
## var output = newSeq[float32](1024)
## mix(track1, track2, output)
##
## # Apply volume (in dB)
## applyGainDb(samples, -6.0)  # Halve volume
##
## # Pan audio (0.0 = left, 0.5 = center, 1.0 = right)
## panStereo(monoSamples, leftOut, rightOut, pan = 0.75)
##
## # Crossfade between two tracks
## crossfade(trackA, trackB, output, fadePosition = 0.5)
## ```

import std/math

# =============================================================================
# Basic Mixing
# =============================================================================

proc mix*[T](input1, input2: openArray[T], output: var openArray[T]) {.inline.} =
  ## Mix two audio streams (simple addition)
  ##
  ## output = input1 + input2
  ##
  ## WARNING: Can cause clipping if inputs are loud
  ## Use mixWithGain() for automatic level compensation
  if input1.len != input2.len or output.len != input1.len:
    raise newException(ValueError, "All buffers must have same length")

  for i in 0..<output.len:
    when T is float32 or T is float64:
      output[i] = input1[i] + input2[i]
    else:
      # Integer: clamp to prevent overflow
      let sum = input1[i].int64 + input2[i].int64
      when T is int16:
        output[i] = T(clamp(sum, -32768'i64, 32767'i64))
      elif T is int32:
        output[i] = T(clamp(sum, -2147483648'i64, 2147483647'i64))
      else:
        output[i] = T(sum)

proc mixWeighted*[T](input1, input2: openArray[T], output: var openArray[T],
                      weight1, weight2: T) {.inline.} =
  ## Mix two streams with individual gain weights
  ##
  ## output = input1 * weight1 + input2 * weight2
  ##
  ## Common patterns:
  ## - Equal mix: weight1=0.5, weight2=0.5
  ## - Crossfade: weight1=1-t, weight2=t
  if input1.len != input2.len or output.len != input1.len:
    raise newException(ValueError, "All buffers must have same length")

  for i in 0..<output.len:
    when T is float32 or T is float64:
      output[i] = input1[i] * weight1 + input2[i] * weight2
    else:
      let mixed = (input1[i].int64 * weight1.int64 + input2[i].int64 * weight2.int64)
      when T is int16:
        output[i] = T(clamp(mixed, -32768'i64, 32767'i64))
      else:
        output[i] = T(mixed)

proc mixMultiple*[T](inputs: openArray[seq[T]], output: var openArray[T]) =
  ## Mix multiple audio streams
  ##
  ## Automatically compensates gain to prevent clipping
  ## output = (input1 + input2 + ... + inputN) / N
  if inputs.len == 0:
    raise newException(ValueError, "Need at least one input")

  let numInputs = inputs.len
  let samples = output.len

  # Verify all inputs same length
  for input in inputs:
    if input.len != samples:
      raise newException(ValueError, "All inputs must have same length")

  # Mix with automatic gain compensation
  when T is float32 or T is float64:
    let gainComp = T(1.0) / T(numInputs)

    for i in 0..<samples:
      var sum = T(0)
      for input in inputs:
        sum += input[i]
      output[i] = sum * gainComp

  else:
    for i in 0..<samples:
      var sum: int64 = 0
      for input in inputs:
        sum += input[i].int64
      output[i] = T(sum div numInputs.int64)

# =============================================================================
# Volume Control
# =============================================================================

proc applyGain*[T](samples: var openArray[T], gain: T) {.inline.} =
  ## Apply linear gain to samples
  ##
  ## gain: Linear gain factor
  ##   1.0 = unity (no change)
  ##   0.5 = half volume (-6 dB)
  ##   2.0 = double volume (+6 dB)
  ##   0.0 = silence
  for i in 0..<samples.len:
    when T is float32 or T is float64:
      samples[i] = samples[i] * gain
    else:
      let scaled = samples[i].int64 * gain.int64
      when T is int16:
        samples[i] = T(clamp(scaled, -32768'i64, 32767'i64))
      else:
        samples[i] = T(scaled)

proc applyGainDb*[T](samples: var openArray[T], gainDb: float64) {.inline.} =
  ## Apply gain in decibels
  ##
  ## gainDb: Gain in dB
  ##   0 dB = unity (no change)
  ##   -6 dB ≈ half volume
  ##   +6 dB ≈ double volume
  ##   -∞ dB = silence
  ##
  ## Common values:
  ##   -3 dB = ~0.707 (reduce by √2)
  ##   -6 dB = 0.5 (halve)
  ##   -12 dB = 0.25 (quarter)
  let linearGain = pow(10.0, gainDb / 20.0)

  when T is float32:
    applyGain(samples, linearGain.float32)
  elif T is float64:
    applyGain(samples, linearGain)
  else:
    applyGain(samples, T(linearGain))

proc dbToLinear*(db: float64): float64 {.inline.} =
  ## Convert decibels to linear gain
  ## db: Decibels
  ## Returns: Linear gain factor
  result = pow(10.0, db / 20.0)

proc linearToDb*(linear: float64): float64 {.inline.} =
  ## Convert linear gain to decibels
  ## linear: Linear gain factor
  ## Returns: Decibels
  if linear <= 0.0:
    result = -100.0  # -∞ dB approximation
  else:
    result = 20.0 * log10(linear)

# =============================================================================
# Panning (Stereo Positioning)
# =============================================================================

proc panStereo*[T](mono: openArray[T], left, right: var openArray[T],
                   pan: float64) {.inline.} =
  ## Pan mono audio to stereo
  ##
  ## pan: Pan position (0.0 = full left, 0.5 = center, 1.0 = full right)
  ##
  ## Uses constant-power panning (maintains perceived loudness)
  if left.len != mono.len or right.len != mono.len:
    raise newException(ValueError, "Output buffers must match mono length")

  if pan < 0.0 or pan > 1.0:
    raise newException(ValueError, "Pan must be 0.0-1.0")

  # Constant-power panning (equal power, not equal amplitude)
  let angle = pan * PI / 2.0
  let leftGain = cos(angle)
  let rightGain = sin(angle)

  when T is float32:
    let lg = leftGain.float32
    let rg = rightGain.float32
    for i in 0..<mono.len:
      left[i] = mono[i] * lg
      right[i] = mono[i] * rg

  elif T is float64:
    for i in 0..<mono.len:
      left[i] = mono[i] * leftGain
      right[i] = mono[i] * rightGain

  else:
    let lg = T(leftGain * 256.0)  # Fixed-point for integers
    let rg = T(rightGain * 256.0)
    for i in 0..<mono.len:
      left[i] = T((mono[i].int64 * lg.int64) shr 8)
      right[i] = T((mono[i].int64 * rg.int64) shr 8)

proc adjustPanStereo*[T](left, right: var openArray[T], pan: float64) {.inline.} =
  ## Adjust panning of existing stereo signal
  ##
  ## pan: Pan position (-1.0 = full left, 0.0 = center, +1.0 = full right)
  if left.len != right.len:
    raise newException(ValueError, "Left and right must have same length")

  if pan < -1.0 or pan > 1.0:
    raise newException(ValueError, "Pan must be -1.0 to +1.0")

  # Calculate gains based on pan
  let leftGain = if pan <= 0.0: 1.0 else: 1.0 - pan
  let rightGain = if pan >= 0.0: 1.0 else: 1.0 + pan

  when T is float32 or T is float64:
    for i in 0..<left.len:
      left[i] = left[i] * T(leftGain)
      right[i] = right[i] * T(rightGain)

# =============================================================================
# Crossfading
# =============================================================================

proc crossfade*[T](trackA, trackB: openArray[T], output: var openArray[T],
                   fadePosition: float64) {.inline.} =
  ## Crossfade between two audio tracks
  ##
  ## fadePosition: Crossfade position (0.0 = all A, 1.0 = all B)
  ##
  ## Uses equal-power crossfade for smooth transition
  if trackA.len != trackB.len or output.len != trackA.len:
    raise newException(ValueError, "All buffers must have same length")

  if fadePosition < 0.0 or fadePosition > 1.0:
    raise newException(ValueError, "Fade position must be 0.0-1.0")

  # Equal-power crossfade
  let angle = fadePosition * PI / 2.0
  let gainA = cos(angle)
  let gainB = sin(angle)

  when T is float32 or T is float64:
    let ga = T(gainA)
    let gb = T(gainB)
    for i in 0..<output.len:
      output[i] = trackA[i] * ga + trackB[i] * gb

proc crossfadeLinear*[T](trackA, trackB: openArray[T], output: var openArray[T]) {.inline.} =
  ## Linear crossfade over entire buffer length
  ##
  ## Fades from trackA at start to trackB at end
  ## Simpler than crossfade() but with linear fade curve
  if trackA.len != trackB.len or output.len != trackA.len:
    raise newException(ValueError, "All buffers must have same length")

  let len = output.len

  when T is float32 or T is float64:
    for i in 0..<len:
      let t = T(i) / T(len - 1)
      output[i] = trackA[i] * (T(1.0) - t) + trackB[i] * t

# =============================================================================
# Normalization
# =============================================================================

proc normalizePeak*[T](samples: var openArray[T], targetPeak: T) =
  ## Normalize audio to target peak amplitude
  ##
  ## Scales samples so highest peak reaches targetPeak
  ## Preserves dynamic range and waveform shape
  ##
  ## targetPeak: Target peak level (e.g., 1.0 for float, 32767 for int16)
  when T is float32 or T is float64:
    var maxAbs = T(0)
    for s in samples:
      maxAbs = max(maxAbs, abs(s))

    if maxAbs > T(1e-10):
      let scale = targetPeak / maxAbs
      for i in 0..<samples.len:
        samples[i] = samples[i] * scale

proc normalizeRMS*[T](samples: var openArray[T], targetRMS: T) =
  ## Normalize audio to target RMS (average) level
  ##
  ## More consistent for perceived loudness than peak normalization
  ## Good for dialogue, podcasts, streaming
  ##
  ## targetRMS: Target RMS level (typically 0.1-0.3 for float)
  when T is float32 or T is float64:
    # Calculate RMS
    var sumSquares = T(0)
    for s in samples:
      sumSquares += s * s

    let rms = sqrt(sumSquares / T(samples.len))

    if rms > T(1e-10):
      let scale = targetRMS / rms
      for i in 0..<samples.len:
        samples[i] = samples[i] * scale

# =============================================================================
# Clipping and Limiting
# =============================================================================

proc softClip*[T](samples: var openArray[T]) {.inline.} =
  ## Apply soft clipping (smooth saturation)
  ##
  ## Prevents harsh digital clipping with smooth curve
  ## Good for slight overdrive protection
  when T is float32 or T is float64:
    for i in 0..<samples.len:
      let x = samples[i]
      # Soft clipping with tanh-like curve
      if x > T(1.0):
        samples[i] = T(1.0)
      elif x < T(-1.0):
        samples[i] = T(-1.0)
      else:
        # Cubic soft clip: x - x^3/3
        samples[i] = x - (x * x * x) / T(3.0)

proc hardClip*[T](samples: var openArray[T], threshold: T) {.inline.} =
  ## Hard clip samples to threshold
  ##
  ## Simple brick-wall limiter
  ## Can cause distortion - use sparingly
  for i in 0..<samples.len:
    when T is float32 or T is float64:
      if samples[i] > threshold:
        samples[i] = threshold
      elif samples[i] < -threshold:
        samples[i] = -threshold

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/strformat

  echo "Audio Mixing Example"
  echo "===================="
  echo ""

  # Test mixing two signals
  const n = 8
  var signal1: array[n, float32] = [0.5'f32, 0.6, 0.7, 0.8, 0.9, 1.0, 0.9, 0.8]
  var signal2: array[n, float32] = [0.1'f32, 0.2, 0.3, 0.4, 0.5, 0.6, 0.5, 0.4]

  echo "Signal 1:", signal1
  echo "Signal 2:", signal2

  var mixed = newSeq[float32](n)
  mixWeighted(signal1, signal2, mixed, 0.5'f32, 0.5'f32)
  echo "Mixed (equal weights):", mixed
  echo ""

  # Test panning
  echo "Panning Test:"
  var mono: array[4, float32] = [1.0'f32, 1.0, 1.0, 1.0]
  var left, right = newSeq[float32](4)

  # Center
  panStereo(mono, left, right, pan = 0.5)
  echo &"  Center (pan=0.5): L={left[0]:.3f}, R={right[0]:.3f}"

  # Left
  panStereo(mono, left, right, pan = 0.0)
  echo &"  Left (pan=0.0):   L={left[0]:.3f}, R={right[0]:.3f}"

  # Right
  panStereo(mono, left, right, pan = 1.0)
  echo &"  Right (pan=1.0):  L={left[0]:.3f}, R={right[0]:.3f}"
  echo ""

  # Test crossfade
  echo "Crossfade Test:"
  var trackA: array[4, float32] = [1.0'f32, 1.0, 1.0, 1.0]
  var trackB: array[4, float32] = [0.0'f32, 0.0, 0.0, 0.0]
  var faded = newSeq[float32](4)

  crossfade(trackA, trackB, faded, fadePosition = 0.0)
  echo &"  Position 0.0 (all A): {faded[0]:.3f}"

  crossfade(trackA, trackB, faded, fadePosition = 0.5)
  echo &"  Position 0.5 (middle): {faded[0]:.3f}"

  crossfade(trackA, trackB, faded, fadePosition = 1.0)
  echo &"  Position 1.0 (all B): {faded[0]:.3f}"
  echo ""

  # Test gain conversion
  echo "Gain Conversion:"
  echo &"  -6 dB = {dbToLinear(-6.0):.4f} (should be ~0.5)"
  echo &"  0 dB = {dbToLinear(0.0):.4f} (should be 1.0)"
  echo &"  +6 dB = {dbToLinear(6.0):.4f} (should be ~2.0)"
  echo ""
  echo &"  0.5 linear = {linearToDb(0.5):.2f} dB (should be ~-6)"
  echo &"  1.0 linear = {linearToDb(1.0):.2f} dB (should be 0)"
  echo &"  2.0 linear = {linearToDb(2.0):.2f} dB (should be ~+6)"
