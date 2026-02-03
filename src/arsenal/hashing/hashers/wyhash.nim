## wyhash Implementation
## ====================
##
## Pure Nim implementation of wyhash, a very fast non-cryptographic hash function.
## wyhash is designed for speed and passes all SMHasher tests.
##
## Performance: ~18 GB/s on modern hardware (fastest pure hash function)
## Quality: Excellent statistical properties

import ../hasher
export HashSeed, DefaultSeed

type
  WyHash* = object
    ## wyhash hasher type.

  WyHashState* = object
    ## Incremental hashing state for wyhash.
    seed: uint64
    secret: array[4, uint64]  # Secret keys for hashing
    buffer: array[48, byte]   # Internal buffer for incomplete blocks
    bufferSize: int
    totalLen: uint64
    see1: uint64  # Running hash state

const
  # wyhash uses these secret constants
  WY_SECRET_0 = 0x2d358dccaa6c78a5'u64
  WY_SECRET_1 = 0x8bb84b93962eacc9'u64
  WY_SECRET_2 = 0x4b33a62ed433d4a3'u64
  WY_SECRET_3 = 0x4d5a2da7342122e9'u64

  WY_PRIME_0 = 0xa0761d6478bd642f'u64
  WY_PRIME_1 = 0xe7037ed1a0b428db'u64
  WY_PRIME_2 = 0x8ebc6af09c88c6e3'u64
  WY_PRIME_3 = 0x589965cc75374cc3'u64
  WY_PRIME_4 = 0x1d8e4e27c47d124f'u64

# Forward declarations
proc wymum*(a, b: uint64): uint64 {.inline.}

# =============================================================================
# One-shot Hashing
# =============================================================================

proc wyread8(p: ptr byte): uint64 {.inline.} =
  ## Read 8 bytes as uint64 from pointer
  cast[ptr uint64](p)[]

proc wyread4(p: ptr byte): uint64 {.inline.} =
  ## Read 4 bytes as uint64 from pointer
  cast[ptr uint32](p)[].uint64

proc wyread3(p: ptr byte, k: int): uint64 {.inline.} =
  ## Read 1-3 bytes from pointer
  ((p[].uint64 shl 16) or (cast[ptr byte](cast[uint](p) + (k shr 1).uint)[].uint64 shl 8) or cast[ptr byte](cast[uint](p) + (k - 1).uint)[].uint64)

proc wymix(a, b: uint64): uint64 {.inline.} =
  ## Final mixing function
  wymum(a xor WY_SECRET_0, b xor WY_SECRET_1)

proc hash*(hasher: typedesc[WyHash], data: openArray[byte], seed: HashSeed = DefaultSeed): uint64 =
  ## Compute wyhash of data in one pass.
  ##
  ## IMPLEMENTATION:
  ## wyhash algorithm:
  ## 1. Mix seed with secret constants
  ## 2. Process data in 48-byte chunks with wymum (multiply-mix)
  ## 3. Handle remaining bytes (32, 16, 8, 4, 1-3 byte cases)
  ## 4. Final mixing with length

  let len = data.len.uint64
  var see1 = uint64(seed)

  if len == 0:
    return wymix(see1, 0)

  let p = cast[ptr UncheckedArray[byte]](unsafeAddr data[0])

  if len <= 16:
    if len >= 4:
      let a = (wyread4(addr p[0]) shl 32) or wyread4(addr p[len.int - 4])
      let b = (wyread4(addr p[len.int shr 1 - 2]) shl 32) or wyread4(addr p[len.int shr 1 + len.int - 6])
      return wymix(a xor WY_SECRET_0, b xor see1)
    elif len > 0:
      return wymix(wyread3(addr p[0], len.int) xor WY_SECRET_0, see1)
    else:
      return wymix(see1, 0)

  var i = len
  if i > 48:
    var see2 = see1
    while i > 48:
      see1 = wymum(wyread8(addr p[len.int - i.int]) xor WY_SECRET_0, wyread8(addr p[len.int - i.int + 8]) xor see1)
      see2 = wymum(wyread8(addr p[len.int - i.int + 16]) xor WY_SECRET_1, wyread8(addr p[len.int - i.int + 24]) xor see2)
      see1 = wymum(wyread8(addr p[len.int - i.int + 32]) xor WY_SECRET_2, wyread8(addr p[len.int - i.int + 40]) xor see1)
      i -= 48
    see1 = see1 xor see2

  # Process remaining bytes (0-48)
  while i > 16:
    see1 = wymum(wyread8(addr p[len.int - i.int]) xor WY_SECRET_0, wyread8(addr p[len.int - i.int + 8]) xor see1)
    i -= 16

  # Final 0-16 bytes
  let a = wyread8(addr p[len.int - 16])
  let b = wyread8(addr p[len.int - 8])
  return wymix(a xor WY_SECRET_0 xor len, b xor see1)

