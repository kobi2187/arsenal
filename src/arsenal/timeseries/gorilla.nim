## Gorilla Time Series Compression
## ================================
##
## Facebook's Gorilla compression for time series data.
## Achieves ~12x compression (16 bytes -> 1.37 bytes average).
##
## Paper: "Gorilla: A Fast, Scalable, In-Memory Time Series Database"
##        https://www.vldb.org/pvldb/vol8/p1816-teller.pdf
##
## Two key techniques:
## 1. Delta-of-Delta for timestamps (96% compress to 1 bit)
## 2. XOR encoding for float values (51% compress to 1 bit)
##
## Typical compression results:
## - 96% timestamps: 1 bit (regular intervals)
## - 51% values: 1 bit (identical to previous)
## - 30% values: ~26 bits (similar values)
## - 19% values: ~37 bits (different values)

import std/[bitops, math]

type
  BitBuffer* = object
    ## Bit-level buffer for reading/writing
    data: seq[uint8]
    bitPos: int           # Current bit position for writing
    readBitPos: int       # Current bit position for reading

  GorillaEncoder* = object
    ## Encodes time series data points using Gorilla compression.
    ##
    ## Usage:
    ##   var enc = newGorillaEncoder(blockStartTime)
    ##   enc.encode(timestamp1, value1)
    ##   enc.encode(timestamp2, value2)
    ##   let compressed = enc.finish()
    buffer: BitBuffer
    # Timestamp state
    prevTimestamp: int64
    prevDelta: int64
    firstTimestamp: bool
    # Value state
    prevValue: uint64       # Previous value as bits
    prevLeadingZeros: int
    prevTrailingZeros: int
    firstValue: bool

  GorillaDecoder* = object
    ## Decodes Gorilla-compressed time series data.
    buffer: BitBuffer
    blockStart: int64
    prevTimestamp: int64
    prevDelta: int64
    prevValue: uint64
    prevLeadingZeros: int
    prevTrailingZeros: int
    firstPoint: bool

# =============================================================================
# BitBuffer Operations
# =============================================================================

proc newBitBuffer*(capacity: int = 256): BitBuffer =
  BitBuffer(
    data: newSeq[uint8](capacity),
    bitPos: 0,
    readBitPos: 0
  )

