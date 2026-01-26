## Tests for Fast Fourier Transform
## ==================================

import std/[unittest, math, complex]
import ../src/arsenal/media/dsp/fft

proc almostEqual(a, b: float64, tolerance: float64 = 1e-10): bool =
  abs(a - b) < tolerance

proc almostEqualComplex(a, b: Complex64, tolerance: float64 = 1e-10): bool =
  abs(a.re - b.re) < tolerance and abs(a.im - b.im) < tolerance

suite "FFT - Basic Operations":
  test "power of 2 validation":
    expect(ValueError):
      var data = newSeq[Complex64](100)  # Not power of 2
      fft(data)

  test "FFT of DC signal (all ones)":
    var data = newSeq[Complex64](8)
    for i in 0..<8:
      data[i] = complex64(1.0, 0.0)

    fft(data)

    # DC component should be N
    check almostEqualComplex(data[0], complex64(8.0, 0.0), 1e-10)

    # All other bins should be ~0
    for i in 1..<8:
      check abs(data[i]) < 1e-10

  test "FFT/IFFT round-trip":
    var data = newSeq[Complex64](16)
    var original = newSeq[Complex64](16)

    for i in 0..<16:
      data[i] = complex64(float64(i), 0.0)
      original[i] = data[i]

    fft(data)
    ifft(data)

    # Should recover original signal
    for i in 0..<16:
      check almostEqualComplex(data[i], original[i], 1e-10)

  test "linearity: FFT(a*x + b*y) = a*FFT(x) + b*FFT(y)":
    const n = 8
    var x = newSeq[Complex64](n)
    var y = newSeq[Complex64](n)

    for i in 0..<n:
      x[i] = complex64(float64(i), 0.0)
      y[i] = complex64(float64(n - i), 0.0)

    var x_copy = x
    var y_copy = y

    # Compute FFT(x) and FFT(y)
    fft(x_copy)
    fft(y_copy)

    # Compute a*FFT(x) + b*FFT(y)
    let a = 2.0
    let b = 3.0
    var expected = newSeq[Complex64](n)
    for i in 0..<n:
      expected[i] = complex64(a, 0.0) * x_copy[i] + complex64(b, 0.0) * y_copy[i]

    # Compute FFT(a*x + b*y)
    var combined = newSeq[Complex64](n)
    for i in 0..<n:
      combined[i] = complex64(a, 0.0) * x[i] + complex64(b, 0.0) * y[i]
    fft(combined)

    # Check linearity
    for i in 0..<n:
      check almostEqualComplex(combined[i], expected[i], 1e-9)

suite "FFT - Signal Analysis":
  test "single frequency detection":
    const n = 64
    const freq = 8.0  # 8 cycles in 64 samples
    var data = newSeq[Complex64](n)

    # Generate pure sine wave
    for i in 0..<n:
      let phase = 2.0 * PI * freq * float64(i) / float64(n)
      data[i] = complex64(sin(phase), 0.0)

    fft(data)

    let mag = magnitude(data)

    # Peak should be at bin 8 and bin n-8 (conjugate symmetry)
    check mag[8] > 20.0  # Strong peak
    check mag[n - 8] > 20.0  # Conjugate peak

    # Other bins should be ~0
    for i in 0..<n:
      if i != 8 and i != (n - 8):
        check mag[i] < 1.0

  test "DC offset detection":
    const n = 16
    var data = newSeq[Complex64](n)

    # Signal with DC offset
    for i in 0..<n:
      data[i] = complex64(5.0, 0.0)  # Constant 5.0

    fft(data)

    # Only DC bin (bin 0) should be non-zero
    check almostEqualComplex(data[0], complex64(80.0, 0.0), 1e-9)  # 5.0 * 16

    for i in 1..<n:
      check abs(data[i]) < 1e-10

