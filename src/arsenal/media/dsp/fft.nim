## Fast Fourier Transform (FFT)
## ============================
##
## Radix-2 Cooley-Tukey FFT implementation.
## Converts time-domain signals to frequency-domain and back.
##
## Features:
## - In-place FFT (memory efficient)
## - Radix-2 decimation-in-time algorithm
## - Inverse FFT (IFFT)
## - Real-valued FFT optimization
## - Bit-reversal permutation
## - Complex number arithmetic
##
## Performance:
## - O(N log N) complexity
## - Cache-friendly access patterns
## - Suitable for real-time audio (N=512-4096)
##
## Usage:
## ```nim
## import arsenal/media/dsp/fft
##
## var signal = newSeq[Complex64](1024)
## # Fill with audio samples...
## fft(signal)  # In-place transform
## # signal now contains frequency domain data
## ifft(signal)  # Back to time domain
## ```

import std/math
import std/complex

# =============================================================================
# Complex Number Types
# =============================================================================

type
  Complex64* = Complex64  ## Re-export from std/complex (float64 real/imag)

# =============================================================================
# FFT Constants
# =============================================================================

const
  TwoPi = 2.0 * PI

# =============================================================================
# Bit Reversal
# =============================================================================

proc reverseBits(x: int, bits: int): int {.inline.} =
  ## Reverse the bottom 'bits' bits of integer x
  result = 0
  var n = x
  for i in 0..<bits:
    result = (result shl 1) or (n and 1)
    n = n shr 1

proc bitReversePermute*[T](data: var openArray[T]) =
  ## Bit-reverse permutation (in-place)
  ## Required preprocessing for decimation-in-time FFT
  let n = data.len
  let bits = fastLog2(n)  # Number of bits needed

  for i in 0..<n:
    let j = reverseBits(i, bits)
    if i < j:
      swap(data[i], data[j])

proc fastLog2(n: int): int {.inline.} =
  ## Fast log2 for powers of 2
  result = 0
  var x = n
  while x > 1:
    x = x shr 1
    inc result

# =============================================================================
# FFT Core Algorithm (Radix-2 Cooley-Tukey)
# =============================================================================

proc fft*(data: var openArray[Complex64]) =
  ## In-place Fast Fourier Transform (Radix-2 Cooley-Tukey)
  ##
  ## Input: Time-domain signal (must be power of 2 length)
  ## Output: Frequency-domain coefficients (in-place)
  ##
  ## Algorithm: Decimation-in-time with bit-reversal
  ##
  ## Complexity: O(N log N)
  let n = data.len

  # Validate power of 2
  if (n and (n - 1)) != 0:
    raise newException(ValueError, "FFT size must be power of 2")

  # Bit-reversal permutation
  bitReversePermute(data)

  # Cooley-Tukey decimation-in-time
  var size = 2
  while size <= n:
    let halfSize = size div 2
    let angle = -TwoPi / size.float64

    # Twiddle factor step
    let wStep = complex64(cos(angle), sin(angle))

    for i in countup(0, n - 1, size):
      var w = complex64(1.0, 0.0)  # Unity twiddle factor

      for j in 0..<halfSize:
        let u = data[i + j]
        let v = data[i + j + halfSize] * w

        data[i + j] = u + v
        data[i + j + halfSize] = u - v

        w = w * wStep

    size = size * 2

proc ifft*(data: var openArray[Complex64]) =
  ## Inverse Fast Fourier Transform
  ##
  ## Input: Frequency-domain coefficients
  ## Output: Time-domain signal (in-place)
  ##
  ## Uses conjugate trick: IFFT(X) = conj(FFT(conj(X))) / N
  let n = data.len

  # Conjugate input
  for i in 0..<n:
    data[i] = complex64(data[i].re, -data[i].im)

  # Forward FFT
  fft(data)

  # Conjugate output and scale
  let scale = 1.0 / n.float64
  for i in 0..<n:
    data[i] = complex64(data[i].re * scale, -data[i].im * scale)

# =============================================================================
# Real FFT (Optimized for Real-Valued Input)
# =============================================================================