proc hash*(hasher: typedesc[WyHash], s: string, seed: HashSeed = DefaultSeed): uint64 {.inline.} =
  ## Hash a string.
  result = WyHash.hash(s.toOpenArrayByte(0, s.len - 1), seed)

# =============================================================================
# Incremental Hashing
# =============================================================================

proc init*(hasher: typedesc[WyHash], seed: HashSeed = DefaultSeed): WyHashState =
  ## Initialize incremental hasher.
  let s = uint64(seed)
  result.secret[0] = WY_SECRET_0
  result.secret[1] = WY_SECRET_1
  result.secret[2] = WY_SECRET_2
  result.secret[3] = WY_SECRET_3
  result.seed = s
  result.see1 = s
  result.totalLen = 0
  result.bufferSize = 0

proc update*(state: var WyHashState, data: openArray[byte]) =
  ## Add data to hash computation.
  ## Processes data in 48-byte chunks, buffering remainder.

  state.totalLen += uint64(data.len)

  var dataPos = 0
  let dataLen = data.len

  # If we have buffered data, try to fill buffer to 48 bytes
  if state.bufferSize > 0:
    let bytesToCopy = min(48 - state.bufferSize, dataLen)
    copyMem(addr state.buffer[state.bufferSize], unsafeAddr data[0], bytesToCopy)
    state.bufferSize += bytesToCopy
    dataPos += bytesToCopy

    # Process buffer if it's full (48 bytes)
    if state.bufferSize == 48:
      let p = cast[ptr UncheckedArray[byte]](addr state.buffer[0])
      state.see1 = wymum(wyread8(addr p[0]) xor state.secret[0], wyread8(addr p[8]) xor state.see1)
      let see2 = wymum(wyread8(addr p[16]) xor state.secret[1], wyread8(addr p[24]) xor state.see1)
      state.see1 = wymum(wyread8(addr p[32]) xor state.secret[2], wyread8(addr p[40]) xor state.see1)
      state.see1 = state.see1 xor see2
      state.bufferSize = 0

  # Process remaining data in 48-byte chunks
  while dataPos + 48 <= dataLen:
    let p = cast[ptr UncheckedArray[byte]](unsafeAddr data[dataPos])
    state.see1 = wymum(wyread8(addr p[0]) xor state.secret[0], wyread8(addr p[8]) xor state.see1)
    let see2 = wymum(wyread8(addr p[16]) xor state.secret[1], wyread8(addr p[24]) xor state.see1)
    state.see1 = wymum(wyread8(addr p[32]) xor state.secret[2], wyread8(addr p[40]) xor state.see1)
    state.see1 = state.see1 xor see2
    dataPos += 48

  # Buffer remaining bytes (< 48 bytes)
  if dataPos < dataLen:
    let remainder = dataLen - dataPos
    copyMem(addr state.buffer[0], unsafeAddr data[dataPos], remainder)
    state.bufferSize = remainder