proc writeBit*(buf: var BitBuffer, bit: bool) =
  ## Write a single bit
  let byteIdx = buf.bitPos div 8
  let bitIdx = 7 - (buf.bitPos mod 8)

  if byteIdx >= buf.data.len:
    buf.data.setLen(buf.data.len * 2)

  if bit:
    buf.data[byteIdx] = buf.data[byteIdx] or (1'u8 shl bitIdx)
  else:
    buf.data[byteIdx] = buf.data[byteIdx] and not (1'u8 shl bitIdx)

  inc buf.bitPos

proc writeBits*(buf: var BitBuffer, value: uint64, numBits: int) =
  ## Write multiple bits (MSB first)
  for i in countdown(numBits - 1, 0):
    buf.writeBit(((value shr i) and 1) == 1)

proc readBit*(buf: var BitBuffer): bool =
  ## Read a single bit
  let byteIdx = buf.readBitPos div 8
  let bitIdx = 7 - (buf.readBitPos mod 8)
  inc buf.readBitPos
  result = ((buf.data[byteIdx] shr bitIdx) and 1) == 1

proc readBits*(buf: var BitBuffer, numBits: int): uint64 =
  ## Read multiple bits (MSB first)
  result = 0
  for i in 0 ..< numBits:
    result = (result shl 1) or (if buf.readBit(): 1'u64 else: 0'u64)

proc getData*(buf: BitBuffer): seq[uint8] =
  ## Get the buffer data (trimmed to actual size)
  let numBytes = (buf.bitPos + 7) div 8
  result = buf.data[0 ..< numBytes]

# =============================================================================
# Timestamp Encoding (Delta-of-Delta)
# =============================================================================
##
## Timestamp Compression Algorithm:
## ================================
##
## Based on observation that most timestamps arrive at fixed intervals.
## Uses delta-of-delta encoding:
##
## D = (t[n] - t[n-1]) - (t[n-1] - t[n-2])
##
## Encoding scheme:
## ----------------
## Case 1: D = 0           -> write '0'                (1 bit)
## Case 2: D in [-63,64]   -> write '10' + D (7 bits)  (9 bits)
## Case 3: D in [-255,256] -> write '110' + D (9 bits) (12 bits)
## Case 4: D in [-2047,2048] -> write '1110' + D (12 bits) (16 bits)
## Case 5: otherwise       -> write '1111' + D (32 bits) (36 bits)
##
## Results: ~96% of timestamps compress to 1 bit

proc encodeTimestamp(enc: var GorillaEncoder, timestamp: int64) =
  ## Encode a timestamp using delta-of-delta
  if enc.firstTimestamp:
    # First timestamp: store as delta from block start (14 bits)
    # Allows 1-second granularity in 2-hour window
    enc.buffer.writeBits(uint64(timestamp), 64)
    enc.prevTimestamp = timestamp
    enc.prevDelta = 0
    enc.firstTimestamp = false
    return

  let delta = timestamp - enc.prevTimestamp
  let deltaOfDelta = delta - enc.prevDelta

  if deltaOfDelta == 0:
    # Case 1: Same interval as before - most common (96%)
    enc.buffer.writeBit(false)  # '0'

  elif deltaOfDelta >= -63 and deltaOfDelta <= 64:
    # Case 2: Small change, 7 bits
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(false)  # '0'
    # Use ZigZag encoding for signed -> unsigned
    let zigzag = if deltaOfDelta >= 0:
      uint64(deltaOfDelta * 2)
    else:
      uint64(-deltaOfDelta * 2 - 1)
    enc.buffer.writeBits(zigzag, 7)

  elif deltaOfDelta >= -255 and deltaOfDelta <= 256:
    # Case 3: Medium change, 9 bits
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(false)  # '0'
    let zigzag = if deltaOfDelta >= 0:
      uint64(deltaOfDelta * 2)
    else:
      uint64(-deltaOfDelta * 2 - 1)
    enc.buffer.writeBits(zigzag, 9)

  elif deltaOfDelta >= -2047 and deltaOfDelta <= 2048:
    # Case 4: Larger change, 12 bits
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(false)  # '0'
    let zigzag = if deltaOfDelta >= 0:
      uint64(deltaOfDelta * 2)
    else:
      uint64(-deltaOfDelta * 2 - 1)
    enc.buffer.writeBits(zigzag, 12)

  else:
    # Case 5: Full 32-bit delta
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBit(true)   # '1'
    enc.buffer.writeBits(cast[uint64](deltaOfDelta), 32)

  enc.prevDelta = delta
  enc.prevTimestamp = timestamp

# =============================================================================
# Value Encoding (XOR)
# =============================================================================
##
## Float Value Compression Algorithm:
## ===================================
##
## Key insight: Consecutive float values are often similar.
## XOR of similar floats has many leading/trailing zeros.
##
## Algorithm:
## 1. XOR current value with previous value
## 2. If XOR = 0 (identical values) -> write '0'          (1 bit)
## 3. If meaningful bits fit in previous window -> write '10' + bits
## 4. Otherwise -> write '11' + leading zeros (5) + length (6) + bits
##
## "Meaningful bits" = bits between first and last 1 in XOR result
##
## Results:
## - 51% values: 1 bit (identical)
## - 30% values: ~26 bits (similar, reuse window)
## - 19% values: ~37 bits (different, new window)

proc encodeValue(enc: var GorillaEncoder, value: float64) =
  ## Encode a float64 value using XOR compression
  let valueBits = cast[uint64](value)

  if enc.firstValue:
    # First value: store uncompressed
    enc.buffer.writeBits(valueBits, 64)
    enc.prevValue = valueBits
    enc.prevLeadingZeros = 64
    enc.prevTrailingZeros = 64
    enc.firstValue = false
    return

  let xored = valueBits xor enc.prevValue

  if xored == 0:
    # Case 1: Identical value (51% of cases)
    enc.buffer.writeBit(false)  # '0'

  else:
    enc.buffer.writeBit(true)   # '1'

    # Count leading and trailing zeros
    let leadingZeros = countLeadingZeroBits(xored)
    let trailingZeros = countTrailingZeroBits(xored)
    let meaningfulBits = 64 - leadingZeros - trailingZeros

    # Check if meaningful bits fit within previous window
    if leadingZeros >= enc.prevLeadingZeros and
       trailingZeros >= enc.prevTrailingZeros:
      # Case 2: Reuse previous window (30% of cases)
      enc.buffer.writeBit(false)  # '0'
      # Extract and write only the meaningful bits using previous window
      let prevMeaningfulBits = 64 - enc.prevLeadingZeros - enc.prevTrailingZeros
      let shifted = xored shr enc.prevTrailingZeros
      enc.buffer.writeBits(shifted, prevMeaningfulBits)

    else:
      # Case 3: New window needed (19% of cases)
      enc.buffer.writeBit(true)   # '1'
      # Write leading zeros (5 bits, max 31)
      enc.buffer.writeBits(uint64(min(leadingZeros, 31)), 5)
      # Write meaningful bit count (6 bits, 1-64 stored as 0-63)
      enc.buffer.writeBits(uint64(meaningfulBits - 1), 6)
      # Write the meaningful bits
      let shifted = xored shr trailingZeros
      enc.buffer.writeBits(shifted, meaningfulBits)

      enc.prevLeadingZeros = leadingZeros
      enc.prevTrailingZeros = trailingZeros

  enc.prevValue = valueBits

# =============================================================================
# Public API
# =============================================================================

proc newGorillaEncoder*(blockStartTime: int64 = 0): GorillaEncoder =
  ## Create a new Gorilla encoder for a time series block.
  ##
  ## blockStartTime: The starting timestamp for this block.
  ##                 Typically aligned to 2-hour boundaries.
  result = GorillaEncoder(
    buffer: newBitBuffer(1024),
    prevTimestamp: blockStartTime,
    prevDelta: 0,
    firstTimestamp: true,
    prevValue: 0,
    prevLeadingZeros: 0,
    prevTrailingZeros: 0,
    firstValue: true
  )

proc encode*(enc: var GorillaEncoder, timestamp: int64, value: float64) =
  ## Encode a data point (timestamp, value pair).
  ##
  ## Timestamps should be monotonically increasing.
  ## For best compression, use regular intervals (e.g., every 60 seconds).
  enc.encodeTimestamp(timestamp)
  enc.encodeValue(value)

proc finish*(enc: GorillaEncoder): seq[uint8] =
  ## Finish encoding and return compressed data.
  enc.buffer.getData()

proc newGorillaDecoder*(data: seq[uint8], blockStartTime: int64 = 0): GorillaDecoder =
  ## Create a decoder for Gorilla-compressed data.
  result = GorillaDecoder(
    buffer: BitBuffer(data: data, bitPos: data.len * 8, readBitPos: 0),
    blockStart: blockStartTime,
    prevTimestamp: blockStartTime,
    prevDelta: 0,
    prevValue: 0,
    prevLeadingZeros: 0,
    prevTrailingZeros: 0,
    firstPoint: true
  )

proc decodeTimestamp(dec: var GorillaDecoder): int64 =
  ## Decode next timestamp
  if dec.firstPoint:
    dec.prevTimestamp = int64(dec.buffer.readBits(64))
    return dec.prevTimestamp

  # Read control bits to determine encoding
  if not dec.buffer.readBit():
    # '0' - same delta as before
    dec.prevTimestamp += dec.prevDelta
    return dec.prevTimestamp

  # Determine which case based on prefix
  var deltaOfDelta: int64

  if not dec.buffer.readBit():
    # '10' - 7 bit delta-of-delta
    let zigzag = dec.buffer.readBits(7)
    deltaOfDelta = if (zigzag and 1) == 0:
      int64(zigzag div 2)
    else:
      -int64((zigzag + 1) div 2)

  elif not dec.buffer.readBit():
    # '110' - 9 bit
    let zigzag = dec.buffer.readBits(9)
    deltaOfDelta = if (zigzag and 1) == 0:
      int64(zigzag div 2)
    else:
      -int64((zigzag + 1) div 2)

  elif not dec.buffer.readBit():
    # '1110' - 12 bit
    let zigzag = dec.buffer.readBits(12)
    deltaOfDelta = if (zigzag and 1) == 0:
      int64(zigzag div 2)
    else:
      -int64((zigzag + 1) div 2)

  else:
    # '1111' - 32 bit
    deltaOfDelta = cast[int64](dec.buffer.readBits(32))

  dec.prevDelta += deltaOfDelta
  dec.prevTimestamp += dec.prevDelta
  result = dec.prevTimestamp

proc decodeValue(dec: var GorillaDecoder): float64 =
  ## Decode next value
  if dec.firstPoint:
    dec.prevValue = dec.buffer.readBits(64)
    dec.firstPoint = false
    return cast[float64](dec.prevValue)

  if not dec.buffer.readBit():
    # '0' - same value
    return cast[float64](dec.prevValue)

  var xored: uint64

  if not dec.buffer.readBit():
    # '10' - reuse previous window
    let meaningfulBits = 64 - dec.prevLeadingZeros - dec.prevTrailingZeros
    xored = dec.buffer.readBits(meaningfulBits) shl dec.prevTrailingZeros

  else:
    # '11' - new window
    let leadingZeros = int(dec.buffer.readBits(5))
    let meaningfulBits = int(dec.buffer.readBits(6)) + 1
    let trailingZeros = 64 - leadingZeros - meaningfulBits

    xored = dec.buffer.readBits(meaningfulBits) shl trailingZeros

    dec.prevLeadingZeros = leadingZeros
    dec.prevTrailingZeros = trailingZeros

  dec.prevValue = dec.prevValue xor xored
  result = cast[float64](dec.prevValue)

proc decode*(dec: var GorillaDecoder): (int64, float64) =
  ## Decode next data point.
  ## Returns (timestamp, value) tuple.
  let ts = dec.decodeTimestamp()
  let val = dec.decodeValue()
  result = (ts, val)

proc decodeAll*(data: seq[uint8], numPoints: int): seq[(int64, float64)] =
  ## Decode all data points from compressed data.
  ##
  ## numPoints: Number of data points to decode (must be known).
  result = newSeq[(int64, float64)](numPoints)
  var dec = newGorillaDecoder(data)
  for i in 0 ..< numPoints:
    result[i] = dec.decode()

# =============================================================================
# Compression Statistics
# =============================================================================

proc compressionRatio*(originalBytes, compressedBytes: int): float =
  ## Calculate compression ratio
  if compressedBytes == 0: return 0.0
  float(originalBytes) / float(compressedBytes)

proc bitsPerPoint*(compressedBytes, numPoints: int): float =
  ## Calculate average bits per data point
  if numPoints == 0: return 0.0
  float(compressedBytes * 8) / float(numPoints)