proc rfft*(realData: openArray[float64]): seq[Complex64] =
  ## Real FFT: Optimized FFT for real-valued input
  ##
  ## Input: Real-valued time-domain signal
  ## Output: Complex frequency-domain (only positive frequencies + DC/Nyquist)
  ##
  ## Returns N/2 + 1 complex values (exploits Hermitian symmetry)
  let n = realData.len

  if (n and (n - 1)) != 0:
    raise newException(ValueError, "FFT size must be power of 2")

  # Convert real to complex
  result = newSeq[Complex64](n)
  for i in 0..<n:
    result[i] = complex64(realData[i], 0.0)

  # Perform complex FFT
  fft(result)

  # For real input, only return positive frequencies (N/2 + 1 values)
  # Negative frequencies are complex conjugates (Hermitian symmetry)
  result.setLen(n div 2 + 1)

proc irfft*(freqData: openArray[Complex64], outputSize: int): seq[float64] =
  ## Inverse Real FFT
  ##
  ## Input: Complex frequency-domain (positive frequencies only)
  ## Output: Real-valued time-domain signal
  ##
  ## Reconstructs full spectrum using Hermitian symmetry
  if (outputSize and (outputSize - 1)) != 0:
    raise newException(ValueError, "Output size must be power of 2")

  let halfSize = outputSize div 2

  # Reconstruct full spectrum (Hermitian symmetry)
  var fullSpectrum = newSeq[Complex64](outputSize)

  # Copy positive frequencies
  for i in 0..halfSize:
    fullSpectrum[i] = freqData[i]

  # Mirror negative frequencies (complex conjugate)
  for i in 1..<halfSize:
    fullSpectrum[outputSize - i] = complex64(freqData[i].re, -freqData[i].im)

  # Inverse FFT
  ifft(fullSpectrum)

  # Extract real part
  result = newSeq[float64](outputSize)
  for i in 0..<outputSize:
    result[i] = fullSpectrum[i].re

# =============================================================================
# FFT Utilities
# =============================================================================

proc magnitude*(data: openArray[Complex64]): seq[float64] =
  ## Compute magnitude spectrum from FFT output
  ## Returns |X[k]| for each frequency bin
  result = newSeq[float64](data.len)
  for i in 0..<data.len:
    result[i] = abs(data[i])

proc magnitudeDb*(data: openArray[Complex64]): seq[float64] =
  ## Compute magnitude spectrum in decibels
  ## Returns 20 * log10(|X[k]|) for each frequency bin
  result = newSeq[float64](data.len)
  for i in 0..<data.len:
    let mag = abs(data[i])
    result[i] = if mag > 1e-10: 20.0 * log10(mag) else: -200.0

proc phase*(data: openArray[Complex64]): seq[float64] =
  ## Compute phase spectrum from FFT output
  ## Returns arg(X[k]) in radians for each frequency bin
  result = newSeq[float64](data.len)
  for i in 0..<data.len:
    result[i] = arctan2(data[i].im, data[i].re)

proc powerSpectrum*(data: openArray[Complex64]): seq[float64] =
  ## Compute power spectrum from FFT output
  ## Returns |X[k]|^2 for each frequency bin
  result = newSeq[float64](data.len)
  for i in 0..<data.len:
    let re = data[i].re
    let im = data[i].im
    result[i] = re * re + im * im

# =============================================================================
# Frequency Bin Utilities
# =============================================================================

proc fftFreqs*(n: int, sampleRate: float64): seq[float64] =
  ## Compute FFT frequency bins
  ##
  ## Returns frequency in Hz for each FFT bin
  ## n: FFT size
  ## sampleRate: Sampling rate in Hz
  result = newSeq[float64](n)
  let df = sampleRate / n.float64  # Frequency resolution

  for i in 0..<n:
    result[i] = i.float64 * df

proc rfftFreqs*(n: int, sampleRate: float64): seq[float64] =
  ## Compute Real FFT frequency bins (positive frequencies only)
  ##
  ## Returns frequency in Hz for each bin (N/2 + 1 values)
  result = newSeq[float64](n div 2 + 1)
  let df = sampleRate / n.float64

  for i in 0..(n div 2):
    result[i] = i.float64 * df

# =============================================================================
# Convolution via FFT
# =============================================================================