suite "FFT - Real-valued Optimizations":
  test "RFFT basic":
    const n = 16
    var signal = newSeq[float64](n)

    for i in 0..<n:
      signal[i] = float64(i)

    let spectrum = rfft(signal)

    # RFFT returns n/2 + 1 values
    check spectrum.len == n div 2 + 1

  test "RFFT/IRFFT round-trip":
    const n = 32
    var signal = newSeq[float64](n)

    for i in 0..<n:
      signal[i] = sin(2.0 * PI * 4.0 * float64(i) / float64(n))

    let spectrum = rfft(signal)
    let recovered = irfft(spectrum, n)

    # Should recover original signal
    for i in 0..<n:
      check almostEqual(signal[i], recovered[i], 1e-10)

suite "FFT - Utility Functions":
  test "magnitude spectrum":
    const n = 8
    var data = newSeq[Complex64](n)

    data[0] = complex64(3.0, 4.0)  # |3 + 4i| = 5
    data[1] = complex64(1.0, 0.0)  # |1| = 1
    data[2] = complex64(0.0, 1.0)  # |i| = 1

    let mag = magnitude(data)

    check almostEqual(mag[0], 5.0)
    check almostEqual(mag[1], 1.0)
    check almostEqual(mag[2], 1.0)

  test "magnitude in dB":
    const n = 8
    var data = newSeq[Complex64](n)

    data[0] = complex64(1.0, 0.0)  # 0 dB
    data[1] = complex64(10.0, 0.0)  # 20 dB
    data[2] = complex64(0.1, 0.0)  # -20 dB

    let magDb = magnitudeDb(data)

    check almostEqual(magDb[0], 0.0, 0.01)
    check almostEqual(magDb[1], 20.0, 0.01)
    check almostEqual(magDb[2], -20.0, 0.01)

  test "phase spectrum":
    const n = 4
    var data = newSeq[Complex64](n)

    data[0] = complex64(1.0, 0.0)  # 0 radians
    data[1] = complex64(0.0, 1.0)  # π/2 radians
    data[2] = complex64(-1.0, 0.0)  # π radians
    data[3] = complex64(0.0, -1.0)  # -π/2 radians

    let phases = phase(data)

    check almostEqual(phases[0], 0.0)
    check almostEqual(phases[1], PI / 2.0, 1e-10)
    check almostEqual(abs(phases[2]), PI, 1e-10)
    check almostEqual(phases[3], -PI / 2.0, 1e-10)

  test "power spectrum":
    const n = 4
    var data = newSeq[Complex64](n)

    data[0] = complex64(3.0, 4.0)  # |3+4i|^2 = 25
    data[1] = complex64(1.0, 1.0)  # |1+i|^2 = 2

    let power = powerSpectrum(data)

    check almostEqual(power[0], 25.0)
    check almostEqual(power[1], 2.0)

suite "FFT - Frequency Bins":
  test "FFT frequency bins":
    const n = 8
    const sampleRate = 1000.0

    let freqs = fftFreqs(n, sampleRate)

    check freqs.len == n
    check almostEqual(freqs[0], 0.0)
    check almostEqual(freqs[1], 125.0)  # 1000 / 8
    check almostEqual(freqs[n div 2], 500.0)  # Nyquist

  test "RFFT frequency bins":
    const n = 16
    const sampleRate = 44100.0

    let freqs = rfftFreqs(n, sampleRate)

    check freqs.len == n div 2 + 1
    check almostEqual(freqs[0], 0.0)  # DC
    check almostEqual(freqs[n div 2], 22050.0)  # Nyquist

suite "FFT - Convolution":
  test "convolution via FFT":
    var signal = @[1.0, 2.0, 3.0, 4.0]
    var kernel = @[0.5, 0.5]

    let result = convolve(signal, kernel)

    # Manual verification: moving average filter
    check almostEqual(result[0], 0.5)  # 1 * 0.5
    check almostEqual(result[1], 1.5)  # (1 + 2) * 0.5
    check almostEqual(result[2], 2.5)  # (2 + 3) * 0.5
    check almostEqual(result[3], 3.5)  # (3 + 4) * 0.5
    check almostEqual(result[4], 2.0)  # 4 * 0.5

  test "convolution is commutative":
    var a = @[1.0, 2.0, 3.0]
    var b = @[4.0, 5.0]

    let ab = convolve(a, b)
    let ba = convolve(b, a)

    check ab.len == ba.len
    for i in 0..<ab.len:
      check almostEqual(ab[i], ba[i], 1e-10)

