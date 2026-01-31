## SIMD Intrinsics
## ================
##
## Thin wrappers over x86 SSE/AVX and ARM NEON intrinsics.
## Provides portable SIMD operations.
##
## Note: Nim's experimental/simd module exists but is limited.
## This provides direct access to hardware intrinsics.
##
## Usage:
## ```nim
## import arsenal/simd/intrinsics
##
## when hasSSE2:
##   var a = mm_set1_ps(1.0)
##   var b = mm_set1_ps(2.0)
##   var c = mm_add_ps(a, b)  # SIMD add
## ```

import ../platform/config

# =============================================================================
# x86 SSE2 (128-bit)
# =============================================================================

when defined(amd64) or defined(i386):
  type
    M128* {.importc: "__m128", header: "<emmintrin.h>".} = object
      ## 128-bit SSE register (4 x float32 or 2 x float64)

    M128i* {.importc: "__m128i", header: "<emmintrin.h>".} = object
      ## 128-bit integer register

    M128d* {.importc: "__m128d", header: "<emmintrin.h>".} = object
      ## 128-bit double register (2 x float64)

  # SSE2 float operations
  proc mm_set1_ps*(a: float32): M128 {.importc: "_mm_set1_ps", header: "<emmintrin.h>".}
    ## Set all 4 floats to same value

  proc mm_add_ps*(a, b: M128): M128 {.importc: "_mm_add_ps", header: "<emmintrin.h>".}
    ## Add 4 floats in parallel

  proc mm_sub_ps*(a, b: M128): M128 {.importc: "_mm_sub_ps", header: "<emmintrin.h>".}
    ## Subtract 4 floats

  proc mm_mul_ps*(a, b: M128): M128 {.importc: "_mm_mul_ps", header: "<emmintrin.h>".}
    ## Multiply 4 floats

  proc mm_div_ps*(a, b: M128): M128 {.importc: "_mm_div_ps", header: "<emmintrin.h>".}
    ## Divide 4 floats

  proc mm_sqrt_ps*(a: M128): M128 {.importc: "_mm_sqrt_ps", header: "<emmintrin.h>".}
    ## Square root of 4 floats

  proc mm_load_ps*(p: ptr float32): M128 {.importc: "_mm_load_ps", header: "<emmintrin.h>".}
    ## Load 4 floats from aligned memory (16-byte aligned)

  proc mm_loadu_ps*(p: ptr float32): M128 {.importc: "_mm_loadu_ps", header: "<emmintrin.h>".}
    ## Load 4 floats from unaligned memory

  proc mm_store_ps*(p: ptr float32, a: M128) {.importc: "_mm_store_ps", header: "<emmintrin.h>".}
    ## Store 4 floats to aligned memory

  proc mm_storeu_ps*(p: ptr float32, a: M128) {.importc: "_mm_storeu_ps", header: "<emmintrin.h>".}
    ## Store 4 floats to unaligned memory

  # SSE2 integer operations
  proc mm_set1_epi32*(a: int32): M128i {.importc: "_mm_set1_epi32", header: "<emmintrin.h>".}
    ## Set all 4 int32s to same value

  proc mm_add_epi32*(a, b: M128i): M128i {.importc: "_mm_add_epi32", header: "<emmintrin.h>".}
    ## Add 4 int32s

  proc mm_sub_epi32*(a, b: M128i): M128i {.importc: "_mm_sub_epi32", header: "<emmintrin.h>".}
    ## Subtract 4 int32s

# =============================================================================
# x86 AVX2 (256-bit)
# =============================================================================

