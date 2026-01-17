## Window Functions for FFT
## =========================
##
## Window functions reduce spectral leakage in FFT analysis.
## Essential for accurate frequency analysis of non-periodic signals.
##
## Features:
## - Common window types: Hann, Hamming, Blackman, Bartlett, etc.
## - Windowing utilities
## - Window normalization
## - Overlap-add processing support
##
## Usage:
## ```nim
## import arsenal/media/dsp/window
##
## # Create Hann window
## let window = hann(1024)
##
## # Apply to signal
## applyWindow(signal, window)
## ```

import std/math

# =============================================================================
# Window Types
# =============================================================================

type
  WindowType* = enum
    ## Standard window function types
    Rectangular  ## No windowing (all ones)
    Hann         ## Hann (raised cosine)
    Hamming      ## Hamming (optimized cosine)
    Blackman     ## Blackman (better sidelobe suppression)
    BlackmanHarris  ## Blackman-Harris (4-term)
    Bartlett     ## Bartlett (triangular)
    Welch        ## Welch (parabolic)
    Kaiser       ## Kaiser (parametric)
    FlatTop      ## Flat top (amplitude accuracy)

# =============================================================================
# Window Generation
# =============================================================================

proc rectangular*(n: int): seq[float64] =
  ## Rectangular window (no windowing)
  ## All samples = 1.0
  ## Narrowest main lobe, worst side lobes
  result = newSeq[float64](n)
  for i in 0..<n:
    result[i] = 1.0

proc hann*(n: int): seq[float64] =
  ## Hann window (raised cosine)
  ##
  ## Most common window for FFT analysis
  ## Good balance between main lobe width and side lobe suppression
  ##
  ## w[n] = 0.5 * (1 - cos(2π*n/(N-1)))
  result = newSeq[float64](n)
  for i in 0..<n:
    result[i] = 0.5 * (1.0 - cos(2.0 * PI * i.float64 / (n - 1).float64))

proc hamming*(n: int): seq[float64] =
  ## Hamming window
  ##
  ## Similar to Hann but optimized for slightly better side lobe suppression
  ## Commonly used in audio and speech processing
  ##
  ## w[n] = 0.54 - 0.46 * cos(2π*n/(N-1))
  result = newSeq[float64](n)
  for i in 0..<n:
    result[i] = 0.54 - 0.46 * cos(2.0 * PI * i.float64 / (n - 1).float64)

proc blackman*(n: int): seq[float64] =
  ## Blackman window
  ##
  ## Better side lobe suppression than Hann/Hamming
  ## Wider main lobe, but cleaner frequency separation
  ##
  ## w[n] = 0.42 - 0.5*cos(2π*n/(N-1)) + 0.08*cos(4π*n/(N-1))
  result = newSeq[float64](n)
  for i in 0..<n:
    let x = i.float64 / (n - 1).float64
    result[i] = 0.42 - 0.5 * cos(2.0 * PI * x) + 0.08 * cos(4.0 * PI * x)

proc blackmanHarris*(n: int): seq[float64] =
  ## Blackman-Harris window (4-term)
  ##
  ## Even better side lobe suppression than Blackman
  ## Excellent for high-dynamic-range measurements
  ##
  ## 4-term cosine sum
  result = newSeq[float64](n)
  const
    a0 = 0.35875
    a1 = 0.48829
    a2 = 0.14128
    a3 = 0.01168

  for i in 0..<n:
    let x = i.float64 / (n - 1).float64
    result[i] = a0 -
                a1 * cos(2.0 * PI * x) +
                a2 * cos(4.0 * PI * x) -
                a3 * cos(6.0 * PI * x)

proc bartlett*(n: int): seq[float64] =
  ## Bartlett window (triangular)
  ##
  ## Simple triangular window
  ## Equivalent to convolving two rectangular windows
  ##
  ## w[n] = 1 - |2n/(N-1) - 1|
  result = newSeq[float64](n)
  for i in 0..<n:
    result[i] = 1.0 - abs(2.0 * i.float64 / (n - 1).float64 - 1.0)

proc welch*(n: int): seq[float64] =
  ## Welch window (parabolic)
  ##
  ## Smoother than Bartlett
  ## w[n] = 1 - (2n/(N-1) - 1)^2
  result = newSeq[float64](n)
  for i in 0..<n:
    let x = 2.0 * i.float64 / (n - 1).float64 - 1.0
    result[i] = 1.0 - x * x