suite "FFT - Correlation":
  test "auto-correlation peak at zero":
    var signal = @[1.0, 2.0, 3.0, 4.0, 5.0]

    let corr = correlate(signal, signal)

    # Auto-correlation should peak at zero lag
    let maxIdx = corr.find(corr.max)
    check maxIdx == 0 or maxIdx == corr.len - 1  # Zero lag (accounting for wrap)

suite "FFT - Helper Functions":
  test "nextPowerOf2":
    check nextPowerOf2(1) == 1
    check nextPowerOf2(2) == 2
    check nextPowerOf2(3) == 4
    check nextPowerOf2(15) == 16
    check nextPowerOf2(100) == 128
    check nextPowerOf2(1000) == 1024

  test "isPowerOf2":
    check isPowerOf2(1)
    check isPowerOf2(2)
    check isPowerOf2(4)
    check isPowerOf2(1024)
    check not isPowerOf2(0)
    check not isPowerOf2(3)
    check not isPowerOf2(1000)

suite "FFT - Parseval's Theorem":
  test "energy conservation":
    # Parseval's theorem: sum(|x[n]|^2) = (1/N) * sum(|X[k]|^2)
    const n = 16
    var signal = newSeq[Complex64](n)

    for i in 0..<n:
      signal[i] = complex64(sin(2.0 * PI * float64(i) / float64(n)), 0.0)

    # Compute time-domain energy
    var timeEnergy = 0.0
    for i in 0..<n:
      timeEnergy += abs(signal[i]) * abs(signal[i])

    var spectrum = signal  # Copy
    fft(spectrum)

    # Compute frequency-domain energy
    var freqEnergy = 0.0
    for i in 0..<n:
      freqEnergy += abs(spectrum[i]) * abs(spectrum[i])

    freqEnergy /= float64(n)

    # Should be equal (Parseval's theorem)
    check almostEqual(timeEnergy, freqEnergy, 1e-8)

## Performance Notes
## ==================
##
## FFT Complexity:
##   - Time: O(N log N) where N is FFT size
##   - Space: O(N) for in-place, O(2N) for out-of-place
##
## Typical Performance (N=1024, modern CPU):
##   - FFT: ~10-50 μs
##   - IFFT: ~10-50 μs
##   - RFFT: ~5-25 μs (2x faster for real input)
##
## Real-Time Audio:
##   - 512 samples @ 44.1kHz: ~11.6ms latency
##   - 1024 samples @ 44.1kHz: ~23.2ms latency
##   - 2048 samples @ 44.1kHz: ~46.4ms latency
##
## Use Cases:
##   - Audio analysis (pitch detection, spectrum analyzer)
##   - Signal processing (filtering, compression)
##   - Image processing (JPEG, convolution)
##   - Telecommunications (OFDM, channel estimation)
##   - Scientific computing (solving PDEs)
##
## Optimization Tips:
##   1. Use power-of-2 sizes (required for radix-2)
##   2. RFFT for real-valued input (2x faster)
##   3. Reuse buffers (avoid allocation overhead)
##   4. Consider SIMD for large FFTs
##   5. Use look-up tables for twiddle factors
##
## Alternatives:
##   - Radix-4: Faster for some sizes (requires N = 4^k)
##   - Prime-factor FFT: For non-power-of-2 sizes
##   - FFTW library: Highly optimized (adaptive algorithm)
##
## Limitations:
##   - Requires power-of-2 size (use zero-padding)
##   - Circular convolution (use zero-padding for linear)
##   - Spectral leakage (use windowing functions)
##   - Frequency resolution = sampleRate / N