when defined(amd64) or defined(i386):
  type
    M256* {.importc: "__m256", header: "<immintrin.h>".} = object
      ## 256-bit AVX register (8 x float32)

    M256i* {.importc: "__m256i", header: "<immintrin.h>".} = object
      ## 256-bit integer register

    M256d* {.importc: "__m256d", header: "<immintrin.h>".} = object
      ## 256-bit double register (4 x float64)

  proc mm256_set1_ps*(a: float32): M256 {.importc: "_mm256_set1_ps", header: "<immintrin.h>".}
    ## Set all 8 floats to same value

  proc mm256_add_ps*(a, b: M256): M256 {.importc: "_mm256_add_ps", header: "<immintrin.h>".}
    ## Add 8 floats in parallel

  proc mm256_mul_ps*(a, b: M256): M256 {.importc: "_mm256_mul_ps", header: "<immintrin.h>".}
    ## Multiply 8 floats

  proc mm256_fmadd_ps*(a, b, c: M256): M256 {.importc: "_mm256_fmadd_ps", header: "<immintrin.h>".}
    ## Fused multiply-add: a*b + c (AVX2/FMA)

  proc mm256_load_ps*(p: ptr float32): M256 {.importc: "_mm256_load_ps", header: "<immintrin.h>".}
    ## Load 8 floats from aligned memory (32-byte aligned)

  proc mm256_loadu_ps*(p: ptr float32): M256 {.importc: "_mm256_loadu_ps", header: "<immintrin.h>".}
    ## Load 8 floats from unaligned memory

  proc mm256_store_ps*(p: ptr float32, a: M256) {.importc: "_mm256_store_ps", header: "<immintrin.h>".}
    ## Store 8 floats to aligned memory

# =============================================================================
# ARM NEON (128-bit)
# =============================================================================

when defined(arm) or defined(arm64):
  type
    Float32x4* {.importc: "float32x4_t", header: "<arm_neon.h>".} = object
      ## 128-bit NEON register (4 x float32)

    Int32x4* {.importc: "int32x4_t", header: "<arm_neon.h>".} = object
      ## 128-bit integer register (4 x int32)

  proc vdupq_n_f32*(value: float32): Float32x4 {.importc, header: "<arm_neon.h>".}
    ## Set all 4 floats to same value

  proc vaddq_f32*(a, b: Float32x4): Float32x4 {.importc, header: "<arm_neon.h>".}
    ## Add 4 floats

  proc vsubq_f32*(a, b: Float32x4): Float32x4 {.importc, header: "<arm_neon.h>".}
    ## Subtract 4 floats

  proc vmulq_f32*(a, b: Float32x4): Float32x4 {.importc, header: "<arm_neon.h>".}
    ## Multiply 4 floats

  proc vld1q_f32*(p: ptr float32): Float32x4 {.importc, header: "<arm_neon.h>".}
    ## Load 4 floats from memory

  proc vst1q_f32*(p: ptr float32, a: Float32x4) {.importc, header: "<arm_neon.h>".}
    ## Store 4 floats to memory

# =============================================================================
# Portable SIMD Operations
# =============================================================================

type
  Vec4f* = object
    ## Portable 4-wide float vector
    when defined(amd64) or defined(i386):
      data: M128
    elif defined(arm) or defined(arm64):
      data: Float32x4
    else:
      data: array[4, float32]

proc vec4f*(x: float32): Vec4f {.inline.} =
  ## Create vector with all elements set to x
  when defined(amd64) or defined(i386):
    result.data = mm_set1_ps(x)
  elif defined(arm) or defined(arm64):
    result.data = vdupq_n_f32(x)
  else:
    result.data = [x, x, x, x]

proc `+`*(a, b: Vec4f): Vec4f {.inline.} =
  ## Add two vectors
  when defined(amd64) or defined(i386):
    result.data = mm_add_ps(a.data, b.data)
  elif defined(arm) or defined(arm64):
    result.data = vaddq_f32(a.data, b.data)
  else:
    for i in 0..3:
      result.data[i] = a.data[i] + b.data[i]

proc `*`*(a, b: Vec4f): Vec4f {.inline.} =
  ## Multiply two vectors
  when defined(amd64) or defined(i386):
    result.data = mm_mul_ps(a.data, b.data)
  elif defined(arm) or defined(arm64):
    result.data = vmulq_f32(a.data, b.data)
  else:
    for i in 0..3:
      result.data[i] = a.data[i] * b.data[i]

