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
## spawn:
##   ch.send(42)  # Blocks until someone receives
##
## spawn:
##   let value = ch.recv()  # Blocks until someone sends
##   echo value  # 42
##
## runAll()
## ```

import std/options
import std/deques
import ../coroutines/coroutine
import ../scheduler
import ../sync/spinlock

type
  ChannelState* = enum
    ## Channel lifecycle states.
    csOpen      ## Normal operation
    csClosed    ## Closed, no more sends allowed

  ChannelError* = object of CatchableError
    ## Error raised on invalid channel operations.

  WaiterRef[T] = ref object
    ## A coroutine waiting on a channel operation.
    ## Heap-allocated because coroutine stacks are shared and
    ## stack pointers become invalid after yield.
    coro: Coroutine
    value: T            # For senders: the value to send
    hasValue: bool      # For receivers: set to true when value is received

  Chan*[T] = ref object
    ## Unbuffered (synchronous) channel.
    ## Send and receive must rendezvous - each send blocks until
    ## a corresponding receive, and vice versa.
    state: ChannelState
    sendWaiters: Deque[WaiterRef[T]]
    recvWaiters: Deque[WaiterRef[T]]
    lock: Spinlock

  BufferedChan*[T] = ref object
    ## Buffered (asynchronous) channel with fixed capacity.
    ## Send blocks only when buffer is full.
    ## Receive blocks only when buffer is empty.
    state: ChannelState
    buffer: Deque[T]
    capacity: int
    sendWaiters: Deque[WaiterRef[T]]
    recvWaiters: Deque[WaiterRef[T]]
    lock: Spinlock

# =============================================================================
# Unbuffered Channel
# =============================================================================

proc newChan*[T](): Chan[T] =
  ## Create an unbuffered channel.
  ## All operations synchronize - send waits for receive.
  result = Chan[T](
    state: csOpen,
    sendWaiters: initDeque[WaiterRef[T]](),
    recvWaiters: initDeque[WaiterRef[T]](),
    lock: Spinlock.init()
  )

proc send*[T](ch: Chan[T], value: T) =
  ## Send a value on the channel. Blocks until a receiver is ready.
  ##
  ## For unbuffered channels, this is a rendezvous - the sender blocks
  ## until a receiver takes the value directly.

  ch.lock.acquire()

  if ch.state == csClosed:
    ch.lock.release()
    raise newException(ChannelError, "send on closed channel")

  if ch.recvWaiters.len > 0:
    # Direct transfer to waiting receiver
    let waiter = ch.recvWaiters.popFirst()
    waiter.value = value
    waiter.hasValue = true
    ch.lock.release()
    ready(waiter.coro)  # Wake receiver
  else:
    # No receiver ready - block until one arrives
    let currentCoro = running()
    if currentCoro == nil:
      ch.lock.release()
      raise newException(ChannelError, "send called outside coroutine context")

    # Heap-allocate the waiter so it survives the yield
    let waiter = WaiterRef[T](coro: currentCoro, value: value, hasValue: true)
    ch.sendWaiters.addLast(waiter)
    ch.lock.release()
    coroYield()  # Suspend until receiver wakes us

proc recv*[T](ch: Chan[T]): T =
  ## Receive a value from the channel. Blocks until a sender is ready.
  ##
  ## For unbuffered channels, this is a rendezvous - the receiver blocks
  ## until a sender provides a value directly.

  ch.lock.acquire()

  if ch.sendWaiters.len > 0:
    # Direct transfer from waiting sender
    let waiter = ch.sendWaiters.popFirst()
    result = waiter.value
    ch.lock.release()
    ready(waiter.coro)  # Wake sender
  elif ch.state == csClosed:
    ch.lock.release()
    return default(T)  # Return zero value on closed channel
  else:
    # No sender ready - block until one arrives
    let currentCoro = running()
    if currentCoro == nil:
      ch.lock.release()
      raise newException(ChannelError, "recv called outside coroutine context")

    # Heap-allocate the waiter so it survives the yield
    let waiter = WaiterRef[T](coro: currentCoro, hasValue: false)
    ch.recvWaiters.addLast(waiter)
    ch.lock.release()
    coroYield()  # Suspend until sender wakes us
    result = waiter.value

proc tryRecv*[T](ch: Chan[T]): Option[T] =
  ## Try to receive without blocking. Returns none if no sender ready.

  ch.lock.acquire()

  if ch.sendWaiters.len > 0:
    let waiter = ch.sendWaiters.popFirst()
    result = some(waiter.value)
    ch.lock.release()
    ready(waiter.coro)
  else:
    ch.lock.release()
    result = none(T)

proc trySend*[T](ch: Chan[T], value: T): bool =
  ## Try to send without blocking. Returns false if no receiver ready.

  ch.lock.acquire()

  if ch.state == csClosed:
    ch.lock.release()
    return false

  if ch.recvWaiters.len > 0:
    let waiter = ch.recvWaiters.popFirst()
    waiter.value = value
    waiter.hasValue = true
    ch.lock.release()
    ready(waiter.coro)
    result = true
  else:
    ch.lock.release()
    result = false

