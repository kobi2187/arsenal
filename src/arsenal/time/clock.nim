## High-Resolution Time and Clocks
## =================================
##
## Precise timing for benchmarking and real-time systems.
## Leverages Nim's std/monotimes and adds lower-level primitives.
##
## What std/monotimes provides:
## - MonoTime: Monotonic timestamp (never goes backwards)
## - getMonoTime(): Get current monotonic time
## - High-resolution cross-platform timing
##
## What this module adds:
## - RDTSC: Direct CPU cycle counter (x86, sub-nanosecond precision)
## - Convenient timer utilities
## - Benchmarking helpers

# Use stdlib for cross-platform monotonic time
import std/monotimes
export monotimes

import std/times
export times

when defined(linux) or defined(macosx):
  when defined(linux):
    import ../kernel/syscalls

# =============================================================================
# RDTSC (Read Time-Stamp Counter) - x86 only
# =============================================================================

when defined(amd64) or defined(i386):
  proc rdtsc*(): uint64 {.inline.} =
    ## Read CPU cycle counter (x86/x86_64).
    ## Precision: ~1 CPU cycle (~0.3 ns on 3GHz CPU)
    ##
    ## IMPLEMENTATION:
    ## ```nim
    ## var lo, hi: uint32
    ## {.emit: """
    ## asm volatile(
    ##   "rdtsc"
    ##   : "=a"(`lo`), "=d"(`hi`)
    ## );
    ## """.}
    ## result = (hi.uint64 shl 32) or lo.uint64
    ## ```

    var lo, hi: uint32
    {.emit: """
    asm volatile(
      "rdtsc"
      : "=a"(`lo`), "=d"(`hi`)
    );
    """.}
    result = (hi.uint64 shl 32) or lo.uint64

  proc rdtscp*(): uint64 {.inline.} =
    ## Read CPU cycle counter with serialization (prevents reordering).
    ## Use for more accurate measurements.
    var lo, hi, aux: uint32
    {.emit: """
    asm volatile(
      "rdtscp"
      : "=a"(`lo`), "=d"(`hi`), "=c"(`aux`)
    );
    """.}
    result = (hi.uint64 shl 32) or lo.uint64

  type
    CpuCycleTimer* = object
      ## CPU cycle counter timer
      start: uint64

  proc startCycleTimer*(): CpuCycleTimer {.inline.} =
    ## Start cycle counter timer
    result.start = rdtsc()

  proc elapsedCycles*(timer: CpuCycleTimer): uint64 {.inline.} =
    ## Get elapsed cycles
    rdtsc() - timer.start

  proc elapsedNs*(timer: CpuCycleTimer, cpuFreqGHz: float): uint64 {.inline.} =
    ## Convert cycles to nanoseconds
    ## cpuFreqGHz: CPU frequency in GHz (e.g., 3.5 for 3.5GHz)
    uint64(timer.elapsedCycles().float / cpuFreqGHz)

# =============================================================================
# High-Resolution Timer (uses std/monotimes)
# =============================================================================

type
  HighResTimer* = object
    ## High-resolution timer using std/monotimes
    start: MonoTime

proc startTimer*(): HighResTimer {.inline.} =
  ## Start high-resolution timer (cross-platform)
  result.start = getMonoTime()

proc elapsedNs*(timer: HighResTimer): int64 {.inline.} =
  ## Get elapsed nanoseconds
  inNanoseconds(getMonoTime() - timer.start)

proc elapsedUs*(timer: HighResTimer): int64 {.inline.} =
  ## Get elapsed microseconds
  inMicroseconds(getMonoTime() - timer.start)

proc elapsedMs*(timer: HighResTimer): int64 {.inline.} =
  ## Get elapsed milliseconds
  inMilliseconds(getMonoTime() - timer.start)

proc elapsedSeconds*(timer: HighResTimer): float {.inline.} =
  ## Get elapsed seconds as float
  timer.elapsedNs().float / 1_000_000_000.0

# =============================================================================
# Benchmarking Utilities
# =============================================================================

template benchmark*(name: string, iterations: int, body: untyped) =
  ## Simple benchmark macro.
  ##
  ## Usage:
  ## ```nim
  ## benchmark "my operation", 1000:
  ##   someOperation()
  ## ```

  block:
    let timer = startTimer()
    for i in 0..<iterations:
      body
    let elapsed = timer.elapsedNs()
    let perOp = elapsed.float / iterations.float
    echo name, ": ", perOp, " ns/op (", iterations, " iterations)"

proc calibrateCpuFreq*(): float =
  ## Calibrate CPU frequency by comparing RDTSC to monotonic clock.
  ## Returns frequency in GHz.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(amd64) or defined(i386):
  ##   let start = rdtsc()
  ##   let wallStart = getMonoTime()
  ##   sleep(100)
  ##   let wallEnd = getMonoTime()
  ##   let endCycles = rdtsc()
  ##
  ##   let cycles = (endCycles - start).float
  ##   let nanos = inNanoseconds(wallEnd - wallStart).float
  ##   result = cycles / nanos  # GHz
  ## ```

  when defined(amd64) or defined(i386):
    let start = rdtsc()
    let wallStart = getMonoTime()
    sleep(100)
    let wallEnd = getMonoTime()
    let endCycles = rdtsc()

    let cycles = (endCycles - start).float
    let nanos = inNanoseconds(wallEnd - wallStart).float
    result = cycles / nanos
  else:
    # Not applicable on non-x86
    result = 0.0

# =============================================================================
# Notes
# =============================================================================

## USAGE NOTES:
##
## **For general timing (recommended):**
## ```nim
## import std/monotimes
## let start = getMonoTime()
## doWork()
## echo "Elapsed: ", inMilliseconds(getMonoTime() - start), " ms"
## ```
##
## **For cycle-accurate benchmarking (x86 only):**
## ```nim
## when defined(amd64):
##   let timer = startCycleTimer()
##   criticalSection()
##   echo "Cycles: ", timer.elapsedCycles()
## ```
##
## **For convenient timing:**
## ```nim
## let timer = startTimer()
## doWork()
## echo "Elapsed: ", timer.elapsedMs(), " ms"
## ```
##
## **Precision:**
## - std/monotimes: ~20 ns resolution (platform-dependent)
## - RDTSC: ~0.3 ns (1 CPU cycle)
##
## **Caveats:**
## - RDTSC can be affected by CPU frequency scaling
## - Always warm up code before benchmarking
## - Run multiple iterations for statistical significance
