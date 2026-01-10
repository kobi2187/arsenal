## Spinlocks - Low-Level Synchronization Primitives
## ================================================
##
## Spinlocks are lightweight locks that busy-wait instead of sleeping.
## Use for very short critical sections where the overhead of OS mutexes
## is too high.
##
## WARNING: Spinlocks can waste CPU cycles and cause priority inversion.
## Only use when you know what you're doing.
##
## Variants:
## - `Spinlock`: Basic test-and-set spinlock
## - `TicketLock`: Fair FIFO spinlock (prevents starvation)
## - `RWSpinlock`: Reader-writer spinlock (multiple readers OR one writer)

import ../atomics/atomic
import ../../platform/strategies

type
  Spinlock* = object
    ## Basic spinlock using test-and-set.
    ## NOT fair - threads may starve under high contention.
    ## Use `TicketLock` for fairness.
    locked: Atomic[bool]

  TicketLock* = object
    ## Fair FIFO spinlock using ticket algorithm.
    ## Threads acquire in order of arrival. No starvation.
    ## Slightly higher overhead than basic spinlock.
    nowServing: Atomic[uint32]
    nextTicket: Atomic[uint32]

  RWSpinlock* = object
    ## Reader-writer spinlock.
    ## Multiple readers can hold the lock simultaneously.
    ## Writers have exclusive access.
    ##
    ## State encoding:
    ## - 0: unlocked
    ## - positive: number of readers
    ## - -1: writer holds lock
    state: Atomic[int32]

# =============================================================================
# Basic Spinlock
# =============================================================================

proc init*(_: typedesc[Spinlock]): Spinlock {.inline.} =
  ## Create an unlocked spinlock.
  result.locked = Atomic[bool].init(false)

proc tryAcquire*(lock: var Spinlock): bool {.inline.} =
  ## Try to acquire the lock without blocking.
  ## Returns true if acquired, false if already held.
  ##
  ## IMPLEMENTATION:
  ## Use atomic exchange to set locked=true and check old value:
  ## ```nim
  ## not lock.locked.exchange(true, Acquire)
  ## ```
  ##
  ## If old value was false, we acquired it.
  ## If old value was true, someone else has it.

  var expected = false
  lock.locked.compareExchange(expected, true, Acquire, Relaxed)

proc acquire*(lock: var Spinlock) =
  ## Acquire the lock, spinning until successful.
  ##
  ## IMPLEMENTATION:
  ## 1. Fast path: Try atomic exchange
  ## 2. If failed, spin-wait with backoff:
  ##    a. First, spin on read (avoids cache line bouncing)
  ##    b. Then try atomic exchange again
  ##    c. Use `spinHint()` (PAUSE instruction) in loop
  ##    d. Optionally: exponential backoff or yield after N iterations
  ##
  ## ```nim
  ## while lock.locked.exchange(true, Acquire):
  ##   while lock.locked.load(Relaxed):
  ##     spinHint()
  ## ```
  ##
  ## The inner loop reads without writing, which is more cache-friendly
  ## when there's high contention.

  let cfg = getConfig()
  var spins = 0

  while not lock.tryAcquire():
    # Spin on read to avoid cache line bouncing
    while lock.locked.load(Relaxed):
      spinHint()
      inc spins
      if spins > cfg.spinIterations and not cfg.busyWait:
        # Could yield to OS here if not in busy-wait mode
        discard

proc release*(lock: var Spinlock) {.inline.} =
  ## Release the lock.
  ##
  ## IMPLEMENTATION:
  ## Simply store false with Release ordering:
  ## ```nim
  ## lock.locked.store(false, Release)
  ## ```

  lock.locked.store(false, Release)

template withLock*(lock: var Spinlock, body: untyped) =
  ## Execute body while holding the lock.
  lock.acquire()
  try:
    body
  finally:
    lock.release()

# =============================================================================
# Ticket Lock (Fair FIFO)
# =============================================================================

proc init*(_: typedesc[TicketLock]): TicketLock {.inline.} =
  ## Create an unlocked ticket lock.
  result.nowServing = Atomic[uint32].init(0)
  result.nextTicket = Atomic[uint32].init(0)

proc acquire*(lock: var TicketLock) =
  ## Acquire the lock with FIFO fairness.
  ##
  ## IMPLEMENTATION:
  ## 1. Atomically get a ticket number: `myTicket = nextTicket.fetchAdd(1)`
  ## 2. Spin until `nowServing == myTicket`
  ##
  ## ```nim
  ## let myTicket = lock.nextTicket.fetchAdd(1, Relaxed)
  ## while lock.nowServing.load(Acquire) != myTicket:
  ##   spinHint()
  ## ```
  ##
  ## Tickets wrap around at 2^32, which is fine as long as there
  ## aren't 2^32 threads waiting simultaneously.

  let myTicket = lock.nextTicket.fetchAdd(1, Relaxed)
  while lock.nowServing.load(Acquire) != myTicket:
    spinHint()

