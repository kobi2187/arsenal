## Fixed-Point Arithmetic
## =======================
##
## Fixed-point numbers for systems without FPU (embedded, DSP).
## Faster than float on some platforms, deterministic.
##
## Format: Qm.n where m = integer bits, n = fractional bits
## Example: Q16.16 = 16 bits integer, 16 bits fraction
##
## Usage:
## ```nim
## import arsenal/numeric/fixed
##
## # Q16.16 fixed-point
## let a = toFixed16(3.14)
## let b = toFixed16(2.0)
## let c = a + b  # Fixed-point addition
## echo c.toFloat()  # Convert back to float
## ```

type
  Fixed16* = distinct int32
    ## Q16.16 fixed-point (16 integer bits, 16 fractional)
    ## Range: -32768 to 32767.99998
    ## Precision: ~0.00002

  Fixed32* = distinct int64
    ## Q32.32 fixed-point (32 integer bits, 32 fractional)
    ## Range: -2^31 to 2^31-1
    ## Precision: ~2.3e-10

const
  Fixed16FracBits* = 16
  Fixed32FracBits* = 32
  Fixed16One* = Fixed16(1 shl 16)
  Fixed32One* = Fixed32(1'i64 shl 32)

# =============================================================================
# Conversion
# =============================================================================

proc toFixed16*(x: float): Fixed16 {.inline.} =
  ## Convert float to Q16.16.
  Fixed16((x * (1 shl 16).float).int32)

proc toFixed16*(x: int): Fixed16 {.inline.} =
  ## Convert integer to Q16.16.
  Fixed16(x shl 16)

proc toFloat*(x: Fixed16): float {.inline.} =
  ## Convert Q16.16 to float.
  x.int32.float / (1 shl 16).float

proc toInt*(x: Fixed16): int {.inline.} =
  ## Convert Q16.16 to integer (truncate fraction).
  x.int32 shr 16

proc toFixed32*(x: float): Fixed32 {.inline.} =
  ## Convert float to Q32.32.
  Fixed32((x * (1'i64 shl 32).float).int64)

proc toFloat*(x: Fixed32): float {.inline.} =
  ## Convert Q32.32 to float.
  x.int64.float / (1'i64 shl 32).float

# =============================================================================
# Arithmetic (Fixed16)
# =============================================================================

proc `+`*(a, b: Fixed16): Fixed16 {.inline.} =
  ## Add two fixed-point numbers.
  Fixed16(a.int32 + b.int32)

proc `-`*(a, b: Fixed16): Fixed16 {.inline.} =
  ## Subtract fixed-point numbers.
  Fixed16(a.int32 - b.int32)

proc `*`*(a, b: Fixed16): Fixed16 {.inline.} =
  ## Multiply fixed-point numbers.
  ##
  ## IMPLEMENTATION:
  ## Must shift right after multiply to keep format:
  ## ```nim
  ## let product = a.int32.int64 * b.int32.int64
  ## result = Fixed16((product shr Fixed16FracBits).int32)
  ## ```

  let product = a.int32.int64 * b.int32.int64
  Fixed16((product shr Fixed16FracBits).int32)

proc `/`*(a, b: Fixed16): Fixed16 {.inline.} =
  ## Divide fixed-point numbers.
  ##
  ## IMPLEMENTATION:
  ## Must shift left before divide to maintain precision:
  ## ```nim
  ## let dividend = a.int32.int64 shl Fixed16FracBits
  ## result = Fixed16((dividend div b.int32.int64).int32)
  ## ```

  let dividend = a.int32.int64 shl Fixed16FracBits
  Fixed16((dividend div b.int32.int64).int32)

proc `-`*(x: Fixed16): Fixed16 {.inline.} =
  ## Negate.
  Fixed16(-x.int32)

# =============================================================================
# Comparison (Fixed16)
# =============================================================================

proc `==`*(a, b: Fixed16): bool {.inline.} =
  a.int32 == b.int32

proc `<`*(a, b: Fixed16): bool {.inline.} =
  a.int32 < b.int32

proc `<=`*(a, b: Fixed16): bool {.inline.} =
  a.int32 <= b.int32

# =============================================================================
# Math Functions (Fixed16)
# =============================================================================

proc abs*(x: Fixed16): Fixed16 {.inline.} =
  ## Absolute value.
  if x.int32 < 0: Fixed16(-x.int32) else: x

proc sqrt*(x: Fixed16): Fixed16 =
  ## Integer square root using Newton-Raphson.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if x.int32 <= 0: return Fixed16(0)
  ## var estimate = x
  ## for i in 0..<10:  # Iterations
  ##   estimate = Fixed16((estimate.int32 + (x / estimate).int32) shr 1)
  ## result = estimate
  ## ```

  if x.int32 <= 0: return Fixed16(0)
  var estimate = x
  for i in 0..<10:
    estimate = Fixed16((estimate.int32 + (x / estimate).int32) shr 1)
  result = estimate

proc sin*(x: Fixed16): Fixed16 =
  ## Sine using Taylor series or lookup table.
  ##
  ## IMPLEMENTATION:
  ## For performance, use lookup table (LUT):
  ## - Table of 256 entries for 0 to 2π
  ## - Linear interpolation between entries
  ## - Accuracy: ~0.001
  ##
  ## For space, use Taylor series:
  ## ```nim
  ## sin(x) ≈ x - x^3/6 + x^5/120 - x^7/5040
  ## ```

  # Stub - implement via LUT or Taylor series
  toFixed16(toFloat(x).sin)

# =============================================================================
# Saturating Arithmetic
# =============================================================================

proc saturatingAdd*(a, b: int32): int32 =
  ## Add with saturation (clamp to int32 range).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let sum = a.int64 + b.int64
  ## if sum > int32.high:
  ##   return int32.high
  ## elif sum < int32.low:
  ##   return int32.low
  ## else:
  ##   return sum.int32
  ## ```

  let sum = a.int64 + b.int64
  if sum > int32.high:
    int32.high
  elif sum < int32.low:
    int32.low
  else:
    sum.int32

proc saturatingSub*(a, b: int32): int32 =
  ## Subtract with saturation.
  let diff = a.int64 - b.int64
  if diff > int32.high:
    int32.high
  elif diff < int32.low:
    int32.low
  else:
    diff.int32

proc saturatingMul*(a, b: int32): int32 =
  ## Multiply with saturation.
  let product = a.int64 * b.int64
  if product > int32.high:
    int32.high
  elif product < int32.low:
    int32.low
  else:
    product.int32

# =============================================================================
# Checked Arithmetic
# =============================================================================

proc checkedAdd*(a, b: int): Option[int] =
  ## Add with overflow check.
  ##
  ## IMPLEMENTATION:
  ## Can use compiler builtins for efficiency:
  ## ```nim
  ## when defined(gcc) or defined(clang):
  ##   var result: int
  ##   if __builtin_add_overflow(a, b, &result):
  ##     return none(int)
  ##   return some(result)
  ## ```

  import std/options

  # Portable version
  if b > 0 and a > int.high - b:
    return none(int)
  elif b < 0 and a < int.low - b:
    return none(int)
  some(a + b)

proc checkedMul*(a, b: int): Option[int] =
  ## Multiply with overflow check.
  import std/options

  if a == 0 or b == 0:
    return some(0)

  let product = a.int64 * b.int64
  if product > int.high or product < int.low:
    return none(int)
  some(product.int)

# =============================================================================
# Notes
# =============================================================================

## USAGE NOTES:
##
## **When to use fixed-point:**
## - Embedded systems without FPU
## - Deterministic behavior (floats have rounding)
## - Fixed precision requirements
##
## **Performance:**
## - Add/Sub: Same as integer ops (~0.3 ns)
## - Mul/Div: Slightly slower than integer (~1-2 ns)
## - Much faster than software float on systems without FPU
##
## **Precision:**
## - Q16.16: Good for coordinates, physics in games
## - Q32.32: High precision financial calculations
##
## **Example (game physics):**
## ```nim
## type
##   Vec2 = object
##     x, y: Fixed16
##
## var pos = Vec2(x: toFixed16(10.0), y: toFixed16(20.0))
## var vel = Vec2(x: toFixed16(1.5), y: toFixed16(-0.5))
##
## pos.x = pos.x + vel.x  # Fixed-point physics
## pos.y = pos.y + vel.y
## ```
