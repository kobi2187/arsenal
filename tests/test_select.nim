## Select Statement Tests
## ======================
##
## Tests for Go-style select on channels.

import std/options
import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/channels/select
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

# Note: Test helpers provided by unittest framework in test_all.nim
# For standalone execution, we need check template
when not declared(check):
  template check(cond: bool, msg: string = "") =
    doAssert cond, msg

# =============================================================================
# Test 1: Select with default (non-blocking)
# =============================================================================

proc testSelectWithDefault() =
  let ch1 = newBufferedChan[int](2)
  let ch2 = newBufferedChan[string](2)

  var result = ""

  # Nothing ready, should hit default
  select:
    recv ch1 -> opt:
      if opt.isSome:
        result = "ch1: " & $opt.get
    recv ch2 -> opt:
      if opt.isSome:
        result = "ch2: " & opt.get
    default:
      result = "default"

  check result == "default", "Expected default case"

  # Add something to ch1
  discard ch1.trySend(42)

  result = ""
  select:
    recv ch1 -> opt:
      if opt.isSome:
        result = "ch1: " & $opt.get
    recv ch2 -> opt:
      if opt.isSome:
        result = "ch2: " & opt.get
    default:
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
    recv ch1 -> opt:
      if opt.isSome:
        result = "ch1"
    recv ch2 -> opt:
      if opt.isSome:
        result = "ch2: " & opt.get
    default:
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

# Tests are run via test_all.nim using unittest framework
when declared(suite):
  suite "Select Statement Tests":
    test "select with default (non-blocking)":
      testSelectWithDefault()

    test "select with buffered channels":
      testSelectBuffered()

    test "helper functions (sendTo/recvFrom)":
      testHelpers()
else:
  # Standalone execution
  when isMainModule:
    echo "\n=== Select Statement Tests ===\n"

    try:
      testSelectWithDefault()
      echo "  [OK] select with default (non-blocking)"
    except CatchableError as e:
      echo "  [FAIL] select with default (non-blocking): ", e.msg

    try:
      testSelectBuffered()
      echo "  [OK] select with buffered channels"
    except CatchableError as e:
      echo "  [FAIL] select with buffered channels: ", e.msg

    try:
      testHelpers()
      echo "  [OK] helper functions (sendTo/recvFrom)"
    except CatchableError as e:
      echo "  [FAIL] helper functions (sendTo/recvFrom): ", e.msg
