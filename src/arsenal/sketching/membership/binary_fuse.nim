## Binary Fuse Filter
## ==================
##
## A probabilistic filter for approximate set membership testing.
## Improves on XOR filters with 13% overhead vs theoretical minimum.
##
## Paper: "Binary Fuse Filters: Fast and Smaller Than Xor Filters"
##        https://arxiv.org/abs/2201.01174
##
## Key advantages over XOR filter:
## - 13% space overhead (XOR: 23%, Bloom: 44%)
## - 2x faster construction
## - Same query speed (~3 memory accesses)
##
## Algorithm Overview:
## ===================
## 1. Three hash positions are computed for each key: h0, h1, h2
## 2. Fingerprints stored such that: F[h0] XOR F[h1] XOR F[h2] XOR fingerprint(key) = 0
## 3. Query: compute XOR of 3 positions + fingerprint, check if zero
##
## Construction uses "fuse" technique:
## - Keys are distributed across segments
## - Peeling algorithm removes keys that can be uniquely identified
## - Fingerprints assigned in reverse order to satisfy XOR constraints

import std/[hashes, math]

type
  BinaryFuse8* = object
    ## 8-bit fingerprints, ~0.4% false positive rate (1/256)
    seed: uint64
    segmentLength: uint32
    segmentLengthMask: uint32
    segmentCount: uint32
    segmentCountLength: uint32  # segmentCount * segmentLength
    arrayLength: uint32
    fingerprints: seq[uint8]

  BinaryFuse16* = object
    ## 16-bit fingerprints, ~0.0015% false positive rate (1/65536)
    seed: uint64
    segmentLength: uint32
    segmentLengthMask: uint32
    segmentCount: uint32
    segmentCountLength: uint32
    arrayLength: uint32
    fingerprints: seq[uint16]

  BinaryHashes = object
    h0, h1, h2: uint32

# =============================================================================
# Hash Functions
# =============================================================================

proc mix(h: uint64): uint64 {.inline.} =
  ## MurmurHash3 64-bit finalizer
  var x = h
  x = x xor (x shr 33)
  x = x * 0xff51afd7ed558ccd'u64
  x = x xor (x shr 33)
  x = x * 0xc4ceb9fe1a85ec53'u64
  x = x xor (x shr 33)
  result = x

proc mixSplit(key, seed: uint64): uint64 {.inline.} =
  ## Hash key with seed
  mix(key + seed)

proc mulhi(a, b: uint64): uint64 {.inline.} =
  ## High 64 bits of 128-bit product
  # TODO: Use compiler intrinsic when available
  let
    aLo = a and 0xFFFFFFFF'u64
    aHi = a shr 32
    bLo = b and 0xFFFFFFFF'u64
    bHi = b shr 32
    axbHi = aHi * bHi
    axbMid = aHi * bLo
    bxaMid = bHi * aLo
    axbLo = aLo * bLo
  var carry = ((axbMid and 0xFFFFFFFF'u64) + (bxaMid and 0xFFFFFFFF'u64) + (axbLo shr 32)) shr 32
  result = axbHi + (axbMid shr 32) + (bxaMid shr 32) + carry

proc fingerprint8(hash: uint64): uint8 {.inline.} =
  ## Extract 8-bit fingerprint from hash
  uint8(hash xor (hash shr 32))

proc fingerprint16(hash: uint64): uint16 {.inline.} =
  ## Extract 16-bit fingerprint from hash
  uint16(hash xor (hash shr 32))

proc computeHashes(hash: uint64, filter: BinaryFuse8): BinaryHashes {.inline.} =
  ## Compute three hash positions for a key
  ##
  ## Layout: [Segment 0][Segment 1][Segment 2]
  ##         |-- h0 ---|-- h1 ---|-- h2 ---|
  ##
  ## h0 is in segment 0, h1 in segment 1, h2 in segment 2
  ## This ensures the three positions are always distinct
  let hi = mulhi(hash, filter.segmentCountLength)
  result.h0 = uint32(hi)
  result.h1 = result.h0 + filter.segmentLength
  result.h2 = result.h1 + filter.segmentLength
  # XOR with hash bits to distribute within segment
  result.h1 = result.h1 xor (uint32(hash shr 18) and filter.segmentLengthMask)
  result.h2 = result.h2 xor (uint32(hash) and filter.segmentLengthMask)

