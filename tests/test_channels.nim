## Channel Tests
## ==============
##
## Tests for unbuffered and buffered channels.

import std/unittest
import std/options
import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

# For tests, we use {.gcsafe.} override since we know
# single-threaded test context is safe
{.push warning[GcUnsafe2]: off.}

suite "Unbuffered Channel - Basic":
  test "create unbuffered channel":
    let ch = newChan[int]()
    check not ch.isClosed()

  test "trySend fails without receiver":
    let ch = newChan[int]()
    check ch.trySend(42) == false

  test "tryRecv fails without sender":
    let ch = newChan[int]()
    check ch.tryRecv().isNone

  test "close channel":
    let ch = newChan[int]()
    ch.close()
    check ch.isClosed()

suite "Unbuffered Channel - With Coroutines":
  test "send then recv (receiver first)":
    let ch = newChan[int]()
    var received = 0

    # Receiver coroutine - will block waiting for sender
    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        received = ch.recv()
    )

    # Sender coroutine - will find receiver waiting
    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        ch.send(42)
    )

    runAll()
    check received == 42

  test "recv then send (sender first)":
    let ch = newChan[int]()
    var received = 0

    # Sender coroutine - will block waiting for receiver
    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        ch.send(42)
    )

    # Receiver coroutine - will find sender waiting
    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        received = ch.recv()
    )

    runAll()
    check received == 42

  test "multiple values through channel":
    let ch = newChan[int]()
    var sum = 0

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        for i in 1..5:
          ch.send(i)
    )

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        for i in 1..5:
          sum += ch.recv()
    )

    runAll()
    check sum == 15  # 1+2+3+4+5

  test "ping pong":
    let ping = newChan[int]()
    let pong = newChan[int]()
    var lastPing = 0
    var lastPong = 0

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        for i in 1..3:
          ping.send(i)
          lastPong = pong.recv()
    )

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        for i in 1..3:
          lastPing = ping.recv()
          pong.send(lastPing * 10)
    )

    runAll()
    check lastPing == 3
    check lastPong == 30

suite "Buffered Channel - Basic":
  test "create buffered channel":
    let ch = newBufferedChan[int](5)
    check not ch.isClosed()
    check ch.len == 0
    check ch.cap == 5

  test "trySend succeeds when buffer has space":
    let ch = newBufferedChan[int](3)
    check ch.trySend(1) == true
    check ch.trySend(2) == true
    check ch.trySend(3) == true
    check ch.len == 3

  test "trySend fails when buffer full":
    let ch = newBufferedChan[int](2)
    check ch.trySend(1) == true
    check ch.trySend(2) == true
    check ch.trySend(3) == false  # Buffer full
    check ch.len == 2

  test "tryRecv succeeds when buffer has items":
    let ch = newBufferedChan[int](3)
    discard ch.trySend(10)
    discard ch.trySend(20)

    let v1 = ch.tryRecv()
    let v2 = ch.tryRecv()
    let v3 = ch.tryRecv()

    check v1 == some(10)
    check v2 == some(20)
    check v3.isNone

  test "FIFO ordering":
    let ch = newBufferedChan[int](5)
    for i in 1..5:
      discard ch.trySend(i)

    var received: seq[int]
    for i in 1..5:
      let v = ch.tryRecv()
      if v.isSome:
        received.add(v.get)

    check received == @[1, 2, 3, 4, 5]

suite "Buffered Channel - With Coroutines":
  test "producer consumer":
    let ch = newBufferedChan[int](3)
    var received: seq[int]

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        for i in 1..5:
          ch.send(i)
    )

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        for i in 1..5:
          received.add(ch.recv())
    )

    runAll()
    check received == @[1, 2, 3, 4, 5]

  test "buffer allows async progress":
    # Producer can send up to capacity without blocking
    let ch = newBufferedChan[int](3)
    var sendCount = 0

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        for i in 1..3:
          ch.send(i)
          inc sendCount
        # After 3 sends, buffer is full - would block on 4th
    )

    # Run producer - it should complete 3 sends without consumer
    runAll()
    check sendCount == 3
    check ch.len == 3

    # Now consume
    var recvCount = 0
    for i in 1..3:
      let v = ch.tryRecv()
      if v.isSome:
        inc recvCount

    check recvCount == 3
    check ch.len == 0

suite "Channel Close Behavior":
  test "recv on closed empty channel returns default":
    let ch = newChan[int]()
    ch.close()
    var v = -1

    discard spawn(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        v = ch.recv()
    )

    runAll()
    check v == 0  # default(int)

  test "buffered recv drains buffer then returns default":
    let ch = newBufferedChan[int](3)
    discard ch.trySend(10)
    discard ch.trySend(20)
    ch.close()

    let v1 = ch.tryRecv()
    let v2 = ch.tryRecv()
    let v3 = ch.tryRecv()

    check v1 == some(10)
    check v2 == some(20)
    check v3.isNone  # Closed and empty

{.pop.}
