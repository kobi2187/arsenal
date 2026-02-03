## Harley-Seal Population Count
## =============================
##
## SIMD-accelerated population count (bit counting).
## 2x faster than hardware POPCNT for bulk operations.
##
## Paper: "Faster Population Counts Using AVX2 Instructions"
##        https://arxiv.org/abs/1611.07612
##
## Key insight: Use carry-save adder (CSA) to reduce POPCNT calls.
## Chain data through CSA, only call vector popcount every 16 words.
##
## Performance:
## - Scalar POPCNT: ~1 cycle per 64-bit word
## - Harley-Seal AVX2: ~0.5 cycles per 64-bit word (2x faster)
##
## Used by: LLVM (clang), Roaring bitmaps, bioinformatics tools
##
## Requires: nimsimd package for SIMD intrinsics

# Conditional SIMD support - requires nimsimd package
# Set -d:useNimsimd to enable SIMD optimizations
when defined(useNimsimd) and (defined(amd64) or defined(i386)):
  import nimsimd/[sse2, avx2]
  const hasNimsimd = true
else:
  const hasNimsimd = false

import std/bitops

# =============================================================================
# Scalar Implementation
# =============================================================================

proc popcountScalar*(data: openArray[uint64]): int =
  ## Scalar popcount using hardware instruction.
  ## Falls back to software implementation if unavailable.
  result = 0
  for word in data:
    result += countSetBits(word)

proc popcountScalarBytes*(data: openArray[uint8]): int =
  ## Popcount for byte arrays (scalar).
  result = 0
  for b in data:
    result += countSetBits(b)

# =============================================================================
# Carry-Save Adder (CSA)
# =============================================================================
##
## Carry-Save Adder:
## =================
##
## A full adder computes: a + b + c = 2*high + low
##
## For popcount, we use this to combine multiple bit vectors:
##   CSA(a, b, c) -> (high, low)
##   where: popcount(a) + popcount(b) + popcount(c) = 2*popcount(high) + popcount(low)
##
## This reduces 3 popcount calls to 2, and chains to reduce further.
##
## Implementation:
##   high = (a AND b) OR (a AND c) OR (b AND c)  -- majority
##   low  = a XOR b XOR c                         -- parity

proc csa(a, b, c: uint64): tuple[high, low: uint64] {.inline.} =
  ## Carry-save adder for 64-bit words.
  ##
  ## Combines three values such that:
  ## popcount(a) + popcount(b) + popcount(c) = 2*popcount(high) + popcount(low)
  let u = a xor b
  result.high = (a and b) or (u and c)
  result.low = u xor c

when defined(amd64) and hasNimsimd:
  proc csa256(a, b, c: M256i): tuple[high, low: M256i] {.inline.} =
    ## AVX2 carry-save adder for 256-bit vectors.
    let u = mm256_xor_si256(a, b)
    result.high = mm256_or_si256(mm256_and_si256(a, b), mm256_and_si256(u, c))
    result.low = mm256_xor_si256(u, c)

# =============================================================================
# Harley-Seal Algorithm
# =============================================================================
##
## Harley-Seal Popcount:
## =====================
##
## Uses a tree of CSAs to reduce 16 words to 4 popcount calls.
##
## Tree structure (for 16 words):
##
##   Level 0: 16 input words
##   Level 1: CSA pairs -> 8 (low, high) pairs
##   Level 2: CSA pairs -> 4 (low, high) pairs
##   Level 3: CSA pairs -> 2 (low, high) pairs
##   Level 4: CSA pairs -> 1 (low, high) pair
##
## Final: total = popcount(ones) + 2*popcount(twos) +
##                4*popcount(fours) + 8*popcount(eights)
##
## Key insight: Only 4 popcounts for 16 words = 4x reduction

