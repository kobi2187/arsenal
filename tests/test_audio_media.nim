## Tests for Audio Media Processing
## ==================================
##
## Tests for audio format conversion, resampling, MDCT, ring buffer, and mixing

import std/[unittest, math, complex]
import ../src/arsenal/media/audio/[format, resampling, ringbuffer, mixing]
import ../src/arsenal/media/dsp/mdct

suite "Audio Format Conversion":
  test "int16 to float32 conversion":
    var int16Data: array[8, int16] = [
      -32768'i16, -16384, -8192, -1024, 0, 1024, 8192, 16384
    ]

    var float32Data = newSeq[float32](8)
    int16ToFloat32(int16Data, float32Data)

    # Check normalization
    check abs(float32Data[0] - (-1.0'f32)) < 0.01  # -32768 → -1.0
    check abs(float32Data[4] - 0.0'f32) < 0.001    # 0 → 0.0
    check abs(float32Data[7] - 0.5'f32) < 0.01     # 16384 → 0.5

  test "float32 to int16 round-trip":
    var original: array[5, float32] = [-1.0'f32, -0.5, 0.0, 0.5, 1.0]

    var int16Data = newSeq[int16](5)
    float32ToInt16(original, int16Data, useDither = false)

    var recovered = newSeq[float32](5)
    int16ToFloat32(int16Data, recovered)

    # Should be very close (with quantization error)
    for i in 0..<5:
      check abs(recovered[i] - original[i]) < 0.01

  test "stereo interleaving and de-interleaving":
    var left: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
    var right: array[4, float32] = [0.1'f32, 0.2, 0.3, 0.4]

    # Interleave
    var interleaved = newSeq[float32](8)
    interleaveStereo(left, right, interleaved)

    check interleaved[0] == 1.0'f32  # L
    check interleaved[1] == 0.1'f32  # R
    check interleaved[2] == 2.0'f32  # L
    check interleaved[3] == 0.2'f32  # R

    # De-interleave back
    var leftBack, rightBack = newSeq[float32](4)
    deinterleaveStereo(interleaved, leftBack, rightBack)

    for i in 0..<4:
      check leftBack[i] == left[i]
      check rightBack[i] == right[i]

  test "stereo to mono downmix":
    var left: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
    var right: array[4, float32] = [1.0'f32, 0.0, 1.0, 0.0]

    var mono = newSeq[float32](4)
    stereoToMono(left, right, mono)

    check mono[0] == 1.0'f32   # (1.0 + 1.0) / 2
    check mono[1] == 1.0'f32   # (2.0 + 0.0) / 2
    check mono[2] == 2.0'f32   # (3.0 + 1.0) / 2
    check mono[3] == 2.0'f32   # (4.0 + 0.0) / 2

suite "Audio Resampling":
  test "2x upsampling (simple ratio)":
    # Create simple signal: 4 samples
    var input: array[4, float64] = [0.0, 1.0, 0.0, -1.0]

    var resampler = initResampler(
      inputRate = 22050,
      outputRate = 44100,  # 2x
      quality = QualityFast
    )

    let output = resampler.process(input)

    # Should get approximately 8 samples (2x)
    check output.len >= 7 and output.len <= 9

  test "44.1kHz to 48kHz conversion":
    const inputRate = 44100
    const outputRate = 48000

    # Create sine wave at input rate
    const duration = 0.01  # 10ms
    const inputSamples = int(inputRate.float64 * duration)

    var input = newSeq[float64](inputSamples)
    for i in 0..<inputSamples:
      let t = i.float64 / inputRate.float64
      input[i] = sin(2.0 * PI * 1000.0 * t)  # 1 kHz

    var resampler = initResampler(inputRate, outputRate, QualityMedium)
    let output = resampler.process(input)

    # Check output size is approximately correct
    let expectedSize = int(inputSamples.float64 * outputRate.float64 / inputRate.float64)
    check abs(output.len - expectedSize) < 10

  test "ratio simplification":
    let (num, den) = simplifyRatio(44100, 48000)
    check num == 160  # 48000 / gcd(44100, 48000)
    check den == 147  # 44100 / gcd(44100, 48000)

    let (num2, den2) = simplifyRatio(22050, 44100)
    check num2 == 2
    check den2 == 1

suite "MDCT/IMDCT":
  test "IMDCT basic functionality":
    const n = 128

    # Create IMDCT transformer
    let window = generateSineWindow(n * 2)
    var imdct = initIMDCT(n, window)

    # Create simple frequency coefficients (DC + fundamental)
    var coeffs = newSeq[float64](n)
    coeffs[0] = 1.0  # DC
    coeffs[1] = 0.5  # First harmonic

    # Transform to time domain
    let samples = imdct.transform(coeffs)

    # Should produce 2*n samples
    check samples.len == n * 2

    # Output should not be all zeros
    var hasNonZero = false
    for s in samples:
      if abs(s) > 1e-6:
        hasNonZero = true
        break

    check hasNonZero

  test "MDCT/IMDCT perfect reconstruction":
    const n = 256

    # Create sine window
    let window = generateSineWindow(n * 2)

    # Create test signal
    var signal = newSeq[float64](n * 2)
    for i in 0..<(n * 2):
      signal[i] = sin(2.0 * PI * 5.0 * i.float64 / (n * 2).float64)

    # MDCT forward transform
    var mdct = initMDCT(n, window)
    let coeffs = mdct.transform(signal)

    check coeffs.len == n

    # IMDCT inverse transform
    var imdct = initIMDCT(n, window)
    let reconstructed = imdct.transform(coeffs)

    check reconstructed.len == n * 2

    # Check reconstruction error
    var maxError = 0.0
    for i in 0..<(n * 2):
      let error = abs(signal[i] - reconstructed[i])
      maxError = max(maxError, error)

    # Should reconstruct with very small error
    check maxError < 1e-6

  test "sine window generation":
    let window = generateSineWindow(1024)

    check window.len == 1024

    # Check window properties
    check window[0] < 0.01  # Should start near 0
    check window[511] > 0.99  # Should peak near middle
    check window[1023] < 0.01  # Should end near 0

  test "KBD window generation":
    let window = generateKBDWindow(1024, 4.0)

    check window.len == 1024

    # Should be symmetric
    check abs(window[0] - window[1023]) < 1e-6
    check abs(window[100] - window[923]) < 1e-6

suite "Ring Buffer":
  test "basic write and read":
    var rb = initRingBuffer[float32](16)

    # Initially empty
    check rb.isEmpty()
    check not rb.isFull()
    check rb.available() == 0
    check rb.space() == 16

    # Write some data
    var writeData: array[8, float32] = [1.0'f32, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0]
    let written = rb.write(writeData)

    check written == 8
    check rb.available() == 8
    check rb.space() == 8

    # Read data back
    var readData = newSeq[float32](8)
    let read = rb.read(readData)

    check read == 8
    for i in 0..<8:
      check readData[i] == writeData[i]

    check rb.isEmpty()

    rb.destroy()

  test "wrap-around behavior":
    var rb = initRingBuffer[float32](8)

    # Fill buffer
    var data1: array[6, float32] = [1.0'f32, 2.0, 3.0, 4.0, 5.0, 6.0]
    discard rb.write(data1)

    # Read some
    var read1 = newSeq[float32](4)
    discard rb.read(read1)

    # Write more (should wrap around)
    var data2: array[4, float32] = [7.0'f32, 8.0, 9.0, 10.0]
    let written = rb.write(data2)

    check written == 4  # Should have space for 4 (6-4+4 = 6 total)

    # Read all
    var readAll = newSeq[float32](6)
    let readCount = rb.read(readAll)

    check readCount == 6
    check readAll[0] == 5.0'f32  # Remaining from first write
    check readAll[1] == 6.0'f32
    check readAll[2] == 7.0'f32  # From second write
    check readAll[3] == 8.0'f32

    rb.destroy()

  test "single sample operations":
    var rb = initRingBuffer[float32](4)

    # Write single samples
    check rb.writeSingle(1.0'f32)
    check rb.writeSingle(2.0'f32)
    check rb.available() == 2

    # Read single samples
    var sample: float32
    check rb.readSingle(sample)
    check sample == 1.0'f32

    check rb.readSingle(sample)
    check sample == 2.0'f32

    check rb.isEmpty()

    rb.destroy()

  test "overflow and underflow detection":
    var rb = initRingBuffer[float32](16)

    # Nearly empty - underrun risk
    var tiny: array[1, float32] = [1.0'f32]
    discard rb.write(tiny)

    check rb.underrunDetected(0.2)  # Less than 20% full

    # Fill up - overrun risk
    var large: array[15, float32]
    for i in 0..<15:
      large[i] = float32(i)
    discard rb.write(large)

    check rb.overrunRisk(0.9)  # More than 90% full

    rb.destroy()

suite "Audio Mixing":
  test "basic two-channel mix":
    var input1: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
    var input2: array[4, float32] = [0.5'f32, 1.0, 1.5, 2.0]

    var output = newSeq[float32](4)
    mix(input1, input2, output)

    check output[0] == 1.5'f32
    check output[1] == 3.0'f32
    check output[2] == 4.5'f32
    check output[3] == 6.0'f32

  test "weighted mixing":
    var input1: array[4, float32] = [1.0'f32, 1.0, 1.0, 1.0]
    var input2: array[4, float32] = [0.0'f32, 0.0, 0.0, 0.0]

    var output = newSeq[float32](4)

    # 75% input1, 25% input2
    mixWeighted(input1, input2, output, 0.75'f32, 0.25'f32)

    for i in 0..<4:
      check abs(output[i] - 0.75'f32) < 0.001

  test "panning constant power":
    var mono: array[1, float32] = [1.0'f32]
    var left, right = newSeq[float32](1)

    # Center panning
    panStereo(mono, left, right, pan = 0.5)

    # Constant power: left^2 + right^2 should equal original power
    let power = left[0] * left[0] + right[0] * right[0]
    check abs(power - 1.0'f32) < 0.01

  test "crossfade":
    var trackA: array[4, float32] = [1.0'f32, 1.0, 1.0, 1.0]
    var trackB: array[4, float32] = [0.0'f32, 0.0, 0.0, 0.0]
    var output = newSeq[float32](4)

    # All track A
    crossfade(trackA, trackB, output, fadePosition = 0.0)
    check abs(output[0] - 1.0'f32) < 0.01

    # All track B
    crossfade(trackA, trackB, output, fadePosition = 1.0)
    check abs(output[0] - 0.0'f32) < 0.01

    # Middle (should be between 0 and 1, closer to ~0.7 due to equal-power)
    crossfade(trackA, trackB, output, fadePosition = 0.5)
    check output[0] > 0.5'f32 and output[0] < 0.9'f32

  test "dB to linear conversion":
    check abs(dbToLinear(0.0) - 1.0) < 0.001
    check abs(dbToLinear(-6.0) - 0.5) < 0.01
    check abs(dbToLinear(6.0) - 2.0) < 0.01

    check abs(linearToDb(1.0) - 0.0) < 0.001
    check abs(linearToDb(0.5) - (-6.0)) < 0.1
    check abs(linearToDb(2.0) - 6.0) < 0.1

  test "peak normalization":
    var samples: array[4, float32] = [0.5'f32, -0.8, 0.3, -0.2]

    normalizePeak(samples, 1.0'f32)

    # Peak should now be 1.0
    var maxVal = 0.0'f32
    for s in samples:
      maxVal = max(maxVal, abs(s))

    check abs(maxVal - 1.0'f32) < 0.001

# Run all tests
when isMainModule:
  echo "Running Audio Media Processing Tests"
  echo "====================================="