proc close*[T](ch: Chan[T]) =
  ## Close the channel. No more sends allowed.
  ## Pending receivers will receive zero values.

  ch.lock.acquire()
  ch.state = csClosed

  # Wake all waiting receivers with default values
  while ch.recvWaiters.len > 0:
    let waiter = ch.recvWaiters.popFirst()
    waiter.value = default(T)
    waiter.hasValue = true
    ready(waiter.coro)

  # Wake all waiting senders (they'll see closed state on retry)
  while ch.sendWaiters.len > 0:
    let waiter = ch.sendWaiters.popFirst()
    ready(waiter.coro)

  ch.lock.release()

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
    sendWaiters: initDeque[WaiterRef[T]](),
    recvWaiters: initDeque[WaiterRef[T]](),
    lock: Spinlock.init()
  )

proc send*[T](ch: BufferedChan[T], value: T) =
  ## Send a value on the buffered channel.
  ## Blocks only if the buffer is full.

  ch.lock.acquire()

  if ch.state == csClosed:
    ch.lock.release()
    raise newException(ChannelError, "send on closed channel")

  # If there's a waiting receiver and buffer is empty, transfer directly
  if ch.recvWaiters.len > 0 and ch.buffer.len == 0:
    let waiter = ch.recvWaiters.popFirst()
    waiter.value = value
    waiter.hasValue = true
    ch.lock.release()
    ready(waiter.coro)
  elif ch.buffer.len < ch.capacity:
    # Buffer has space
    ch.buffer.addLast(value)
    ch.lock.release()
  else:
    # Buffer full - block until space available
    let currentCoro = running()
    if currentCoro == nil:
      ch.lock.release()
      raise newException(ChannelError, "send called outside coroutine context")

    let waiter = WaiterRef[T](coro: currentCoro, value: value, hasValue: true)
    ch.sendWaiters.addLast(waiter)
    ch.lock.release()
    coroYield()

proc recv*[T](ch: BufferedChan[T]): T =
  ## Receive a value from the buffered channel.
  ## Blocks only if the buffer is empty and no senders waiting.

  ch.lock.acquire()

  if ch.buffer.len > 0:
    # Take from buffer
    result = ch.buffer.popFirst()

    # If there's a waiting sender, move their value to buffer
    if ch.sendWaiters.len > 0:
      let waiter = ch.sendWaiters.popFirst()
      ch.buffer.addLast(waiter.value)
      ch.lock.release()
      ready(waiter.coro)
    else:
      ch.lock.release()
  elif ch.sendWaiters.len > 0:
    # Take directly from waiting sender
    let waiter = ch.sendWaiters.popFirst()
    result = waiter.value
    ch.lock.release()
    ready(waiter.coro)
  elif ch.state == csClosed:
    ch.lock.release()
    return default(T)
  else:
    # Empty and no senders - block
    let currentCoro = running()
    if currentCoro == nil:
      ch.lock.release()
      raise newException(ChannelError, "recv called outside coroutine context")

    let waiter = WaiterRef[T](coro: currentCoro, hasValue: false)
    ch.recvWaiters.addLast(waiter)
    ch.lock.release()
    coroYield()
    result = waiter.value

proc tryRecv*[T](ch: BufferedChan[T]): Option[T] =
  ## Try to receive without blocking.

  ch.lock.acquire()

  if ch.buffer.len > 0:
    result = some(ch.buffer.popFirst())
    if ch.sendWaiters.len > 0:
      let waiter = ch.sendWaiters.popFirst()
      ch.buffer.addLast(waiter.value)
      ch.lock.release()
      ready(waiter.coro)
    else:
      ch.lock.release()
  elif ch.sendWaiters.len > 0:
    let waiter = ch.sendWaiters.popFirst()
    result = some(waiter.value)
    ch.lock.release()
    ready(waiter.coro)
  else:
    ch.lock.release()
    result = none(T)

proc trySend*[T](ch: BufferedChan[T], value: T): bool =
  ## Try to send without blocking.

  ch.lock.acquire()

  if ch.state == csClosed:
    ch.lock.release()
    return false

  if ch.recvWaiters.len > 0 and ch.buffer.len == 0:
    let waiter = ch.recvWaiters.popFirst()
    waiter.value = value
    waiter.hasValue = true
    ch.lock.release()
    ready(waiter.coro)
    result = true
  elif ch.buffer.len < ch.capacity:
    ch.buffer.addLast(value)
    ch.lock.release()
    result = true
  else:
    ch.lock.release()
    result = false

proc close*[T](ch: BufferedChan[T]) =
  ## Close the channel.

  ch.lock.acquire()
  ch.state = csClosed

  # Wake all waiting receivers with default values
  while ch.recvWaiters.len > 0:
    let waiter = ch.recvWaiters.popFirst()
    waiter.value = default(T)
    waiter.hasValue = true
    ready(waiter.coro)

  # Wake all waiting senders
  while ch.sendWaiters.len > 0:
    let waiter = ch.sendWaiters.popFirst()
    ready(waiter.coro)

  ch.lock.release()

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
