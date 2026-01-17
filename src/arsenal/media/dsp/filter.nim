## Digital Filters
## ================
##
## Digital filter implementations for audio and signal processing.
## Focuses on biquad filters (second-order IIR) which are fundamental
## building blocks for audio EQ, effects, and analysis.
##
## Features:
## - Biquad filter (2nd-order IIR)
## - Standard filter types: lowpass, highpass, bandpass, notch, peaking, shelving
## - Direct Form I and Direct Form II implementations
## - Cascaded biquad sections for higher-order filters
## - FIR filter support
##
## Usage:
## ```nim
## import arsenal/media/dsp/filter
##
## # Create lowpass filter at 1000 Hz
## var lpf = initLowpass(sampleRate = 44100.0, cutoff = 1000.0, q = 0.707)
##
## # Process audio samples
## for i in 0..<samples.len:
##   samples[i] = lpf.process(samples[i])
## ```

import std/math

# =============================================================================
# Biquad Filter Structure
# =============================================================================

type
  BiquadCoeffs* = object
    ## Biquad filter coefficients
    ## Transfer function: H(z) = (b0 + b1*z^-1 + b2*z^-2) / (a0 + a1*z^-1 + a2*z^-2)
    b0*, b1*, b2*: float64  # Numerator coefficients (feedforward)
    a0*, a1*, a2*: float64  # Denominator coefficients (feedback)

  BiquadState* = object
    ## Biquad filter state (Direct Form I)
    ## Stores previous inputs and outputs
    x1*, x2*: float64  # Previous inputs  (x[n-1], x[n-2])
    y1*, y2*: float64  # Previous outputs (y[n-1], y[n-2])

  Biquad* = object
    ## Complete biquad filter
    coeffs*: BiquadCoeffs
    state*: BiquadState

  FilterType* = enum
    ## Standard filter types
    Lowpass
    Highpass
    Bandpass
    Notch
    Peaking
    LowShelf
    HighShelf
    AllPass

# =============================================================================
# Biquad Coefficient Calculation
# =============================================================================

proc initLowpass*(sampleRate, cutoff, q: float64): Biquad =
  ## Create lowpass biquad filter
  ##
  ## sampleRate: Sample rate in Hz
  ## cutoff: Cutoff frequency in Hz
  ## q: Q factor (resonance), typical value: 0.707 (Butterworth)
  let omega = 2.0 * PI * cutoff / sampleRate
  let sinOmega = sin(omega)
  let cosOmega = cos(omega)
  let alpha = sinOmega / (2.0 * q)

  result.coeffs.b0 = (1.0 - cosOmega) / 2.0
  result.coeffs.b1 = 1.0 - cosOmega
  result.coeffs.b2 = (1.0 - cosOmega) / 2.0
  result.coeffs.a0 = 1.0 + alpha
  result.coeffs.a1 = -2.0 * cosOmega
  result.coeffs.a2 = 1.0 - alpha

  # Normalize by a0
  result.coeffs.b0 = result.coeffs.b0 / result.coeffs.a0
  result.coeffs.b1 = result.coeffs.b1 / result.coeffs.a0
  result.coeffs.b2 = result.coeffs.b2 / result.coeffs.a0
  result.coeffs.a1 = result.coeffs.a1 / result.coeffs.a0
  result.coeffs.a2 = result.coeffs.a2 / result.coeffs.a0
  result.coeffs.a0 = 1.0

