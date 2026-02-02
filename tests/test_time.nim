## Tests for High-Resolution Time Functions
## ==========================================

import std/[unittest, monotimes, os, times]
import ../src/arsenal/time/clock

suite "High-Resolution Timer":
  test "timer initialization":
    let timer = startTimer()
    check timer.start != MonoTime()

  test "timer measures elapsed time":
    let timer = startTimer()
    # Do some work
    var sum = 0
    for i in 0..<1000:
      sum += i

    let elapsed = timer.elapsedNs()
    check elapsed > 0
    check elapsed < 1_000_000_000  # Less than 1 second

  test "elapsedUs returns microseconds":
    let timer = startTimer()
    sleep(1)  # Sleep 1ms
    let elapsed = timer.elapsedUs()

    check elapsed >= 800  # At least 0.8ms
    check elapsed < 10_000  # Less than 10ms

  test "elapsedMs returns milliseconds":
    let timer = startTimer()
    sleep(10)  # Sleep 10ms
    let elapsed = timer.elapsedMs()

    check elapsed >= 8  # At least 8ms (some variance)
    check elapsed < 100  # Less than 100ms

  test "elapsedSeconds returns float seconds":
    let timer = startTimer()
    sleep(100)  # Sleep 100ms
    let elapsed = timer.elapsedSeconds()

    check elapsed >= 0.08  # At least 80ms
    check elapsed < 1.0  # Less than 1 second

  test "timer is monotonic":
    let timer = startTimer()
    let t1 = timer.elapsedNs()
    let t2 = timer.elapsedNs()
    let t3 = timer.elapsedNs()

    # Time should always increase
    check t2 >= t1
    check t3 >= t2

when defined(amd64) or defined(i386):
  suite "RDTSC - CPU Cycle Counter":
    test "rdtsc returns non-zero":
      let cycles = rdtsc()
      check cycles > 0

    test "rdtsc is monotonic":
      let c1 = rdtsc()
      let c2 = rdtsc()
      let c3 = rdtsc()

      # Cycles should increase (allowing for wrap-around)
      check c2 >= c1
      check c3 >= c2

    test "rdtscp returns non-zero":
      let cycles = rdtscp()
      check cycles > 0

    test "cycle timer measures cycles":
      let timer = startCycleTimer()

      # Do some work
      var sum = 0
      for i in 0..<100:
        sum += i

      let elapsed = timer.elapsedCycles()
      check elapsed > 0
      check elapsed < 1_000_000  # Should be much less

    test "cycle timer to nanoseconds conversion":
      let timer = startCycleTimer()
      sleep(1)  # Sleep 1ms

      # Assume 2-4 GHz CPU for test
      let nsLow = timer.elapsedNs(4.0)  # 4 GHz assumption
      let nsHigh = timer.elapsedNs(2.0)  # 2 GHz assumption

      # Should be roughly 1ms
      check nsLow >= 500_000  # At least 0.5ms
      check nsHigh < 10_000_000  # Less than 10ms

    test "calibrateCpuFreq returns reasonable frequency":
      let freq = calibrateCpuFreq()

      # Modern CPUs are 0.5 - 5.5 GHz
      check freq > 0.5
      check freq < 6.0

suite "Benchmark Template":
  test "benchmark template works":
    var executed = false

    benchmark "test operation", 10:
      executed = true

    check executed

  test "benchmark measures multiple iterations":
    var count = 0

    benchmark "increment", 100:
      inc count

    check count == 100

suite "Time Integration":
  test "std/monotimes integration":
    let t1 = getMonoTime()
    sleep(1)
    let t2 = getMonoTime()

    let diff = t2 - t1
    check inMilliseconds(diff) >= 0

  test "stdlib time functions work":
    let t = getTime()
    check t.toUnix() > 0

suite "Performance Characteristics":
  test "high-res timer overhead is low":
    let timer = startTimer()

    var timings: seq[int64]
    for i in 0..<100:
      let t = startTimer()
      let elapsed = t.elapsedNs()
      timings.add(elapsed)

    # Timer overhead should be < 1000ns typically
    var allFast = true
    for timing in timings:
      if timing > 10_000:  # 10us
        allFast = false

    check allFast

  when defined(amd64) or defined(i386):
    test "rdtsc overhead is minimal":
      let t1 = rdtsc()
      let t2 = rdtsc()
      let overhead = t2 - t1

      # RDTSC overhead typically < 100 cycles
      check overhead < 1000

    test "rdtsc is faster than monotonic clock":
      # Measure rdtsc speed
      let cycleTimer = startCycleTimer()
      for i in 0..<1000:
        discard rdtsc()
      let rdtscTime = cycleTimer.elapsedCycles()

      # Measure monotonic clock speed
      let cycleTimer2 = startCycleTimer()
      for i in 0..<1000:
        discard getMonoTime()
      let monoTime = cycleTimer2.elapsedCycles()

      # RDTSC should be significantly faster
      check rdtscTime < monoTime

suite "Edge Cases":
  test "timer works with zero elapsed time":
    let timer = startTimer()
    let elapsed = timer.elapsedNs()

    # Should be >= 0 even if immediate
    check elapsed >= 0

  test "multiple timers are independent":
    let timer1 = startTimer()
    sleep(10)
    let timer2 = startTimer()
    sleep(10)

    let elapsed1 = timer1.elapsedMs()
    let elapsed2 = timer2.elapsedMs()

    # timer1 should show more elapsed time
    check elapsed1 > elapsed2

  when defined(amd64) or defined(i386):
    test "cycle timer works with zero elapsed cycles":
      let timer = startCycleTimer()
      let elapsed = timer.elapsedCycles()

      # Should be >= 0
      check elapsed >= 0

suite "Practical Usage Patterns":
  test "timing a computation":
    proc expensiveComputation(): int =
      var sum = 0
      for i in 0..<10000:
        sum += i * i
      return sum

    let timer = startTimer()
    let result = expensiveComputation()
    let elapsed = timer.elapsedUs()

    check result == 333283335000
    check elapsed > 0
    check elapsed < 100_000  # Should be < 100ms

  test "comparing two implementations":
    proc method1(): int =
      var sum = 0
      for i in 0..<1000:
        sum += i
      return sum

    proc method2(): int =
      # Gauss formula
      let n = 999
      return n * (n + 1) div 2

    let timer1 = startTimer()
    let result1 = method1()
    let time1 = timer1.elapsedNs()

    let timer2 = startTimer()
    let result2 = method2()
    let time2 = timer2.elapsedNs()

    check result1 == result2
    # Method 2 should be faster
    check time2 < time1

  test "benchmarking with warmup":
    proc operation() =
      var sum = 0
      for i in 0..<100:
        sum += i

    # Warmup (not timed)
    for i in 0..<10:
      operation()

    # Actual benchmark
    let timer = startTimer()
    for i in 0..<100:
      operation()
    let elapsed = timer.elapsedNs()

    check elapsed > 0
