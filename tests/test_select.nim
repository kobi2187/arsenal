## Select Statement Tests
## ======================
##
## Tests for Go-style select on channels.

import std/options
import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/channels/select
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

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
# Test 1: Select with default (non-blocking)
# =============================================================================

proc testSelectWithDefault() =
  let ch1 = newChan[int]()
  let ch2 = newChan[string]()

  var result = ""

  # Nothing ready, should hit default
  select:
    of ch1.tryRecv() -> opt:
      if opt.isSome:
        result = "ch1: " & $opt.get
    of ch2.tryRecv() -> opt:
      if opt.isSome:
        result = "ch2: " & opt.get
    else:
      result = "default"

  check result == "default", "Expected default case"

  # Add something to ch1
  discard ch1.trySend(42)

  result = ""
  select:
    of ch1.tryRecv() -> opt:
      if opt.isSome:
        result = "ch1: " & $opt.get
    of ch2.tryRecv() -> opt:
      if opt.isSome:
        result = "ch2: " & opt.get
    else:
      result = "default"

  check result == "ch1: 42", "Expected ch1 result, got: " & result

# =============================================================================
# Test 2: Multiple channels with buffered channels
# =============================================================================

proc testSelectBuffered() =
  let ch1 = newBufferedChan[int](2)
  let ch2 = newBufferedChan[string](2)

  # Fill ch2
  discard ch2.trySend("hello")

  var result = ""
  select:
    of ch1.tryRecv() -> opt:
      if opt.isSome:
        result = "ch1"
    of ch2.tryRecv() -> opt:
      if opt.isSome:
        result = "ch2: " & opt.get
    else:
      result = "default"

  check result == "ch2: hello", "Expected ch2, got: " & result

# =============================================================================
# Test 3: Helper functions - recvFrom and sendTo
# =============================================================================

proc testHelpers() =
  let ch = newBufferedChan[int](5)

  # Test sendTo
  let sent = sendTo(ch, 42)
  check sent == true, "sendTo should succeed"

  # Test recvFrom
  let opt = recvFrom(ch)
  check opt.isSome, "recvFrom should return Some"
  check opt.get == 42, "recvFrom should return correct value"

  # Empty channel
  let empty = recvFrom(ch)
  check empty.isNone, "recvFrom on empty should return None"

  # Full channel
  for i in 1..5:
    discard sendTo(ch, i)

  let fullSend = sendTo(ch, 99)
  check fullSend == false, "sendTo on full channel should fail"

# =============================================================================
# Main
# =============================================================================

when isMainModule:
  echo "\n=== Select Statement Tests ===\n"

  test "select with default (non-blocking)":
    testSelectWithDefault()

  test "select with buffered channels":
    testSelectBuffered()

  test "helper functions (sendTo/recvFrom)":
    testHelpers()

  echo "\n=== Results: ", testsPassed, " passed, ", testsFailed, " failed ===\n"

  if testsFailed > 0:
    quit(1)
