## Go-Style DSL Tests
## ===================
##
## Tests for the Go-style concurrency DSL (M6).

import ../src/arsenal/concurrency
import std/options

# =============================================================================
# Test Helpers
# =============================================================================

var testsPassed = 0
var testsFailed = 0

template test(name: string, body: untyped) =
  try:
    body
    echo "  [OK] ", name
    inc testsPassed
  except CatchableError as e:
    echo "  [FAIL] ", name, ": ", e.msg
    echo "  Stack trace:"
    echo e.getStackTrace()
    inc testsFailed

template check(cond: bool, msg: string = "") =
  if not cond:
    let fullMsg = if msg.len > 0: "Check failed: " & msg else: "Check failed"
    raise newException(AssertionDefect, fullMsg)

# =============================================================================
# Test 1: Basic go macro
# =============================================================================

var counter1 = 0

proc testBasicGo() =
  counter1 = 0

  go:
    counter1 = 42

  runAll()

  check counter1 == 42, "go macro should execute body"

# =============================================================================
# Test 2: Multiple go coroutines
# =============================================================================

var sum2 = 0

proc testMultipleGo() =
  sum2 = 0

  for i in 1..10:
    let val = i
    go:
      sum2 += val

  runAll()

  check sum2 == 55, "Multiple go coroutines should all execute, got: " & $sum2

# =============================================================================
# Test 3: go with channels
# =============================================================================

var result3 = 0

proc testGoWithChannels() =
  result3 = 0
  let ch = newChan[int]()

  go:
    ch.send(100)

  go:
    result3 = ch.recv()

  runAll()

  check result3 == 100, "go with channels should work"

# =============================================================================
# Test 4: Channel operator <- (receive)
# =============================================================================

proc testChannelOperator() =
  let ch = newBufferedChan[int](5)
  discard ch.trySend(42)

  # Test <- operator
  let value = <-ch

  check value == 42, "Channel <- operator should work"

# =============================================================================
# Test 5: Pipeline with go macro
# =============================================================================

proc testPipeline() =
  let ch1 = newChan[int]()
  let ch2 = newChan[int]()

  var finalSum = 0

  # Generator: 1..5
  go:
    for i in 1..5:
      ch1.send(i)

  # Squarer: square each number
  go:
    for i in 1..5:
      let n = ch1.recv()
      ch2.send(n * n)

  # Summer: sum all squares
  go:
    for i in 1..5:
      finalSum += ch2.recv()

  runAll()

  # 1^2 + 2^2 + 3^2 + 4^2 + 5^2 = 1 + 4 + 9 + 16 + 25 = 55
  check finalSum == 55, "Pipeline should compute sum of squares, got: " & $finalSum

# =============================================================================
# Test 6: Select with go macro
# =============================================================================

proc testSelectWithGo() =
  let ch1 = newBufferedChan[int](5)
  let ch2 = newBufferedChan[string](5)

  var result = ""

  # Send to ch2 in background
  go:
    discard ch2.trySend("hello from go")

  # Wait a bit for send to complete
  runAll()

  # Select should pick ch2
  select:
    of ch1.tryRecv() -> opt:
      if opt.isSome:
        result = "ch1: " & $opt.get
    of ch2.tryRecv() -> opt:
      if opt.isSome:
        result = "ch2: " & opt.get
    else:
      result = "default"

  check result == "ch2: hello from go", "Select with go should work, got: " & result

# =============================================================================
# Test 7: Nested go macros
# =============================================================================

var nested7 = 0

proc testNestedGo() =
  nested7 = 0

  go:
    nested7 = 1
    go:
      nested7 = 2

  runAll()

  check nested7 == 2, "Nested go macros should work"

# =============================================================================
# Test 8: Go macro with closure capture
# =============================================================================

proc testClosureCapture() =
  var results: array[5, int]

  for i in 0..4:
    let captured = i  # Capture by value
    go:
      results[captured] = captured * 10

  runAll()

  for i in 0..4:
    check results[i] == i * 10, "Closure capture should work for index " & $i

# =============================================================================
# Main
# =============================================================================

when isMainModule:
  echo "\n=== Go-Style DSL Tests ===\n"

  test "basic go macro":
    testBasicGo()

  test "multiple go coroutines":
    testMultipleGo()

  test "go with channels":
    testGoWithChannels()

  test "channel <- operator":
    testChannelOperator()

  test "pipeline with go macro":
    testPipeline()

  test "select with go macro":
    testSelectWithGo()

  test "nested go macros":
    testNestedGo()

  test "go with closure capture":
    testClosureCapture()

  echo "\n=== Results: ", testsPassed, " passed, ", testsFailed, " failed ===\n"

  if testsFailed > 0:
    quit(1)
