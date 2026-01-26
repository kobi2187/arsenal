## Tests for Fixed-Point Arithmetic
## =================================

import std/[unittest, math]
import ../src/arsenal/numeric/fixed

suite "Fixed16 (Q16.16) - Conversion":
  test "float to Fixed16":
    let f = toFixed16(3.14)
    check abs(f.toFloat() - 3.14) < 0.0001

  test "integer to Fixed16":
    let i = toFixed16(42)
    check i.toInt() == 42
    check abs(i.toFloat() - 42.0) < 0.0001

  test "Fixed16 to float":
    let f = toFixed16(2.5)
    check abs(f.toFloat() - 2.5) < 0.0001

  test "Fixed16 to int (truncation)":
    let f = toFixed16(3.7)
    check f.toInt() == 3

  test "negative conversion":
    let f = toFixed16(-5.5)
    check abs(f.toFloat() - (-5.5)) < 0.0001
    check f.toInt() == -5

  test "zero conversion":
    let f = toFixed16(0.0)
    check f.toFloat() == 0.0
    check f.toInt() == 0

  test "small fraction":
    let f = toFixed16(0.5)
    check abs(f.toFloat() - 0.5) < 0.0001

suite "Fixed16 - Arithmetic Operations":
  test "addition":
    let a = toFixed16(3.5)
    let b = toFixed16(2.25)
    let c = a + b
    check abs(c.toFloat() - 5.75) < 0.0001

  test "subtraction":
    let a = toFixed16(10.0)
    let b = toFixed16(3.5)
    let c = a - b
    check abs(c.toFloat() - 6.5) < 0.0001

  test "multiplication":
    let a = toFixed16(3.0)
    let b = toFixed16(4.0)
    let c = a * b
    check abs(c.toFloat() - 12.0) < 0.001

  test "division":
    let a = toFixed16(10.0)
    let b = toFixed16(2.0)
    let c = a / b
    check abs(c.toFloat() - 5.0) < 0.001

  test "negation":
    let a = toFixed16(5.5)
    let b = -a
    check abs(b.toFloat() - (-5.5)) < 0.0001

  test "complex expression":
    let a = toFixed16(2.0)
    let b = toFixed16(3.0)
    let c = toFixed16(4.0)
    let result = (a + b) * c  # (2 + 3) * 4 = 20
    check abs(result.toFloat() - 20.0) < 0.01

suite "Fixed16 - Comparison":
  test "equality":
    let a = toFixed16(5.0)
    let b = toFixed16(5.0)
    let c = toFixed16(6.0)
    check a == b
    check not (a == c)

  test "less than":
    let a = toFixed16(3.0)
    let b = toFixed16(5.0)
    check a < b
    check not (b < a)

  test "less than or equal":
    let a = toFixed16(3.0)
    let b = toFixed16(3.0)
    let c = toFixed16(5.0)
    check a <= b
    check a <= c
    check not (c <= a)

suite "Fixed16 - Math Functions":
  test "absolute value":
    let a = toFixed16(-5.5)
    let b = abs(a)
    check abs(b.toFloat() - 5.5) < 0.0001

  test "absolute value of positive":
    let a = toFixed16(3.0)
    let b = abs(a)
    check abs(b.toFloat() - 3.0) < 0.0001

  test "square root":
    let a = toFixed16(9.0)
    let b = sqrt(a)
    check abs(b.toFloat() - 3.0) < 0.01

  test "square root of fraction":
    let a = toFixed16(4.0)
    let b = sqrt(a)
    check abs(b.toFloat() - 2.0) < 0.01

suite "Fixed16 - Edge Cases":
  test "very small numbers":
    let a = toFixed16(0.001)
    check a.toFloat() > 0.0
    check a.toFloat() < 0.01

  test "maximum representable":
    let a = toFixed16(32767.0)
    check a.toFloat() > 32766.0

  test "near zero operations":
    let a = toFixed16(0.1)
    let b = toFixed16(0.1)
    let c = a + b
    check abs(c.toFloat() - 0.2) < 0.001

  test "multiplication precision":
    let a = toFixed16(1.5)
    let b = toFixed16(2.5)
    let c = a * b
    check abs(c.toFloat() - 3.75) < 0.01

