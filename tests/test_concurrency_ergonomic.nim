## Tests for ergonomic concurrency API

import std/unittest
import ../src/arsenal/concurrency

suite "Ergonomic Atomics":
  test "atomic() constructor":
    var counter = atomic(0)
    check counter.value == 0

  test "value property getter/setter":
    var counter = atomic(42)
    check counter.value == 42

    counter.value = 100
    check counter.value == 100

  test "ergonomic increment":
    var counter = atomic(0)
    counter.inc()
    check counter.value == 1

    counter += 5
    check counter.value == 6

  test "works with different types":
    var b = atomic(true)
    check b.value == true
    b.value = false
    check b.value == false

suite "Ergonomic Locks":
  test "newLock with defaults":
    var lock = newLock()  # Defaults to Fast
    var executed = false

    lock.withLock:
      executed = true

    check executed

  test "Fair lock (FIFO)":
    var lock = newLock(Fair)
    var count = 0

    lock.withLock:
      count += 1

    check count == 1

  test "ReadWrite lock":
    var lock = newLock(ReadWrite)
    var value = 0

    # Multiple reads
    lock.withReadLock:
      discard value

    lock.withReadLock:
      discard value

    # Exclusive write
    lock.withWriteLock:
      value = 42

    lock.withReadLock:
      check value == 42

  test "exception safety":
    var lock = newLock()

    try:
      lock.withLock:
        raise newException(ValueError, "test")
    except ValueError:
      discard

    # Should be able to acquire again (was released)
    var executed = false
    lock.withLock:
      executed = true
    check executed

suite "Ergonomic Queues":
  test "newQueue with defaults (MPMC)":
    var q = newQueue[int](16)
    check q.isEmpty()
    check q.capacity() == 16

  test "SPSC queue for performance":
    var q = newQueue[int](16, SingleProducerSingleConsumer)
    check q.push(42)

    let val = q.pop()
    check val.isSome()
    check val.get() == 42

  test "ergonomic push/pop":
    var q = newQueue[int](16)

    check q.push(1)
    check q.push(2)
    check q.push(3)

    check q.len() == 3

    check q.pop().get() == 1
    check q.pop().get() == 2
    check q.pop().get() == 3

    check q.isEmpty()

  test "iterator draining":
    var q = newQueue[int](16)

    for i in 1..5:
      discard q.push(i)

    var collected: seq[int]
    for item in q:
      collected.add(item)

    check collected == @[1, 2, 3, 4, 5]
    check q.isEmpty()

  test "optional unpacking":
    var q = newQueue[int](16)
    discard q.push(42)

    let maybeVal = q.pop()
    if maybeVal.isSome():
      check maybeVal.get() == 42
    else:
      fail()

suite "Common Patterns":
  test "retry template":
    var counter = atomic(0)
    var attempts = 0

    retry:
      attempts += 1
      counter.inc()
      attempts > 0  # Succeeds immediately

    check counter.value == 1

suite "Real-World Examples":
  test "concurrent counter":
    var counter = atomic(0)

    # Simulate multiple threads incrementing
    for i in 0..<1000:
      counter.inc()

    check counter.value == 1000

  test "producer-consumer with queue":
    var q = newQueue[int](256)
    const items = 100

    # Producer
    for i in 0..<items:
      retry:
        q.push(i)

    # Consumer
    var sum = 0
    for i in 0..<items:
      var got = false
      retry:
        let maybeVal = q.pop()
        if maybeVal.isSome():
          sum += maybeVal.get()
          got = true
        got

    # Sum of 0..99 = 4950
    check sum == 4950

  test "reader-writer lock pattern":
    var lock = newLock(ReadWrite)
    var data = @[1, 2, 3, 4, 5]

    # Multiple concurrent reads (simulated)
    var sum1 = 0
    lock.withReadLock:
      for x in data:
        sum1 += x

    var sum2 = 0
    lock.withReadLock:
      for x in data:
        sum2 += x

    check sum1 == 15
    check sum2 == 15

    # Exclusive write
    lock.withWriteLock:
      data.add(6)

    # Read updated data
    var sum3 = 0
    lock.withReadLock:
      for x in data:
        sum3 += x

    check sum3 == 21

suite "Ergonomics - Zero Boilerplate":
  test "one-liner atomic operations":
    var x = atomic(0)
    x += 10
    x.inc()
    check x.value == 11

  test "one-liner queue operations":
    var q = newQueue[int](16)
    discard q.push(42)
    check q.pop().get() == 42

  test "one-liner lock usage":
    var lock = newLock()
    var value = 0
    lock.withLock: value = 42
    check value == 42

suite "Type Safety":
  test "queue preserves types":
    var q = newQueue[string](16)
    discard q.push("hello")
    check q.pop().get() == "hello"

  test "atomic preserves types":
    var u = atomic(42'u64)
    check u.value == 42'u64
