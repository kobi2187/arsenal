## Unit tests for MPMC (Multi-Producer Multi-Consumer) Queue

import std/[unittest, options]
import ../src/arsenal/concurrency/queues/mpmc

suite "MPMC Queue - Basic Operations":
  test "init creates empty queue":
    var q = MpmcQueue[int].init(16)
    check q.isEmpty()
    check q.len() == 0
    check q.capacity() == 16

  test "push and pop single item":
    var q = MpmcQueue[int].init(16)
    check q.push(42) == true
    check q.len() == 1
    check not q.isEmpty()

    let val = q.pop()
    check val.isSome()
    check val.get() == 42
    check q.isEmpty()

  test "push and pop multiple items":
    var q = MpmcQueue[int].init(16)

    for i in 0..<10:
      check q.push(i) == true

    check q.len() == 10

    for i in 0..<10:
      let val = q.pop()
      check val.isSome()
      check val.get() == i

    check q.isEmpty()

  test "push returns false when full":
    var q = MpmcQueue[int].init(4)

    # Fill the queue
    for i in 0..<4:
      check q.push(i) == true

    # Next push should fail
    check q.push(99) == false

  test "pop returns none when empty":
    var q = MpmcQueue[int].init(16)
    let val = q.pop()
    check val.isNone()

  test "wraparound behavior":
    var q = MpmcQueue[int].init(4)

    # Fill and empty multiple times to test wraparound
    for round in 0..<10:
      for i in 0..<4:
        check q.push(round * 10 + i) == true

      for i in 0..<4:
        let val = q.pop()
        check val.isSome()
        check val.get() == round * 10 + i

      check q.isEmpty()

  test "interleaved push/pop":
    var q = MpmcQueue[int].init(8)

    for i in 0..<100:
      check q.push(i) == true
      let val = q.pop()
      check val.isSome()
      check val.get() == i

    check q.isEmpty()

suite "MPMC Queue - Single-Threaded Stress":
  test "fill and drain completely":
    var q = MpmcQueue[int].init(256)

    # Fill completely
    for i in 0..<256:
      check q.push(i) == true

    check q.len() == 256

    # Verify full
    check q.push(999) == false

    # Drain completely
    for i in 0..<256:
      let val = q.pop()
      check val.isSome()
      check val.get() == i

    check q.isEmpty()

    # Verify empty
    check q.pop().isNone()

suite "MPMC Queue - Thread Safety":
  test "multiple producers, single consumer":
    when compileOption("threads"):
      var q = MpmcQueue[int].init(256)
      const itemsPerProducer = 1000
      const numProducers = 4

      proc producer(id: int) {.thread.} =
        for i in 0..<itemsPerProducer:
          let value = id * itemsPerProducer + i
          while not q.push(value):
            discard  # Spin until space available

      proc consumer(count: ptr int) {.thread.} =
        var received = 0
        while received < itemsPerProducer * numProducers:
          let val = q.pop()
          if val.isSome():
            inc received
        count[] = received

      var producers: array[numProducers, Thread[int]]
      var consThread: Thread[ptr int]
      var count = 0

      # Start all threads
      for i in 0..<numProducers:
        createThread(producers[i], producer, i)
      createThread(consThread, consumer, addr count)

      # Wait for completion
      for i in 0..<numProducers:
        joinThread(producers[i])
      joinThread(consThread)

      check count == itemsPerProducer * numProducers
      check q.isEmpty()
    else:
      skip()

  test "single producer, multiple consumers":
    when compileOption("threads"):
      var q = MpmcQueue[int].init(256)
      const totalItems = 4000
      const numConsumers = 4

      proc producer() {.thread.} =
        for i in 0..<totalItems:
          while not q.push(i):
            discard

      proc consumer(count: ptr int) {.thread.} =
        var received = 0
        while true:
          let val = q.pop()
          if val.isSome():
            inc received
            if received >= totalItems div numConsumers:
              break

        count[] = received

      var prodThread: Thread[void]
      var consumers: array[numConsumers, Thread[ptr int]]
      var counts: array[numConsumers, int]

      createThread(prodThread, producer)
      for i in 0..<numConsumers:
        createThread(consumers[i], consumer, addr counts[i])

      joinThread(prodThread)
      for i in 0..<numConsumers:
        joinThread(consumers[i])

      var totalReceived = 0
      for c in counts:
        totalReceived += c

      check totalReceived >= totalItems
    else:
      skip()

suite "MPMC Queue - Data Types":
  test "works with different types":
    block:
      var q = MpmcQueue[string].init(8)
      check q.push("hello") == true
      check q.push("world") == true

      let v1 = q.pop()
      check v1.isSome()
      check v1.get() == "hello"

      let v2 = q.pop()
      check v2.isSome()
      check v2.get() == "world"

    block:
      var q = MpmcQueue[float].init(8)
      check q.push(3.14) == true
      check q.push(2.71) == true

      let v1 = q.pop()
      check v1.isSome()
      check v1.get() == 3.14

  test "works with objects":
    type Point = object
      x, y: int

    var q = MpmcQueue[Point].init(8)
    check q.push(Point(x: 1, y: 2)) == true
    check q.push(Point(x: 3, y: 4)) == true

    let v1 = q.pop()
    check v1.isSome()
    check v1.get().x == 1
    check v1.get().y == 2

suite "MPMC Queue - Edge Cases":
  test "minimum size queue (2 elements)":
    var q = MpmcQueue[int].init(2)
    check q.push(1) == true
    check q.push(2) == true
    check q.push(3) == false  # Full

    let v1 = q.pop()
    check v1.get() == 1

    check q.push(3) == true  # Now has space

    let v2 = q.pop()
    check v2.get() == 2

    let v3 = q.pop()
    check v3.get() == 3

    check q.isEmpty()

  test "capacity is preserved":
    var q = MpmcQueue[int].init(64)
    check q.capacity() == 64

    # Fill and empty
    for i in 0..<64:
      discard q.push(i)

    for i in 0..<64:
      discard q.pop()

    # Capacity should remain the same
    check q.capacity() == 64

  test "sequence numbers handle wraparound":
    # Test that the queue works correctly even with large position values
    var q = MpmcQueue[int].init(4)

    # Do many push/pop cycles to advance the position counters
    for round in 0..<100:
      for i in 0..<4:
        check q.push(i) == true
      for i in 0..<4:
        let val = q.pop()
        check val.isSome()
        check val.get() == i

    check q.isEmpty()