proc convolve*(signal, kernel: openArray[float64]): seq[float64] =
  ## Fast convolution using FFT (overlap-add method)
  ##
  ## Computes signal * kernel using frequency domain multiplication
  ## Faster than time-domain for large kernels: O(N log N) vs O(N*M)
  let n = signal.len
  let m = kernel.len
  let resultLen = n + m - 1

  # Find next power of 2 >= resultLen
  var fftSize = 1
  while fftSize < resultLen:
    fftSize = fftSize shl 1

  # Zero-pad inputs
  var sig = newSeq[Complex64](fftSize)
  var kern = newSeq[Complex64](fftSize)

  for i in 0..<n:
    sig[i] = complex64(signal[i], 0.0)
  for i in 0..<m:
    kern[i] = complex64(kernel[i], 0.0)

  # Transform to frequency domain
  fft(sig)
  fft(kern)

  # Multiply in frequency domain
  for i in 0..<fftSize:
    sig[i] = sig[i] * kern[i]

  # Transform back to time domain
  ifft(sig)

  # Extract real part and trim to actual result length
  result = newSeq[float64](resultLen)
  for i in 0..<resultLen:
    result[i] = sig[i].re

# =============================================================================
# FFT-based Correlation
# =============================================================================

proc correlate*(signal1, signal2: openArray[float64]): seq[float64] =
  ## Fast cross-correlation using FFT
  ##
  ## Computes correlation between two signals
  ## Useful for: pitch detection, template matching, time delay estimation
  let n = max(signal1.len, signal2.len)

  # Find next power of 2
  var fftSize = 1
  while fftSize < 2 * n:
    fftSize = fftSize shl 1

  # Zero-pad inputs
  var sig1 = newSeq[Complex64](fftSize)
  var sig2 = newSeq[Complex64](fftSize)

  for i in 0..<signal1.len:
    sig1[i] = complex64(signal1[i], 0.0)
  for i in 0..<signal2.len:
    sig2[i] = complex64(signal2[i], 0.0)

  # Transform to frequency domain
  fft(sig1)
  fft(sig2)

  # Multiply sig1 * conj(sig2) in frequency domain
  for i in 0..<fftSize:
    sig1[i] = sig1[i] * complex64(sig2[i].re, -sig2[i].im)

  # Transform back
  ifft(sig1)

  # Extract real part
  result = newSeq[float64](fftSize)
  for i in 0..<fftSize:
    result[i] = sig1[i].re

# =============================================================================
# Helper Functions
# =============================================================================

proc nextPowerOf2*(n: int): int =
  ## Find next power of 2 >= n
  result = 1
  while result < n:
    result = result shl 1

proc isPowerOf2*(n: int): bool =
  ## Check if n is a power of 2
  n > 0 and (n and (n - 1)) == 0

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/random

  echo "FFT Example"
  echo "==========="

  # Create test signal: 440 Hz sine wave + 880 Hz sine wave
  const sampleRate = 44100.0
  const duration = 0.1  # 100ms
  const n = 1024  # FFT size (power of 2)

  var signal = newSeq[float64](n)

  for i in 0..<n:
    let t = i.float64 / sampleRate
    signal[i] = sin(2.0 * PI * 440.0 * t) + 0.5 * sin(2.0 * PI * 880.0 * t)

  # Compute FFT
  let spectrum = rfft(signal)

  # Get magnitude
  let mag = magnitude(spectrum)

  # Find frequency bins
  let freqs = rfftFreqs(n, sampleRate)

  # Find peaks (should be at 440 Hz and 880 Hz)
  echo "\nTop 5 frequency peaks:"
  var peaks: seq[tuple[freq: float64, mag: float64]]
  for i in 1..<mag.len - 1:
    if mag[i] > mag[i-1] and mag[i] > mag[i+1] and mag[i] > 10.0:
      peaks.add((freqs[i], mag[i]))

  peaks.sort(proc(a, b: auto): int = cmp(b.mag, a.mag))

  for i in 0..<min(5, peaks.len):
    echo "  ", peaks[i].freq.formatFloat(ffDecimal, 1), " Hz: ",
         peaks[i].mag.formatFloat(ffDecimal, 2)