proc release*(lock: var TicketLock) {.inline.} =
  ## Release the lock, advancing to next ticket.
  ##
  ## IMPLEMENTATION:
  ## Simply increment `nowServing`:
  ## ```nim
  ## discard lock.nowServing.fetchAdd(1, Release)
  ## ```

  discard lock.nowServing.fetchAdd(1, Release)

proc tryAcquire*(lock: var TicketLock): bool {.inline.} =
  ## Try to acquire without blocking.
  ## Note: This is not fair - it can skip ahead of waiters.
  ##
  ## IMPLEMENTATION:
  ## Compare-exchange: if `nowServing == nextTicket`, take both forward.

  var serving = lock.nowServing.load(Relaxed)
  var next = lock.nextTicket.load(Relaxed)
  if serving == next:
    if lock.nextTicket.compareExchange(next, next + 1, Acquire, Relaxed):
      result = true

template withLock*(lock: var TicketLock, body: untyped) =
  ## Execute body while holding the lock.
  lock.acquire()
  try:
    body
  finally:
    lock.release()

# =============================================================================
# Reader-Writer Spinlock
# =============================================================================

proc init*(_: typedesc[RWSpinlock]): RWSpinlock {.inline.} =
  ## Create an unlocked reader-writer spinlock.
  result.state = Atomic[int32].init(0)

proc acquireRead*(lock: var RWSpinlock) =
  ## Acquire read lock (shared access).
  ## Multiple readers can hold simultaneously.
  ##
  ## IMPLEMENTATION:
  ## Spin-CAS loop:
  ## 1. Read current state
  ## 2. If state >= 0 (no writer), try to increment
  ## 3. If state < 0 (writer present), spin
  ##
  ## ```nim
  ## while true:
  ##   var s = lock.state.load(Relaxed)
  ##   if s >= 0:
  ##     if lock.state.compareExchange(s, s + 1, Acquire, Relaxed):
  ##       break
  ##   else:
  ##     spinHint()
  ## ```

  while true:
    var s = lock.state.load(Relaxed)
    if s >= 0:
      if lock.state.compareExchange(s, s + 1, Acquire, Relaxed):
        break
    else:
      spinHint()

proc releaseRead*(lock: var RWSpinlock) {.inline.} =
  ## Release read lock.
  ##
  ## IMPLEMENTATION:
  ## Atomically decrement: `lock.state.fetchSub(1, Release)`

  discard lock.state.fetchSub(1, Release)

proc acquireWrite*(lock: var RWSpinlock) =
  ## Acquire write lock (exclusive access).
  ## No other readers or writers can hold.
  ##
  ## IMPLEMENTATION:
  ## Spin-CAS: wait for state == 0, then set to -1.
  ##
  ## ```nim
  ## while true:
  ##   var s: int32 = 0
  ##   if lock.state.compareExchange(s, -1, Acquire, Relaxed):
  ##     break
  ##   spinHint()
  ## ```
  ##
  ## Note: This can starve writers if readers keep arriving.
  ## For writer-priority, use a separate pending-writers flag.

  while true:
    var s: int32 = 0
    if lock.state.compareExchange(s, -1, Acquire, Relaxed):
      break
    spinHint()

proc releaseWrite*(lock: var RWSpinlock) {.inline.} =
  ## Release write lock.
  ##
  ## IMPLEMENTATION:
  ## Store 0 with Release: `lock.state.store(0, Release)`

  lock.state.store(0, Release)

proc tryAcquireRead*(lock: var RWSpinlock): bool {.inline.} =
  ## Try to acquire read lock without blocking.
  var s = lock.state.load(Relaxed)
  if s >= 0:
    result = lock.state.compareExchange(s, s + 1, Acquire, Relaxed)

proc tryAcquireWrite*(lock: var RWSpinlock): bool {.inline.} =
  ## Try to acquire write lock without blocking.
  var s: int32 = 0
  result = lock.state.compareExchange(s, -1, Acquire, Relaxed)

template withReadLock*(lock: var RWSpinlock, body: untyped) =
  ## Execute body while holding read lock.
  lock.acquireRead()
  try:
    body
  finally:
    lock.releaseRead()

template withWriteLock*(lock: var RWSpinlock, body: untyped) =
  ## Execute body while holding write lock.
  lock.acquireWrite()
  try:
    body
  finally:
    lock.releaseWrite()
