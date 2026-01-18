## xxHash64 Implementation
## =======================
##
## Pure Nim implementation of xxHash64, a fast non-cryptographic hash function.
## xxHash64 is an industry standard known for excellent speed and distribution.
##
## Performance: ~14 GB/s on modern hardware
## Quality: Excellent avalanche effect and collision resistance

type
  HashSeed* = distinct uint64
    ## Seed for hash functions

const
  DefaultSeed* = HashSeed(0)

type
  XxHash64* = object
    ## xxHash64 hasher type.

  XxHash64State* = object
    ## Incremental hashing state for xxHash64.
    state: array[4, uint64]  # v1, v2, v3, v4
    buffer: array[32, byte]  # 32-byte input buffer
    bufferSize: int          # How many bytes in buffer
    totalLen: uint64         # Total bytes processed
    seed: uint64

const
  XXH_PRIME64_1 = 0x9E3779B185EBCA87'u64
  XXH_PRIME64_2 = 0xC2B2AE3D27D4EB4F'u64
  XXH_PRIME64_3 = 0x165667B19E3779F9'u64
  XXH_PRIME64_4 = 0x85EBCA77C2B2AE63'u64
  XXH_PRIME64_5 = 0x27D4EB2F165667C5'u64

# =============================================================================
# Utility Functions
# =============================================================================

proc avalanche64(h: uint64): uint64 {.inline.} =
  ## Final avalanche mixing for 64-bit hash.
  ## Ensures every input bit affects every output bit.
  result = h
  result = result xor (result shr 33)
  result *= XXH_PRIME64_2
  result = result xor (result shr 29)
  result *= XXH_PRIME64_3
  result = result xor (result shr 32)

proc round64(acc: uint64, input: uint64): uint64 {.inline.} =
  ## One round of xxHash64 processing.
  result = acc + input * XXH_PRIME64_2
  # Rotate left by 31 bits
  result = (result shl 31) or (result shr (64 - 31))
  result *= XXH_PRIME64_1

# =============================================================================
# One-shot Hashing
# =============================================================================

proc hash*(hasher: typedesc[XxHash64], data: openArray[byte], seed: HashSeed = DefaultSeed): uint64 =
  ## Compute xxHash64 hash of data in one pass.
  ## Implements the xxHash64 algorithm with 4 parallel accumulators.

  let s = uint64(seed)
  let len = data.len

  if len >= 32:
    # Initialize accumulators
    var v1 = s + XXH_PRIME64_1 + XXH_PRIME64_2
    var v2 = s + XXH_PRIME64_2
    var v3 = s
    var v4 = s - XXH_PRIME64_1

    # Process 32-byte chunks
    var p = 0
    while p + 32 <= len:
      # Read 4 x uint64 and process
      let input1 = cast[ptr uint64](unsafeAddr data[p])[]
      let input2 = cast[ptr uint64](unsafeAddr data[p + 8])[]
      let input3 = cast[ptr uint64](unsafeAddr data[p + 16])[]
      let input4 = cast[ptr uint64](unsafeAddr data[p + 24])[]

      v1 = round64(v1, input1)
      v2 = round64(v2, input2)
      v3 = round64(v3, input3)
      v4 = round64(v4, input4)

      p += 32

    # Merge accumulators
    result = ((v1 shl 1) or (v1 shr 63)) +
             ((v2 shl 7) or (v2 shr 57)) +
             ((v3 shl 12) or (v3 shr 52)) +
             ((v4 shl 18) or (v4 shr 46))

    # Process remaining data
    while p + 8 <= len:
      let k1 = cast[ptr uint64](unsafeAddr data[p])[]
      result = result xor round64(0, k1)
      result = ((result shl 27) or (result shr 37)) * XXH_PRIME64_1 + XXH_PRIME64_4
      p += 8

    if p + 4 <= len:
      let k1 = cast[ptr uint32](unsafeAddr data[p])[].uint64
      result = result xor (k1 * XXH_PRIME64_1)
      result = ((result shl 23) or (result shr 41)) * XXH_PRIME64_2 + XXH_PRIME64_3
      p += 4

    while p < len:
      result = result xor (data[p].uint64 * XXH_PRIME64_5)
      result = ((result shl 11) or (result shr 53)) * XXH_PRIME64_1
      p += 1
  else:
    # Short input
    result = s + XXH_PRIME64_5
    var p = 0
    while p + 8 <= len:
      let k1 = cast[ptr uint64](unsafeAddr data[p])[]
      result = result xor round64(0, k1)
      result = ((result shl 27) or (result shr 37)) * XXH_PRIME64_1 + XXH_PRIME64_4
      p += 8

    if p + 4 <= len:
      let k1 = cast[ptr uint32](unsafeAddr data[p])[].uint64
      result = result xor (k1 * XXH_PRIME64_1)
      result = ((result shl 23) or (result shr 41)) * XXH_PRIME64_2 + XXH_PRIME64_3
      p += 4

    while p < len:
      result = result xor (data[p].uint64 * XXH_PRIME64_5)
      result = ((result shl 11) or (result shr 53)) * XXH_PRIME64_1
      p += 1

  # Add length and final avalanche
  result = result + len.uint64
  result = avalanche64(result)