# =============================================================================
# Query Operations
# =============================================================================

proc contains*(filter: BinaryFuse8, key: uint64): bool {.inline.} =
  ## Test if key might be in the set.
  ## Returns true if possibly present, false if definitely absent.
  ##
  ## Algorithm:
  ## 1. Hash the key with the filter's seed
  ## 2. Extract 8-bit fingerprint from hash
  ## 3. Compute three positions h0, h1, h2
  ## 4. XOR fingerprints at all three positions with computed fingerprint
  ## 5. If result is 0, key might be present
  ##
  ## False positive rate: ~1/256 = 0.39%
  let hash = mixSplit(key, filter.seed)
  let f = fingerprint8(hash)
  let hashes = computeHashes(hash, filter)
  let xored = f xor filter.fingerprints[hashes.h0] xor
              filter.fingerprints[hashes.h1] xor
              filter.fingerprints[hashes.h2]
  result = xored == 0

proc contains*(filter: BinaryFuse8, key: string): bool {.inline.} =
  ## String variant - hashes string to uint64 first
  filter.contains(uint64(hash(key)))

# =============================================================================
# Construction
# =============================================================================

proc calculateSegmentLength(size: int, arity: int = 3): uint32 =
  ## Calculate optimal segment length based on set size
  ##
  ## Formula: 2^floor(log(size) / log(3.33) + 2.25)
  ## This balances memory usage vs construction success rate
  if size == 0:
    return 4
  let exponent = floor(ln(float(size)) / ln(3.33) + 2.25)
  result = uint32(1) shl int(exponent)
  if result < 4:
    result = 4

proc calculateSizeFactor(size: int): float =
  ## Calculate size factor for array allocation
  ##
  ## Larger sets can use tighter packing
  ## Formula: max(1.125, 0.875 + 0.25 * log(1e6) / log(size))
  max(1.125, 0.875 + 0.25 * ln(1e6) / ln(float(size)))

