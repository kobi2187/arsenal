## Benchmarks for Hash Functions
## ===============================

import std/[times, strformat, random, sugar, algorithm]
import ../src/arsenal/hashing/hashers/xxhash64
import ../src/arsenal/hashing/hashers/wyhash

# Benchmark configuration
const
  SMALL_SIZE = 32
  MEDIUM_SIZE = 4096
  LARGE_SIZE = 1048576  # 1 MB
  SEED = DefaultSeed

proc benchmarkThroughput(name: string, size: int, iterations: int, fn: proc()) =
  ## Run a benchmark and calculate throughput
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let totalBytes = float(size * iterations)
  let gbPerSec = (totalBytes / (1024.0 * 1024.0 * 1024.0)) / elapsed
  let mbPerSec = (totalBytes / (1024.0 * 1024.0)) / elapsed
  let nsPerByte = (elapsed * 1_000_000_000.0) / totalBytes

  echo &"{name:55} {gbPerSec:8.2f} GB/s  {mbPerSec:10.2f} MB/s  {nsPerByte:6.3f} ns/byte"

proc benchmark(name: string, iterations: int, fn: proc()) =
  ## Run a benchmark and print results
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let opsPerSec = float(iterations) / elapsed
  let nsPerOp = (elapsed * 1_000_000_000.0) / float(iterations)

  echo &"{name:55} {opsPerSec:15.0f} ops/sec  {nsPerOp:8.2f} ns/op"

# Generate test data
echo "Generating test data..."
var smallData = newSeq[byte](SMALL_SIZE)
var mediumData = newSeq[byte](MEDIUM_SIZE)
var largeData = newSeq[byte](LARGE_SIZE)

randomize(42)  # Deterministic for consistent benchmarks
for i in 0..<SMALL_SIZE:
  smallData[i] = byte(rand(255))
for i in 0..<MEDIUM_SIZE:
  mediumData[i] = byte(rand(255))
for i in 0..<LARGE_SIZE:
  largeData[i] = byte(rand(255))

echo ""
echo "Hash Function Benchmarks"
echo "========================"
echo ""

# XXHash64 - One-shot Hashing
echo "XXHash64 - One-shot (hash entire input at once):"
echo "-------------------------------------------------"

benchmarkThroughput "XXHash64 one-shot: 32 bytes", SMALL_SIZE, 1_000_000:
  discard XxHash64.hash(smallData, SEED)

benchmarkThroughput "XXHash64 one-shot: 4 KB", MEDIUM_SIZE, 100_000:
  discard XxHash64.hash(mediumData, SEED)

benchmarkThroughput "XXHash64 one-shot: 1 MB", LARGE_SIZE, 100:
  discard XxHash64.hash(largeData, SEED)

echo ""

# XXHash64 - Incremental Hashing
echo "XXHash64 - Incremental (streaming, chunk by chunk):"
echo "----------------------------------------------------"

benchmarkThroughput "XXHash64 incremental: 32 bytes", SMALL_SIZE, 1_000_000:
  var state = XxHash64.init(SEED)
  state.update(smallData)
  discard state.finish()

benchmarkThroughput "XXHash64 incremental: 4 KB", MEDIUM_SIZE, 100_000:
  var state = XxHash64.init(SEED)
  state.update(mediumData)
  discard state.finish()

benchmarkThroughput "XXHash64 incremental: 1 MB", LARGE_SIZE, 100:
  var state = XxHash64.init(SEED)
  state.update(largeData)
  discard state.finish()

# Incremental with small chunks (simulates streaming)
echo ""
echo "XXHash64 - Incremental with 1 KB chunks (realistic streaming):"
benchmarkThroughput "XXHash64 streaming: 1 MB (1KB chunks)", LARGE_SIZE, 100:
  var state = XxHash64.init(SEED)
  var pos = 0
  while pos < LARGE_SIZE:
    let chunkSize = min(1024, LARGE_SIZE - pos)
    state.update(largeData[pos..<(pos + chunkSize)])
    pos += chunkSize
  discard state.finish()

echo ""

# WyHash - One-shot Hashing
echo "WyHash - One-shot (hash entire input at once):"
echo "-----------------------------------------------"

benchmarkThroughput "WyHash one-shot: 32 bytes", SMALL_SIZE, 1_000_000:
  discard WyHash.hash(smallData, SEED)