proc update*(state: var WyHashState, s: string) {.inline.} =
  state.update(s.toOpenArrayByte(0, s.len - 1))

proc finish*(state: var WyHashState): uint64 =
  ## Complete hash computation.
  ## Processes remaining buffered data and returns final hash value.

  if state.totalLen == 0:
    return wymix(state.see1, 0)

  # If we have less than 48 bytes total, handle specially
  if state.totalLen <= 16:
    let p = cast[ptr UncheckedArray[byte]](addr state.buffer[0])
    if state.totalLen >= 4:
      let a = (wyread4(addr p[0]) shl 32) or wyread4(addr p[state.totalLen.int - 4])
      let b = (wyread4(addr p[state.totalLen.int shr 1 - 2]) shl 32) or
              wyread4(addr p[state.totalLen.int shr 1 + state.totalLen.int - 6])
      return wymix(a xor WY_SECRET_0, b xor state.seed)
    elif state.totalLen > 0:
      return wymix(wyread3(addr p[0], state.totalLen.int) xor WY_SECRET_0, state.seed)
    else:
      return wymix(state.seed, 0)

  result = state.see1

  # Process remaining buffered bytes
  let p = cast[ptr UncheckedArray[byte]](addr state.buffer[0])
  var i = state.bufferSize

  # Process in 16-byte chunks
  var pos = 0
  while i > 16:
    result = wymum(wyread8(addr p[pos]) xor WY_SECRET_0, wyread8(addr p[pos + 8]) xor result)
    i -= 16
    pos += 16

  # Final 0-16 bytes (always present if totalLen > 16)
  if state.bufferSize >= 16:
    let a = wyread8(addr p[state.bufferSize - 16])
    let b = wyread8(addr p[state.bufferSize - 8])
    return wymix(a xor WY_SECRET_0 xor state.totalLen, b xor result)
  elif state.bufferSize > 0:
    # Less than 16 bytes remaining
    if state.bufferSize >= 4:
      let a = (wyread4(addr p[0]) shl 32) or wyread4(addr p[state.bufferSize - 4])
      let b = (wyread4(addr p[state.bufferSize shr 1 - 2]) shl 32) or
              wyread4(addr p[state.bufferSize shr 1 + state.bufferSize - 6])
      return wymix((a xor WY_SECRET_0) xor state.totalLen, b xor result)
    else:
      return wymix(wyread3(addr p[0], state.bufferSize) xor WY_SECRET_0 xor state.totalLen, result)
  else:
    # No buffered data, return current state
    return wymix(result xor state.totalLen, 0)

proc reset*(state: var WyHashState) =
  ## Reset to initial state.
  state = WyHash.init(HashSeed(state.seed))

# =============================================================================
# Core Operations
# =============================================================================

proc wymum*(a, b: uint64): uint64 {.inline.} =
  ## wyhash's multiply-mix operation.
  ## Combines multiplication with mixing for better diffusion.
  ##
  ## Performs 128-bit multiply and mixes high/low 64 bits.

  # Full 128-bit multiply then mix
  var ha, hb, la, lb: uint64

  # Split into high and low 32 bits
  ha = a shr 32
  la = a and 0xFFFFFFFF'u64
  hb = b shr 32
  lb = b and 0xFFFFFFFF'u64

  # 128-bit multiplication
  let rh = ha * hb
  let rm0 = ha * lb
  let rm1 = hb * la
  let rl = la * lb

  # Combine
  let t = rl + (rm0 shl 32)
  let c = if t < rl: 1'u64 else: 0'u64

  let lo = t + (rm1 shl 32)
  let hi = rh + (rm0 shr 32) + (rm1 shr 32) + c + (if lo < t: 1'u64 else: 0'u64)

  result = hi xor lo

# =============================================================================
# SIMD Acceleration (Future)
# =============================================================================

when defined(wyhash_simd):
  # Future: SIMD versions using AVX2/AVX-512
  # Can process 4-8 uint64 values in parallel
  discard