#!/usr/bin/env nim
## Benchmark Runner for Arsenal
## ============================
##
## Runs all performance benchmarks for the Arsenal library.
##
## Usage:
##   nim c -d:release -d:danger -r benchmarks/bench_all.nim
##   nimble bench

import benchmark
import ../src/arsenal/platform/config
import ../src/arsenal/platform/strategies

proc runBenchmarks() =
  echo "Running Arsenal benchmarks..."
  echo ""

  # Atomic operations benchmarks
  echo "=== Atomic Operations ==="
  when defined(useAtomics):
    import ../src/arsenal/concurrency/atomics/atomic

    var counter = Atomic[int].init(0)
    bench("atomic load", 10000):
      discard counter.load()

    bench("atomic store", 10000):
      counter.store(42)

    bench("atomic fetchAdd", 10000):
      discard counter.fetchAdd(1)

  echo ""

  # String search benchmarks
  echo "=== String Search ==="
  when defined(useStringSearch):
    import ../src/arsenal/strings/simd_search

    let haystack = "the quick brown fox jumps over the lazy dog" * 100
    let needle = "fox"

    bench("simdFind (small needle)", 1000):
      discard simdFind(haystack, needle)

    let longNeedle = "the quick brown fox jumps"
    bench("simdFind (long needle)", 1000):
      discard simdFind(haystack, longNeedle)

  echo ""

  # Roaring bitmap benchmarks
  echo "=== Roaring Bitmaps ==="
  when defined(useRoaring):
    import ../src/arsenal/collections/roaring

    var rb = initRoaringBitmap()
    bench("roaring add (1000 values)", 100):
      for i in 0'u32..<1000:
        rb.add(i + (100000'u32 * i))

    bench("roaring contains", 10000):
      discard rb.contains(500000)

  echo ""

  # Binary Fuse Filter benchmarks
  echo "=== Binary Fuse Filters ==="
  when defined(useBinaryFuse):
    import ../src/arsenal/sketching/membership/binary_fuse

    let keys = [1'u64, 2, 3, 5, 8, 13, 21, 34, 55, 89, 144, 233, 377, 610, 987]
    let filter = construct(keys)

    bench("binary fuse contains (hit)", 10000):
      discard filter.contains(144)

    bench("binary fuse contains (miss)", 10000):
      discard filter.contains(999999)

  echo ""
  echo "All benchmarks completed!"

when isMainModule:
  runBenchmarks()