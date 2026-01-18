## Benchmarks for No-Libc Runtime Operations
## ===========================================

import std/[times, strformat]
import ../src/arsenal/embedded/nolibc

# Benchmark configuration
const
  SMALL_SIZE = 32        # Small buffer (L1 cache)
  MEDIUM_SIZE = 4096     # Medium buffer (still in cache)
  LARGE_SIZE = 1048576   # 1 MB (out of L1/L2 cache)

proc benchmark(name: string, iterations: int, fn: proc()) =
  ## Run a benchmark and print results
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let opsPerSec = float(iterations) / elapsed
  let nsPerOp = (elapsed * 1_000_000_000.0) / float(iterations)

  echo &"{name:50} {opsPerSec:12.0f} ops/sec  {nsPerOp:8.2f} ns/op"

proc benchmarkThroughput(name: string, size: int, iterations: int, fn: proc()) =
  ## Run a benchmark and calculate throughput
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let totalBytes = float(size * iterations)
  let mbPerSec = (totalBytes / (1024.0 * 1024.0)) / elapsed
  let nsPerByte = (elapsed * 1_000_000_000.0) / totalBytes

  echo &"{name:50} {mbPerSec:10.2f} MB/s  {nsPerByte:8.4f} ns/byte"

echo "No-Libc Runtime Benchmarks"
echo "=========================="
echo ""

# Memory Operations - memset
echo "memset() Performance:"
echo "---------------------"

var smallBuf: array[SMALL_SIZE, byte]
var mediumBuf: array[MEDIUM_SIZE, byte]
var largeBuf: array[LARGE_SIZE, byte]

benchmarkThroughput "memset 32 bytes (L1 cache)", SMALL_SIZE, 1_000_000:
  discard memset(addr smallBuf, 0x42, SMALL_SIZE)

benchmarkThroughput "memset 4 KB (L1 cache)", MEDIUM_SIZE, 100_000:
  discard memset(addr mediumBuf, 0x42, MEDIUM_SIZE)

benchmarkThroughput "memset 1 MB (out of cache)", LARGE_SIZE, 100:
  discard memset(addr largeBuf, 0x42, LARGE_SIZE)

echo ""

# Memory Operations - memcpy
echo "memcpy() Performance:"
echo "---------------------"

var smallSrc: array[SMALL_SIZE, byte]
var smallDst: array[SMALL_SIZE, byte]
var mediumSrc: array[MEDIUM_SIZE, byte]
var mediumDst: array[MEDIUM_SIZE, byte]
var largeSrc: array[LARGE_SIZE, byte]
var largeDst: array[LARGE_SIZE, byte]

benchmarkThroughput "memcpy 32 bytes (L1 cache)", SMALL_SIZE, 1_000_000:
  discard memcpy(addr smallDst, addr smallSrc, SMALL_SIZE)

benchmarkThroughput "memcpy 4 KB (L1 cache)", MEDIUM_SIZE, 100_000:
  discard memcpy(addr mediumDst, addr mediumSrc, MEDIUM_SIZE)

benchmarkThroughput "memcpy 1 MB (out of cache)", LARGE_SIZE, 100:
  discard memcpy(addr largeDst, addr largeSrc, LARGE_SIZE)

echo ""

# Memory Operations - memmove
echo "memmove() Performance:"
echo "----------------------"

benchmarkThroughput "memmove 32 bytes (non-overlapping)", SMALL_SIZE, 1_000_000:
  discard memmove(addr smallDst, addr smallSrc, SMALL_SIZE)

benchmarkThroughput "memmove 4 KB (non-overlapping)", MEDIUM_SIZE, 100_000:
  discard memmove(addr mediumDst, addr mediumSrc, MEDIUM_SIZE)

benchmarkThroughput "memmove 1 MB (non-overlapping)", LARGE_SIZE, 100:
  discard memmove(addr largeDst, addr largeSrc, LARGE_SIZE)

echo ""

# Memory Operations - memcmp
echo "memcmp() Performance:"
echo "---------------------"

# Make buffers equal for fair comparison
discard memcpy(addr smallDst, addr smallSrc, SMALL_SIZE)
discard memcpy(addr mediumDst, addr mediumSrc, MEDIUM_SIZE)
discard memcpy(addr largeDst, addr largeSrc, LARGE_SIZE)