proc kaiser*(n: int, beta: float64 = 8.6): seq[float64] =
  ## Kaiser window (parametric)
  ##
  ## Adjustable window with beta parameter
  ## beta controls trade-off between main lobe width and side lobe level
  ##
  ## beta = 0: Rectangular window
  ## beta = 5: Similar to Hamming
  ## beta = 8.6: Good default (similar to Blackman)
  ## beta = 14: Very high side lobe suppression
  ##
  ## w[n] = I0(β * sqrt(1 - (2n/(N-1) - 1)^2)) / I0(β)
  result = newSeq[float64](n)

  # Modified Bessel function of first kind, order 0
  proc i0(x: float64): float64 =
    var sum = 1.0
    var term = 1.0
    for k in 1..50:
      term = term * (x / (2.0 * k.float64))
      term = term * (x / (2.0 * k.float64))
      sum += term
      if term < 1e-12:
        break
    result = sum

  let denom = i0(beta)

  for i in 0..<n:
    let x = 2.0 * i.float64 / (n - 1).float64 - 1.0
    let arg = beta * sqrt(1.0 - x * x)
    result[i] = i0(arg) / denom

proc flatTop*(n: int): seq[float64] =
  ## Flat top window
  ##
  ## Optimized for accurate amplitude measurements
  ## Wide main lobe, but minimal scalloping loss
  ## Used in FFT-based spectrum analyzers
  ##
  ## 5-term cosine sum
  result = newSeq[float64](n)
  const
    a0 = 0.21557895
    a1 = 0.41663158
    a2 = 0.277263158
    a3 = 0.083578947
    a4 = 0.006947368

  for i in 0..<n:
    let x = i.float64 / (n - 1).float64
    result[i] = a0 -
                a1 * cos(2.0 * PI * x) +
                a2 * cos(4.0 * PI * x) -
                a3 * cos(6.0 * PI * x) +
                a4 * cos(8.0 * PI * x)

# =============================================================================
# Generic Window Generator
# =============================================================================

proc window*(windowType: WindowType, n: int, beta: float64 = 8.6): seq[float64] =
  ## Generate window of specified type
  ##
  ## windowType: Type of window to generate
  ## n: Window length
  ## beta: Kaiser window parameter (only used for Kaiser)
  case windowType
  of Rectangular:
    rectangular(n)
  of Hann:
    hann(n)
  of Hamming:
    hamming(n)
  of Blackman:
    blackman(n)
  of BlackmanHarris:
    blackmanHarris(n)
  of Bartlett:
    bartlett(n)
  of Welch:
    welch(n)
  of Kaiser:
    kaiser(n, beta)
  of FlatTop:
    flatTop(n)

# =============================================================================
# Window Application
# =============================================================================

proc applyWindow*(signal: var openArray[float64], window: openArray[float64]) =
  ## Apply window to signal (in-place)
  ##
  ## Multiplies each sample by corresponding window value
  if signal.len != window.len:
    raise newException(ValueError, "Signal and window must have same length")

  for i in 0..<signal.len:
    signal[i] = signal[i] * window[i]

proc applyWindow*(signal: openArray[float64], window: openArray[float64]): seq[float64] =
  ## Apply window to signal (returns new sequence)
  if signal.len != window.len:
    raise newException(ValueError, "Signal and window must have same length")

  result = newSeq[float64](signal.len)
  for i in 0..<signal.len:
    result[i] = signal[i] * window[i]

# =============================================================================
# Window Normalization
# =============================================================================

proc normalizePower*(window: var openArray[float64]) =
  ## Normalize window for power measurements
  ##
  ## Ensures sum of squared window values = 1.0
  ## Used for power spectral density estimation
  var sumSquared = 0.0
  for w in window:
    sumSquared += w * w

  let scale = 1.0 / sqrt(sumSquared)
  for i in 0..<window.len:
    window[i] = window[i] * scale

proc normalizeAmplitude*(window: var openArray[float64]) =
  ## Normalize window for amplitude measurements
  ##
  ## Ensures sum of window values = 1.0
  ## Used for amplitude-accurate spectral analysis
  var sum = 0.0
  for w in window:
    sum += w

  let scale = 1.0 / sum
  for i in 0..<window.len:
    window[i] = window[i] * scale

# =============================================================================
# Window Properties
# =============================================================================

