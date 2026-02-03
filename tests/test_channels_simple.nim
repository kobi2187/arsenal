## Channel Coroutine Tests
## =======================
##
## Tests for channels with coroutine blocking.
## These are separate from unittest to avoid scheduler state issues.

import std/options
import std/unittest
import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

# Helper for compatibility
template check*(cond: bool, msg: string) =
  doAssert cond, msg

# Note: Test helpers provided by unittest framework in test_all.nim

# =============================================================================
# Test 1: Basic send/recv with sender first
# =============================================================================

var gCh1: Chan[int]
var gReceived1: int

proc sender1() {.gcsafe.} =
  {.cast(gcsafe).}:
    gCh1.send(42)

proc receiver1() {.gcsafe.} =
  {.cast(gcsafe).}:
    gReceived1 = gCh1.recv()

proc testSenderFirst() =
  gCh1 = newChan[int]()
  gReceived1 = 0

  let s = newCoroutine(sender1)
  let r = newCoroutine(receiver1)

  ready(s)
  ready(r)
  runAll()

  check gReceived1 == 42

# =============================================================================
# Test 2: Basic send/recv with receiver first
# =============================================================================

var gCh2: Chan[int]
var gReceived2: int

proc sender2() {.gcsafe.} =
  {.cast(gcsafe).}:
    gCh2.send(99)

proc receiver2() {.gcsafe.} =
  {.cast(gcsafe).}:
    gReceived2 = gCh2.recv()

proc testReceiverFirst() =
  gCh2 = newChan[int]()
  gReceived2 = 0

  let r = newCoroutine(receiver2)
  let s = newCoroutine(sender2)

  ready(r)  # Receiver first
  ready(s)
  runAll()

  check gReceived2 == 99

# =============================================================================
# Test 3: Multiple values
# =============================================================================

var gCh3: Chan[int]
var gSum3: int

proc sender3() {.gcsafe.} =
  {.cast(gcsafe).}:
    for i in 1..5:
      gCh3.send(i)

proc receiver3() {.gcsafe.} =
  {.cast(gcsafe).}:
    for i in 1..5:
      gSum3 += gCh3.recv()

proc testMultipleValues() =
  gCh3 = newChan[int]()
  gSum3 = 0

  let s = newCoroutine(sender3)
  let r = newCoroutine(receiver3)

  ready(s)
  ready(r)
  runAll()

  check gSum3 == 15  # 1+2+3+4+5

# =============================================================================
# Test 4: Ping pong
# =============================================================================

var gPing: Chan[int]
var gPong: Chan[int]
var gLastPing: int
var gLastPong: int

proc player1() {.gcsafe.} =
  {.cast(gcsafe).}:
    for i in 1..3:
      gPing.send(i)
      gLastPong = gPong.recv()

proc player2() {.gcsafe.} =
  {.cast(gcsafe).}:
    for i in 1..3:
      gLastPing = gPing.recv()
      gPong.send(gLastPing * 10)

proc testPingPong() =
  gPing = newChan[int]()
  gPong = newChan[int]()
  gLastPing = 0
  gLastPong = 0

  let p1 = newCoroutine(player1)
  let p2 = newCoroutine(player2)

  ready(p1)
  ready(p2)
  runAll()

  check gLastPing == 3
  check gLastPong == 30

# =============================================================================
# Test 5: Buffered channel - just trySend/tryRecv (no coroutines)
# =============================================================================

proc testBufferedBasic() =
  let ch = newBufferedChan[int](3)

  # Fill buffer
  check ch.trySend(1) == true
  check ch.trySend(2) == true
  check ch.trySend(3) == true
  check ch.trySend(4) == false  # Full

  # Drain buffer
  check ch.tryRecv().get == 1
  check ch.tryRecv().get == 2
  check ch.tryRecv().get == 3
  check ch.tryRecv().isNone  # Empty

# =============================================================================
# Main
# =============================================================================

# Tests are run via test_all.nim using unittest framework
suite "Channel Coroutine Tests":
  test "send then recv (sender first)":
    testSenderFirst()

  test "recv then send (receiver first)":
    testReceiverFirst()

  test "multiple values through channel":
    testMultipleValues()

  test "ping pong":
    testPingPong()

  test "trySend/tryRecv (no coroutines)":
    testBufferedBasic()

  # Note: Buffered channel with coroutine blocking has a bug
  # that needs further investigation (segfault on recv after send
  # fills buffer and blocks).
