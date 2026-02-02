## Benchmarking Framework
## ======================
##
## High-resolution timing utilities for performance measurement.
##
## Usage:
## ```nim
## import benchmark
##
## bench("my operation"):
##   myFunction()
##
## bench("compare implementations", iterations=1000):
##   # Measure this block
##   result = expensiveComputation()
## ```

import std/monotimes
import std/times
import std/strutils
import std/math

type
  BenchmarkResult* = object
    name*: string
    iterations*: int
    totalTime*: Duration
    avgTime*: Duration
    minTime*: Duration
    maxTime*: Duration
    opsPerSec*: float
    percentiles*: array[5, Duration]  # 50th, 75th, 90th, 95th, 99th

# =============================================================================
# High-Resolution Timer
# =============================================================================

when defined(amd64):
  # Use RDTSC for highest precision on x86_64
  proc rdtsc(): uint64 {.importc: "__builtin_ia32_rdtsc", header: "<x86intrin.h>".}

  proc getTime(): uint64 =
    rdtsc()
elif defined(arm64):
  # Use ARM PMCCNTR_EL0 register (Performance Monitors Cycle Counter)
  proc getTime(): uint64 =
    ## Read the ARM64 cycle counter register (PMCCNTR_EL0)
    ## This provides high-resolution CPU cycle counts
    when defined(gcc) or defined(clang) or defined(llvm_gcc):
      {.emit: """
        uint64_t count;
        __asm__ __volatile__(
          "mrs %0, pmccntr_el0"
          : "=r" (count)
        );
        `result` = count;
      """.}
    else:
      # Fallback for other compilers
      getMonoTime().ticks.uint64
else:
  proc getTime(): uint64 =
    getMonoTime().ticks.uint64

# =============================================================================
# Benchmark Template
# =============================================================================

template bench*(name: string, iterations: int = 1000, body: untyped) =
  ## Benchmark a block of code.
  ##
  ## Parameters:
  ## - name: Descriptive name for the benchmark
  ## - iterations: Number of times to run (default: 1000)
  ## - body: Code block to benchmark
  ##
  ## Example:
  ## ```nim
  ## bench("fibonacci(30)"):
  ##   discard fib(30)
  ## ```

  # Warmup
  for _ in 0..<10:
    body

  # Measure
  var times: seq[Duration]
  for _ in 0..<iterations:
    let start = getMonoTime()
    body
    let elapsed = getMonoTime() - start
    times.add(elapsed)

  # Calculate statistics
  var result = BenchmarkResult(
    name: name,
    iterations: iterations,
    totalTime: sum(times),
    minTime: min(times),
    maxTime: max(times)
  )

  result.avgTime = result.totalTime div iterations

  # Calculate ops/sec
  let totalNs = result.totalTime.inNanoseconds.float
  result.opsPerSec = iterations.float / (totalNs / 1_000_000_000.0)

  # Calculate percentiles
  sort(times, proc(a, b: Duration): int = cmp(a.inNanoseconds, b.inNanoseconds))
  result.percentiles[0] = times[(iterations * 50) div 100]  # 50th
  result.percentiles[1] = times[(iterations * 75) div 100]  # 75th
  result.percentiles[2] = times[(iterations * 90) div 100]  # 90th
  result.percentiles[3] = times[(iterations * 95) div 100]  # 95th
  result.percentiles[4] = times[(iterations * 99) div 100]  # 99th

  # Print results
  echo "Benchmark: ", name
  echo "  Iterations: ", iterations
  echo "  Total time: ", result.totalTime
  echo "  Avg time: ", result.avgTime
  echo "  Min time: ", result.minTime
  echo "  Max time: ", result.maxTime
  echo "  Ops/sec: ", formatFloat(result.opsPerSec, ffDecimal, 2)
  echo "  P50: ", result.percentiles[0]
  echo "  P99: ", result.percentiles[4]
  echo ""

# =============================================================================
# Benchmark Runner
# =============================================================================

proc runBenchmarks*() =
  ## Run all benchmarks. Override this in bench_all.nim
  echo "No benchmarks defined. Override runBenchmarks() in your bench_all.nim"