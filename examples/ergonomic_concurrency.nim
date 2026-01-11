## Ergonomic Concurrency Examples
## ===============================
##
## Demonstrates the high-level, ergonomic API for concurrent programming.

import ../src/arsenal/concurrency

# =============================================================================
# Example 1: Atomic Counters (Zero Boilerplate)
# =============================================================================

proc example1_atomics() =
  echo "\n=== Example 1: Atomic Counters ==="

  # Create atomic with natural syntax
  var counter = atomic(0)

  # Natural operations
  counter.inc()
  counter += 5
  counter.value = 10

  echo "Counter value: ", counter.value
  # Output: Counter value: 10

# =============================================================================
# Example 2: Smart Locks (Automatic Type Selection)
# =============================================================================

proc example2_locks() =
  echo "\n=== Example 2: Smart Locks ==="

  # Fast lock (default)
  var fastLock = newLock()
  var sharedValue = 0

  fastLock.withLock:
    sharedValue += 1
    # Lock automatically released even on exception

  # Fair lock (FIFO, no starvation)
  var fairLock = newLock(Fair)

  fairLock.withLock:
    echo "Critical section with FIFO fairness"

  # Reader-writer lock
  var rwLock = newLock(ReadWrite)
  var data = @[1, 2, 3]

  # Multiple readers can access simultaneously
  rwLock.withReadLock:
    echo "Reading data: ", data

  # Writers get exclusive access
  rwLock.withWriteLock:
    data.add(4)
    echo "Updated data: ", data

# =============================================================================
# Example 3: Smart Queues (Automatic SPSC/MPMC)
# =============================================================================

proc example3_queues() =
  echo "\n=== Example 3: Smart Queues ==="

  # MPMC queue (safe from any thread, default)
  var queue1 = newQueue[int](capacity = 1024)

  # Push and pop with natural syntax
  discard queue1.push(42)
  discard queue1.push(43)

  let maybeValue = queue1.pop()
  if maybeValue.isSome():
    echo "Popped: ", maybeValue.get()

  # SPSC queue (optimized for single producer/consumer)
  var queue2 = newQueue[string](1024, SingleProducerSingleConsumer)

  discard queue2.push("hello")
  discard queue2.push("world")

  # Drain queue with iterator
  for item in queue2:
    echo "Got: ", item

# =============================================================================
# Example 4: Producer-Consumer Pattern
# =============================================================================

proc example4_producer_consumer() =
  echo "\n=== Example 4: Producer-Consumer ==="

  var queue = newQueue[int](capacity = 256)
  var processed = atomic(0)

  # Producer: generate items
  echo "Producing items..."
  for i in 0..<100:
    retry:  # Automatically retries with backoff
      queue.push(i)

  # Consumer: process items
  echo "Consuming items..."
  for i in 0..<100:
    retry:
      let maybeItem = queue.pop()
      if maybeItem.isSome():
        processed.inc()
        true
      else:
        false

  echo "Processed ", processed.value, " items"

# =============================================================================
# Example 5: Shared Counter with Lock
# =============================================================================

proc example5_shared_counter() =
  echo "\n=== Example 5: Shared Counter with Lock ==="

  var lock = newLock()
  var counter = 0

  # Simulate concurrent increments
  for i in 0..<1000:
    lock.withLock:
      counter += 1

  echo "Final counter: ", counter

# =============================================================================
# Example 6: Work Queue Pattern
# =============================================================================

type
  Task = object
    id: int
    data: string

proc example6_work_queue() =
  echo "\n=== Example 6: Work Queue Pattern ==="

  var workQueue = newQueue[Task](capacity = 128)
  var completedCount = atomic(0)

  # Producer: add work items
  echo "Adding tasks to queue..."
  for i in 1..10:
    let task = Task(id: i, data: "Task " & $i)
    retry:
      workQueue.push(task)

  # Worker: process tasks
  echo "Processing tasks..."
  while not workQueue.isEmpty():
    let maybeTask = workQueue.pop()
    if maybeTask.isSome():
      echo "  Processing: ", maybeTask.get().data
      completedCount.inc()

  echo "Completed ", completedCount.value, " tasks"

# =============================================================================
# Example 7: Cache with Reader-Writer Lock
# =============================================================================

type
  Cache = object
    lock: Lock
    data: seq[(string, int)]

proc newCache(): Cache =
  Cache(lock: newLock(ReadWrite), data: @[])

proc get(cache: var Cache, key: string): int =
  cache.lock.withReadLock:
    for (k, v) in cache.data:
      if k == key:
        return v
    return -1

proc put(cache: var Cache, key: string, value: int) =
  cache.lock.withWriteLock:
    cache.data.add((key, value))

proc example7_cache() =
  echo "\n=== Example 7: Cache with RW Lock ==="

  var cache = newCache()

  # Multiple writes
  cache.put("foo", 42)
  cache.put("bar", 100)

  # Multiple reads (can happen concurrently)
  echo "foo = ", cache.get("foo")
  echo "bar = ", cache.get("bar")
  echo "baz = ", cache.get("baz")  # Not found

# =============================================================================
# Main: Run all examples
# =============================================================================

when isMainModule:
  echo "Arsenal Ergonomic Concurrency Examples"
  echo "======================================"

  example1_atomics()
  example2_locks()
  example3_queues()
  example4_producer_consumer()
  example5_shared_counter()
  example6_work_queue()
  example7_cache()

  echo "\n✓ All examples completed successfully!"
