## Arsenal Compression - Unified High-Level API
## ==============================================
##
## This module provides a consistent, ergonomic API for all compression
## codecs. It wraps the underlying implementations without modifying them.
##
## You can use either:
## - This high-level API (consistent, discoverable)
## - Direct implementation modules (full control, all features)
##
## Usage:
## ```nim
## import arsenal/compression
##
## # Integer compression
## let codec = IntCodec.new()
## let compressed = codec.encode([1, 2, 3, 4, 5])
## let decoded = codec.decode(compressed, count = 5)
## ```

import arsenal/compression/streamvbyte

export streamvbyte  # Re-export for direct use

# =============================================================================
# INT CODEC - Unified API for integer compression
# =============================================================================

type
  IntCodec* = object
    ## High-level API for integer compression
    ##
    ## Wraps: StreamVByte
    ##
    ## Properties:
    ## - Fast encoding/decoding (4+ billion ints/sec)
    ## - SIMD-friendly
    ## - Particularly good for sorted sequences with delta encoding
    useDelta: bool

  IntCodecBuilder* = object
    useDelta: bool

# Constructors
proc new*(_: typedesc[IntCodec]): IntCodecBuilder =
  ## Create int codec builder
  ##
  ## Example:
  ## ```nim
  ## let codec = IntCodec.new()
  ##   .withDeltaEncoding()
  ##   .build()
  ## ```
  IntCodecBuilder(useDelta: false)

proc withDeltaEncoding*(builder: IntCodecBuilder, enabled: bool = true): IntCodecBuilder =
  ## Enable delta encoding (for sorted sequences)
  result = builder
  result.useDelta = enabled

proc build*(builder: IntCodecBuilder): IntCodec =
  ## Build codec from builder
  IntCodec(useDelta: builder.useDelta)

proc init*(_: typedesc[IntCodec], useDelta: bool = false): IntCodec {.inline.} =
  ## Direct construction
  IntCodec(useDelta: useDelta)

# Encoding/Decoding
proc encode*(codec: IntCodec, values: openArray[uint32]): tuple[control: seq[uint8], data: seq[uint8]] =
  ## Encode integers
  ##
  ## Returns (control_bytes, data_bytes) tuple
  ##
  ## Example:
  ## ```nim
  ## let (ctrl, data) = codec.encode([1, 2, 3, 4])
  ## ```
  if codec.useDelta:
    let deltas = deltaEncode(values)
    encodeStreamVByte(deltas)
  else:
    encodeStreamVByte(values)

proc encode*(codec: IntCodec, values: openArray[int]): tuple[control: seq[uint8], data: seq[uint8]] =
  ## Encode signed integers (zigzag encoded)
  let unsigned = zigzagEncodeArray(values.mapIt(it.int32))
  codec.encode(unsigned)

proc decode*(codec: IntCodec, control: openArray[uint8],
             data: openArray[uint8], count: int): seq[uint32] =
  ## Decode integers
  ##
  ## Parameters:
  ## - control: Control byte stream
  ## - data: Data byte stream
  ## - count: Number of integers to decode
  ##
  ## Returns decoded integers
  let decoded = decodeStreamVByte(control, data, count)
  if codec.useDelta:
    deltaDecode(decoded)
  else:
    decoded

proc decodeInt*(codec: IntCodec, control: openArray[uint8],
                data: openArray[uint8], count: int): seq[int32] =
  ## Decode signed integers
  let unsigned = codec.decode(control, data, count)
  zigzagDecodeArray(unsigned)

# Convenience methods
proc compress*(codec: IntCodec, values: openArray[uint32]): seq[byte] =
  ## Compress to single byte stream (combines control + data)
  ##
  ## Example:
  ## ```nim
  ## let compressed = codec.compress([1, 2, 3, 4])
  ## ```
  let (control, data) = codec.encode(values)

  # Format: [control_len: 4 bytes][control bytes][data bytes]
  result = newSeq[byte](4 + control.len + data.len)

  # Write control length (little-endian)
  result[0] = ((control.len shr 0) and 0xFF).byte
  result[1] = ((control.len shr 8) and 0xFF).byte
  result[2] = ((control.len shr 16) and 0xFF).byte
  result[3] = ((control.len shr 24) and 0xFF).byte

  # Write control and data
  for i, b in control:
    result[4 + i] = b
  for i, b in data:
    result[4 + control.len + i] = b

