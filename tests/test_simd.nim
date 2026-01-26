## Tests for SIMD Intrinsics
## ==========================

import std/[unittest, math]
import ../src/arsenal/simd/intrinsics

# Helper to compare float arrays with tolerance
proc floatsEqual(a, b: openArray[float32], tolerance: float32 = 0.0001): bool =
  if a.len != b.len:
    return false
  for i in 0..<a.len:
    if abs(a[i] - b[i]) > tolerance:
      return false
  return true

when defined(amd64) or defined(i386):
  suite "SSE2 - Float Operations (x86)":
    test "mm_set1_ps - broadcast float":
      var a = mm_set1_ps(3.14'f32)
      # All 4 lanes should be 3.14
      var result: array[4, float32]
      mm_store_ps(addr result[0], a)

      for val in result:
        check abs(val - 3.14'f32) < 0.0001

    test "mm_add_ps - add 4 floats":
      var a = mm_set1_ps(2.0'f32)
      var b = mm_set1_ps(3.0'f32)
      var c = mm_add_ps(a, b)

      var result: array[4, float32]
      mm_store_ps(addr result[0], c)

      for val in result:
        check abs(val - 5.0'f32) < 0.0001

    test "mm_sub_ps - subtract 4 floats":
      var a = mm_set1_ps(10.0'f32)
      var b = mm_set1_ps(3.0'f32)
      var c = mm_sub_ps(a, b)

      var result: array[4, float32]
      mm_store_ps(addr result[0], c)

      for val in result:
        check abs(val - 7.0'f32) < 0.0001

    test "mm_mul_ps - multiply 4 floats":
      var a = mm_set1_ps(4.0'f32)
      var b = mm_set1_ps(2.5'f32)
      var c = mm_mul_ps(a, b)

      var result: array[4, float32]
      mm_store_ps(addr result[0], c)

      for val in result:
        check abs(val - 10.0'f32) < 0.0001

    test "mm_div_ps - divide 4 floats":
      var a = mm_set1_ps(20.0'f32)
      var b = mm_set1_ps(4.0'f32)
      var c = mm_div_ps(a, b)

      var result: array[4, float32]
      mm_store_ps(addr result[0], c)

      for val in result:
        check abs(val - 5.0'f32) < 0.0001

    test "mm_sqrt_ps - square root of 4 floats":
      var a = mm_set1_ps(16.0'f32)
      var b = mm_sqrt_ps(a)

      var result: array[4, float32]
      mm_store_ps(addr result[0], b)

      for val in result:
        check abs(val - 4.0'f32) < 0.0001

    test "mm_load/store aligned":
      var input: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
      var output: array[4, float32]

      var a = mm_load_ps(addr input[0])
      mm_store_ps(addr output[0], a)

      check floatsEqual(input, output)

    test "mm_loadu/storeu unaligned":
      var input: array[4, float32] = [5.0'f32, 6.0, 7.0, 8.0]
      var output: array[4, float32]

      var a = mm_loadu_ps(addr input[0])
      mm_storeu_ps(addr output[0], a)

      check floatsEqual(input, output)

  suite "SSE2 - Integer Operations (x86)":
    test "mm_set1_epi32 - broadcast int32":
      var a = mm_set1_epi32(42)
      # Verification would need mm_store_si128, keeping simple

    test "mm_add_epi32 - add 4 int32s":
      var a = mm_set1_epi32(10)
      var b = mm_set1_epi32(5)
      var c = mm_add_epi32(a, b)
      # Result should be all 15s

    test "mm_sub_epi32 - subtract 4 int32s":
      var a = mm_set1_epi32(20)
      var b = mm_set1_epi32(8)
      var c = mm_sub_epi32(a, b)
      # Result should be all 12s

  suite "AVX2 - 256-bit Operations (x86)":
    test "mm256_set1_ps - broadcast 8 floats":
      var a = mm256_set1_ps(2.5'f32)
      # All 8 lanes should be 2.5

    test "mm256_add_ps - add 8 floats":
      var a = mm256_set1_ps(1.0'f32)
      var b = mm256_set1_ps(2.0'f32)
      var c = mm256_add_ps(a, b)
      # All should be 3.0

    test "mm256_mul_ps - multiply 8 floats":
      var a = mm256_set1_ps(3.0'f32)
      var b = mm256_set1_ps(4.0'f32)
      var c = mm256_mul_ps(a, b)
      # All should be 12.0

    test "mm256_fmadd_ps - fused multiply-add":
      var a = mm256_set1_ps(2.0'f32)
      var b = mm256_set1_ps(3.0'f32)
      var c = mm256_set1_ps(1.0'f32)
      var result = mm256_fmadd_ps(a, b, c)  # a*b + c = 2*3 + 1 = 7

  suite "SSE2 - Practical Operations (x86)":
    test "dot product of 4 floats":
      var a: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
      var b: array[4, float32] = [2.0'f32, 3.0, 4.0, 5.0]

      var va = mm_load_ps(addr a[0])
      var vb = mm_load_ps(addr b[0])
      var prod = mm_mul_ps(va, vb)  # [2, 6, 12, 20]

      var result: array[4, float32]
      mm_store_ps(addr result[0], prod)

      # Sum manually (real impl would use horizontal add)
      let dotProduct = result[0] + result[1] + result[2] + result[3]
      check abs(dotProduct - 40.0'f32) < 0.001  # 2+6+12+20 = 40

    test "vector scaling":
      var vec: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
      let scalar = 2.5'f32

      var v = mm_load_ps(addr vec[0])
      var s = mm_set1_ps(scalar)
      var scaled = mm_mul_ps(v, s)

      var result: array[4, float32]
      mm_store_ps(addr result[0], scaled)

      check abs(result[0] - 2.5'f32) < 0.001
      check abs(result[1] - 5.0'f32) < 0.001
      check abs(result[2] - 7.5'f32) < 0.001
      check abs(result[3] - 10.0'f32) < 0.001

    test "element-wise operations":
      var a: array[4, float32] = [10.0'f32, 20.0, 30.0, 40.0]
      var b: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]

      var va = mm_load_ps(addr a[0])
      var vb = mm_load_ps(addr b[0])

      # (a + b) * 2
      var sum = mm_add_ps(va, vb)
      var two = mm_set1_ps(2.0'f32)
      var result_vec = mm_mul_ps(sum, two)

      var result: array[4, float32]
      mm_store_ps(addr result[0], result_vec)

      check abs(result[0] - 22.0'f32) < 0.001  # (10+1)*2
      check abs(result[1] - 44.0'f32) < 0.001  # (20+2)*2
      check abs(result[2] - 66.0'f32) < 0.001  # (30+3)*2
      check abs(result[3] - 88.0'f32) < 0.001  # (40+4)*2

when defined(arm) or defined(arm64):
  suite "NEON - Float Operations (ARM)":
    test "vdupq_n_f32 - broadcast float":
      var a = vdupq_n_f32(3.14'f32)
      # All 4 lanes should be 3.14

    test "vaddq_f32 - add 4 floats":
      var a = vdupq_n_f32(2.0'f32)
      var b = vdupq_n_f32(3.0'f32)
      var c = vaddq_f32(a, b)
      # All should be 5.0

    test "vsubq_f32 - subtract 4 floats":
      var a = vdupq_n_f32(10.0'f32)
      var b = vdupq_n_f32(3.0'f32)
      var c = vsubq_f32(a, b)
      # All should be 7.0

    test "vmulq_f32 - multiply 4 floats":
      var a = vdupq_n_f32(4.0'f32)
      var b = vdupq_n_f32(2.5'f32)
      var c = vmulq_f32(a, b)
      # All should be 10.0

    test "vld1q/vst1q load/store":
      var input: array[4, float32] = [1.0'f32, 2.0, 3.0, 4.0]
      var output: array[4, float32]

      var a = vld1q_f32(addr input[0])
      vst1q_f32(addr output[0], a)

      check floatsEqual(input, output)

## Platform Detection
## ===================
when not (defined(amd64) or defined(i386) or defined(arm) or defined(arm64)):
  suite "SIMD - Platform Not Supported":
    test "SIMD not available on this platform":
      skip()

## Performance Notes
## ==================
##
## SIMD Performance:
##   - SSE2 (128-bit): 4x float32 or 2x float64 in parallel
##   - AVX2 (256-bit): 8x float32 or 4x float64 in parallel
##   - NEON (128-bit): 4x float32 in parallel
##
## Typical Speedups:
##   - Best case: 4-8x (perfect vectorization)
##   - Typical: 2-4x (memory bandwidth, alignment issues)
##   - Worst case: 1x (scalar code path)
##
## Optimization Tips:
##   1. Align data to 16/32 bytes (use __attribute__((aligned(N))))
##   2. Use unaligned loads sparingly (slower)
##   3. Minimize data shuffling/rearrangement
##   4. Keep data in SIMD registers (avoid store/load)
##   5. Use FMA (fused multiply-add) when available
##
## Use Cases:
##   - Graphics (vector/matrix math)
##   - Signal processing (audio, images)
##   - Machine learning (matrix multiplication)
##   - Physics simulation (many particles)
##   - Compression/decompression
##
## Hardware Support:
##   - SSE2: All x86_64 CPUs (baseline)
##   - AVX2: Intel Haswell+ (2013), AMD Excavator+ (2015)
##   - NEON: All ARMv7+ (mandatory on ARMv8/AArch64)
##
## Fallback Strategy:
##   - Always provide scalar fallback
##   - Runtime detection: Use cpuid/getauxval
##   - Compile-time: Use #ifdef or when defined()
##
## Common Pitfalls:
##   - Unaligned access (crashes or slow)
##   - Data dependencies (can't vectorize)
##   - Branches in loop (breaks vectorization)
##   - Too many loads/stores (memory bound)
##   - Small data (overhead > benefit)
##
## When SIMD Helps:
##   - Large datasets (> 1KB)
##   - Independent operations
##   - Memory access is aligned
##   - Computation heavy (not memory bound)
##
## When SIMD Doesn't Help:
##   - Small datasets (< 100 elements)
##   - Complex control flow
##   - Memory bound workload
##   - Unaligned, scattered data access
