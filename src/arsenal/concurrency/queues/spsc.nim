## Single-Producer Single-Consumer (SPSC) Lock-Free Queue
## ======================================================
##
## A bounded, lock-free queue for exactly one producer and one consumer thread.
## Highest throughput when you have a dedicated producer-consumer pair.
##
## Performance: >10M operations/second typical, <50ns per operation.
##
## Usage:
## ```nim
## var queue = SpscQueue[int].init(1024)  # capacity must be power of 2
##
## # Producer thread:
## while not queue.push(value):
##   # Queue full, retry or backoff
##
## # Consumer thread:
## if (let v = queue.pop(); v.isSome):
##   process(v.get)
## ```

import std/options
import ../atomics/atomic
import ../../platform/config

const
  CacheLineSize = DefaultCacheLineSize

type
  # Cache line padding to prevent false sharing
  CacheLinePad = array[CacheLineSize, byte]

  SpscQueue*[T] = object
    ## Lock-free SPSC bounded ring buffer.
    ##
    ## Memory layout is designed to prevent false sharing:
    ## - head (producer writes, consumer reads) on its own cache line
    ## - tail (consumer writes, producer reads) on its own cache line
    ## - buffer pointer and capacity on separate line

    pad0: CacheLinePad
    head: Atomic[uint64]        ## Next position to write (producer-owned)
    pad1: CacheLinePad
    tail: Atomic[uint64]        ## Next position to read (consumer-owned)
    pad2: CacheLinePad
    buffer: ptr UncheckedArray[T]
    capacity: uint64            ## Must be power of 2
    mask: uint64                ## capacity - 1, for fast modulo

# =============================================================================
# Initialization / Destruction
# =============================================================================

proc init*[T](_: typedesc[SpscQueue[T]], capacity: int): SpscQueue[T] =
  ## Create a new SPSC queue with given capacity.
  ## Capacity MUST be a power of 2 (for fast modulo via bit masking).

  assert capacity > 0 and (capacity and (capacity - 1)) == 0,
    "Capacity must be power of 2"

  result.capacity = capacity.uint64
  result.mask = (capacity - 1).uint64
  result.head = Atomic[uint64].init(0)
  result.tail = Atomic[uint64].init(0)

  # Allocate buffer
  result.buffer = cast[ptr UncheckedArray[T]](
    alloc0(capacity * sizeof(T))
  )

proc `=destroy`*[T](q: SpscQueue[T]) =
  ## Free the queue's buffer.
  if q.buffer != nil:
    dealloc(q.buffer)

# =============================================================================
# Producer Operations (Single Thread Only!)
# =============================================================================

proc push*[T](q: var SpscQueue[T], value: sink T): bool =
  ## Push a value to the queue. Returns false if queue is full.
  ## ONLY call from the producer thread!
  ##
  ## IMPLEMENTATION:
  ## 1. Load head (relaxed - we're the only writer)
  ## 2. Load tail (acquire - synchronize with consumer)
  ## 3. Check if full: (head - tail) >= capacity
  ## 4. Write value to buffer[head & mask]
  ## 5. Store head + 1 (release - make value visible to consumer)
  ##
  ## ```nim
  ## let h = q.head.load(Relaxed)
  ## let t = q.tail.load(Acquire)
  ##
  ## if h - t >= q.capacity:
  ##   return false  # Full
  ##
  ## q.buffer[h and q.mask] = value
  ## q.head.store(h + 1, Release)
  ## return true
  ## ```
  ##
  ## Note: We use unsigned wrapping arithmetic. The queue is full when
  ## head is capacity slots ahead of tail.

  let h = q.head.load(Relaxed)
  let t = q.tail.load(Acquire)

  if h - t >= q.capacity:
    return false  # Full

  # Write to buffer
  q.buffer[h and q.mask] = value
  q.head.store(h + 1, Release)
  return true

proc tryPush*[T](q: var SpscQueue[T], value: sink T): bool {.inline.} =
  ## Alias for push (they're the same for SPSC).
  push(q, value)

# =============================================================================
# Consumer Operations (Single Thread Only!)
# =============================================================================

proc pop*[T](q: var SpscQueue[T]): Option[T] =
  ## Pop a value from the queue. Returns none if queue is empty.
  ## ONLY call from the consumer thread!
  ##
  ## IMPLEMENTATION:
  ## 1. Load tail (relaxed - we're the only writer)
  ## 2. Load head (acquire - synchronize with producer)
  ## 3. Check if empty: tail == head
  ## 4. Read value from buffer[tail & mask]
  ## 5. Store tail + 1 (release - allow producer to reuse slot)
  ##
  ## ```nim
  ## let t = q.tail.load(Relaxed)
  ## let h = q.head.load(Acquire)
  ##
  ## if t == h:
  ##   return none(T)  # Empty
  ##
  ## let value = q.buffer[t and q.mask]
  ## q.tail.store(t + 1, Release)
  ## return some(value)
  ## ```

  let t = q.tail.load(Relaxed)
  let h = q.head.load(Acquire)

  if t == h:
    return none(T)  # Empty

  # Read from buffer
  let value = q.buffer[t and q.mask]
  q.tail.store(t + 1, Release)
  return some(value)

proc tryPop*[T](q: var SpscQueue[T]): Option[T] {.inline.} =
  ## Alias for pop (they're the same for SPSC).
  pop(q)

# =============================================================================
# Status Queries (Thread-Safe)
# =============================================================================

proc isEmpty*[T](q: SpscQueue[T]): bool {.inline.} =
  ## Check if queue is empty. May be stale by the time you act on it.
  q.head.load(Relaxed) == q.tail.load(Relaxed)

proc isFull*[T](q: SpscQueue[T]): bool {.inline.} =
  ## Check if queue is full. May be stale by the time you act on it.
  let h = q.head.load(Relaxed)
  let t = q.tail.load(Relaxed)
  h - t >= q.capacity

proc len*[T](q: SpscQueue[T]): int {.inline.} =
  ## Approximate number of items in queue.
  let h = q.head.load(Relaxed)
  let t = q.tail.load(Relaxed)
  (h - t).int

proc capacity*[T](q: SpscQueue[T]): int {.inline.} =
  ## Maximum capacity of the queue.
  q.capacity.int