proc construct*(keys: openArray[uint64]): BinaryFuse8 =
  ## Construct a Binary Fuse Filter from a set of 64-bit keys.
  ##
  ## Algorithm (Fuse Construction):
  ## ==============================
  ##
  ## Phase 1: Allocate and initialize
  ## - Calculate segment length based on set size
  ## - Allocate fingerprint array with size factor overhead
  ## - Initialize constraint tracking arrays
  ##
  ## Phase 2: Build constraint graph (with random seed)
  ## - For each key, compute h0, h1, h2 positions
  ## - Track count and XOR of keys at each position
  ##
  ## Phase 3: Peeling
  ## - Find positions with exactly 1 key (singletons)
  ## - Remove key from constraint graph, add to stack
  ## - Repeat until all keys processed or stuck
  ## - If stuck, retry with different seed (up to 100 times)
  ##
  ## Phase 4: Assign fingerprints (reverse order)
  ## - Pop keys from stack
  ## - Assign fingerprint to satisfy: F[h0] XOR F[h1] XOR F[h2] = fingerprint(key)
  ##
  ## Time: O(n) expected
  ## Space: ~24 bytes per key during construction, 9.04 bits per key final

  if keys.len == 0:
    return BinaryFuse8(
      segmentLength: 4,
      segmentLengthMask: 3,
      segmentCount: 1,
      fingerprints: newSeq[uint8](4)
    )

  let size = keys.len
  result.segmentLength = calculateSegmentLength(size)
  result.segmentLengthMask = result.segmentLength - 1

  let sizeFactor = calculateSizeFactor(size)
  let capacity = uint32(float(size) * sizeFactor)
  result.segmentCount = (capacity + result.segmentLength - 1) div result.segmentLength
  if result.segmentCount < 3:
    result.segmentCount = 3

  result.segmentCountLength = result.segmentCount * result.segmentLength
  result.arrayLength = result.segmentCountLength + result.segmentLength * 2
  result.fingerprints = newSeq[uint8](result.arrayLength)

  # Construction arrays
  var
    count = newSeq[uint8](result.arrayLength)      # Keys mapping to each position
    xorAcc = newSeq[uint64](result.arrayLength)    # XOR of all keys at position
    stack = newSeq[tuple[idx: uint32, hash: uint64]](size)
    stackPos = 0

  const maxIterations = 100
  var iteration = 0

  while iteration < maxIterations:
    inc iteration
    result.seed = uint64(iteration) * 0x9e3779b97f4a7c15'u64

    # Reset construction state
    for i in 0 ..< result.arrayLength.int:
      count[i] = 0
      xorAcc[i] = 0
    stackPos = 0

    # Phase 2: Build constraint graph
    for key in keys:
      let hash = mixSplit(key, result.seed)
      let hashes = computeHashes(hash, result)

      inc count[hashes.h0]
      inc count[hashes.h1]
      inc count[hashes.h2]
      xorAcc[hashes.h0] = xorAcc[hashes.h0] xor hash
      xorAcc[hashes.h1] = xorAcc[hashes.h1] xor hash
      xorAcc[hashes.h2] = xorAcc[hashes.h2] xor hash

    # Phase 3: Peeling - find singletons and remove
    var queue = newSeq[uint32]()
    for i in 0'u32 ..< result.arrayLength:
      if count[i] == 1:
        queue.add(i)

    while queue.len > 0:
      let idx = queue.pop()
      if count[idx] != 1:
        continue

      let hash = xorAcc[idx]
      let hashes = computeHashes(hash, result)

      stack[stackPos] = (idx, hash)
      inc stackPos

      # Remove from all three positions
      for pos in [hashes.h0, hashes.h1, hashes.h2]:
        dec count[pos]
        xorAcc[pos] = xorAcc[pos] xor hash
        if count[pos] == 1 and pos != idx:
          queue.add(pos)

    # Check if all keys were peeled
    if stackPos == size:
      break

  if stackPos != size:
    raise newException(ValueError, "Binary Fuse construction failed - try larger size factor")

  # Phase 4: Assign fingerprints in reverse order
  for i in countdown(stackPos - 1, 0):
    let (idx, hash) = stack[i]
    let hashes = computeHashes(hash, result)
    let fp = fingerprint8(hash)

    # Determine which position this key was peeled from
    # and compute fingerprint to satisfy XOR constraint
    if idx == hashes.h0:
      result.fingerprints[hashes.h0] = fp xor
        result.fingerprints[hashes.h1] xor result.fingerprints[hashes.h2]
    elif idx == hashes.h1:
      result.fingerprints[hashes.h1] = fp xor
        result.fingerprints[hashes.h0] xor result.fingerprints[hashes.h2]
    else:
      result.fingerprints[hashes.h2] = fp xor
        result.fingerprints[hashes.h0] xor result.fingerprints[hashes.h1]

# =============================================================================
# Utility
# =============================================================================

proc sizeInBytes*(filter: BinaryFuse8): int =
  ## Return memory usage in bytes
  filter.fingerprints.len + sizeof(filter)

proc bitsPerEntry*(filter: BinaryFuse8, numKeys: int): float =
  ## Return bits per entry (should be ~9.04 for 8-bit filter)
  if numKeys == 0: return 0.0
  float(filter.fingerprints.len * 8) / float(numKeys)

# =============================================================================
# 16-bit variant (lower false positive rate)
# =============================================================================

proc computeHashes16(hash: uint64, filter: BinaryFuse16): BinaryHashes {.inline.} =
  ## Compute three hash positions for a 16-bit filter key
  let hi = mulhi(hash, filter.segmentCountLength)
  result.h0 = uint32(hi)
  result.h1 = result.h0 + filter.segmentLength
  result.h2 = result.h1 + filter.segmentLength
  result.h1 = result.h1 xor (uint32(hash shr 18) and filter.segmentLengthMask)
  result.h2 = result.h2 xor (uint32(hash) and filter.segmentLengthMask)

proc contains*(filter: BinaryFuse16, key: uint64): bool {.inline.} =
  ## Test if key might be in the set (16-bit variant).
  ## False positive rate: ~1/65536 = 0.0015%
  let hash = mixSplit(key, filter.seed)
  let f = fingerprint16(hash)
  let hashes = computeHashes16(hash, filter)
  let xored = f xor filter.fingerprints[hashes.h0] xor
              filter.fingerprints[hashes.h1] xor
              filter.fingerprints[hashes.h2]
  result = xored == 0

