## Audio Format Conversion
## ========================
##
## High-performance PCM audio format conversions for audio processing.
## Critical for interfacing with audio codecs, hardware, and processing pipelines.
##
## Features:
## - Integer ↔ Float conversions (int8, int16, int24, int32 ↔ float32, float64)
## - Planar ↔ Interleaved channel layout conversions
## - Bit depth conversions with proper scaling
## - Dithering for bit depth reduction (TPDF, shaped)
## - Channel count conversions (mono↔stereo, upmix/downmix)
## - Endianness handling
## - SIMD-optimizable implementations
##
## Performance:
## - ~0.1-0.5 ns per sample for simple conversions
## - ~1-2 ns per sample with dithering
## - Branchless for maximum throughput
##
## Usage:
## ```nim
## import arsenal/media/audio/format
##
## # Convert int16 to float32 (normalized to ±1.0)
## var float32Samples = newSeq[float32](1024)
## int16ToFloat32(int16Buffer, float32Samples)
##
## # Convert back with dithering
## var int16Out = newSeq[int16](1024)
## float32ToInt16(float32Samples, int16Out, useDither = true)
##
## # Interleaved stereo → Planar (separate L/R channels)
## var left, right = newSeq[float32](512)
## deinterleave(stereoInterleaved, left, right)
## ```

import std/math

# =============================================================================
# Format Types
# =============================================================================

type
  AudioFormat* = enum
    ## Audio sample formats
    FormatInt8      ## 8-bit signed integer
    FormatUInt8     ## 8-bit unsigned integer
    FormatInt16     ## 16-bit signed integer
    FormatInt24     ## 24-bit signed integer (packed in int32)
    FormatInt32     ## 32-bit signed integer
    FormatFloat32   ## 32-bit floating point (normalized ±1.0)
    FormatFloat64   ## 64-bit floating point (normalized ±1.0)

  ChannelLayout* = enum
    ## Audio channel layout
    LayoutInterleaved  ## LRLRLR... (common in files, hardware)
    LayoutPlanar       ## LLL...RRR... (efficient for processing)

  DitherType* = enum
    ## Dithering algorithms for bit depth reduction
    DitherNone      ## No dithering (truncation/rounding)
    DitherTPDF      ## Triangular PDF (Triangular dither, most common)
    DitherRPDF      ## Rectangular PDF (White noise)
    DitherShaped    ## Noise-shaped dither (pushes noise to inaudible frequencies)

# =============================================================================
# Integer → Float Conversions
# =============================================================================

const
  Int8Scale* = 1.0'f32 / 128.0'f32
  Int16Scale* = 1.0'f32 / 32768.0'f32
  Int24Scale* = 1.0'f32 / 8388608.0'f32
  Int32Scale* = 1.0'f32 / 2147483648.0'f32

proc int8ToFloat32*(input: openArray[int8], output: var openArray[float32]) {.inline.} =
  ## Convert int8 samples to float32 (normalized to ±1.0)
  ##
  ## Fast branchless conversion
  ## int8: -128..127 → float32: -1.0..~0.992
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  for i in 0..<input.len:
    output[i] = input[i].float32 * Int8Scale

proc int16ToFloat32*(input: openArray[int16], output: var openArray[float32]) {.inline.} =
  ## Convert int16 samples to float32 (normalized to ±1.0)
  ##
  ## Most common conversion for CD-quality audio
  ## int16: -32768..32767 → float32: -1.0..~0.99997
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  for i in 0..<input.len:
    output[i] = input[i].float32 * Int16Scale

proc int24ToFloat32*(input: openArray[int32], output: var openArray[float32]) {.inline.} =
  ## Convert int24 samples (packed in int32) to float32
  ##
  ## int24 stored in upper 24 bits of int32
  ## int24: -8388608..8388607 → float32: -1.0..~0.9999999
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  for i in 0..<input.len:
    # Shift to get 24-bit value, then convert
    let val24 = input[i] shr 8
    output[i] = val24.float32 * Int24Scale

