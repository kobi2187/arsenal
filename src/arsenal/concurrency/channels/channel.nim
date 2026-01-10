## Go-Style Channels
## =================
##
## Channels provide typed, synchronized communication between coroutines.
## They are the primary mechanism for safe data sharing in Arsenal's
## concurrency model.
##
## Two variants:
## - Unbuffered (synchronous): Send blocks until receive, and vice versa
## - Buffered (asynchronous): Send blocks only when full, receive when empty
##
## Usage:
## ```nim
## let ch = newChan[int]()  # Unbuffered channel
##
## go:
##   ch.send(42)  # Blocks until someone receives
##
## go:
##   let value = ch.recv()  # Blocks until someone sends
##   echo value  # 42
## ```

import std/options
import std/deques
import ../coroutines/coroutine
import ../queues/spsc
import ../sync/spinlock

type
  ChannelState* = enum
    ## Channel lifecycle states.
    csOpen      ## Normal operation
    csClosed    ## Closed, no more sends allowed

  ChannelError* = object of CatchableError
    ## Error raised on invalid channel operations.

  WaitQueue[T] = object
    ## Queue of coroutines waiting on a channel operation.
    ## Used for unbuffered channels and when buffered channels are full/empty.
    waiters: Deque[tuple[coro: Coroutine, value: ptr T]]
    lock: Spinlock

  Chan*[T] = ref object
    ## Unbuffered (synchronous) channel.
    ## Send and receive must rendezvous - each send blocks until
    ## a corresponding receive, and vice versa.
    state: ChannelState
    sendWaiters: WaitQueue[T]
    recvWaiters: WaitQueue[T]
    lock: Spinlock

  BufferedChan*[T] = ref object
    ## Buffered (asynchronous) channel with fixed capacity.
    ## Send blocks only when buffer is full.
    ## Receive blocks only when buffer is empty.
    state: ChannelState
    buffer: Deque[T]
    capacity: int
    sendWaiters: WaitQueue[T]
    recvWaiters: WaitQueue[T]
    lock: Spinlock

# =============================================================================
# Unbuffered Channel
# =============================================================================

proc newChan*[T](): Chan[T] =
  ## Create an unbuffered channel.
  ## All operations synchronize - send waits for receive.
  result = Chan[T](
    state: csOpen,
    lock: Spinlock.init()
  )

proc send*[T](ch: Chan[T], value: T) =
  ## Send a value on the channel. Blocks until a receiver is ready.
  ##
  ## IMPLEMENTATION:
  ## 1. Acquire lock
  ## 2. Check if channel is closed -> raise error
  ## 3. Check if there's a waiting receiver:
  ##    a. If yes: transfer value directly, wake receiver, return
  ##    b. If no: add self to sendWaiters, yield, wake up when matched
  ##
  ## ```nim
  ## ch.lock.acquire()
  ## defer: ch.lock.release()
  ##
  ## if ch.state == csClosed:
  ##   raise newException(ChannelError, "send on closed channel")
  ##
  ## if ch.recvWaiters.len > 0:
  ##   # Direct transfer to waiting receiver
  ##   let (receiver, destPtr) = ch.recvWaiters.popFirst()
  ##   destPtr[] = value
  ##   ch.lock.release()
  ##   scheduler.ready(receiver)  # Wake receiver
  ## else:
  ##   # No receiver, block until one arrives
  ##   var valueCopy = value
  ##   ch.sendWaiters.addLast((running(), addr valueCopy))
  ##   ch.lock.release()
  ##   coroYield()  # Suspend until receiver wakes us
  ## ```

  if ch.state == csClosed:
    raise newException(ChannelError, "send on closed channel")

  # TODO: Implement with coroutine scheduling
  discard

proc recv*[T](ch: Chan[T]): T =
  ## Receive a value from the channel. Blocks until a sender is ready.
  ##
  ## IMPLEMENTATION:
  ## 1. Acquire lock
  ## 2. Check if there's a waiting sender:
  ##    a. If yes: take value, wake sender, return value
  ##    b. If no: add self to recvWaiters, yield, return value when woken
  ## 3. If closed and no senders: return default value or raise
  ##
  ## ```nim
  ## ch.lock.acquire()
  ## defer: ch.lock.release()
  ##
  ## if ch.sendWaiters.len > 0:
  ##   # Direct transfer from waiting sender
  ##   let (sender, valuePtr) = ch.sendWaiters.popFirst()
  ##   result = valuePtr[]
  ##   ch.lock.release()
  ##   scheduler.ready(sender)  # Wake sender
  ## elif ch.state == csClosed:
  ##   return default(T)  # Or raise, depending on API choice
  ## else:
  ##   # No sender, block until one arrives
  ##   var dest: T
  ##   ch.recvWaiters.addLast((running(), addr dest))
  ##   ch.lock.release()
  ##   coroYield()
  ##   result = dest
  ## ```

  if ch.state == csClosed:
    raise newException(ChannelError, "recv on closed channel")

  # TODO: Implement with coroutine scheduling
  discard