proc initHighpass*(sampleRate, cutoff, q: float64): Biquad =
  ## Create highpass biquad filter
  ##
  ## sampleRate: Sample rate in Hz
  ## cutoff: Cutoff frequency in Hz
  ## q: Q factor, typical value: 0.707
  let omega = 2.0 * PI * cutoff / sampleRate
  let sinOmega = sin(omega)
  let cosOmega = cos(omega)
  let alpha = sinOmega / (2.0 * q)

  result.coeffs.b0 = (1.0 + cosOmega) / 2.0
  result.coeffs.b1 = -(1.0 + cosOmega)
  result.coeffs.b2 = (1.0 + cosOmega) / 2.0
  result.coeffs.a0 = 1.0 + alpha
  result.coeffs.a1 = -2.0 * cosOmega
  result.coeffs.a2 = 1.0 - alpha

  # Normalize
  result.coeffs.b0 = result.coeffs.b0 / result.coeffs.a0
  result.coeffs.b1 = result.coeffs.b1 / result.coeffs.a0
  result.coeffs.b2 = result.coeffs.b2 / result.coeffs.a0
  result.coeffs.a1 = result.coeffs.a1 / result.coeffs.a0
  result.coeffs.a2 = result.coeffs.a2 / result.coeffs.a0
  result.coeffs.a0 = 1.0

proc initBandpass*(sampleRate, center, bandwidth: float64): Biquad =
  ## Create bandpass biquad filter
  ##
  ## sampleRate: Sample rate in Hz
  ## center: Center frequency in Hz
  ## bandwidth: Bandwidth in Hz
  let omega = 2.0 * PI * center / sampleRate
  let sinOmega = sin(omega)
  let cosOmega = cos(omega)
  let q = center / bandwidth
  let alpha = sinOmega / (2.0 * q)

  result.coeffs.b0 = alpha
  result.coeffs.b1 = 0.0
  result.coeffs.b2 = -alpha
  result.coeffs.a0 = 1.0 + alpha
  result.coeffs.a1 = -2.0 * cosOmega
  result.coeffs.a2 = 1.0 - alpha

  # Normalize
  result.coeffs.b0 = result.coeffs.b0 / result.coeffs.a0
  result.coeffs.b1 = result.coeffs.b1 / result.coeffs.a0
  result.coeffs.b2 = result.coeffs.b2 / result.coeffs.a0
  result.coeffs.a1 = result.coeffs.a1 / result.coeffs.a0
  result.coeffs.a2 = result.coeffs.a2 / result.coeffs.a0
  result.coeffs.a0 = 1.0

proc initNotch*(sampleRate, center, q: float64): Biquad =
  ## Create notch (band-stop) biquad filter
  ##
  ## Useful for removing specific frequencies (e.g., 60 Hz hum)
  ##
  ## sampleRate: Sample rate in Hz
  ## center: Notch center frequency in Hz
  ## q: Q factor (narrowness of notch)
  let omega = 2.0 * PI * center / sampleRate
  let sinOmega = sin(omega)
  let cosOmega = cos(omega)
  let alpha = sinOmega / (2.0 * q)

  result.coeffs.b0 = 1.0
  result.coeffs.b1 = -2.0 * cosOmega
  result.coeffs.b2 = 1.0
  result.coeffs.a0 = 1.0 + alpha
  result.coeffs.a1 = -2.0 * cosOmega
  result.coeffs.a2 = 1.0 - alpha

  # Normalize
  result.coeffs.b0 = result.coeffs.b0 / result.coeffs.a0
  result.coeffs.b1 = result.coeffs.b1 / result.coeffs.a0
  result.coeffs.b2 = result.coeffs.b2 / result.coeffs.a0
  result.coeffs.a1 = result.coeffs.a1 / result.coeffs.a0
  result.coeffs.a2 = result.coeffs.a2 / result.coeffs.a0
  result.coeffs.a0 = 1.0

