## Arsenal Concurrency - Ergonomic Lock-Free Programming
## ======================================================
##
## High-level, ergonomic API for lock-free concurrent programming.
## Provides safe defaults while allowing expert users to drop down to
## unsafe primitives when needed.
##
## Quick Start:
## ```nim
## import arsenal/concurrency
##
## # Atomic counter (safe and easy)
## var counter = atomic(0)
## counter.inc()
## counter += 5
## echo counter.value  # Ergonomic access
##
## # Lock-free queue (pick the right one automatically)
## var queue = newQueue[int](capacity = 1024)
## queue.push(42)
## if let val = queue.pop():
##   echo "Got: ", val
##
## # Spinlock with RAII
## var lock = newLock()
## lock.withLock:
##   # critical section - automatically released
##   echo "Safe!"
## ```
##
## Philosophy:
## - **Safe by default**: Use the safest option unless you opt-in to unsafe
## - **Ergonomic**: Minimal boilerplate, natural syntax
## - **Zero-cost**: Abstractions compile away to direct calls
## - **Composable**: Mix and match primitives
## - **Fast path**: Common operations are one-liners

# Re-export core primitives
import concurrency/atomics/atomic
export atomic.Atomic, atomic.MemoryOrder
export atomic.load, atomic.store, atomic.exchange
export atomic.compareExchange, atomic.compareExchangeWeak
export atomic.fetchAdd, atomic.fetchSub, atomic.fetchAnd, atomic.fetchOr, atomic.fetchXor
export atomic.inc, atomic.dec, atomic.`+=`, atomic.`-=`
export atomic.atomicThreadFence, atomic.atomicSignalFence, atomic.spinHint

# Re-export memory order enum values
const
  Relaxed* = atomic.Relaxed
  Consume* = atomic.Consume
  Acquire* = atomic.Acquire
  Release* = atomic.Release
  AcqRel* = atomic.AcqRel
  SeqCst* = atomic.SeqCst

import concurrency/sync/spinlock
export spinlock.Spinlock, spinlock.TicketLock, spinlock.RWSpinlock
export spinlock.withLock, spinlock.withReadLock, spinlock.withWriteLock

import concurrency/queues/spsc
export spsc.SpscQueue

import concurrency/queues/mpmc
export mpmc.MpmcQueue

# =============================================================================
# Ergonomic Wrappers
# =============================================================================

# Atomic value with natural syntax
proc atomic*[T](value: T): Atomic[T] {.inline.} =
  ## Create an atomic value with ergonomic syntax.
  ##
  ## **Note**: Currently only supports integer types (int, uint, bool).
  ## Float, pointer, and enum types are not yet supported.
  ## See atomic.nim for TODO list.
  ##
  ## ```nim
  ## var counter = atomic(0)
  ## counter.inc()
  ## echo counter.value  # Natural access
  ## ```
  Atomic[T].init(value)

proc value*[T](a: Atomic[T]): T {.inline.} =
  ## Get the current value with ergonomic property-like syntax.
  ## Uses sequentially-consistent ordering by default (safest).
  a.load(SeqCst)

proc `value=`*[T](a: var Atomic[T], val: T) {.inline.} =
  ## Set the value with ergonomic property-like syntax.
  ## Uses sequentially-consistent ordering by default (safest).
  a.store(val, SeqCst)

# Smart lock that chooses the right spinlock type
type
  LockKind* = enum
    Fast       ## Fastest, but unfair (may starve)
    Fair       ## FIFO ordering, prevents starvation
    ReadWrite  ## Multiple readers OR one writer

  Lock* = object
    ## Smart lock that picks the right implementation.
    ## Ergonomic RAII-style locking.
    case kind: LockKind
    of Fast:
      fast: Spinlock
    of Fair:
      fair: TicketLock
    of ReadWrite:
      rw: RWSpinlock

proc newLock*(kind: LockKind = Fast): Lock =
  ## Create a new lock of the specified kind.
  ## Defaults to Fast (best performance, use Fair if you need FIFO).
  result = Lock(kind: kind)
  case kind
  of Fast:
    result.fast = Spinlock.init()
  of Fair:
    result.fair = TicketLock.init()
  of ReadWrite:
    result.rw = RWSpinlock.init()

template withLock*(lock: var Lock, body: untyped) =
  ## Execute body while holding the lock (RAII style).
  ## Lock is automatically released even on exception.
  case lock.kind
  of Fast:
    lock.fast.withLock:
      body
  of Fair:
    lock.fair.withLock:
      body
  of ReadWrite:
    # Default to write lock for safety
    lock.rw.withWriteLock:
      body

template withReadLock*(lock: var Lock, body: untyped) =
  ## Execute body while holding read lock (ReadWrite locks only).
  assert lock.kind == ReadWrite, "withReadLock requires ReadWrite lock"
  lock.rw.withReadLock:
    body

template withWriteLock*(lock: var Lock, body: untyped) =
  ## Execute body while holding write lock (ReadWrite locks only).
  assert lock.kind == ReadWrite, "withWriteLock requires ReadWrite lock"
  lock.rw.withWriteLock:
    body

