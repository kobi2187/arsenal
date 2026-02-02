## Benchmarks for Bit Manipulation Operations
## ============================================

import std/[times, strformat, sugar, algorithm]
import ../src/arsenal/bits/bitops

proc benchmark(name: string, iterations: int, fn: proc()) =
  ## Run a benchmark and print results
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let opsPerSec = float(iterations) / elapsed
  let nsPerOp = (elapsed * 1_000_000_000.0) / float(iterations)

  echo &"{name:55} {opsPerSec:12.0f} ops/sec  {nsPerOp:6.2f} ns/op"

echo "Bit Manipulation Benchmarks"
echo "============================"
echo ""

# Count Leading Zeros (CLZ)
echo "Count Leading Zeros (CLZ):"
echo "--------------------------"

var testVal32 = 0x12345678'u32
benchmark "countLeadingZeros (uint32)", 100_000_000:
  discard countLeadingZeros(testVal32)

var testVal64 = 0x123456789ABCDEF0'u64
benchmark "countLeadingZeros (uint64)", 100_000_000:
  discard countLeadingZeros(testVal64)

benchmark "clz alias (uint32)", 100_000_000:
  discard clz(testVal32)

echo ""

# Count Trailing Zeros (CTZ)
echo "Count Trailing Zeros (CTZ):"
echo "----------------------------"

benchmark "countTrailingZeros (uint32)", 100_000_000:
  discard countTrailingZeros(testVal32)

benchmark "countTrailingZeros (uint64)", 100_000_000:
  discard countTrailingZeros(testVal64)

benchmark "ctz alias (uint32)", 100_000_000:
  discard ctz(testVal32)

echo ""

# Population Count (POPCNT)
echo "Population Count (POPCNT):"
echo "--------------------------"

benchmark "popcount (uint32)", 100_000_000:
  discard popcount(testVal32)

benchmark "popcount (uint64)", 100_000_000:
  discard popcount(testVal64)