proc hash*(hasher: typedesc[XxHash64], s: string, seed: HashSeed = DefaultSeed): uint64 {.inline.} =
  ## Hash a string.
  result = XxHash64.hash(s.toOpenArrayByte(0, s.len - 1), seed)

# =============================================================================
# Incremental Hashing
# =============================================================================

proc init*(hasher: typedesc[XxHash64], seed: HashSeed = DefaultSeed): XxHash64State =
  ## Initialize incremental hasher with seed.
  ## Initialize the four 64-bit accumulators.
  let s = uint64(seed)
  result.state[0] = s + XXH_PRIME64_1 + XXH_PRIME64_2
  result.state[1] = s + XXH_PRIME64_2
  result.state[2] = s
  result.state[3] = s - XXH_PRIME64_1
  result.seed = s
  result.bufferSize = 0
  result.totalLen = 0

proc update*(state: var XxHash64State, data: openArray[byte]) =
  ## Add data to the hash computation.
  ##
  ## IMPLEMENTATION:
  ## 1. Fill internal buffer to 32 bytes
  ## 2. Process full 32-byte chunks
  ## 3. Keep remainder in buffer

  state.totalLen += uint64(data.len)

  var dataPos = 0
  let dataLen = data.len

  # If we have buffered data, try to fill buffer to 32 bytes
  if state.bufferSize > 0:
    let bytesToCopy = min(32 - state.bufferSize, dataLen)
    copyMem(addr state.buffer[state.bufferSize], unsafeAddr data[0], bytesToCopy)
    state.bufferSize += bytesToCopy
    dataPos += bytesToCopy

    # Process buffer if it's full
    if state.bufferSize == 32:
      let input1 = cast[ptr uint64](unsafeAddr state.buffer[0])[]
      let input2 = cast[ptr uint64](unsafeAddr state.buffer[8])[]
      let input3 = cast[ptr uint64](unsafeAddr state.buffer[16])[]
      let input4 = cast[ptr uint64](unsafeAddr state.buffer[24])[]

      state.state[0] = round64(state.state[0], input1)
      state.state[1] = round64(state.state[1], input2)
      state.state[2] = round64(state.state[2], input3)
      state.state[3] = round64(state.state[3], input4)

      state.bufferSize = 0

  # Process remaining data in 32-byte chunks
  while dataPos + 32 <= dataLen:
    let input1 = cast[ptr uint64](unsafeAddr data[dataPos])[]
    let input2 = cast[ptr uint64](unsafeAddr data[dataPos + 8])[]
    let input3 = cast[ptr uint64](unsafeAddr data[dataPos + 16])[]
    let input4 = cast[ptr uint64](unsafeAddr data[dataPos + 24])[]

    state.state[0] = round64(state.state[0], input1)
    state.state[1] = round64(state.state[1], input2)
    state.state[2] = round64(state.state[2], input3)
    state.state[3] = round64(state.state[3], input4)

    dataPos += 32

  # Buffer remaining bytes (< 32 bytes)
  if dataPos < dataLen:
    let remainder = dataLen - dataPos
    copyMem(addr state.buffer[0], unsafeAddr data[dataPos], remainder)
    state.bufferSize = remainder

proc update*(state: var XxHash64State, s: string) {.inline.} =
  ## Add string to the hash computation.
  state.update(s.toOpenArrayByte(0, s.len - 1))

proc finish*(state: var XxHash64State): uint64 =
  ## Complete the hash computation and return the result.
  ## Processes any remaining buffered data and mixes accumulators.

  if state.totalLen >= 32:
    # Merge the four accumulators
    result = ((state.state[0] shl 1) or (state.state[0] shr 63)) +
             ((state.state[1] shl 7) or (state.state[1] shr 57)) +
             ((state.state[2] shl 12) or (state.state[2] shr 52)) +
             ((state.state[3] shl 18) or (state.state[3] shr 46))
  else:
    # Short input - use seed + PRIME5
    result = state.seed + XXH_PRIME64_5

  # Add total length
  result += state.totalLen

  # Process remaining buffered bytes
  var p = 0
  while p + 8 <= state.bufferSize:
    let k1 = cast[ptr uint64](unsafeAddr state.buffer[p])[]
    result = result xor round64(0, k1)
    result = ((result shl 27) or (result shr 37)) * XXH_PRIME64_1 + XXH_PRIME64_4
    p += 8

  if p + 4 <= state.bufferSize:
    let k1 = cast[ptr uint32](unsafeAddr state.buffer[p])[].uint64
    result = result xor (k1 * XXH_PRIME64_1)
    result = ((result shl 23) or (result shr 41)) * XXH_PRIME64_2 + XXH_PRIME64_3
    p += 4

  while p < state.bufferSize:
    result = result xor (state.buffer[p].uint64 * XXH_PRIME64_5)
    result = ((result shl 11) or (result shr 53)) * XXH_PRIME64_1
    p += 1

  # Final avalanche mixing
  result = avalanche64(result)

proc reset*(state: var XxHash64State) =
  ## Reset the hasher to initial state.
  ##
  ## IMPLEMENTATION:
  ## Reinitialize state as in init().

  let s = state.seed
  state = XxHash64.init(HashSeed(s))

# =============================================================================
# SIMD Acceleration (Future)
# =============================================================================

when defined(xxhash64_simd):
  # Future: SSE2/AVX2 versions for 2x-4x speedup
  # Process multiple lanes in parallel
  discard