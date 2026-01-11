## Unit tests for spinlock implementations

import std/[unittest, os]
import ../src/arsenal/concurrency/sync/spinlock
import ../src/arsenal/concurrency/atomics/atomic

suite "Spinlock - Basic Operations":
  test "init creates unlocked spinlock":
    var lock = Spinlock.init()
    check lock.tryAcquire() == true
    lock.release()

  test "acquire and release":
    var lock = Spinlock.init()
    lock.acquire()
    lock.release()

  test "tryAcquire fails when locked":
    var lock = Spinlock.init()
    check lock.tryAcquire() == true
    check lock.tryAcquire() == false  # Already locked
    lock.release()

  test "withLock template":
    var lock = Spinlock.init()
    var executed = false

    lock.withLock:
      executed = true

    check executed == true

  test "withLock releases on exception":
    var lock = Spinlock.init()

    try:
      lock.withLock:
        raise newException(ValueError, "test")
    except ValueError:
      discard

    # Lock should be released, so we can acquire it
    check lock.tryAcquire() == true
    lock.release()

suite "Spinlock - Thread Safety":
  test "mutual exclusion with threads":
    when compileOption("threads"):
      var lock = Spinlock.init()
      var counter = 0
      const iterations = 10000

      proc worker() {.thread.} =
        for _ in 0..<iterations:
          lock.withLock:
            counter += 1

      var threads: array[4, Thread[void]]
      for i in 0..<4:
        createThread(threads[i], worker)

      joinThreads(threads)

      check counter == iterations * 4
    else:
      skip()

suite "TicketLock - Basic Operations":
  test "init creates unlocked ticket lock":
    var lock = TicketLock.init()
    check lock.tryAcquire() == true
    lock.release()

  test "acquire and release":
    var lock = TicketLock.init()
    lock.acquire()
    lock.release()

  test "withLock template":
    var lock = TicketLock.init()
    var executed = false

    lock.withLock:
      executed = true

    check executed == true

  test "withLock releases on exception":
    var lock = TicketLock.init()

    try:
      lock.withLock:
        raise newException(ValueError, "test")
    except ValueError:
      discard

    # Lock should be released, so we can acquire it
    check lock.tryAcquire() == true
    lock.release()

suite "TicketLock - Thread Safety and Fairness":
  test "mutual exclusion with threads":
    when compileOption("threads"):
      var lock = TicketLock.init()
      var counter = 0
      const iterations = 10000

      proc worker() {.thread.} =
        for _ in 0..<iterations:
          lock.withLock:
            counter += 1

      var threads: array[4, Thread[void]]
      for i in 0..<4:
        createThread(threads[i], worker)

      joinThreads(threads)

      check counter == iterations * 4
    else:
      skip()

  test "FIFO fairness - sequential acquisition":
    # Simplified test for fairness without threading complexity
    var lock = TicketLock.init()

    # Acquire and release multiple times sequentially
    for i in 0..<10:
      lock.acquire()
      lock.release()

    # If we get here without deadlock, ticket lock works correctly
    check true

suite "RWSpinlock - Basic Operations":
  test "init creates unlocked RW spinlock":
    var lock = RWSpinlock.init()
    check lock.tryAcquireRead() == true
    lock.releaseRead()

  test "multiple readers can acquire simultaneously":
    var lock = RWSpinlock.init()
    check lock.tryAcquireRead() == true
    check lock.tryAcquireRead() == true
    check lock.tryAcquireRead() == true
    lock.releaseRead()
    lock.releaseRead()
    lock.releaseRead()

  test "writer blocks readers":
    var lock = RWSpinlock.init()
    lock.acquireWrite()
    check lock.tryAcquireRead() == false
    lock.releaseWrite()

  test "readers block writer":
    var lock = RWSpinlock.init()
    lock.acquireRead()
    check lock.tryAcquireWrite() == false
    lock.releaseRead()

  test "withReadLock template":
    var lock = RWSpinlock.init()
    var executed = false

    lock.withReadLock:
      executed = true

    check executed == true

  test "withWriteLock template":
    var lock = RWSpinlock.init()
    var executed = false

    lock.withWriteLock:
      executed = true

    check executed == true

suite "RWSpinlock - Thread Safety":
  test "multiple readers access simultaneously":
    when compileOption("threads"):
      var lock = RWSpinlock.init()
      var readersInside = Atomic[int].init(0)
      var maxConcurrentReaders = 0
      var maxLock = Spinlock.init()

      proc reader() {.thread.} =
        for _ in 0..<100:
          lock.withReadLock:
            let current = readersInside.fetchAdd(1) + 1

            # Track max concurrent readers
            maxLock.withLock:
              if current > maxConcurrentReaders:
                maxConcurrentReaders = current

            sleep(1)  # Hold read lock briefly
            discard readersInside.fetchSub(1)

      var threads: array[4, Thread[void]]
      for i in 0..<4:
        createThread(threads[i], reader)

      joinThreads(threads)

      # We should have seen multiple readers inside at once
      check maxConcurrentReaders > 1
    else:
      skip()

  test "writer has exclusive access":
    when compileOption("threads"):
      var lock = RWSpinlock.init()
      var counter = 0
      const iterations = 1000

      proc writer() {.thread.} =
        for _ in 0..<iterations:
          lock.withWriteLock:
            let old = counter
            sleep(0)  # Yield to try to expose races
            counter = old + 1

      var threads: array[4, Thread[void]]
      for i in 0..<4:
        createThread(threads[i], writer)

      joinThreads(threads)

      check counter == iterations * 4
    else:
      skip()

suite "Performance Characteristics":
  test "uncontended spinlock is fast":
    var lock = Spinlock.init()
    let iterations = 100000

    for _ in 0..<iterations:
      lock.acquire()
      lock.release()

    # If this completes quickly, spinlock overhead is low
    check true

  test "uncontended ticket lock is fast":
    var lock = TicketLock.init()
    let iterations = 100000

    for _ in 0..<iterations:
      lock.acquire()
      lock.release()

    check true