proc initPeaking*(sampleRate, center, q, gainDb: float64): Biquad =
  ## Create peaking EQ biquad filter
  ##
  ## Boosts or cuts frequencies around center frequency
  ## Used in parametric EQ
  ##
  ## sampleRate: Sample rate in Hz
  ## center: Center frequency in Hz
  ## q: Q factor (bandwidth)
  ## gainDb: Gain in dB (positive = boost, negative = cut)
  let omega = 2.0 * PI * center / sampleRate
  let sinOmega = sin(omega)
  let cosOmega = cos(omega)
  let alpha = sinOmega / (2.0 * q)
  let a = pow(10.0, gainDb / 40.0)  # Amplitude = 10^(dB/20), squared for power

  result.coeffs.b0 = 1.0 + alpha * a
  result.coeffs.b1 = -2.0 * cosOmega
  result.coeffs.b2 = 1.0 - alpha * a
  result.coeffs.a0 = 1.0 + alpha / a
  result.coeffs.a1 = -2.0 * cosOmega
  result.coeffs.a2 = 1.0 - alpha / a

  # Normalize
  result.coeffs.b0 = result.coeffs.b0 / result.coeffs.a0
  result.coeffs.b1 = result.coeffs.b1 / result.coeffs.a0
  result.coeffs.b2 = result.coeffs.b2 / result.coeffs.a0
  result.coeffs.a1 = result.coeffs.a1 / result.coeffs.a0
  result.coeffs.a2 = result.coeffs.a2 / result.coeffs.a0
  result.coeffs.a0 = 1.0

proc initLowShelf*(sampleRate, cutoff, q, gainDb: float64): Biquad =
  ## Create low shelf biquad filter
  ##
  ## Boosts or cuts low frequencies
  ## Used in tone controls
  ##
  ## sampleRate: Sample rate in Hz
  ## cutoff: Shelf frequency in Hz
  ## q: Shelf slope
  ## gainDb: Gain in dB
  let omega = 2.0 * PI * cutoff / sampleRate
  let sinOmega = sin(omega)
  let cosOmega = cos(omega)
  let a = pow(10.0, gainDb / 40.0)
  let beta = sqrt((a * a + 1.0) / q - (a - 1.0) * (a - 1.0))

  result.coeffs.b0 = a * ((a + 1.0) - (a - 1.0) * cosOmega + beta * sinOmega)
  result.coeffs.b1 = 2.0 * a * ((a - 1.0) - (a + 1.0) * cosOmega)
  result.coeffs.b2 = a * ((a + 1.0) - (a - 1.0) * cosOmega - beta * sinOmega)
  result.coeffs.a0 = (a + 1.0) + (a - 1.0) * cosOmega + beta * sinOmega
  result.coeffs.a1 = -2.0 * ((a - 1.0) + (a + 1.0) * cosOmega)
  result.coeffs.a2 = (a + 1.0) + (a - 1.0) * cosOmega - beta * sinOmega

  # Normalize
  result.coeffs.b0 = result.coeffs.b0 / result.coeffs.a0
  result.coeffs.b1 = result.coeffs.b1 / result.coeffs.a0
  result.coeffs.b2 = result.coeffs.b2 / result.coeffs.a0
  result.coeffs.a1 = result.coeffs.a1 / result.coeffs.a0
  result.coeffs.a2 = result.coeffs.a2 / result.coeffs.a0
  result.coeffs.a0 = 1.0

proc initHighShelf*(sampleRate, cutoff, q, gainDb: float64): Biquad =
  ## Create high shelf biquad filter
  ##
  ## Boosts or cuts high frequencies
  ## Used in tone controls
  ##
  ## sampleRate: Sample rate in Hz
  ## cutoff: Shelf frequency in Hz
  ## q: Shelf slope
  ## gainDb: Gain in dB
  let omega = 2.0 * PI * cutoff / sampleRate
  let sinOmega = sin(omega)
  let cosOmega = cos(omega)
  let a = pow(10.0, gainDb / 40.0)
  let beta = sqrt((a * a + 1.0) / q - (a - 1.0) * (a - 1.0))

  result.coeffs.b0 = a * ((a + 1.0) + (a - 1.0) * cosOmega + beta * sinOmega)
  result.coeffs.b1 = -2.0 * a * ((a - 1.0) + (a + 1.0) * cosOmega)
  result.coeffs.b2 = a * ((a + 1.0) + (a - 1.0) * cosOmega - beta * sinOmega)
  result.coeffs.a0 = (a + 1.0) - (a - 1.0) * cosOmega + beta * sinOmega
  result.coeffs.a1 = 2.0 * ((a - 1.0) - (a + 1.0) * cosOmega)
  result.coeffs.a2 = (a + 1.0) - (a - 1.0) * cosOmega - beta * sinOmega

  # Normalize
  result.coeffs.b0 = result.coeffs.b0 / result.coeffs.a0
  result.coeffs.b1 = result.coeffs.b1 / result.coeffs.a0
  result.coeffs.b2 = result.coeffs.b2 / result.coeffs.a0
  result.coeffs.a1 = result.coeffs.a1 / result.coeffs.a0
  result.coeffs.a2 = result.coeffs.a2 / result.coeffs.a0
  result.coeffs.a0 = 1.0