benchmarkThroughput "WyHash one-shot: 4 KB", MEDIUM_SIZE, 100_000:
  discard WyHash.hash(mediumData, SEED)

benchmarkThroughput "WyHash one-shot: 1 MB", LARGE_SIZE, 100:
  discard WyHash.hash(largeData, SEED)

echo ""

# WyHash - Incremental Hashing
echo "WyHash - Incremental (streaming, chunk by chunk):"
echo "--------------------------------------------------"

benchmarkThroughput "WyHash incremental: 32 bytes", SMALL_SIZE, 1_000_000:
  var state = WyHash.init(SEED)
  state.update(smallData)
  discard state.finish()

benchmarkThroughput "WyHash incremental: 4 KB", MEDIUM_SIZE, 100_000:
  var state = WyHash.init(SEED)
  state.update(mediumData)
  discard state.finish()

benchmarkThroughput "WyHash incremental: 1 MB", LARGE_SIZE, 100:
  var state = WyHash.init(SEED)
  state.update(largeData)
  discard state.finish()

# Incremental with small chunks (simulates streaming)
echo ""
echo "WyHash - Incremental with 1 KB chunks (realistic streaming):"
benchmarkThroughput "WyHash streaming: 1 MB (1KB chunks)", LARGE_SIZE, 100:
  var state = WyHash.init(SEED)
  var pos = 0
  while pos < LARGE_SIZE:
    let chunkSize = min(1024, LARGE_SIZE - pos)
    state.update(largeData[pos..<(pos + chunkSize)])
    pos += chunkSize
  discard state.finish()

echo ""

# Direct Comparison
echo "Direct Comparison (1 MB input):"
echo "--------------------------------"

var xxhash64Result: uint64
var wyhashResult: uint64

benchmark "XXHash64 one-shot (1 MB)", 1000:
  xxhash64Result = XxHash64.hash(largeData, SEED)

benchmark "WyHash one-shot (1 MB)", 1000:
  wyhashResult = WyHash.hash(largeData, SEED)

echo ""
echo &"  XXHash64 output: 0x{xxhash64Result:016X}"
echo &"  WyHash output:   0x{wyhashResult:016X}"

echo ""

# Incremental init/finish overhead
echo "Incremental Hashing Overhead:"
echo "------------------------------"

benchmark "XXHash64 init() + finish() (empty)", 10_000_000:
  var state = XxHash64.init(SEED)
  discard state.finish()

benchmark "WyHash init() + finish() (empty)", 10_000_000:
  var state = WyHash.init(SEED)
  discard state.finish()

echo ""

echo "Performance Summary"
echo "==================="
echo ""
echo "Hash Function Characteristics:"
echo ""
echo "XXHash64:"
echo "  - Algorithm: 32-byte chunks, 4x 64-bit accumulators"
echo "  - Expected Throughput: 8-10 GB/s (single core, modern CPU)"
echo "  - Best For: General-purpose hashing, good distribution"
echo "  - Incremental: Efficient buffering, ~32 bytes overhead"
echo ""
echo "WyHash:"
echo "  - Algorithm: 48-byte chunks, wymum (128-bit multiply-mix)"
echo "  - Expected Throughput: 15-18 GB/s (fastest non-crypto hash)"
echo "  - Best For: Maximum speed, hash tables, checksums"
echo "  - Incremental: Efficient buffering, ~48 bytes overhead"
echo ""
echo "Performance Notes:"
echo "  - One-shot: Best for small inputs (< 1 KB)"
echo "  - Incremental: Necessary for large inputs or streaming"
echo "  - Chunk Size: Larger chunks (1-4 KB) reduce overhead"
echo "  - Cache Effects: Large inputs (> 256 KB) limited by RAM bandwidth"
echo ""
echo "Comparison:"
echo "  - WyHash is ~1.5-2x faster than XXHash64"
echo "  - Both have excellent hash distribution"
echo "  - XXHash64 is more widely tested/adopted"
echo "  - WyHash is simpler and faster"
echo ""
echo "Use Cases:"
echo "  - Hash Tables: WyHash (speed priority)"
echo "  - Checksums: Either (both are excellent)"
echo "  - File Hashing: Incremental mode (memory efficient)"
echo "  - Network Protocols: XXHash64 (better compatibility)"