proc coherentGain*(window: openArray[float64]): float64 =
  ## Compute coherent gain (DC gain) of window
  ##
  ## Sum of all window coefficients
  ## Important for amplitude-accurate measurements
  result = 0.0
  for w in window:
    result += w
  result = result / window.len.float64

proc energyGain*(window: openArray[float64]): float64 =
  ## Compute energy gain (power gain) of window
  ##
  ## Sum of squared window coefficients
  ## Important for power spectral density
  result = 0.0
  for w in window:
    result += w * w
  result = sqrt(result / window.len.float64)

proc equivalentNoiseBandwidth*(window: openArray[float64]): float64 =
  ## Compute equivalent noise bandwidth (ENBW)
  ##
  ## Measure of frequency resolution degradation
  ## ENBW = N * sum(w^2) / (sum(w))^2
  var sumW = 0.0
  var sumW2 = 0.0

  for w in window:
    sumW += w
    sumW2 += w * w

  result = window.len.float64 * sumW2 / (sumW * sumW)

# =============================================================================
# Overlap-Add Processing
# =============================================================================

proc overlapAdd*(signal: openArray[float64], frameSize, hopSize: int,
                 windowType: WindowType = Hann): seq[float64] =
  ## Overlap-add processing framework
  ##
  ## Splits signal into overlapping frames, applies window
  ## Useful for STFT (Short-Time Fourier Transform)
  ##
  ## signal: Input signal
  ## frameSize: Frame/window size (should be power of 2 for FFT)
  ## hopSize: Hop size between frames (typical: frameSize/2 for 50% overlap)
  ## windowType: Window to apply to each frame
  ##
  ## Returns concatenated windowed frames (for further processing)
  if frameSize <= hopSize:
    raise newException(ValueError, "Frame size must be > hop size for overlap")

  let numFrames = (signal.len - frameSize) div hopSize + 1
  let win = window(windowType, frameSize)

  result = newSeq[float64](numFrames * frameSize)

  for frameIdx in 0..<numFrames:
    let offset = frameIdx * hopSize

    for i in 0..<frameSize:
      if offset + i < signal.len:
        result[frameIdx * frameSize + i] = signal[offset + i] * win[i]

# =============================================================================
# Window Comparison
# =============================================================================

proc compareWindows*(): string =
  ## Generate comparison of different window properties
  result = "Window Comparison (N=1024)\n"
  result.add("=" .repeat(60) & "\n\n")
  result.add("Window          Coherent Gain  Energy Gain   ENBW\n")
  result.add("-" .repeat(60) & "\n")

  let n = 1024
  let windows = [
    ("Rectangular", rectangular(n)),
    ("Hann", hann(n)),
    ("Hamming", hamming(n)),
    ("Blackman", blackman(n)),
    ("BlackmanHarris", blackmanHarris(n)),
    ("Bartlett", bartlett(n)),
    ("Kaiser(β=8.6)", kaiser(n, 8.6)),
    ("FlatTop", flatTop(n))
  ]

  for (name, win) in windows:
    let cg = coherentGain(win)
    let eg = energyGain(win)
    let enbw = equivalentNoiseBandwidth(win)
    result.add(name.alignLeft(15) & " ")
    result.add(cg.formatFloat(ffDecimal, 4).alignLeft(14) & " ")
    result.add(eg.formatFloat(ffDecimal, 4).alignLeft(13) & " ")
    result.add(enbw.formatFloat(ffDecimal, 2) & "\n")

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/strformat

  echo "Window Functions Example"
  echo "========================\n"

  # Generate different windows
  const n = 512

  echo "Generating windows of size ", n, "...\n"

  # Show first 5 values of each window
  echo "First 5 values of each window:"
  let windows = [
    ("Hann", hann(n)),
    ("Hamming", hamming(n)),
    ("Blackman", blackman(n)),
    ("Bartlett", bartlett(n))
  ]

  for (name, win) in windows:
    echo &"  {name:12s}: {win[0]:.6f}, {win[1]:.6f}, {win[2]:.6f}, {win[3]:.6f}, {win[4]:.6f}"

  echo "\n", compareWindows()

  # Show window properties
  echo "\nHann window properties:"
  let hannWin = hann(1024)
  echo "  Coherent gain: ", coherentGain(hannWin).formatFloat(ffDecimal, 6)
  echo "  Energy gain: ", energyGain(hannWin).formatFloat(ffDecimal, 6)
  echo "  ENBW: ", equivalentNoiseBandwidth(hannWin).formatFloat(ffDecimal, 2), " bins"
