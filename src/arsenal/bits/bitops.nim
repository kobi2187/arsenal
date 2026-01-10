## Bit Manipulation Operations
## ===========================
##
## Fast bit manipulation primitives using CPU intrinsics where available.
## These operations are fundamental building blocks for many algorithms.
##
## All operations have:
## - Hardware-accelerated versions (via compiler intrinsics)
## - Portable fallback implementations
##
## Usage:
## ```nim
## echo countLeadingZeros(0b00001000'u32)  # 28
## echo countTrailingZeros(0b00001000'u32) # 3
## echo popcount(0b10101010'u32)           # 4
## ```

type
  BitIndex* = range[0..63]
    ## Index of a bit within a 64-bit word.

# =============================================================================
# Count Leading Zeros (CLZ) / Bit Scan Reverse
# =============================================================================

proc countLeadingZeros*(x: uint32): int {.inline.} =
  ## Count the number of leading (high) zero bits.
  ## Returns 32 if x is 0.
  ##
  ## IMPLEMENTATION:
  ## Use `__builtin_clz` (GCC/Clang) or `_BitScanReverse` (MSVC):
  ##
  ## ```nim
  ## when defined(gcc) or defined(clang):
  ##   if x == 0: return 32
  ##   {.emit: "`result` = __builtin_clz(`x`);".}
  ## elif defined(vcc):
  ##   var index: culong
  ##   if _BitScanReverse(addr index, x) == 0:
  ##     return 32
  ##   result = 31 - index.int
  ## else:
  ##   # Portable fallback using binary search
  ##   if x == 0: return 32
  ##   var n = 0
  ##   if (x and 0xFFFF0000'u32) == 0: n += 16; x = x shl 16
  ##   if (x and 0xFF000000'u32) == 0: n += 8; x = x shl 8
  ##   if (x and 0xF0000000'u32) == 0: n += 4; x = x shl 4
  ##   if (x and 0xC0000000'u32) == 0: n += 2; x = x shl 2
  ##   if (x and 0x80000000'u32) == 0: n += 1
  ##   result = n
  ## ```
  ##
  ## x86: BSR instruction (bit scan reverse)
  ## ARM: CLZ instruction

  if x == 0: return 32
  var n = 0
  var v = x
  if (v and 0xFFFF0000'u32) == 0: n += 16; v = v shl 16
  if (v and 0xFF000000'u32) == 0: n += 8; v = v shl 8
  if (v and 0xF0000000'u32) == 0: n += 4; v = v shl 4
  if (v and 0xC0000000'u32) == 0: n += 2; v = v shl 2
  if (v and 0x80000000'u32) == 0: n += 1
  result = n

proc countLeadingZeros*(x: uint64): int {.inline.} =
  ## 64-bit version.
  ##
  ## IMPLEMENTATION:
  ## Use `__builtin_clzll`:
  ## ```nim
  ## {.emit: "`result` = `x` == 0 ? 64 : __builtin_clzll(`x`);".}
  ## ```

  if x == 0: return 64
  let hi = (x shr 32).uint32
  if hi != 0:
    return countLeadingZeros(hi)
  else:
    return 32 + countLeadingZeros(x.uint32)

proc clz*(x: uint32): int {.inline.} = countLeadingZeros(x)
proc clz*(x: uint64): int {.inline.} = countLeadingZeros(x)

# =============================================================================
# Count Trailing Zeros (CTZ) / Bit Scan Forward
# =============================================================================

proc countTrailingZeros*(x: uint32): int {.inline.} =
  ## Count the number of trailing (low) zero bits.
  ## Returns 32 if x is 0.
  ##
  ## IMPLEMENTATION:
  ## Use `__builtin_ctz` (GCC/Clang) or `_BitScanForward` (MSVC):
  ##
  ## ```nim
  ## when defined(gcc) or defined(clang):
  ##   if x == 0: return 32
  ##   {.emit: "`result` = __builtin_ctz(`x`);".}
  ## else:
  ##   # Portable: use de Bruijn sequence
  ##   if x == 0: return 32
  ##   const debruijn = 0x077CB531'u32
  ##   const table = [0, 1, 28, 2, 29, 14, 24, 3, 30, 22, 20, 15, 25, 17, 4, 8,
  ##                  31, 27, 13, 23, 21, 19, 16, 7, 26, 12, 18, 6, 11, 5, 10, 9]
  ##   result = table[((x and (-x).uint32) * debruijn) shr 27]
  ## ```
  ##
  ## x86: BSF instruction (bit scan forward) or TZCNT (BMI1)
  ## ARM: RBIT + CLZ

  if x == 0: return 32
  # De Bruijn sequence method
  const debruijn = 0x077CB531'u32
  const table = [
    0'i8, 1, 28, 2, 29, 14, 24, 3, 30, 22, 20, 15, 25, 17, 4, 8,
    31, 27, 13, 23, 21, 19, 16, 7, 26, 12, 18, 6, 11, 5, 10, 9
  ]
  let isolated = x and (0'u32 - x)  # Isolate lowest set bit
  result = table[(isolated * debruijn) shr 27].int

proc countTrailingZeros*(x: uint64): int {.inline.} =
  ## 64-bit version.

  if x == 0: return 64
  let lo = x.uint32
  if lo != 0:
    return countTrailingZeros(lo)
  else:
    return 32 + countTrailingZeros((x shr 32).uint32)

proc ctz*(x: uint32): int {.inline.} = countTrailingZeros(x)
proc ctz*(x: uint64): int {.inline.} = countTrailingZeros(x)

# =============================================================================
# Population Count (POPCNT)
# =============================================================================

proc popcount*(x: uint32): int {.inline.} =
  ## Count the number of set (1) bits.
  ##
  ## IMPLEMENTATION:
  ## Use `__builtin_popcount` if available, or SIMD POPCNT instruction:
  ##
  ## ```nim
  ## when defined(popcnt):
  ##   {.emit: "`result` = __builtin_popcount(`x`);".}
  ## else:
  ##   # Portable: parallel bit counting
  ##   var v = x
  ##   v = v - ((v shr 1) and 0x55555555'u32)
  ##   v = (v and 0x33333333'u32) + ((v shr 2) and 0x33333333'u32)
  ##   v = (v + (v shr 4)) and 0x0F0F0F0F'u32
  ##   result = ((v * 0x01010101'u32) shr 24).int
  ## ```

  var v = x
  v = v - ((v shr 1) and 0x55555555'u32)
  v = (v and 0x33333333'u32) + ((v shr 2) and 0x33333333'u32)
  v = (v + (v shr 4)) and 0x0F0F0F0F'u32
  result = ((v * 0x01010101'u32) shr 24).int

proc popcount*(x: uint64): int {.inline.} =
  ## 64-bit version.

  var v = x
  v = v - ((v shr 1) and 0x5555555555555555'u64)
  v = (v and 0x3333333333333333'u64) + ((v shr 2) and 0x3333333333333333'u64)
  v = (v + (v shr 4)) and 0x0F0F0F0F0F0F0F0F'u64
  result = ((v * 0x0101010101010101'u64) shr 56).int

# =============================================================================
# Byte Swap (Endianness Conversion)
# =============================================================================

proc byteSwap*(x: uint16): uint16 {.inline.} =
  ## Swap bytes (for endianness conversion).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## {.emit: "`result` = __builtin_bswap16(`x`);".}
  ## ```
  ## Or x86 BSWAP, ARM REV instructions.

  ((x and 0xFF) shl 8) or (x shr 8)

proc byteSwap*(x: uint32): uint32 {.inline.} =
  ## 32-bit byte swap.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## {.emit: "`result` = __builtin_bswap32(`x`);".}
  ## ```

  ((x and 0xFF) shl 24) or
  ((x and 0xFF00) shl 8) or
  ((x and 0xFF0000) shr 8) or
  (x shr 24)

proc byteSwap*(x: uint64): uint64 {.inline.} =
  ## 64-bit byte swap.

  let hi = byteSwap((x shr 32).uint32).uint64
  let lo = byteSwap(x.uint32).uint64
  (lo shl 32) or hi

# =============================================================================
# Rotate
# =============================================================================

proc rotateLeft*(x: uint32, n: int): uint32 {.inline.} =
  ## Rotate bits left by n positions.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## {.emit: "`result` = (`x` << `n`) | (`x` >> (32 - `n`));".}
  ## ```
  ## Compilers recognize this pattern and emit ROL instruction.

  let n = n and 31
  (x shl n) or (x shr (32 - n))

proc rotateLeft*(x: uint64, n: int): uint64 {.inline.} =
  let n = n and 63
  (x shl n) or (x shr (64 - n))

proc rotateRight*(x: uint32, n: int): uint32 {.inline.} =
  rotateLeft(x, 32 - n)

proc rotateRight*(x: uint64, n: int): uint64 {.inline.} =
  rotateLeft(x, 64 - n)

# =============================================================================
# Power of Two Operations
# =============================================================================

proc isPowerOfTwo*(x: uint32): bool {.inline.} =
  ## Check if x is a power of 2 (exactly one bit set).
  x != 0 and (x and (x - 1)) == 0

proc isPowerOfTwo*(x: uint64): bool {.inline.} =
  x != 0 and (x and (x - 1)) == 0

proc nextPowerOfTwo*(x: uint32): uint32 {.inline.} =
  ## Round up to the next power of 2.
  ## If x is already a power of 2, returns x.
  ##
  ## IMPLEMENTATION:
  ## Use CLZ: `1 << (32 - clz(x - 1))`
  ## Or bit smearing:

  var v = x - 1
  v = v or (v shr 1)
  v = v or (v shr 2)
  v = v or (v shr 4)
  v = v or (v shr 8)
  v = v or (v shr 16)
  v + 1

proc nextPowerOfTwo*(x: uint64): uint64 {.inline.} =
  var v = x - 1
  v = v or (v shr 1)
  v = v or (v shr 2)
  v = v or (v shr 4)
  v = v or (v shr 8)
  v = v or (v shr 16)
  v = v or (v shr 32)
  v + 1

proc log2Floor*(x: uint32): int {.inline.} =
  ## Floor of log base 2 (index of highest set bit).
  ## Undefined for x == 0.
  31 - countLeadingZeros(x)

proc log2Floor*(x: uint64): int {.inline.} =
  63 - countLeadingZeros(x)

# =============================================================================
# Bit Extraction (BMI1/BMI2)
# =============================================================================

proc extractBits*(x: uint64, start, length: int): uint64 {.inline.} =
  ## Extract `length` bits starting at bit `start`.
  ##
  ## IMPLEMENTATION (BMI1 BEXTR):
  ## ```nim
  ## when defined(bmi1):
  ##   {.emit: "`result` = _bextr_u64(`x`, `start`, `length`);".}
  ## else:
  ##   (x shr start) and ((1'u64 shl length) - 1)
  ## ```

  (x shr start) and ((1'u64 shl length) - 1)

proc depositBits*(x, mask: uint64): uint64 {.inline.} =
  ## Parallel bit deposit (BMI2 PDEP).
  ## Scatter contiguous low bits of x to positions marked by mask.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(bmi2):
  ##   {.emit: "`result` = _pdep_u64(`x`, `mask`);".}
  ## else:
  ##   # Slow fallback
  ##   var m = mask
  ##   var s = x
  ##   result = 0
  ##   while m != 0:
  ##     let bit = m and (-m).uint64  # Lowest set bit
  ##     if (s and 1) != 0:
  ##       result = result or bit
  ##     s = s shr 1
  ##     m = m and (m - 1)  # Clear lowest set bit
  ## ```

  # Slow fallback
  var m = mask
  var s = x
  result = 0
  while m != 0:
    let bit = m and (0'u64 - m)
    if (s and 1) != 0:
      result = result or bit
    s = s shr 1
    m = m and (m - 1)

proc extractBitsParallel*(x, mask: uint64): uint64 {.inline.} =
  ## Parallel bit extract (BMI2 PEXT).
  ## Gather bits from positions marked by mask to contiguous low bits.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(bmi2):
  ##   {.emit: "`result` = _pext_u64(`x`, `mask`);".}
  ## else:
  ##   # Slow fallback
  ##   ...
  ## ```

  var m = mask
  var src = x
  result = 0
  var dst = 0
  while m != 0:
    let bit = m and (0'u64 - m)
    if (src and bit) != 0:
      result = result or (1'u64 shl dst)
    m = m and (m - 1)
    inc dst
