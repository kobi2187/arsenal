## Random Number Generators
## =========================
##
## High-quality RNGs for different use cases.
## Leverages Nim's stdlib and adds alternatives.
##
## What std/random provides:
## - Rand: RNG state using Xoshiro256+ (fast, high-quality)
## - rand(), sample(), shuffle() with good statistical properties
## - Thread-safe when using separate Rand instances
##
## What this module adds:
## - PCG32: Small state, multiple independent streams (for parallel)
## - SplitMix64: Fast initialization/seeding
## - CryptoRNG: Cryptographically secure (via libsodium)
##
## When to use what:
## - **Games, simulations**: std/random (Xoshiro256+, fast, good quality)
## - **Crypto, security**: CryptoRNG (CSPRNG)
## - **Parallel**: PCG32 (multiple independent streams)
## - **Quick seed**: SplitMix64

# Re-export stdlib random (Xoshiro256+)
import std/random
export random

import std/times

# =============================================================================
# SplitMix64 (Fast Seeding)
# =============================================================================

type
  SplitMix64* = object
    ## Fast PRNG for seeding other generators.
    ## Not suitable for simulation (low quality), but very fast.
    state: uint64

proc initSplitMix64*(seed: uint64 = 0): SplitMix64 =
  ## Initialize SplitMix64 with seed.
  ## If seed is 0, uses current time.
  let s = if seed == 0: getTime().toUnix.uint64 else: seed
  result.state = s

proc next*(rng: var SplitMix64): uint64 =
  ## Generate next random uint64.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## rng.state += 0x9e3779b97f4a7c15'u64
  ## var z = rng.state
  ## z = (z xor (z shr 30)) * 0xbf58476d1ce4e5b9'u64
  ## z = (z xor (z shr 27)) * 0x94d049bb133111eb'u64
  ## result = z xor (z shr 31)
  ## ```

  rng.state += 0x9e3779b97f4a7c15'u64
  var z = rng.state
  z = (z xor (z shr 30)) * 0xbf58476d1ce4e5b9'u64
  z = (z xor (z shr 27)) * 0x94d049bb133111eb'u64
  result = z xor (z shr 31)

# =============================================================================
# PCG (Permuted Congruential Generator)
# =============================================================================

type
  Pcg32* = object
    ## PCG32 RNG - good statistical properties, small state.
    ## Supports multiple independent streams for parallel use.
    state: uint64
    inc: uint64  # Stream selector (must be odd)

proc next*(rng: var Pcg32): uint32

proc initPcg32*(seed: uint64 = 0, stream: uint64 = 1): Pcg32 =
  ## Initialize PCG32.
  ## stream: Stream selector for parallel RNG (must be odd)
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result.state = 0
  ## result.inc = (stream shl 1) or 1  # Ensure odd
  ## discard result.next()
  ## result.state += seed
  ## discard result.next()
  ## ```

  result.state = 0
  result.inc = (stream shl 1) or 1
  discard result.next()
  result.state += (if seed == 0: getTime().toUnix.uint64 else: seed)
  discard result.next()

proc next*(rng: var Pcg32): uint32 =
  ## Generate next random uint32.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let oldstate = rng.state
  ## rng.state = oldstate * 6364136223846793005'u64 + rng.inc
  ## let xorshifted = uint32(((oldstate shr 18) xor oldstate) shr 27)
  ## let rot = uint32(oldstate shr 59)
  ## result = (xorshifted shr rot) or (xorshifted shl ((- rot) and 31))
  ## ```

  let oldstate = rng.state
  rng.state = oldstate * 6364136223846793005'u64 + rng.inc
  let xorshifted = uint32(((oldstate shr 18) xor oldstate) shr 27)
  let rot = uint32(oldstate shr 59)
  result = (xorshifted shr rot) or (xorshifted shl ((-rot.int32) and 31))

proc nextU64*(rng: var Pcg32): uint64 =
  ## Generate uint64 (two calls to next)
  (rng.next().uint64 shl 32) or rng.next().uint64

proc nextFloat*(rng: var Pcg32): float =
  ## Generate float in [0.0, 1.0)
  rng.next().float / (1'u64 shl 32).float

proc nextRange*(rng: var Pcg32, max: uint32): uint32 =
  ## Generate integer in [0, max)
  ## Uses unbiased algorithm (no modulo bias)
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let threshold = (-max) mod max  # Rejection threshold
  ## while true:
  ##   let r = rng.next()
  ##   if r >= threshold:
  ##     return r mod max
  ## ```

  if max == 0: return 0
  let threshold = (0'u32 - max) mod max
  while true:
    let r = rng.next()
    if r >= threshold:
      return r mod max

# =============================================================================
# Cryptographic RNG (via libsodium)
# =============================================================================

when not defined(arsenal_no_crypto):
  import ../crypto/primitives

  type
    CryptoRng* = object
      ## Cryptographically secure RNG.
      ## Uses libsodium's randombytes.
      initialized: bool

  proc initCryptoRng*(): CryptoRng =
    ## Initialize crypto RNG.
    result.initialized = initCrypto()

  proc next*(rng: var CryptoRng): uint64 =
    ## Generate cryptographically secure uint64.
    var buf: array[8, byte]
    randombytes(buf)
    result = cast[ptr uint64](addr buf[0])[]

  proc nextBytes*(rng: var CryptoRng, n: int): seq[byte] =
    ## Generate n random bytes.
    randomBytes(n)

# =============================================================================
# Utilities
# =============================================================================

proc shuffle*[T](rng: var Pcg32, arr: var openArray[T]) =
  ## Fisher-Yates shuffle using PCG.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## for i in countdown(arr.len - 1, 1):
  ##   let j = rng.nextRange((i + 1).uint32).int
  ##   swap(arr[i], arr[j])
  ## ```

  for i in countdown(arr.len - 1, 1):
    let j = rng.nextRange((i + 1).uint32).int
    swap(arr[i], arr[j])

proc sample*[T](rng: var Pcg32, arr: openArray[T]): T =
  ## Sample random element from array.
  if arr.len == 0:
    raise newException(IndexDefect, "Cannot sample from empty array")
  arr[rng.nextRange(arr.len.uint32).int]

# =============================================================================
# Notes
# =============================================================================

## USAGE NOTES:
##
## **General Purpose (recommended):**
## ```nim
## import std/random
## randomize()  # Seed from time
## echo rand(100)  # Use stdlib Xoshiro256+
## ```
##
## **Multiple Streams (Parallel):**
## ```nim
## # Each thread gets independent stream
## var rng1 = initPcg32(seed = 12345, stream = 1)
## var rng2 = initPcg32(seed = 12345, stream = 2)
## # Can run in parallel threads safely
## ```
##
## **Cryptographic:**
## ```nim
## var rng = initCryptoRng()
## let secret = rng.nextBytes(32)  # Suitable for keys
## ```
##
## **Fast Seeding:**
## ```nim
## var sm = initSplitMix64(12345)
## var seed1 = sm.next()
## var seed2 = sm.next()
## # Use seeds for other RNGs
## ```
##
## **Performance:**
## - Xoshiro256+ (std/random): ~0.7 ns/number
## - PCG32: ~1 ns/number
## - SplitMix64: ~0.5 ns/number
## - CryptoRng (ChaCha): ~10 ns/number
##
## **Quality:**
## - std/random (Xoshiro256+): Passes BigCrush (best in class)
## - PCG32: Passes PractRand, good for simulation
## - SplitMix64: Suitable only for seeding
## - CryptoRng: Cryptographically secure
