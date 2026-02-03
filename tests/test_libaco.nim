## Test libaco bindings
## ====================
##
## Tests for Arsenal's libaco bindings.
## libaco requires one-time thread initialization, then creates
## a main_co as the "caller" context for all coroutines.

import ../src/arsenal/concurrency/coroutines/libaco
import std/[times, strutils]

# =============================================================================
# Global state for tests (cdecl procs can't capture)
# =============================================================================

var testValue = 0
var multiCounter = 0
var benchYieldCount = 0

# Single thread initialization and main context
var mainCo: ptr AcoHandle
var sharedStack: ptr AcoShareStack

proc initForTests() =
  ## Initialize libaco once for all tests
  aco_thread_init(nil)
  mainCo = aco_create(nil, nil, 0, nil, nil)
  sharedStack = aco_share_stack_new(0)  # 0 = default 2MB

proc cleanupAfterTests() =
  ## Cleanup after all tests
  aco_share_stack_destroy(sharedStack)
  aco_destroy(mainCo)

# =============================================================================
# Test 1: Basic Context Switch
# =============================================================================

proc coroFunc() {.cdecl.} =
  testValue = 1
  aco_yield()
  testValue = 2
  aco_yield()
  testValue = 3
  aco_exit()

proc testBasicContextSwitch() =
  echo "=== Test: Basic Context Switch ==="
  
  testValue = 0
  let co = aco_create(mainCo, sharedStack, 0, cast[AcoFuncPtr](coroFunc), nil)
  doAssert co != nil, "Failed to create coroutine"
  echo "✓ Coroutine created"
  
  # First resume: should set testValue to 1 and yield
  doAssert testValue == 0
  aco_resume(co)
  doAssert testValue == 1, "Expected testValue=1, got " & $testValue
  doAssert not isEnded(co)
  echo "✓ First resume: testValue = ", testValue
  
  # Second resume
  aco_resume(co)
  doAssert testValue == 2
  echo "✓ Second resume: testValue = ", testValue
  
  # Third resume
  aco_resume(co)
  doAssert testValue == 3
  doAssert isEnded(co)
  echo "✓ Third resume: testValue = ", testValue, " (finished)"
  
  aco_destroy(co)
  echo "=== PASSED ===\n"

# =============================================================================
# Test 2: Multiple Coroutines with Shared Stack
# =============================================================================

proc countingCoro() {.cdecl.} =
  inc multiCounter
  aco_yield()
  inc multiCounter
  aco_exit()

proc testMultipleCoroutines() =
  echo "=== Test: Multiple Coroutines ==="
  
  multiCounter = 0
  
  let co1 = aco_create(mainCo, sharedStack, 0, cast[AcoFuncPtr](countingCoro), nil)
  let co2 = aco_create(mainCo, sharedStack, 0, cast[AcoFuncPtr](countingCoro), nil)
  let co3 = aco_create(mainCo, sharedStack, 0, cast[AcoFuncPtr](countingCoro), nil)
  
  # Resume each once
  aco_resume(co1)
  aco_resume(co2)
  aco_resume(co3)
  doAssert multiCounter == 3, "Expected 3, got " & $multiCounter
  echo "✓ After first round: multiCounter = ", multiCounter
  
  # Resume each again to finish
  aco_resume(co1)
  aco_resume(co2)
  aco_resume(co3)
  doAssert multiCounter == 6
  echo "✓ After second round: multiCounter = ", multiCounter
  
  doAssert isEnded(co1) and isEnded(co2) and isEnded(co3)
  echo "✓ All coroutines finished"
  
  aco_destroy(co1)
  aco_destroy(co2)
  aco_destroy(co3)
  echo "=== PASSED ===\n"

# =============================================================================
# Test 3: Passing Argument via aco_get_arg()
# =============================================================================

proc argCoro() {.cdecl.} =
  let arg = cast[ptr int](aco_get_arg())
  arg[] = 42
  aco_exit()

proc testPassingArgument() =
  echo "=== Test: Passing Argument ==="
  
  var result = 0
  let co = aco_create(mainCo, sharedStack, 0, cast[AcoFuncPtr](argCoro), addr result)
  
  doAssert result == 0
  aco_resume(co)
  doAssert result == 42
  echo "✓ Coroutine set result via argument: ", result
  
  aco_destroy(co)
  echo "=== PASSED ===\n"

# =============================================================================
# Test 4: Benchmark Context Switch Time
# =============================================================================

proc benchCoro() {.cdecl.} =
  while true:
    inc benchYieldCount
    aco_yield()

proc testBenchmark() =
  echo "=== Benchmark: Context Switch Time ==="

  let co = aco_create(mainCo, sharedStack, 0, cast[AcoFuncPtr](benchCoro), nil)

  # Warmup run
  echo "Warming up..."
  for _ in 0..<10_000:
    aco_resume(co)

  # Reset counter and run actual benchmark
  benchYieldCount = 0
  const iterations = 1_000_000

  echo "Running ", iterations, " iterations..."
  let start = epochTime()
  for _ in 0..<iterations:
    aco_resume(co)
  let elapsed = epochTime() - start

  let msTotal = elapsed * 1000.0
  let nsPerSwitch = (elapsed * 1_000_000_000.0) / float(iterations)
  let switchesPerSec = float(iterations) / elapsed

  echo "Results:"
  echo "  Total time: ", formatFloat(msTotal, ffDecimal, 3), " ms"
  echo "  Time per switch: ", formatFloat(nsPerSwitch, ffDecimal, 2), " ns"
  echo "  Throughput: ", formatFloat(switchesPerSec / 1_000_000.0, ffDecimal, 2), " million switches/sec"
  echo "  Iterations completed: ", benchYieldCount

  # Don't destroy - infinite loop coroutine
  echo "=== BENCHMARK COMPLETE ===\n"

# =============================================================================
# Main
# =============================================================================

when isMainModule:
  echo "\n=== libaco Binding Tests ===\n"
  
  initForTests()
  echo "✓ Thread initialized"
  echo "✓ Main coroutine created"
  echo "✓ Shared stack created (size: ", getShareStackSize(sharedStack), " bytes)\n"
  
  testBasicContextSwitch()
  testMultipleCoroutines()
  testPassingArgument()
  testBenchmark()
  
  cleanupAfterTests()
  
  echo "All tests passed! ✓\n"