# =============================================================================
# Filter Processing (Direct Form I)
# =============================================================================

proc process*(filter: var Biquad, input: float64): float64 {.inline.} =
  ## Process single sample through biquad filter (Direct Form I)
  ##
  ## This is the standard difference equation:
  ## y[n] = b0*x[n] + b1*x[n-1] + b2*x[n-2] - a1*y[n-1] - a2*y[n-2]
  let output = filter.coeffs.b0 * input +
               filter.coeffs.b1 * filter.state.x1 +
               filter.coeffs.b2 * filter.state.x2 -
               filter.coeffs.a1 * filter.state.y1 -
               filter.coeffs.a2 * filter.state.y2

  # Update state
  filter.state.x2 = filter.state.x1
  filter.state.x1 = input
  filter.state.y2 = filter.state.y1
  filter.state.y1 = output

  result = output

proc processBlock*(filter: var Biquad, data: var openArray[float64]) =
  ## Process block of samples through biquad filter (in-place)
  for i in 0..<data.len:
    data[i] = filter.process(data[i])

proc reset*(filter: var Biquad) =
  ## Reset filter state (clear history)
  filter.state.x1 = 0.0
  filter.state.x2 = 0.0
  filter.state.y1 = 0.0
  filter.state.y2 = 0.0

# =============================================================================
# Cascaded Biquads (Higher-Order Filters)
# =============================================================================

type
  BiquadCascade* = object
    ## Cascade of biquad sections
    ## Used for higher-order filters (4th, 6th, 8th order, etc.)
    sections*: seq[Biquad]

proc initCascade*(filters: varargs[Biquad]): BiquadCascade =
  ## Create cascade of biquad filters
  result.sections = @filters

proc process*(cascade: var BiquadCascade, input: float64): float64 =
  ## Process sample through cascaded biquads
  result = input
  for i in 0..<cascade.sections.len:
    result = cascade.sections[i].process(result)

proc processBlock*(cascade: var BiquadCascade, data: var openArray[float64]) =
  ## Process block through cascaded biquads (in-place)
  for section in cascade.sections.mitems:
    section.processBlock(data)

proc reset*(cascade: var BiquadCascade) =
  ## Reset all sections in cascade
  for section in cascade.sections.mitems:
    section.reset()

# =============================================================================
# FIR Filter
# =============================================================================

type
  FirFilter* = object
    ## Finite Impulse Response filter
    ## No feedback, always stable
    coeffs*: seq[float64]      # Filter coefficients (taps)
    buffer*: seq[float64]      # Circular buffer for history
    writePos*: int             # Write position in buffer

proc initFir*(coeffs: openArray[float64]): FirFilter =
  ## Create FIR filter from coefficients
  result.coeffs = @coeffs
  result.buffer = newSeq[float64](coeffs.len)
  result.writePos = 0

proc process*(filter: var FirFilter, input: float64): float64 =
  ## Process single sample through FIR filter
  # Write input to circular buffer
  filter.buffer[filter.writePos] = input

  # Convolution with coefficients
  result = 0.0
  var bufPos = filter.writePos
  for i in 0..<filter.coeffs.len:
    result += filter.coeffs[i] * filter.buffer[bufPos]
    bufPos = if bufPos == 0: filter.buffer.len - 1 else: bufPos - 1

  # Advance write position
  filter.writePos = (filter.writePos + 1) mod filter.buffer.len