proc tryRecv*[T](ch: Chan[T]): Option[T] =
  ## Try to receive without blocking. Returns none if no sender ready.
  ##
  ## IMPLEMENTATION:
  ## Same as recv but return none instead of blocking.

  result = none(T)

proc trySend*[T](ch: Chan[T], value: T): bool =
  ## Try to send without blocking. Returns false if no receiver ready.
  ##
  ## IMPLEMENTATION:
  ## Same as send but return false instead of blocking.

  result = false

proc close*[T](ch: Chan[T]) =
  ## Close the channel. No more sends allowed.
  ## Pending receivers will receive zero values.
  ##
  ## IMPLEMENTATION:
  ## 1. Set state to csClosed
  ## 2. Wake all waiting receivers with default values
  ## 3. Wake all waiting senders (they'll see closed state)

  ch.state = csClosed
  # TODO: Wake waiters

proc isClosed*[T](ch: Chan[T]): bool {.inline.} =
  ## Check if channel is closed.
  ch.state == csClosed

# =============================================================================
# Buffered Channel
# =============================================================================

proc newBufferedChan*[T](capacity: int): BufferedChan[T] =
  ## Create a buffered channel with the given capacity.
  ## Send blocks only when buffer is full.
  ## Receive blocks only when buffer is empty.
  assert capacity > 0, "Capacity must be positive"
  result = BufferedChan[T](
    state: csOpen,
    buffer: initDeque[T](),
    capacity: capacity,
    lock: Spinlock.init()
  )

proc send*[T](ch: BufferedChan[T], value: T) =
  ## Send a value on the buffered channel.
  ## Blocks only if the buffer is full.
  ##
  ## IMPLEMENTATION:
  ## 1. Acquire lock
  ## 2. If there's a waiting receiver and buffer is empty:
  ##    - Transfer directly, wake receiver
  ## 3. Elif buffer has space:
  ##    - Add to buffer
  ## 4. Else (buffer full):
  ##    - Add self to sendWaiters, yield
  ##
  ## ```nim
  ## ch.lock.acquire()
  ##
  ## if ch.recvWaiters.len > 0 and ch.buffer.len == 0:
  ##   let (receiver, destPtr) = ch.recvWaiters.popFirst()
  ##   destPtr[] = value
  ##   ch.lock.release()
  ##   scheduler.ready(receiver)
  ## elif ch.buffer.len < ch.capacity:
  ##   ch.buffer.addLast(value)
  ##   ch.lock.release()
  ## else:
  ##   var valueCopy = value
  ##   ch.sendWaiters.addLast((running(), addr valueCopy))
  ##   ch.lock.release()
  ##   coroYield()
  ## ```

  if ch.state == csClosed:
    raise newException(ChannelError, "send on closed channel")

  # TODO: Implement
  discard

proc recv*[T](ch: BufferedChan[T]): T =
  ## Receive a value from the buffered channel.
  ## Blocks only if the buffer is empty.
  ##
  ## IMPLEMENTATION:
  ## 1. Acquire lock
  ## 2. If buffer has items:
  ##    - Take from buffer
  ##    - If waiting sender: move their value to buffer, wake them
  ## 3. Elif waiting sender:
  ##    - Take directly from sender, wake them
  ## 4. Else (empty, no senders):
  ##    - Add self to recvWaiters, yield

  if ch.state == csClosed and ch.buffer.len == 0:
    raise newException(ChannelError, "recv on closed empty channel")

  # TODO: Implement
  discard

proc tryRecv*[T](ch: BufferedChan[T]): Option[T] =
  ## Try to receive without blocking.
  result = none(T)

proc trySend*[T](ch: BufferedChan[T], value: T): bool =
  ## Try to send without blocking.
  result = false

proc close*[T](ch: BufferedChan[T]) =
  ## Close the channel.
  ch.state = csClosed

proc isClosed*[T](ch: BufferedChan[T]): bool {.inline.} =
  ch.state == csClosed

proc len*[T](ch: BufferedChan[T]): int {.inline.} =
  ## Number of items currently in buffer.
  ch.buffer.len

proc cap*[T](ch: BufferedChan[T]): int {.inline.} =
  ## Buffer capacity.
  ch.capacity

# =============================================================================
# Channel Concept
# =============================================================================

type
  AnyChannel*[T] = concept ch
    ## Unified interface for both buffered and unbuffered channels.
    ch.send(T)
    ch.recv() is T
    ch.close()
    ch.isClosed() is bool