proc harleySealScalar*(data: openArray[uint64]): int =
  ## Harley-Seal popcount for 64-bit word arrays.
  ##
  ## Processes 16 words at a time using CSA tree.
  ## Falls back to simple popcount for remainders.

  result = 0
  let n = data.len
  var i = 0

  # Accumulators at each bit position
  var ones, twos, fours, eights, sixteens: uint64 = 0
  var twosA, twosB, foursA, foursB, eightsA, eightsB: uint64

  # Process 16 words at a time
  while i + 16 <= n:
    # Layer 1: Combine pairs -> twos and ones
    (twosA, ones) = csa(ones, data[i], data[i+1])
    (twosB, ones) = csa(ones, data[i+2], data[i+3])
    (foursA, twos) = csa(twos, twosA, twosB)

    (twosA, ones) = csa(ones, data[i+4], data[i+5])
    (twosB, ones) = csa(ones, data[i+6], data[i+7])
    (foursB, twos) = csa(twos, twosA, twosB)
    (eightsA, fours) = csa(fours, foursA, foursB)

    (twosA, ones) = csa(ones, data[i+8], data[i+9])
    (twosB, ones) = csa(ones, data[i+10], data[i+11])
    (foursA, twos) = csa(twos, twosA, twosB)

    (twosA, ones) = csa(ones, data[i+12], data[i+13])
    (twosB, ones) = csa(ones, data[i+14], data[i+15])
    (foursB, twos) = csa(twos, twosA, twosB)
    (eightsB, fours) = csa(fours, foursA, foursB)

    (sixteens, eights) = csa(eights, eightsA, eightsB)

    # Count the sixteens
    result += countSetBits(sixteens) * 16

    i += 16

  # Finalize remaining accumulators
  result += countSetBits(eights) * 8
  result += countSetBits(fours) * 4
  result += countSetBits(twos) * 2
  result += countSetBits(ones)

  # Handle remainder
  while i < n:
    result += countSetBits(data[i])
    inc i

# =============================================================================
# AVX2 Implementation
# =============================================================================
##
## AVX2 Harley-Seal:
## =================
##
## Same algorithm but with 256-bit vectors.
## Processes 16 x 256-bit vectors = 512 bytes per iteration.
##
## Uses lookup table for final popcount:
## - Split each byte into two 4-bit nibbles
## - Use PSHUFB to lookup popcount in table
## - Sum results