benchmark "popcount (all ones uint32)", 100_000_000:
  discard popcount(0xFFFFFFFF'u32)

benchmark "popcount (all ones uint64)", 100_000_000:
  discard popcount(0xFFFFFFFFFFFFFFFF'u64)

echo ""

# Byte Swap
echo "Byte Swap (Endianness Conversion):"
echo "-----------------------------------"

var val16 = 0x1234'u16
benchmark "byteSwap (uint16)", 100_000_000:
  discard byteSwap(val16)

benchmark "byteSwap (uint32)", 100_000_000:
  discard byteSwap(testVal32)

benchmark "byteSwap (uint64)", 100_000_000:
  discard byteSwap(testVal64)

echo ""

# Rotate
echo "Rotate Operations:"
echo "------------------"

benchmark "rotateLeft (uint32, 7)", 100_000_000:
  discard rotateLeft(testVal32, 7)

benchmark "rotateLeft (uint64, 13)", 100_000_000:
  discard rotateLeft(testVal64, 13)

benchmark "rotateRight (uint32, 7)", 100_000_000:
  discard rotateRight(testVal32, 7)

benchmark "rotateRight (uint64, 13)", 100_000_000:
  discard rotateRight(testVal64, 13)

echo ""

# Power of Two Operations
echo "Power of Two Operations:"
echo "------------------------"

var pow2Val = 1024'u32
benchmark "isPowerOfTwo (uint32)", 100_000_000:
  discard isPowerOfTwo(pow2Val)

var nonPow2 = 1023'u32
benchmark "isPowerOfTwo (non-power, uint32)", 100_000_000:
  discard isPowerOfTwo(nonPow2)

benchmark "nextPowerOfTwo (uint32)", 100_000_000:
  discard nextPowerOfTwo(nonPow2)

benchmark "nextPowerOfTwo (uint64)", 100_000_000:
  discard nextPowerOfTwo(1023'u64)

benchmark "log2Floor (uint32)", 100_000_000:
  discard log2Floor(testVal32)

benchmark "log2Floor (uint64)", 100_000_000:
  discard log2Floor(testVal64)

echo ""

# Bit Extraction
echo "Bit Extraction:"
echo "---------------"

benchmark "extractBits (8 bits)", 50_000_000:
  discard extractBits(testVal64, 8, 8)

benchmark "extractBits (16 bits)", 50_000_000:
  discard extractBits(testVal64, 0, 16)

echo ""

# Parallel Bit Operations (BMI2-style)
echo "Parallel Bit Operations (BMI2-style):"
echo "--------------------------------------"

var mask = 0xAAAAAAAAAAAAAAAA'u64
benchmark "depositBits", 1_000_000:
  discard depositBits(0xFF'u64, mask)

benchmark "extractBitsParallel", 1_000_000:
  discard extractBitsParallel(testVal64, mask)

echo ""

# Real-World Use Cases
echo "Real-World Use Case Benchmarks:"
echo "--------------------------------"

benchmark "Isolate lowest set bit", 100_000_000:
  discard testVal32 and (0'u32 - testVal32)

benchmark "Clear lowest set bit", 100_000_000:
  discard testVal32 and (testVal32 - 1)

benchmark "Check if bit N is set", 100_000_000:
  discard (testVal32 and (1'u32 shl 15)) != 0

benchmark "Set bit N", 100_000_000:
  discard testVal32 or (1'u32 shl 15)

benchmark "Clear bit N", 100_000_000:
  discard testVal32 and not (1'u32 shl 15)

benchmark "Toggle bit N", 100_000_000:
  discard testVal32 xor (1'u32 shl 15)

echo ""

# Bit Scan Operations
echo "Bit Scan Operations:"
echo "--------------------"

benchmark "Find first set bit (ffs)", 100_000_000:
  discard countTrailingZeros(testVal32)

benchmark "Find last set bit", 100_000_000:
  discard 31 - countLeadingZeros(testVal32)

echo ""

# Loop-Based Operations
echo "Loop Performance (Iterating Set Bits):"
echo "---------------------------------------"

proc iterateSetBits(x: uint64): int =
  ## Count set bits by iterating (for comparison)
  var count = 0
  var val = x
  while val != 0:
    val = val and (val - 1)  # Clear lowest bit
    inc count
  return count

benchmark "Iterate set bits (loop method)", 10_000_000:
  discard iterateSetBits(testVal64)

benchmark "Iterate set bits (popcount)", 100_000_000:
  discard popcount(testVal64)

echo ""

# Performance Comparison
echo "Direct Performance Comparison (100M iterations):"
echo "-------------------------------------------------"

let startClz = cpuTime()
for i in 0..<100_000_000:
  discard countLeadingZeros(testVal32)
let clzTime = cpuTime() - startClz

let startCtz = cpuTime()
for i in 0..<100_000_000:
  discard countTrailingZeros(testVal32)
let ctzTime = cpuTime() - startCtz

let startPopcnt = cpuTime()
for i in 0..<100_000_000:
  discard popcount(testVal32)
let popcntTime = cpuTime() - startPopcnt

let startRotate = cpuTime()
for i in 0..<100_000_000:
  discard rotateLeft(testVal32, 7)
let rotateTime = cpuTime() - startRotate

echo &"  CLZ:        {100_000_000.0 / clzTime / 1_000_000:.2f} M ops/sec  ({clzTime * 10:.2f} ns/op)"
echo &"  CTZ:        {100_000_000.0 / ctzTime / 1_000_000:.2f} M ops/sec  ({ctzTime * 10:.2f} ns/op)"
echo &"  POPCNT:     {100_000_000.0 / popcntTime / 1_000_000:.2f} M ops/sec  ({popcntTime * 10:.2f} ns/op)"
echo &"  ROTATE:     {100_000_000.0 / rotateTime / 1_000_000:.2f} M ops/sec  ({rotateTime * 10:.2f} ns/op)"

echo ""

# Performance Summary
echo "Performance Summary"
echo "==================="
echo ""
echo "Expected Performance (typical modern CPU with hardware support):"
echo "  Operation          | Software  | Hardware  | Instruction"
echo "  -------------------|-----------|-----------|----------------"
echo "  CLZ (uint32)       | ~5 ns     | ~1-2 ns   | BSR/LZCNT"
echo "  CTZ (uint32)       | ~5 ns     | ~1-2 ns   | BSF/TZCNT"
echo "  POPCNT (uint32)    | ~5 ns     | ~1-2 ns   | POPCNT"
echo "  Rotate             | ~1 ns     | ~1 ns     | ROL/ROR"
echo "  Byte Swap          | ~2 ns     | ~1-2 ns   | BSWAP/REV"
echo "  Is Power of 2      | ~1 ns     | ~1 ns     | Bit ops"
echo "  Next Power of 2    | ~5 ns     | ~2-3 ns   | CLZ + shift"
echo ""
echo "Hardware Instruction Sets:"
echo "  - x86:  BSR, BSF, BSWAP, ROL, ROR"
echo "  - x86 (BMI1): TZCNT, LZCNT, BEXTR"
echo "  - x86 (BMI2): PDEP, PEXT"
echo "  - x86 (ABM): POPCNT"
echo "  - ARM:  CLZ, RBIT, REV, ROR"
echo "  - ARM (v8): CLS, CLZ"
echo ""
echo "Performance Notes:"
echo "  1. Hardware instructions ~5-10x faster than software"
echo "  2. Compiler auto-detects and uses intrinsics when available"
echo "  3. Portable fallbacks ensure correctness on all platforms"
echo "  4. Most operations are 1-2 cycles with hardware support"
echo ""
echo "Common Use Cases:"
echo "  - CLZ/CTZ:       Binary search, allocation sizes, sparse sets"
echo "  - POPCNT:        Hamming distance, bit set cardinality"
echo "  - Rotate:        Cryptography, hash functions, bit permutations"
echo "  - Byte Swap:     Network protocols (endianness conversion)"
echo "  - Power of 2:    Memory allocation, hash table sizing"
echo ""
echo "Optimization Tips:"
echo "  1. Use compiler intrinsics for guaranteed hardware usage"
echo "  2. Profile to identify bit operation bottlenecks"
echo "  3. Consider SIMD for bulk bit operations"
echo "  4. BMI1/BMI2 (x86) provide advanced bit manipulation"
echo "  5. Check CPU support at runtime for optimal path"
echo ""
echo "Hardware Support Detection:"
echo "  - x86: Check CPUID for POPCNT, BMI1, BMI2"
echo "  - ARM: All ARMv5+ have CLZ"
echo "  - RISC-V: B extension provides bit manipulation"