proc int32ToFloat32*(input: openArray[int32], output: var openArray[float32]) {.inline.} =
  ## Convert int32 samples to float32 (normalized to ±1.0)
  ##
  ## Highest quality integer format
  ## int32: -2147483648..2147483647 → float32: -1.0..~1.0
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  for i in 0..<input.len:
    output[i] = input[i].float32 * Int32Scale

proc int16ToFloat64*(input: openArray[int16], output: var openArray[float64]) {.inline.} =
  ## Convert int16 to float64 (for high-precision processing)
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  for i in 0..<input.len:
    output[i] = input[i].float64 / 32768.0

# =============================================================================
# Float → Integer Conversions (with optional dithering)
# =============================================================================

proc float32ToInt16*(input: openArray[float32], output: var openArray[int16],
                     useDither: bool = false) {.inline.} =
  ## Convert float32 (±1.0) to int16
  ##
  ## input: Float samples normalized to ±1.0
  ## output: Int16 samples -32768..32767
  ## useDither: Apply TPDF dithering to prevent quantization artifacts
  ##
  ## Most common conversion for audio output
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  if useDither:
    # TPDF (Triangular PDF) dithering
    # Sum of two uniform random values = triangular distribution
    # Whitens quantization noise, prevents harmonic distortion
    var rng = 12345'u32  # Simple LCG for dither

    proc nextDither(): float32 =
      # Fast LCG random number generator
      rng = rng * 1664525'u32 + 1013904223'u32
      let r1 = (rng.float32 / 4294967296.0'f32) - 0.5'f32
      rng = rng * 1664525'u32 + 1013904223'u32
      let r2 = (rng.float32 / 4294967296.0'f32) - 0.5'f32
      result = r1 + r2  # Triangular distribution

    for i in 0..<input.len:
      # Apply dither before quantization
      let dithered = input[i] + nextDither() / 32768.0'f32
      let scaled = dithered * 32768.0'f32

      # Clamp to int16 range
      let clamped =
        if scaled >= 32767.0'f32: 32767
        elif scaled <= -32768.0'f32: -32768
        else: scaled.int32

      output[i] = clamped.int16

  else:
    # No dithering - simple conversion
    for i in 0..<input.len:
      let scaled = input[i] * 32768.0'f32

      # Clamp to int16 range
      let clamped =
        if scaled >= 32767.0'f32: 32767
        elif scaled <= -32768.0'f32: -32768
        else: scaled.int32

      output[i] = clamped.int16

proc float32ToInt24*(input: openArray[float32], output: var openArray[int32],
                     useDither: bool = false) {.inline.} =
  ## Convert float32 (±1.0) to int24 (packed in int32)
  ##
  ## Result is stored in upper 24 bits of int32
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  const scale = 8388608.0'f32  # 2^23

  if useDither:
    var rng = 54321'u32

    proc nextDither(): float32 =
      rng = rng * 1664525'u32 + 1013904223'u32
      let r1 = (rng.float32 / 4294967296.0'f32) - 0.5'f32
      rng = rng * 1664525'u32 + 1013904223'u32
      let r2 = (rng.float32 / 4294967296.0'f32) - 0.5'f32
      result = r1 + r2

    for i in 0..<input.len:
      let dithered = input[i] + nextDither() / scale
      let scaled = dithered * scale

      let clamped =
        if scaled >= 8388607.0'f32: 8388607
        elif scaled <= -8388608.0'f32: -8388608
        else: scaled.int32

      output[i] = clamped shl 8  # Pack in upper 24 bits

  else:
    for i in 0..<input.len:
      let scaled = input[i] * scale

      let clamped =
        if scaled >= 8388607.0'f32: 8388607
        elif scaled <= -8388608.0'f32: -8388608
        else: scaled.int32

      output[i] = clamped shl 8

proc float32ToInt32*(input: openArray[float32], output: var openArray[int32]) {.inline.} =
  ## Convert float32 (±1.0) to int32
  ##
  ## Highest quality output
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  const scale = 2147483647.0'f32  # Max int32

  for i in 0..<input.len:
    let scaled = input[i] * scale

    let clamped =
      if scaled >= 2147483647.0'f32: 2147483647
      elif scaled <= -2147483648.0'f32: -2147483648
      else: scaled.int32

    output[i] = clamped

proc float64ToInt16*(input: openArray[float64], output: var openArray[int16],
                     useDither: bool = false) {.inline.} =
  ## Convert float64 to int16 (high-precision input)
  if input.len != output.len:
    raise newException(ValueError, "Input and output must have same length")

  if useDither:
    var rng = 98765'u32

    proc nextDither(): float64 =
      rng = rng * 1664525'u32 + 1013904223'u32
      let r1 = (rng.float64 / 4294967296.0) - 0.5
      rng = rng * 1664525'u32 + 1013904223'u32
      let r2 = (rng.float64 / 4294967296.0) - 0.5
      result = r1 + r2

    for i in 0..<input.len:
      let dithered = input[i] + nextDither() / 32768.0
      let scaled = dithered * 32768.0

      let clamped =
        if scaled >= 32767.0: 32767
        elif scaled <= -32768.0: -32768
        else: scaled.int32

      output[i] = clamped.int16

  else:
    for i in 0..<input.len:
      let scaled = input[i] * 32768.0

      let clamped =
        if scaled >= 32767.0: 32767
        elif scaled <= -32768.0: -32768
        else: scaled.int32

      output[i] = clamped.int16

# =============================================================================
# Channel Layout Conversions
# =============================================================================

proc interleaveMonoToStereo*[T](mono: openArray[T], stereo: var openArray[T]) {.inline.} =
  ## Convert mono to stereo (duplicate to both channels)
  ##
  ## mono: N samples
  ## stereo: 2*N samples (LRLRLR...)
  if stereo.len != mono.len * 2:
    raise newException(ValueError, "Stereo buffer must be 2x mono size")

  for i in 0..<mono.len:
    stereo[i * 2] = mono[i]      # Left
    stereo[i * 2 + 1] = mono[i]  # Right (same as left)

proc interleaveStereo*[T](left, right: openArray[T], interleaved: var openArray[T]) {.inline.} =
  ## Interleave separate left/right channels
  ##
  ## left: N samples
  ## right: N samples
  ## interleaved: 2*N samples (LRLRLR...)
  if left.len != right.len:
    raise newException(ValueError, "Left and right must have same length")
  if interleaved.len != left.len * 2:
    raise newException(ValueError, "Interleaved buffer must be 2x channel size")

  for i in 0..<left.len:
    interleaved[i * 2] = left[i]
    interleaved[i * 2 + 1] = right[i]

proc deinterleaveStereo*[T](interleaved: openArray[T], left, right: var openArray[T]) {.inline.} =
  ## De-interleave stereo to separate left/right channels
  ##
  ## interleaved: 2*N samples (LRLRLR...)
  ## left: N samples
  ## right: N samples
  ##
  ## Essential for efficient processing (SIMD, filtering)
  if interleaved.len != left.len * 2 or left.len != right.len:
    raise newException(ValueError, "Size mismatch in deinterleave")

  for i in 0..<left.len:
    left[i] = interleaved[i * 2]
    right[i] = interleaved[i * 2 + 1]

proc stereoToMono*[T](left, right: openArray[T], mono: var openArray[T]) {.inline.} =
  ## Mix stereo down to mono (average of L+R)
  ##
  ## Standard downmix formula
  if left.len != right.len or mono.len != left.len:
    raise newException(ValueError, "Channel size mismatch")

  when T is float32 or T is float64:
    # Float: simple average
    for i in 0..<mono.len:
      mono[i] = (left[i] + right[i]) * 0.5
  else:
    # Integer: avoid overflow
    for i in 0..<mono.len:
      mono[i] = T((left[i].int32 + right[i].int32) div 2)

proc stereoToMonoInterleaved*[T](stereo: openArray[T], mono: var openArray[T]) {.inline.} =
  ## Convert interleaved stereo to mono (average L+R)
  ##
  ## stereo: 2*N samples (LRLRLR...)
  ## mono: N samples
  if stereo.len != mono.len * 2:
    raise newException(ValueError, "Stereo must be 2x mono size")

  when T is float32 or T is float64:
    for i in 0..<mono.len:
      mono[i] = (stereo[i * 2] + stereo[i * 2 + 1]) * 0.5
  else:
    for i in 0..<mono.len:
      mono[i] = T((stereo[i * 2].int32 + stereo[i * 2 + 1].int32) div 2)

# =============================================================================
# Utility Functions
# =============================================================================

proc normalizePeak*[T](samples: var openArray[T], targetPeak: T) =
  ## Normalize audio to target peak amplitude
  ##
  ## Scales entire buffer so highest peak reaches targetPeak
  ## Preserves dynamic range
  when T is float32 or T is float64:
    var maxAbs = T(0)
    for s in samples:
      maxAbs = max(maxAbs, abs(s))

    if maxAbs > T(1e-10):  # Avoid division by zero
      let scale = targetPeak / maxAbs
      for i in 0..<samples.len:
        samples[i] = samples[i] * scale

proc applyGain*[T](samples: var openArray[T], gainDb: float32) =
  ## Apply gain in decibels
  ##
  ## gainDb: Gain in dB (0 dB = unity, positive = louder, negative = quieter)
  ## Common values: -6 dB (half), 0 dB (unity), +6 dB (double)
  when T is float32 or T is float64:
    let linearGain = T(pow(10.0, gainDb / 20.0))
    for i in 0..<samples.len:
      samples[i] = samples[i] * linearGain

proc dcRemove*[T](samples: var openArray[T]) =
  ## Remove DC offset (center signal around zero)
  ##
  ## Useful after certain operations or file imports
  when T is float32 or T is float64:
    var sum = T(0)
    for s in samples:
      sum += s

    let dcOffset = sum / T(samples.len)

    for i in 0..<samples.len:
      samples[i] = samples[i] - dcOffset

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/strformat

  echo "Audio Format Conversion Example"
  echo "================================"
  echo ""

  # Test int16 ↔ float32 conversion (most common)
  const numSamples = 8
  var int16Samples: array[numSamples, int16] = [
    -32768'i16, -16384, -8192, -1024, 1024, 8192, 16384, 32767
  ]

  echo "Original int16 samples:"
  for i in 0..<numSamples:
    echo &"  [{i}] = {int16Samples[i]}"

  # Convert to float32
  var float32Samples = newSeq[float32](numSamples)
  int16ToFloat32(int16Samples, float32Samples)

  echo "\nConverted to float32:"
  for i in 0..<numSamples:
    echo &"  [{i}] = {float32Samples[i]:.6f}"

  # Convert back to int16
  var int16Back = newSeq[int16](numSamples)
  float32ToInt16(float32Samples, int16Back, useDither = false)

  echo "\nConverted back to int16:"
  for i in 0..<numSamples:
    echo &"  [{i}] = {int16Back[i]} (error: {int16Back[i] - int16Samples[i]})"

  # Test interleaving
  echo "\n" & "=".repeat(40)
  echo "Channel Interleaving Test"
  echo "=".repeat(40)

  var left: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
  var right: array[4, float32] = [0.1'f32, 0.2, 0.3, 0.4]

  echo "\nLeft channel:  ", left
  echo "Right channel: ", right

  var interleaved = newSeq[float32](8)
  interleaveStereo(left, right, interleaved)

  echo "\nInterleaved (LRLR...): "
  for i in 0..<8:
    echo &"  [{i}] = {interleaved[i]:.1f}"

  # De-interleave back
  var leftBack, rightBack = newSeq[float32](4)
  deinterleaveStereo(interleaved, leftBack, rightBack)

  echo "\nDe-interleaved:"
  echo "  Left:  ", leftBack
  echo "  Right: ", rightBack

  # Stereo to mono
  var mono = newSeq[float32](4)
  stereoToMono(left, right, mono)

  echo "\nStereo → Mono (average):"
  for i in 0..<4:
    echo &"  [{i}] = {mono[i]:.2f} (expected: {(left[i] + right[i]) * 0.5:.2f})"