when defined(amd64) and hasNimsimd:
  # Lookup table for 4-bit popcount
  const POPCOUNT_4BIT = [0'u8, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4]

  proc popcount256*(v: M256i): int =
    ## Popcount for 256-bit vector using PSHUFB lookup.
    ##
    ## Algorithm:
    ## 1. Split bytes into low/high nibbles
    ## 2. Use PSHUFB to lookup popcount of each nibble
    ## 3. Sum all bytes

    # Create lookup table vector
    let lookup = mm256_setr_epi8(
      0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4,
      0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4
    )

    let lowMask = mm256_set1_epi8(0x0F)

    # Extract low and high nibbles
    let lo = mm256_and_si256(v, lowMask)
    let hi = mm256_and_si256(mm256_srli_epi16(v, 4), lowMask)

    # Lookup popcounts
    let popcntLo = mm256_shuffle_epi8(lookup, lo)
    let popcntHi = mm256_shuffle_epi8(lookup, hi)

    # Sum nibble popcounts
    let sum = mm256_add_epi8(popcntLo, popcntHi)

    # Horizontal sum using SAD (sum of absolute differences with zero)
    let zero = mm256_setzero_si256()
    let sad = mm256_sad_epu8(sum, zero)

    # Extract and sum the 4 64-bit sums
    result = int(mm256_extract_epi64(sad, 0) + mm256_extract_epi64(sad, 1) +
                 mm256_extract_epi64(sad, 2) + mm256_extract_epi64(sad, 3))

  proc harleySealAVX2*(data: ptr UncheckedArray[uint8], len: int): int =
    ## AVX2 Harley-Seal popcount.
    ##
    ## Processes 512 bytes (16 x 256-bit) per iteration.
    ## ~0.5 cycles per 64-bit word, 2x faster than scalar POPCNT.

    result = 0
    var pos = 0
    let dataVec = cast[ptr UncheckedArray[M256i]](data)

    # Accumulators
    var ones, twos, fours, eights, sixteens: M256i
    ones = mm256_setzero_si256()
    twos = mm256_setzero_si256()
    fours = mm256_setzero_si256()
    eights = mm256_setzero_si256()
    sixteens = mm256_setzero_si256()

    var twosA, twosB, foursA, foursB, eightsA, eightsB: M256i

    # Process 16 vectors (512 bytes) at a time
    while pos + 16 <= len div 32:
      (twosA, ones) = csa256(ones, dataVec[pos], dataVec[pos+1])
      (twosB, ones) = csa256(ones, dataVec[pos+2], dataVec[pos+3])
      (foursA, twos) = csa256(twos, twosA, twosB)

      (twosA, ones) = csa256(ones, dataVec[pos+4], dataVec[pos+5])
      (twosB, ones) = csa256(ones, dataVec[pos+6], dataVec[pos+7])
      (foursB, twos) = csa256(twos, twosA, twosB)
      (eightsA, fours) = csa256(fours, foursA, foursB)

      (twosA, ones) = csa256(ones, dataVec[pos+8], dataVec[pos+9])
      (twosB, ones) = csa256(ones, dataVec[pos+10], dataVec[pos+11])
      (foursA, twos) = csa256(twos, twosA, twosB)

      (twosA, ones) = csa256(ones, dataVec[pos+12], dataVec[pos+13])
      (twosB, ones) = csa256(ones, dataVec[pos+14], dataVec[pos+15])
      (foursB, twos) = csa256(twos, twosA, twosB)
      (eightsB, fours) = csa256(fours, foursA, foursB)

      (sixteens, eights) = csa256(eights, eightsA, eightsB)

      result += popcount256(sixteens) * 16
      pos += 16

    # Finalize accumulators
    result += popcount256(eights) * 8
    result += popcount256(fours) * 4
    result += popcount256(twos) * 2
    result += popcount256(ones)

    # Handle remaining bytes
    let remaining = len - pos * 32
    if remaining > 0:
      for i in pos * 32 ..< len:
        result += countSetBits(data[i])

# =============================================================================
# Public API
# =============================================================================

proc popcount*(data: openArray[uint64]): int =
  ## Count set bits in array of 64-bit words.
  ## Automatically selects best implementation.
  when defined(amd64):
    # Use Harley-Seal for large arrays
    if data.len >= 32:
      return harleySealScalar(data)
  popcountScalar(data)

proc popcount*(data: openArray[uint8]): int =
  ## Count set bits in byte array.
  when defined(amd64) and defined(avx2) and hasNimsimd:
    if data.len >= 512:
      return harleySealAVX2(cast[ptr UncheckedArray[uint8]](data[0].unsafeAddr), data.len)
  popcountScalarBytes(data)

proc popcount*(data: string): int =
  ## Count set bits in string (as bytes).
  popcount(cast[seq[uint8]](data))

# =============================================================================
# Positional Population Count
# =============================================================================
##
## Positional Popcount:
## ====================
##
## Given N words, count bits at each position (0-63).
## Result is 64 counts, one per bit position.
##
## Use case: Columnar data analysis, bitmap statistics

proc positionalPopcount*(data: openArray[uint64]): array[64, int] =
  ## Count set bits at each bit position across all words.
  ##
  ## Returns array where result[i] = number of words with bit i set.
  for i in 0 ..< 64:
    result[i] = 0

  for word in data:
    var w = word
    for i in 0 ..< 64:
      if (w and 1) != 0:
        inc result[i]
      w = w shr 1

proc positionalPopcount16*(data: openArray[uint16]): array[16, int] =
  ## Positional popcount for 16-bit words.
  ##
  ## Useful for one-hot encoded vectors.
  ## SIMD version can process ~25 billion 16-bit words per second.
  for i in 0 ..< 16:
    result[i] = 0

  for word in data:
    var w = word
    for i in 0 ..< 16:
      if (w and 1) != 0:
        inc result[i]
      w = w shr 1