proc load*(p: ptr float32): Vec4f {.inline.} =
  ## Load vector from memory
  when defined(amd64) or defined(i386):
    result.data = mm_loadu_ps(p)
  elif defined(arm) or defined(arm64):
    result.data = vld1q_f32(p)
  else:
    for i in 0..3:
      result.data[i] = cast[ptr UncheckedArray[float32]](p)[i]

proc store*(p: ptr float32, v: Vec4f) {.inline.} =
  ## Store vector to memory
  when defined(amd64) or defined(i386):
    mm_storeu_ps(p, v.data)
  elif defined(arm) or defined(arm64):
    vst1q_f32(p, v.data)
  else:
    for i in 0..3:
      cast[ptr UncheckedArray[float32]](p)[i] = v.data[i]

# =============================================================================
# Example: SIMD Vector Add
# =============================================================================

proc vectorAdd*(dst, a, b: ptr float32, n: int) =
  ## Add two arrays element-wise using SIMD.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var i = 0
  ## # SIMD loop (process 4 floats at a time)
  ## while i + 4 <= n:
  ##   let va = load(cast[ptr float32](cast[uint](a) + i.uint * sizeof(float32)))
  ##   let vb = load(cast[ptr float32](cast[uint](b) + i.uint * sizeof(float32)))
  ##   let vr = va + vb
  ##   store(cast[ptr float32](cast[uint](dst) + i.uint * sizeof(float32)), vr)
  ##   i += 4
  ##
  ## # Scalar tail
  ## while i < n:
  ##   cast[ptr UncheckedArray[float32]](dst)[i] =
  ##     cast[ptr UncheckedArray[float32]](a)[i] +
  ##     cast[ptr UncheckedArray[float32]](b)[i]
  ##   inc i
  ## ```

  var i = 0
  # SIMD loop
  while i + 4 <= n:
    let aPtr = cast[ptr float32](cast[uint](a) + i.uint * sizeof(float32).uint)
    let bPtr = cast[ptr float32](cast[uint](b) + i.uint * sizeof(float32).uint)
    let dstPtr = cast[ptr float32](cast[uint](dst) + i.uint * sizeof(float32).uint)

    let va = load(aPtr)
    let vb = load(bPtr)
    let vr = va + vb
    store(dstPtr, vr)
    i += 4

  # Scalar tail
  let aArr = cast[ptr UncheckedArray[float32]](a)
  let bArr = cast[ptr UncheckedArray[float32]](b)
  let dstArr = cast[ptr UncheckedArray[float32]](dst)
  while i < n:
    dstArr[i] = aArr[i] + bArr[i]
    inc i

# =============================================================================
# Compiler Flags
# =============================================================================

when defined(amd64) or defined(i386):
  # Enable SSE2 by default (all x86_64 has it)
  {.passC: "-msse2".}

  # Enable AVX2 if available
  when defined(avx2):
    {.passC: "-mavx2 -mfma".}

when defined(arm64):
  # NEON is standard on ARM64
  {.passC: "-march=armv8-a".}

# =============================================================================
# Notes
# =============================================================================

## USAGE NOTES:
##
## **Compile-time selection:**
## ```nim
## when defined(avx2):
##   # Use AVX2 path
## elif defined(sse2):
##   # Use SSE2 path
## else:
##   # Scalar fallback
## ```
##
## **Alignment:**
## - Aligned loads/stores are faster
## - Allocate with 16/32-byte alignment:
##   ```nim
##   var data {.align(32).}: array[1024, float32]
##   ```
##
## **Performance:**
## - SSE: 4x speedup for float32
## - AVX2: 8x speedup for float32
## - NEON: 4x speedup for float32
##
## **Common operations:**
## - Dot product: multiply + horizontal sum
## - Matrix multiply: FMA operations
## - Image processing: parallel pixel operations
