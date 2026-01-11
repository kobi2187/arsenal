## Test minicoro bindings
## =======================

import ../src/arsenal/concurrency/coroutines/minicoro
import std/times

# =============================================================================
# Test 1: Basic Context Switch
# =============================================================================

var testValue = 0

proc coroFunc(co: ptr McoCoro) {.cdecl.} =
  testValue = 1
  discard mco_yield(co)
  testValue = 2
  discard mco_yield(co)
  testValue = 3
  # Just return - coroutine becomes DEAD

proc testBasicContextSwitch() =
  echo "=== Test: Basic Context Switch ==="
  
  var desc = mco_desc_init(coroFunc, 0)  # 0 = default stack size
  var co: ptr McoCoro
  
  let res = mco_create(addr co, addr desc)
  doAssert res == MCO_SUCCESS, "Failed to create: " & $mco_result_description(res)
  doAssert mco_status(co) == MCO_SUSPENDED
  echo "✓ Coroutine created (suspended)"
  
  testValue = 0
  
  # First resume
  checkResult mco_resume(co)
  doAssert testValue == 1
  doAssert mco_status(co) == MCO_SUSPENDED
  echo "✓ First resume: testValue = ", testValue
  
  # Second resume
  checkResult mco_resume(co)
  doAssert testValue == 2
  doAssert mco_status(co) == MCO_SUSPENDED
  echo "✓ Second resume: testValue = ", testValue
  
  # Third resume - coroutine finishes
  checkResult mco_resume(co)
  doAssert testValue == 3
  doAssert mco_status(co) == MCO_DEAD
  echo "✓ Third resume: testValue = ", testValue, " (dead)"
  
  checkResult mco_destroy(co)
  echo "=== PASSED ===\n"

# =============================================================================
# Test 2: Multiple Coroutines
# =============================================================================

var multiCounter = 0

proc countCoro(co: ptr McoCoro) {.cdecl.} =
  inc multiCounter
  discard mco_yield(co)
  inc multiCounter

proc testMultipleCoroutines() =
  echo "=== Test: Multiple Coroutines ==="
  
  var desc = mco_desc_init(countCoro, 0)
  var co1, co2, co3: ptr McoCoro
  
  checkResult mco_create(addr co1, addr desc)
  checkResult mco_create(addr co2, addr desc)
  checkResult mco_create(addr co3, addr desc)
  
  multiCounter = 0
  
  # First round
  checkResult mco_resume(co1)
  checkResult mco_resume(co2)
  checkResult mco_resume(co3)
  doAssert multiCounter == 3
  echo "✓ After first round: multiCounter = ", multiCounter
  
  # Second round - finish
  checkResult mco_resume(co1)
  checkResult mco_resume(co2)
  checkResult mco_resume(co3)
  doAssert multiCounter == 6
  echo "✓ After second round: multiCounter = ", multiCounter
  
  doAssert isDead(co1) and isDead(co2) and isDead(co3)
  echo "✓ All coroutines dead"
  
  checkResult mco_destroy(co1)
  checkResult mco_destroy(co2)
  checkResult mco_destroy(co3)
  echo "=== PASSED ===\n"

# =============================================================================
# Test 3: User Data
# =============================================================================

proc userDataCoro(co: ptr McoCoro) {.cdecl.} =
  let data = cast[ptr int](mco_get_user_data(co))
  data[] = 42

proc testUserData() =
  echo "=== Test: User Data ==="
  
  var result = 0
  var desc = mco_desc_init(userDataCoro, 0)
  desc.user_data = addr result
  
  var co: ptr McoCoro
  checkResult mco_create(addr co, addr desc)
  
  doAssert result == 0
  checkResult mco_resume(co)
  doAssert result == 42
  echo "✓ User data set to: ", result
  
  checkResult mco_destroy(co)
  echo "=== PASSED ===\n"

# =============================================================================
# Test 4: Benchmark
# =============================================================================

var benchCounter = 0

proc benchCoro(co: ptr McoCoro) {.cdecl.} =
  while true:
    inc benchCounter
    discard mco_yield(co)

proc testBenchmark() =
  echo "=== Benchmark: Context Switch Time ==="
  
  var desc = mco_desc_init(benchCoro, 0)
  var co: ptr McoCoro
  checkResult mco_create(addr co, addr desc)
  
  const iterations = 1_000_000
  benchCounter = 0
  
  let start = cpuTime()
  for _ in 0..<iterations:
    discard mco_resume(co)
  let elapsed = cpuTime() - start
  
  let nsPerSwitch = (elapsed * 1_000_000_000.0) / float(iterations)
  echo "✓ ", iterations, " context switches in ", elapsed * 1000, " ms"
  echo "✓ ", nsPerSwitch, " ns per switch"
  echo "✓ benchCounter = ", benchCounter
  
  # Don't destroy - infinite loop (leak is fine for benchmark)
  echo "=== BENCHMARK COMPLETE ===\n"

# =============================================================================
# Main
# =============================================================================

when isMainModule:
  echo "\n=== minicoro Binding Tests ===\n"
  
  testBasicContextSwitch()
  testMultipleCoroutines()
  testUserData()
  testBenchmark()
  
  echo "All tests passed! ✓\n"