proc contains*(filter: BinaryFuse16, key: string): bool {.inline.} =
  ## String variant for 16-bit filter
  filter.contains(uint64(hash(key)))

proc construct16*(keys: openArray[uint64]): BinaryFuse16 =
  ## Construct 16-bit Binary Fuse Filter.
  ## Same algorithm as 8-bit but with uint16 fingerprints.
  ## False positive rate: ~1/65536 = 0.0015%

  if keys.len == 0:
    return BinaryFuse16(
      segmentLength: 4,
      segmentLengthMask: 3,
      segmentCount: 1,
      fingerprints: newSeq[uint16](4)
    )

  let size = keys.len
  result.segmentLength = calculateSegmentLength(size)
  result.segmentLengthMask = result.segmentLength - 1

  let sizeFactor = calculateSizeFactor(size)
  let capacity = uint32(float(size) * sizeFactor)
  result.segmentCount = (capacity + result.segmentLength - 1) div result.segmentLength
  if result.segmentCount < 3:
    result.segmentCount = 3

  result.segmentCountLength = result.segmentCount * result.segmentLength
  result.arrayLength = result.segmentCountLength + result.segmentLength * 2
  result.fingerprints = newSeq[uint16](result.arrayLength)

  # Construction arrays
  var
    count = newSeq[uint8](result.arrayLength)
    xorAcc = newSeq[uint64](result.arrayLength)
    stack = newSeq[tuple[idx: uint32, hash: uint64]](size)
    stackPos = 0

  const maxIterations = 100
  var iteration = 0

  while iteration < maxIterations:
    inc iteration
    result.seed = uint64(iteration) * 0x9e3779b97f4a7c15'u64

    # Reset construction state
    for i in 0 ..< result.arrayLength.int:
      count[i] = 0
      xorAcc[i] = 0
    stackPos = 0

    # Phase 2: Build constraint graph
    for key in keys:
      let hash = mixSplit(key, result.seed)
      let hashes = computeHashes16(hash, result)

      inc count[hashes.h0]
      inc count[hashes.h1]
      inc count[hashes.h2]
      xorAcc[hashes.h0] = xorAcc[hashes.h0] xor hash
      xorAcc[hashes.h1] = xorAcc[hashes.h1] xor hash
      xorAcc[hashes.h2] = xorAcc[hashes.h2] xor hash

    # Phase 3: Peeling
    var queue = newSeq[uint32]()
    for i in 0'u32 ..< result.arrayLength:
      if count[i] == 1:
        queue.add(i)

    while queue.len > 0:
      let idx = queue.pop()
      if count[idx] != 1:
        continue

      let hash = xorAcc[idx]
      let hashes = computeHashes16(hash, result)

      stack[stackPos] = (idx, hash)
      inc stackPos

      for pos in [hashes.h0, hashes.h1, hashes.h2]:
        dec count[pos]
        xorAcc[pos] = xorAcc[pos] xor hash
        if count[pos] == 1 and pos != idx:
          queue.add(pos)

    if stackPos == size:
      break

  if stackPos != size:
    raise newException(ValueError, "Binary Fuse 16 construction failed")

  # Phase 4: Assign fingerprints in reverse order
  for i in countdown(stackPos - 1, 0):
    let (idx, hash) = stack[i]
    let hashes = computeHashes16(hash, result)
    let fp = fingerprint16(hash)

    if idx == hashes.h0:
      result.fingerprints[hashes.h0] = fp xor
        result.fingerprints[hashes.h1] xor result.fingerprints[hashes.h2]
    elif idx == hashes.h1:
      result.fingerprints[hashes.h1] = fp xor
        result.fingerprints[hashes.h0] xor result.fingerprints[hashes.h2]
    else:
      result.fingerprints[hashes.h2] = fp xor
        result.fingerprints[hashes.h0] xor result.fingerprints[hashes.h1]

proc sizeInBytes*(filter: BinaryFuse16): int =
  ## Return memory usage in bytes for 16-bit filter
  filter.fingerprints.len * 2 + sizeof(filter)

proc bitsPerEntry*(filter: BinaryFuse16, numKeys: int): float =
  ## Return bits per entry (should be ~18.08 for 16-bit filter)
  if numKeys == 0: return 0.0
  float(filter.fingerprints.len * 16) / float(numKeys)
