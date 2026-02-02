## Select Timeout Tests
## ====================
##
## Tests for timeout functionality in select.

import std/times
import std/options
import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/channels/select

# Helper for standalone execution
when not declared(check):
  template check(cond: bool, msg: string = "") =
    doAssert cond, msg

# Test 1: Timeout with direct keyword
proc testTimeoutKeyword() =
  let ch = newBufferedChan[int](2)
  var result = ""

  # Should timeout since channel is empty
  select:
    recv ch -> opt:
      if opt.isSome:
        result = "got message"
    timeout initDuration(milliseconds = 100):
      result = "timeout"

  check result == "timeout", "Expected timeout, got: " & result

# Test 2: Message before timeout
proc testMessageBeforeTimeout() =
  let ch = newBufferedChan[int](2)
  var result = ""

  # Send a message first
  discard ch.trySend(42)

  # Should get message, not timeout
  select:
    recv ch -> opt:
      if opt.isSome:
        result = "got: " & $opt.get
    timeout initDuration(seconds = 1):
      result = "timeout"

  check result == "got: 42", "Expected message, got: " & result

# Test 3: Timer channel with after()
proc testAfterFunction() =
  let ch = newBufferedChan[int](2)
  var timer = after(initDuration(milliseconds = 100))
  var result = ""

  # Should timeout
  select:
    recv ch -> opt:
      if opt.isSome:
        result = "got message"
    recv timer -> _:
      result = "timeout via after()"

  check result == "timeout via after()", "Expected timeout, got: " & result

# Main
when isMainModule:
  echo "\n=== Select Timeout Tests ===\n"

  try:
    testTimeoutKeyword()
    echo "  [OK] timeout keyword"
  except CatchableError as e:
    echo "  [FAIL] timeout keyword: ", e.msg

  try:
    testMessageBeforeTimeout()
    echo "  [OK] message before timeout"
  except CatchableError as e:
    echo "  [FAIL] message before timeout: ", e.msg

  try:
    testAfterFunction()
    echo "  [OK] after() function"
  except CatchableError as e:
    echo "  [FAIL] after() function: ", e.msg