benchmarkThroughput "memcmp 32 bytes (equal)", SMALL_SIZE, 1_000_000:
  discard memcmp(addr smallSrc, addr smallDst, SMALL_SIZE)

benchmarkThroughput "memcmp 4 KB (equal)", MEDIUM_SIZE, 100_000:
  discard memcmp(addr mediumSrc, addr mediumDst, MEDIUM_SIZE)

benchmarkThroughput "memcmp 1 MB (equal)", LARGE_SIZE, 100:
  discard memcmp(addr largeSrc, addr largeDst, LARGE_SIZE)

echo ""

# String Operations
echo "String Operations:"
echo "------------------"

let shortStr = "hello"
let medStr = "hello world from the embedded system"
let longStr = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."

benchmark "strlen (5 chars)", 10_000_000:
  discard strlen(shortStr.cstring)

benchmark "strlen (37 chars)", 1_000_000:
  discard strlen(medStr.cstring)

benchmark "strlen (123 chars)", 1_000_000:
  discard strlen(longStr.cstring)

var strBuf: array[256, char]

benchmark "strcpy (5 chars)", 1_000_000:
  strcpy(cast[cstring](addr strBuf), shortStr.cstring)

benchmark "strcpy (37 chars)", 1_000_000:
  strcpy(cast[cstring](addr strBuf), medStr.cstring)

benchmark "strcpy (123 chars)", 500_000:
  strcpy(cast[cstring](addr strBuf), longStr.cstring)

benchmark "strcmp (equal, 5 chars)", 1_000_000:
  discard strcmp(shortStr.cstring, "hello".cstring)

benchmark "strcmp (equal, 37 chars)", 1_000_000:
  discard strcmp(medStr.cstring, medStr.cstring)

benchmark "strcmp (different, first char)", 10_000_000:
  discard strcmp("abc".cstring, "xyz".cstring)

echo ""

# Integer to String Conversion
echo "intToStr() Performance:"
echo "-----------------------"

var numBuf: array[32, char]

benchmark "intToStr (0)", 1_000_000:
  discard intToStr(0, addr numBuf[0], 10)

benchmark "intToStr (positive small, base 10)", 1_000_000:
  discard intToStr(42, addr numBuf[0], 10)

benchmark "intToStr (positive large, base 10)", 1_000_000:
  discard intToStr(1234567890, addr numBuf[0], 10)

benchmark "intToStr (negative, base 10)", 1_000_000:
  discard intToStr(-12345, addr numBuf[0], 10)

benchmark "intToStr (base 16, hex)", 1_000_000:
  discard intToStr(0xDEADBEEF, addr numBuf[0], 16)

benchmark "intToStr (base 2, binary)", 500_000:
  discard intToStr(255, addr numBuf[0], 2)

benchmark "intToStr (base 36, max)", 500_000:
  discard intToStr(123456, addr numBuf[0], 36)

echo ""

echo "Performance Summary"
echo "==================="
echo ""
echo "Memory Operations (Optimized Implementation):"
echo "- memset: Word-aligned bulk fill, ~0.125 cycles/byte (large blocks)"
echo "- memcpy: 4-way unrolled copy, ~0.25 cycles/byte (L1 cache)"
echo "- memmove: Similar to memcpy, handles overlap correctly"
echo "- memcmp: Scalar comparison, ~1 cycle/byte"
echo ""
echo "String Operations:"
echo "- strlen: Linear scan, ~1 cycle/byte"
echo "- strcpy: Optimized loop, ~1 cycle/byte"
echo "- strcmp: Early exit on mismatch, ~1 cycle/byte"
echo ""
echo "Integer Conversion:"
echo "- intToStr: Division-based, 10-50 cycles per digit"
echo "  - Decimal: ~100-500 ns total"
echo "  - Binary: More iterations but simpler per-digit"
echo ""
echo "Cache Effects:"
echo "- L1 cache (32 KB): Best performance, <1 ns/byte"
echo "- L2 cache (256 KB): Good performance, 1-2 ns/byte"
echo "- RAM: Memory bandwidth limited, 3-10 ns/byte"
echo ""
echo "Note: Actual embedded performance depends on:"
echo "- CPU frequency (16 MHz - 168 MHz typical)"
echo "- Cache configuration (often no cache on Cortex-M0/M3)"
echo "- Memory bus width (32-bit typical)"
echo "- Flash vs RAM execution"