proc reset*(filter: var FirFilter) =
  ## Reset FIR filter state
  for i in 0..<filter.buffer.len:
    filter.buffer[i] = 0.0
  filter.writePos = 0

# =============================================================================
# Filter Design Helpers
# =============================================================================

proc butterworthLowpass*(order: int, sampleRate, cutoff: float64): BiquadCascade =
  ## Design Butterworth lowpass filter
  ##
  ## Butterworth filters have maximally flat passband
  ## order: Filter order (must be even for cascade of biquads)
  ## sampleRate: Sample rate in Hz
  ## cutoff: Cutoff frequency in Hz
  ##
  ## Returns cascade of second-order sections
  if order mod 2 != 0:
    raise newException(ValueError, "Order must be even")

  let numSections = order div 2
  result.sections = newSeq[Biquad](numSections)

  for k in 0..<numSections:
    # Butterworth pole locations
    let theta = PI * (2.0 * k.float64 + 1.0) / (2.0 * order.float64)
    let q = 1.0 / (2.0 * cos(theta))

    result.sections[k] = initLowpass(sampleRate, cutoff, q)

# =============================================================================
# Frequency Response
# =============================================================================

proc frequencyResponse*(filter: Biquad, freq, sampleRate: float64): tuple[magnitude, phase: float64] =
  ## Compute frequency response at specific frequency
  ##
  ## Returns magnitude and phase at given frequency
  ## freq: Frequency in Hz
  ## sampleRate: Sample rate in Hz
  let omega = 2.0 * PI * freq / sampleRate

  # Evaluate transfer function H(e^jω)
  let cosOmega = cos(omega)
  let sinOmega = sin(omega)

  # Numerator: b0 + b1*e^(-jω) + b2*e^(-2jω)
  let numRe = filter.coeffs.b0 + filter.coeffs.b1 * cosOmega + filter.coeffs.b2 * cos(2.0 * omega)
  let numIm = -filter.coeffs.b1 * sinOmega - filter.coeffs.b2 * sin(2.0 * omega)

  # Denominator: a0 + a1*e^(-jω) + a2*e^(-2jω)
  let denRe = filter.coeffs.a0 + filter.coeffs.a1 * cosOmega + filter.coeffs.a2 * cos(2.0 * omega)
  let denIm = -filter.coeffs.a1 * sinOmega - filter.coeffs.a2 * sin(2.0 * omega)

  # H = Num / Den (complex division)
  let denMagSq = denRe * denRe + denIm * denIm
  let hRe = (numRe * denRe + numIm * denIm) / denMagSq
  let hIm = (numIm * denRe - numRe * denIm) / denMagSq

  result.magnitude = sqrt(hRe * hRe + hIm * hIm)
  result.phase = arctan2(hIm, hRe)

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  echo "Biquad Filter Example"
  echo "====================="

  # Create lowpass filter at 1kHz
  var lpf = initLowpass(sampleRate = 44100.0, cutoff = 1000.0, q = 0.707)

  # Test with impulse
  echo "\nImpulse response (first 10 samples):"
  lpf.reset()
  for i in 0..<10:
    let input = if i == 0: 1.0 else: 0.0
    let output = lpf.process(input)
    echo "  ", i, ": ", output.formatFloat(ffDecimal, 6)

  # Frequency response
  echo "\nFrequency response:"
  lpf.reset()
  let testFreqs = [100.0, 500.0, 1000.0, 2000.0, 5000.0, 10000.0]
  for freq in testFreqs:
    let (mag, phase) = lpf.frequencyResponse(freq, 44100.0)
    let magDb = 20.0 * log10(mag)
    echo "  ", freq.formatFloat(ffDecimal, 0), " Hz: ",
         magDb.formatFloat(ffDecimal, 2), " dB"
