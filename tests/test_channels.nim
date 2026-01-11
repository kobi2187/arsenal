## Channel Tests
## ==============
##
## Tests for unbuffered and buffered channels.

import std/unittest
import std/options
import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

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

# Note: Coroutine-based tests are in test_channels_simple.nim
# The unittest framework has issues with coroutine scheduler state.