suite "Fixed32 (Q32.32) - Conversion":
  test "float to Fixed32":
    let f = toFixed32(3.141592653)
    check abs(f.toFloat() - 3.141592653) < 0.000001

  test "higher precision than Fixed16":
    let f16 = toFixed16(3.141592653)
    let f32 = toFixed32(3.141592653)

    # Fixed32 should be more accurate
    let error16 = abs(f16.toFloat() - 3.141592653)
    let error32 = abs(f32.toFloat() - 3.141592653)
    check error32 < error16

  test "large numbers":
    let f = toFixed32(1000000.5)
    check abs(f.toFloat() - 1000000.5) < 0.001

suite "Fixed-Point - Practical Use Cases":
  test "angle calculations (degrees)":
    let angle1 = toFixed16(45.0)
    let angle2 = toFixed16(90.0)
    let sum = angle1 + angle2
    check abs(sum.toFloat() - 135.0) < 0.01

  test "percentage calculations":
    let total = toFixed16(100.0)
    let percent = toFixed16(0.15)  # 15%
    let result = total * percent
    check abs(result.toFloat() - 15.0) < 0.1

  test "scaling operations":
    let originalSize = toFixed16(800.0)
    let scaleFactor = toFixed16(0.5)
    let scaledSize = originalSize * scaleFactor
    check abs(scaledSize.toFloat() - 400.0) < 1.0

  test "linear interpolation":
    proc lerp(a, b, t: Fixed16): Fixed16 =
      a + (b - a) * t

    let start = toFixed16(0.0)
    let end = toFixed16(10.0)
    let t = toFixed16(0.5)  # 50%
    let midpoint = lerp(start, end, t)

    check abs(midpoint.toFloat() - 5.0) < 0.1

suite "Fixed-Point - Performance Characteristics":
  test "addition is exact":
    let a = toFixed16(1.0)
    let sum = a + a + a + a + a  # 5.0
    check abs(sum.toFloat() - 5.0) < 0.0001

  test "multiplication accumulates error":
    var result = toFixed16(1.1)
    for i in 0..<10:
      result = result * toFixed16(1.1)

    # Error should be small but present
    let expected = pow(1.1, 11.0)
    let error = abs(result.toFloat() - expected)
    check error < 0.1  # Allow some error accumulation

  test "no floating-point rounding issues":
    # Classic floating-point problem: 0.1 + 0.2 != 0.3
    let a = toFixed16(0.1)
    let b = toFixed16(0.2)
    let c = a + b

    # Fixed-point handles this better (but still has precision limits)
    check abs(c.toFloat() - 0.3) < 0.001

suite "Fixed-Point - Constants":
  test "Fixed16One constant":
    check Fixed16One.toInt() == 1
    check abs(Fixed16One.toFloat() - 1.0) < 0.0001

  test "Fixed32One constant":
    check abs(Fixed32One.toFloat() - 1.0) < 0.000001

suite "Fixed-Point - Special Values":
  test "zero is zero":
    let zero = toFixed16(0.0)
    check zero.toInt() == 0
    check zero.toFloat() == 0.0

  test "one is one":
    let one = toFixed16(1.0)
    check one.toInt() == 1
    check abs(one.toFloat() - 1.0) < 0.0001

  test "negative numbers work":
    let neg = toFixed16(-10.5)
    check neg.toInt() == -10
    check abs(neg.toFloat() - (-10.5)) < 0.0001

## Performance Notes
## ==================
##
## Fixed-point vs Floating-point:
##   - Fixed-point: ~1-2 cycles per operation (no FPU needed)
##   - Floating-point: ~3-5 cycles (depends on FPU)
##   - Fixed-point: Deterministic, no rounding surprises
##   - Floating-point: More dynamic range
##
## Use Fixed-Point When:
##   - Embedded systems without FPU
##   - Deterministic behavior required (games, physics)
##   - Range is known and limited
##   - Performance critical on low-end hardware
##
## Use Floating-Point When:
##   - Wide dynamic range needed
##   - FPU available
##   - Precision more important than determinism
##
## Precision Comparison:
##   - Q16.16: ~5 decimal digits (0.00002 precision)
##   - Q32.32: ~10 decimal digits (2.3e-10 precision)
##   - float32: ~7 decimal digits
##   - float64: ~15 decimal digits
##
## Common Pitfalls:
##   - Overflow: Q16.16 range is only ±32768
##   - Multiplication error accumulation
##   - Division by small numbers loses precision
##   - Need to shift carefully to maintain format