proc decompress*(codec: IntCodec, compressed: openArray[byte], count: int): seq[uint32] =
  ## Decompress from single byte stream
  ##
  ## Parameters:
  ## - compressed: Compressed bytes (from compress())
  ## - count: Number of integers
  if compressed.len < 4:
    raise newException(ValueError, "Invalid compressed data")

  # Read control length
  let controlLen = compressed[0].int or
                   (compressed[1].int shl 8) or
                   (compressed[2].int shl 16) or
                   (compressed[3].int shl 24)

  if compressed.len < 4 + controlLen:
    raise newException(ValueError, "Invalid compressed data")

  # Split into control and data
  let control = compressed[4..<(4 + controlLen)]
  let data = compressed[(4 + controlLen)..^1]

  codec.decode(control, data, count)

# Statistics
proc compressionRatio*(originalSize, compressedSize: int): float64 {.inline.} =
  ## Calculate compression ratio (higher is better)
  originalSize.float64 / compressedSize.float64

proc bitsPerInt*(dataSize, count: int): float64 {.inline.} =
  ## Calculate average bits per integer
  (dataSize.float64 * 8.0) / count.float64

proc `$`*(codec: IntCodec): string =
  "IntCodec(delta=" & $codec.useDelta & ")"

# =============================================================================
# CONVENIENCE CONSTRUCTORS
# =============================================================================

template newIntCodec*(useDelta: bool = false): IntCodec =
  ## Quick constructor
  IntCodec.init(useDelta)

# Helper for delta encoding/decoding
template deltaCodec*(): IntCodec =
  ## Codec with delta encoding enabled
  IntCodec.init(useDelta = true)

