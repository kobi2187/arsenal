## Unit tests for atomic operations

import std/unittest
import ../src/arsenal/concurrency/atomics/atomic

suite "Atomic Operations":
  test "init and load":
    var a = Atomic[int].init(42)
    check a.load() == 42

    var b = init(100)
    check b.load() == 100

  test "store":
    var a = Atomic[int].init(0)
    a.store(123)
    check a.load() == 123

  test "exchange":
    var a = Atomic[int].init(10)
    let old = a.exchange(20)
    check old == 10
    check a.load() == 20

  test "compareExchange success":
    var a = Atomic[int].init(42)
    var expected = 42
    let success = a.compareExchange(expected, 100)
    check success == true
    check a.load() == 100
    check expected == 42  # Not modified on success

  test "compareExchange failure":
    var a = Atomic[int].init(42)
    var expected = 99  # Wrong value
    let success = a.compareExchange(expected, 100)
    check success == false
    check a.load() == 42  # Unchanged
    check expected == 42  # Updated to actual value

  test "fetchAdd":
    var a = Atomic[int].init(10)
    let old = a.fetchAdd(5)
    check old == 10
    check a.load() == 15

  test "fetchSub":
    var a = Atomic[int].init(20)
    let old = a.fetchSub(7)
    check old == 20
    check a.load() == 13

  test "fetchAnd":
    var a = Atomic[int].init(0b1111)
    let old = a.fetchAnd(0b1010)
    check old == 0b1111
    check a.load() == 0b1010

  test "fetchOr":
    var a = Atomic[int].init(0b1010)
    let old = a.fetchOr(0b0101)
    check old == 0b1010
    check a.load() == 0b1111

  test "fetchXor":
    var a = Atomic[int].init(0b1111)
    let old = a.fetchXor(0b0101)
    check old == 0b1111
    check a.load() == 0b1010

  test "convenience operators":
    var a = Atomic[int].init(0)
    a += 10
    check a.load() == 10
    a -= 3
    check a.load() == 7

  test "inc/dec":
    var a = Atomic[int].init(5)
    a.inc()
    check a.load() == 6
    a.dec()
    check a.load() == 5

  test "memory ordering":
    # Just verify different orderings compile and work
    var a = Atomic[int].init(0)
    discard a.load(Relaxed)
    discard a.load(Acquire)
    discard a.load(SeqCst)

    a.store(1, Relaxed)
    a.store(2, Release)
    a.store(3, SeqCst)

    discard a.fetchAdd(1, Relaxed)
    discard a.fetchAdd(1, AcqRel)

  test "different types":
    var ai = Atomic[int].init(42)
    var au = Atomic[uint].init(100'u)
    var ab = Atomic[bool].init(true)

    check ai.load() == 42
    check au.load() == 100'u
    check ab.load() == true

    ab.store(false)
    check ab.load() == false

suite "Memory Fences":
  test "atomicThreadFence compiles":
    atomicThreadFence(Relaxed)
    atomicThreadFence(Acquire)
    atomicThreadFence(Release)
    atomicThreadFence(AcqRel)
    atomicThreadFence(SeqCst)

  test "atomicSignalFence compiles":
    atomicSignalFence(Relaxed)
    atomicSignalFence(SeqCst)

suite "Spin Hint":
  test "spinHint compiles":
    spinHint()
    spinHint()
    spinHint()
