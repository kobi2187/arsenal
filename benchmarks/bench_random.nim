## Benchmarks for Random Number Generators
## =========================================

import std/[times, strformat, random]
import ../src/arsenal/random/rng

proc benchmark(name: string, iterations: int, fn: proc()) =
  ## Run a benchmark and print results
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let opsPerSec = float(iterations) / elapsed
  let nsPerOp = (elapsed * 1_000_000_000.0) / float(iterations)

  echo &"{name:50} {opsPerSec:15.0f} ops/sec  {nsPerOp:6.2f} ns/op"

echo "Random Number Generator Benchmarks"
echo "==================================="
echo ""

# SplitMix64 Benchmarks
echo "SplitMix64 (Fast Seeding RNG):"
echo "-------------------------------"

benchmark "SplitMix64 init", 1_000_000:
  var rng = initSplitMix64(12345)

benchmark "SplitMix64 next()", 10_000_000:
  var rng = initSplitMix64(12345)
  discard rng.next()

var splitRng = initSplitMix64(12345)
benchmark "SplitMix64 next() (pre-init)", 100_000_000:
  discard splitRng.next()

echo ""

# PCG32 Benchmarks
echo "PCG32 (Permuted Congruential Generator):"
echo "-----------------------------------------"

benchmark "PCG32 init", 1_000_000:
  var rng = initPcg32(12345, 1)

benchmark "PCG32 next()", 10_000_000:
  var rng = initPcg32(12345, 1)
  discard rng.next()

var pcgRng = initPcg32(12345, 1)
benchmark "PCG32 next() (pre-init)", 100_000_000:
  discard pcgRng.next()

benchmark "PCG32 nextU64()", 10_000_000:
  discard pcgRng.nextU64()

benchmark "PCG32 nextFloat()", 10_000_000:
  discard pcgRng.nextFloat()

benchmark "PCG32 nextRange(100)", 10_000_000:
  discard pcgRng.nextRange(100)

echo ""

# Utility Function Benchmarks
echo "PCG32 Utility Functions:"
echo "------------------------"

var arr1000 = newSeq[int](1000)
for i in 0..<1000:
  arr1000[i] = i

benchmark "PCG32 shuffle (1000 elements)", 10_000:
  var arr = arr1000
  pcgRng.shuffle(arr)

var arr100 = newSeq[int](100)
for i in 0..<100:
  arr100[i] = i

benchmark "PCG32 sample (100 elements)", 10_000_000:
  discard pcgRng.sample(arr100)

echo ""

# Stdlib Random Benchmarks (Xoshiro256+)
echo "stdlib random (Xoshiro256+) - For Comparison:"
echo "----------------------------------------------"

randomize(42)

benchmark "std/random rand(int.high)", 100_000_000:
  discard rand(int.high)

benchmark "std/random rand(100)", 100_000_000:
  discard rand(100)

benchmark "std/random sample (100 elements)", 10_000_000:
  discard sample(arr100)

var arrStd = arr1000
benchmark "std/random shuffle (1000 elements)", 10_000:
  shuffle(arrStd)

echo ""

# Crypto RNG Benchmarks
when not defined(arsenal_no_crypto):
  echo "CryptoRNG (Cryptographically Secure):"
  echo "--------------------------------------"

  var cryptoRng = initCryptoRng()

  benchmark "CryptoRNG next()", 1_000_000:
    discard cryptoRng.next()

  benchmark "CryptoRNG nextBytes(32)", 1_000_000:
    discard cryptoRng.nextBytes(32)

  benchmark "CryptoRNG nextBytes(1024)", 100_000:
    discard cryptoRng.nextBytes(1024)

  echo ""

# Direct Comparison
echo "Direct Performance Comparison (100M iterations):"
echo "-------------------------------------------------"

var split = initSplitMix64(42)
var pcg = initPcg32(42, 1)

let splitStart = cpuTime()
for i in 0..<100_000_000:
  discard split.next()
let splitTime = cpuTime() - splitStart

let pcgStart = cpuTime()
for i in 0..<100_000_000:
  discard pcg.next()
let pcgTime = cpuTime() - pcgStart

randomize(42)
let stdStart = cpuTime()
for i in 0..<100_000_000:
  discard rand(int.high)
let stdTime = cpuTime() - stdStart

echo &"  SplitMix64:        {100_000_000.0 / splitTime / 1_000_000:.2f} M ops/sec  ({splitTime * 10:.2f} ns/op)"
echo &"  PCG32:             {100_000_000.0 / pcgTime / 1_000_000:.2f} M ops/sec  ({pcgTime * 10:.2f} ns/op)"
echo &"  std/random (Xo+):  {100_000_000.0 / stdTime / 1_000_000:.2f} M ops/sec  ({stdTime * 10:.2f} ns/op)"

echo ""

# Statistical Quality Note
echo "Performance Summary"
echo "==================="
echo ""
echo "Expected Performance (typical modern CPU, 3 GHz):"
echo "  - SplitMix64:      ~0.5 ns/op  (~2000 M ops/sec)"
echo "  - PCG32:           ~1.0 ns/op  (~1000 M ops/sec)"
echo "  - Xoshiro256+:     ~0.7 ns/op  (~1400 M ops/sec)"
echo "  - CryptoRNG:       ~10 ns/op   (~100 M ops/sec)"
echo ""
echo "Statistical Quality:"
echo "  - SplitMix64:      Poor (seeding only)"
echo "  - PCG32:           Good (passes PractRand)"
echo "  - Xoshiro256+:     Excellent (passes BigCrush)"
echo "  - CryptoRNG:       Cryptographically secure"
echo ""
echo "Use Cases:"
echo "  - SplitMix64:      Fast seeding for other RNGs"
echo "  - PCG32:           Parallel streams, general simulation"
echo "  - Xoshiro256+:     General purpose (stdlib, recommended)"
echo "  - CryptoRNG:       Security, cryptographic keys"
echo ""
echo "Performance vs Quality Trade-off:"
echo "  - For simulations:    Use std/random (Xoshiro256+)"
echo "  - For parallel:       Use PCG32 with different streams"
echo "  - For max speed:      Use SplitMix64 (quality trade-off)"
echo "  - For security:       Use CryptoRNG (10x slower but secure)"
echo ""
echo "Memory Usage:"
echo "  - SplitMix64:      8 bytes (state)"
echo "  - PCG32:           16 bytes (state + inc)"
echo "  - Xoshiro256+:     32 bytes (4x uint64)"
echo "  - CryptoRNG:       Varies (external libsodium)"
