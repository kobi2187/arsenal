## Benchmarks for High-Resolution Time Functions
## ===============================================

import std/[times, strformat, monotimes]
import ../src/arsenal/time/clock

proc benchmark(name: string, iterations: int, fn: proc()) =
  ## Run a benchmark and print results
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let opsPerSec = float(iterations) / elapsed
  let nsPerOp = (elapsed * 1_000_000_000.0) / float(iterations)

  echo &"{name:55} {opsPerSec:12.0f} ops/sec  {nsPerOp:8.2f} ns/op"

echo "High-Resolution Time Benchmarks"
echo "================================"
echo ""

# High-Resolution Timer Benchmarks
echo "High-Resolution Timer (std/monotimes):"
echo "---------------------------------------"

benchmark "startTimer()", 10_000_000:
  discard startTimer()

let timer = startTimer()
benchmark "timer.elapsedNs()", 10_000_000:
  discard timer.elapsedNs()

benchmark "timer.elapsedUs()", 10_000_000:
  discard timer.elapsedUs()

benchmark "timer.elapsedMs()", 10_000_000:
  discard timer.elapsedMs()

benchmark "timer.elapsedSeconds()", 10_000_000:
  discard timer.elapsedSeconds()

echo ""

# RDTSC Benchmarks (x86 only)
when defined(amd64) or defined(i386):
  echo "RDTSC (CPU Cycle Counter) - x86/x86_64 only:"
  echo "---------------------------------------------"

  benchmark "rdtsc()", 100_000_000:
    discard rdtsc()

  benchmark "rdtscp() (serializing)", 100_000_000:
    discard rdtscp()

  benchmark "startCycleTimer()", 10_000_000:
    discard startCycleTimer()

  let cycleTimer = startCycleTimer()
  benchmark "cycleTimer.elapsedCycles()", 10_000_000:
    discard cycleTimer.elapsedCycles()

  benchmark "cycleTimer.elapsedNs()", 10_000_000:
    discard cycleTimer.elapsedNs(3.0)

  echo ""

# Stdlib Monotimes Benchmarks (for comparison)
echo "std/monotimes (Platform Monotonic Clock):"
echo "------------------------------------------"

benchmark "getMonoTime()", 10_000_000:
  discard getMonoTime()

let mono1 = getMonoTime()
let mono2 = getMonoTime()
benchmark "MonoTime subtraction", 10_000_000:
  discard mono2 - mono1

benchmark "inNanoseconds()", 10_000_000:
  discard inNanoseconds(mono2 - mono1)

benchmark "inMicroseconds()", 10_000_000:
  discard inMicroseconds(mono2 - mono1)

benchmark "inMilliseconds()", 10_000_000:
  discard inMilliseconds(mono2 - mono1)

echo ""

# Stdlib Times Benchmarks (wall clock)
echo "std/times (Wall Clock Time):"
echo "----------------------------"

benchmark "getTime()", 10_000_000:
  discard getTime()

benchmark "now()", 1_000_000:
  discard now()

echo ""

# Timing Overhead Measurement
echo "Timing Overhead Measurement:"
echo "----------------------------"

# Measure overhead of different timing methods
var dummy = 0

let overheadTimer = startTimer()
for i in 0..<1_000_000:
  let t = startTimer()
  discard t.elapsedNs()
let timerOverhead = overheadTimer.elapsedNs() / 1_000_000

when defined(amd64) or defined(i386):
  let rdtscOverheadTimer = startTimer()
  for i in 0..<1_000_000:
    discard rdtsc()
  let rdtscOverhead = rdtscOverheadTimer.elapsedNs() / 1_000_000

  let rdtscpOverheadTimer = startTimer()
  for i in 0..<1_000_000:
    discard rdtscp()
  let rdtscpOverhead = rdtscpOverheadTimer.elapsedNs() / 1_000_000

let monoOverheadTimer = startTimer()
for i in 0..<1_000_000:
  discard getMonoTime()
let monoOverhead = monoOverheadTimer.elapsedNs() / 1_000_000

echo &"  HighResTimer overhead:     {timerOverhead:8.2f} ns"
when defined(amd64) or defined(i386):
  echo &"  RDTSC overhead:            {rdtscOverhead:8.2f} ns"
  echo &"  RDTSCP overhead:           {rdtscpOverhead:8.2f} ns"
echo &"  std/monotimes overhead:    {monoOverhead:8.2f} ns"

echo ""

# Calibration Test
when defined(amd64) or defined(i386):
  echo "CPU Frequency Calibration:"
  echo "--------------------------"

  echo "  Calibrating CPU frequency (takes ~100ms)..."
  let freq = calibrateCpuFreq()
  echo &"  Estimated CPU frequency: {freq:.3f} GHz"
  echo ""

# Benchmark Template Test
echo "Benchmark Template:"
echo "-------------------"

var sum = 0
benchmark "simple computation", 10_000:
  for i in 0..<1000:
    sum += i

echo ""

# Real-World Scenario: Timing a Sort
echo "Real-World Timing Example (Sorting 10K items):"
echo "-----------------------------------------------"

import std/algorithm

proc timeSort() =
  var data = newSeq[int](10000)
  for i in 0..<10000:
    data[i] = 10000 - i

  let timer = startTimer()
  data.sort()
  let elapsed = timer.elapsedUs()

  echo &"  Sort completed in: {elapsed} μs ({elapsed.float / 1000.0:.2f} ms)"

timeSort()

echo ""

# Performance Summary
echo "Performance Summary"
echo "==================="
echo ""
echo "Timing Method Comparison:"
echo "  Method              | Overhead  | Resolution | Use Case"
echo "  --------------------|-----------|------------|---------------------------"
when defined(amd64) or defined(i386):
  echo "  RDTSC               | ~3-10 ns  | ~0.3 ns    | Micro-benchmarks, inner loops"
  echo "  RDTSCP              | ~10-20 ns | ~0.3 ns    | Accurate measurements (serializing)"
echo "  HighResTimer        | ~20-30 ns | ~10-20 ns  | General purpose"
echo "  std/monotimes       | ~20-30 ns | ~10-20 ns  | Cross-platform timing"
echo "  std/times           | ~50-100 ns| ~1 μs      | Wall clock time"
echo ""
echo "Recommendations:"
echo "  - General timing:      Use HighResTimer or std/monotimes"
echo "  - Micro-benchmarks:    Use RDTSC (x86 only)"
echo "  - Production code:     Use std/monotimes (portable)"
echo "  - Wall clock:          Use std/times"
echo ""
when defined(amd64) or defined(i386):
  echo "RDTSC Caveats (x86 only):"
  echo "  - Affected by CPU frequency scaling"
  echo "  - Can be out of order (use RDTSCP for serialization)"
  echo "  - May vary between CPU cores"
  echo "  - Need calibration for time conversion"
  echo ""
echo "Best Practices:"
  echo "  1. Always warm up code before benchmarking"
echo "  2. Run multiple iterations for statistics"
echo "  3. Disable frequency scaling for consistent results"
echo "  4. Use RDTSCP for barriers around measured code"
echo "  5. Consider cache effects in measurements"
echo ""
echo "Typical Resolution:"
when defined(amd64) or defined(i386):
  echo "  - RDTSC:           ~0.3 ns (1 CPU cycle @ 3 GHz)"
echo "  - Linux:           ~10-20 ns (CLOCK_MONOTONIC)"
echo "  - Windows:         ~100 ns (QueryPerformanceCounter)"
echo "  - macOS:           ~40 ns (mach_absolute_time)"