# =============================================================================
# EXAMPLE USAGE
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "Arsenal Compression - Unified API Demo"
  echo "======================================="
  echo ""

  # Basic encoding/decoding
  echo "1. Basic Integer Compression"
  echo "---------------------------"

  let codec = IntCodec.init()
  let values = [1'u32, 100, 10_000, 1_000_000]

  let (control, data) = codec.encode(values)
  let decoded = codec.decode(control, data, values.len)

  echo "Original: ", values
  echo "Decoded:  ", decoded
  echo "Match: ", decoded == @values
  echo ""

  echo "Compression:"
  echo "  Control bytes: ", control.len
  echo "  Data bytes: ", data.len
  echo "  Total: ", control.len + data.len, " bytes"
  echo "  Uncompressed: ", values.len * 4, " bytes"
  echo "  Ratio: ", compressionRatio(values.len * 4, control.len + data.len).formatFloat(ffDecimal, 2), "×"
  echo ""

  # Delta encoding for sorted sequences
  echo "2. Delta Encoding (Sorted Sequences)"
  echo "------------------------------------"

  # Generate sorted sequence
  var sorted = newSeq[uint32](1000)
  sorted[0] = 100
  for i in 1..<1000:
    sorted[i] = sorted[i-1] + 1 + rand(10).uint32

  # Without delta
  let codecNoDelta = IntCodec.init(useDelta = false)
  let (ctrl1, data1) = codecNoDelta.encode(sorted)
  let size1 = ctrl1.len + data1.len

  # With delta
  let codecDelta = IntCodec.init(useDelta = true)
  let (ctrl2, data2) = codecDelta.encode(sorted)
  let size2 = ctrl2.len + data2.len

  echo "1000 sorted integers (spacing 1-10):"
  echo "  Without delta: ", size1, " bytes (", bitsPerInt(size1, 1000).formatFloat(ffDecimal, 2), " bits/int)"
  echo "  With delta: ", size2, " bytes (", bitsPerInt(size2, 1000).formatFloat(ffDecimal, 2), " bits/int)"
  echo "  Improvement: ", ((size1 - size2).float64 / size1.float64 * 100).formatFloat(ffDecimal, 1), "%"
  echo ""

  # Verify delta decoding
  let decodedDelta = codecDelta.decode(ctrl2, data2, sorted.len)
  echo "  Delta decode correct: ", decodedDelta == sorted
  echo ""

  # compress/decompress convenience methods
  echo "3. Convenience Methods (compress/decompress)"
  echo "--------------------------------------------"

  let codec3 = IntCodec.init()
  let values3 = [1'u32, 2, 3, 4, 5]

  let compressed = codec3.compress(values3)
  let decompressed = codec3.decompress(compressed, values3.len)

  echo "Original: ", values3
  echo "Compressed size: ", compressed.len, " bytes"
  echo "Decompressed: ", decompressed
  echo "Match: ", decompressed == @values3
  echo ""

  # Performance benchmark
  echo "4. Performance Benchmark"
  echo "-----------------------"

  let numInts = 1_000_000
  var testVals = newSeq[uint32](numInts)

  # Generate small integers (compress well)
  randomize(42)
  for i in 0..<numInts:
    testVals[i] = rand(1000).uint32

  echo "Encoding ", numInts, " small integers (0-999)..."
  let encStart = cpuTime()
  let (ctrlPerf, dataPerf) = codec.encode(testVals)
  let encTime = cpuTime() - encStart

  echo "  Encode time: ", (encTime * 1000).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (numInts.float64 / encTime / 1_000_000).formatFloat(ffDecimal, 2), " M ints/sec"
  echo ""

  let compSize = ctrlPerf.len + dataPerf.len
  let origSize = numInts * 4

  echo "Compression results:"
  echo "  Original: ", (origSize.float64 / 1024 / 1024).formatFloat(ffDecimal, 2), " MB"
  echo "  Compressed: ", (compSize.float64 / 1024 / 1024).formatFloat(ffDecimal, 2), " MB"
  echo "  Ratio: ", compressionRatio(origSize, compSize).formatFloat(ffDecimal, 2), "×"
  echo "  Bits/int: ", bitsPerInt(compSize, numInts).formatFloat(ffDecimal, 2)
  echo ""

  echo "Decoding ", numInts, " integers..."
  let decStart = cpuTime()
  let decodedPerf = codec.decode(ctrlPerf, dataPerf, numInts)
  let decTime = cpuTime() - decStart

  echo "  Decode time: ", (decTime * 1000).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (numInts.float64 / decTime / 1_000_000).formatFloat(ffDecimal, 2), " M ints/sec"
  echo "  Correct: ", decodedPerf == testVals
  echo ""

  # Best/worst case
  echo "5. Best vs Worst Case Compression"
  echo "---------------------------------"

  # Best case: all small integers
  var small = newSeq[uint32](10_000)
  for i in 0..<10_000:
    small[i] = rand(255).uint32

  let (ctrlSmall, dataSmall) = codec.encode(small)
  let sizeSmall = ctrlSmall.len + dataSmall.len

  echo "Best case (10K integers in [0, 255]):"
  echo "  Compressed: ", sizeSmall, " bytes"
  echo "  Original: ", small.len * 4, " bytes"
  echo "  Ratio: ", compressionRatio(small.len * 4, sizeSmall).formatFloat(ffDecimal, 2), "×"
  echo "  Bits/int: ", bitsPerInt(sizeSmall, small.len).formatFloat(ffDecimal, 2)
  echo ""

  # Worst case: all large integers
  var large = newSeq[uint32](10_000)
  for i in 0..<10_000:
    large[i] = 0xFF000000'u32 + rand(0xFFFFFF).uint32

  let (ctrlLarge, dataLarge) = codec.encode(large)
  let sizeLarge = ctrlLarge.len + dataLarge.len

  echo "Worst case (10K integers in [0xFF000000, 0xFFFFFFFF]):"
  echo "  Compressed: ", sizeLarge, " bytes"
  echo "  Original: ", large.len * 4, " bytes"
  echo "  Ratio: ", compressionRatio(large.len * 4, sizeLarge).formatFloat(ffDecimal, 2), "×"
  echo "  Bits/int: ", bitsPerInt(sizeLarge, large.len).formatFloat(ffDecimal, 2)
  echo ""

  echo "All demos completed!"