# Smart queue that picks SPSC or MPMC based on usage
type
  QueueKind* = enum
    SingleProducerSingleConsumer  ## Fastest (>10M ops/sec)
    MultiProducerMultiConsumer    ## Thread-safe from any thread

  Queue*[T] = object
    ## Smart queue that picks the right implementation.
    ## Ergonomic push/pop with automatic capacity management.
    case kind: QueueKind
    of SingleProducerSingleConsumer:
      spsc: SpscQueue[T]
    of MultiProducerMultiConsumer:
      mpmc: MpmcQueue[T]

proc newQueue*[T](capacity: int, kind: QueueKind = MultiProducerMultiConsumer): Queue[T] =
  ## Create a new queue with the specified capacity.
  ## Defaults to MPMC (safest), use SPSC for single producer/consumer.
  ##
  ## Capacity must be a power of 2.
  ##
  ## ```nim
  ## # Safe for any threading scenario
  ## var q1 = newQueue[int](1024)
  ##
  ## # Optimized for dedicated producer/consumer
  ## var q2 = newQueue[int](1024, SingleProducerSingleConsumer)
  ## ```
  result = Queue[T](kind: kind)
  case kind
  of SingleProducerSingleConsumer:
    result.spsc = SpscQueue[T].init(capacity)
  of MultiProducerMultiConsumer:
    result.mpmc = MpmcQueue[T].init(capacity)

proc push*[T](q: var Queue[T], value: sink T): bool {.inline.} =
  ## Push a value to the queue. Returns false if full.
  ##
  ## ```nim
  ## var queue = newQueue[int](1024)
  ## if queue.push(42):
  ##   echo "Pushed successfully"
  ## ```
  case q.kind
  of SingleProducerSingleConsumer:
    q.spsc.push(value)
  of MultiProducerMultiConsumer:
    q.mpmc.push(value)

import std/options

proc pop*[T](q: var Queue[T]): Option[T] {.inline.} =
  ## Pop a value from the queue. Returns none if empty.
  ##
  ## ```nim
  ## var queue = newQueue[int](1024)
  ## if let val = queue.pop():
  ##   echo "Got: ", val
  ## ```
  case q.kind
  of SingleProducerSingleConsumer:
    q.spsc.pop()
  of MultiProducerMultiConsumer:
    q.mpmc.pop()

proc isEmpty*[T](q: Queue[T]): bool {.inline.} =
  ## Check if queue is empty (may be stale).
  case q.kind
  of SingleProducerSingleConsumer:
    q.spsc.isEmpty()
  of MultiProducerMultiConsumer:
    q.mpmc.isEmpty()

proc len*[T](q: Queue[T]): int {.inline.} =
  ## Get approximate number of items in queue.
  case q.kind
  of SingleProducerSingleConsumer:
    q.spsc.len()
  of MultiProducerMultiConsumer:
    q.mpmc.len()

proc capacity*[T](q: Queue[T]): int {.inline.} =
  ## Get maximum capacity of queue.
  case q.kind
  of SingleProducerSingleConsumer:
    q.spsc.capacity()
  of MultiProducerMultiConsumer:
    q.mpmc.capacity()

# Optional: Iterator-style API for draining queues
iterator items*[T](q: var Queue[T]): T =
  ## Drain all items from the queue.
  ##
  ## ```nim
  ## for item in queue:
  ##   echo item
  ## ```
  while true:
    let val = q.pop()
    if val.isNone:
      break
    yield val.get()

# =============================================================================
# Common Patterns
# =============================================================================

template retry*(op: untyped): untyped =
  ## Retry an operation until it succeeds.
  ## Uses exponential backoff to reduce contention.
  ##
  ## ```nim
  ## retry:
  ##   queue.push(value)
  ## ```
  var b = 1
  const maxB = 64
  while not (op):
    for _ in 0..<b:
      spinHint()
    b = min(b * 2, maxB)

# Export options for ergonomic unpacking
export options.Option, options.some, options.none, options.isSome, options.isNone, options.get

# =============================================================================
# High-Level Concurrency (M2-M6: Coroutines, Channels, Go-style DSL)
# =============================================================================

# Coroutines
import concurrency/coroutines/coroutine
export coroutine.Coroutine, coroutine.CoroutineState
export coroutine.newCoroutine, coroutine.resume, coroutine.destroy
export coroutine.isFinished, coroutine.isSuspended, coroutine.isReady
export coroutine.coroYield, coroutine.running

# Scheduler
import concurrency/scheduler
export scheduler.ready, scheduler.schedule, scheduler.spawn
export scheduler.runNext, scheduler.runAll, scheduler.runUntilEmpty
export scheduler.hasPending, scheduler.currentCoroutine

# Channels
import concurrency/channels/channel
export channel.Chan, channel.BufferedChan
export channel.newChan, channel.newBufferedChan
export channel.send, channel.recv, channel.trySend, channel.tryRecv
export channel.close, channel.isClosed
# Note: len and cap are already exported for Queue, avoid conflicts

# Select
import concurrency/channels/select
export select.select, select.sendTo, select.recvFrom

# Go-style DSL
import concurrency/dsl/go_macro
export go_macro.go, go_macro.`<-`

# =============================================================================
# Convenience Helpers
# =============================================================================

proc runScheduler*() =
  ## Run the scheduler until all coroutines complete.
  ## Alias for runAll() for Go-style code.
  runAll()
