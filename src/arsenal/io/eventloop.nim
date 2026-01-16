## Event Loop Foundation
## =====================
##
## Asynchronous I/O event loop that integrates with coroutines.
## Supports epoll (Linux), kqueue (macOS/BSD), IOCP (Windows).
##
## The event loop runs in a dedicated coroutine and processes I/O events,
## resuming coroutines when their I/O operations complete.
##
## Usage:
## ```nim
## let loop = newEventLoop()
##
## # Register a socket for reading
## loop.addRead(socket, coro)
##
## # Run the event loop
## loop.run()
## ```

import std/options
import std/tables
import std/selectors  # Nim's cross-platform I/O multiplexing (epoll/kqueue/IOCP)
import ../platform/config
import ../concurrency/coroutines/coroutine
import ../concurrency/scheduler

type
  Future*[T] = ref object
    ## Placeholder for async result (simplified for now).
    ## Full implementation would integrate with coroutine system.
    completed*: bool
    value*: T

  IoWaiter* = ref object
    ## A coroutine waiting for I/O.
    coro*: Coroutine
    kind*: EventKind

  EventLoop* = ref object
    ## Central event loop for async I/O operations.
    ## Integrates with coroutine scheduler to resume coroutines
    ## when I/O operations complete.
    ## Uses std/selectors for cross-platform I/O multiplexing.
    stopped*: bool
    selector*: Selector[IoWaiter]  # Nim's selector (epoll/kqueue/IOCP wrapper)
    waiters*: Table[int, IoWaiter]  # fd -> waiting coroutine

  EventKind* = enum
    ## Types of I/O events we can wait for.
    ekRead        ## Readable (data available or connection ready)
    ekWrite       ## Writable (can send data)
    ekAccept      ## Incoming connection (server socket)
    ekConnect     ## Outgoing connection completed
    ekError       ## I/O error occurred

  IoRequest* = object
    ## An I/O operation request.
    ## When registered, the requesting coroutine is suspended
    ## until the operation completes or times out.
    fd*: int           ## File descriptor (socket, pipe, etc.)
    kind*: EventKind   ## What operation we want to monitor
    timeoutMs*: int    ## Timeout in milliseconds (0 = no timeout)

  IoResult* = object
    ## Result of an I/O operation.
    case kind*: EventKind
    of ekRead, ekWrite:
      bytesTransferred*: int  ## How many bytes were read/written
    of ekAccept:
      clientFd*: int          ## Accepted client socket
      clientAddr*: string     ## Client address
    of ekConnect:
      connected*: bool        ## Whether connection succeeded
    of ekError:
      errorCode*: int         ## System error code
      errorMsg*: string       ## Error description

# =============================================================================
# Event Loop Creation
# =============================================================================

proc newEventLoop*(): EventLoop =
  ## Create a new event loop using std/selectors.
  ## This provides cross-platform I/O multiplexing:
  ## - Linux: epoll
  ## - macOS/BSD: kqueue
  ## - Windows: IOCP/select
  result = EventLoop(
    stopped: false,
    selector: newSelector[IoWaiter](),
    waiters: initTable[int, IoWaiter]()
  )

proc destroy*(loop: EventLoop) =
  ## Clean up event loop resources.
  loop.selector.close()
  loop.waiters.clear()

# =============================================================================
# Event Registration
# =============================================================================

proc waitForRead*(loop: EventLoop, fd: int | SocketHandle) =
  ## Register interest in read events and yield current coroutine.
  ## The coroutine will be resumed when the fd is readable.
  let currentCoro = running()
  if currentCoro == nil:
    raise newException(IOError, "waitForRead called outside coroutine")

  # Create waiter
  let waiter = IoWaiter(coro: currentCoro, kind: ekRead)
  let fdInt = fd.int
  loop.waiters[fdInt] = waiter

  # Register with selector (uses epoll/kqueue/IOCP under the hood)
  loop.selector.registerHandle(fdInt, {Event.Read}, waiter)

  # Yield until I/O is ready
  coroYield()

proc waitForWrite*(loop: EventLoop, fd: int | SocketHandle) =
  ## Register interest in write events and yield current coroutine.
  let currentCoro = running()
  if currentCoro == nil:
    raise newException(IOError, "waitForWrite called outside coroutine")

  let waiter = IoWaiter(coro: currentCoro, kind: ekWrite)
  let fdInt = fd.int
  loop.waiters[fdInt] = waiter

  loop.selector.registerHandle(fdInt, {Event.Write}, waiter)

  coroYield()

proc removeWaiter*(loop: EventLoop, fd: int) =
  ## Remove a waiter for this fd.
  if loop.waiters.hasKey(fd):
    try:
      loop.selector.unregister(fd)
    except:
      discard  # Already unregistered
    loop.waiters.del(fd)

# =============================================================================
# Event Loop Execution
# =============================================================================

proc runOnce*(loop: EventLoop, timeoutMs: int = 100): bool =
  ## Process one batch of I/O events. Returns true if any events were processed.
  ## timeoutMs: How long to wait for events (default 100ms)

  # Use std/selectors to wait for I/O events (cross-platform)
  let readyKeys = loop.selector.select(timeoutMs)

  if readyKeys.len == 0:
    return false

  # Resume coroutines that have I/O ready
  for key in readyKeys:
    let waiter = key.data
    let fd = key.fd.int

    # Unregister and remove waiter
    if loop.waiters.hasKey(fd):
      loop.waiters.del(fd)
      try:
        loop.selector.unregister(fd)
      except:
        discard

    # Resume the waiting coroutine
    ready(waiter.coro)

  return readyKeys.len > 0

proc run*(loop: EventLoop) =
  ## Run the event loop. Processes I/O events and resumes coroutines.
  ## This runs until stop() is called or there are no more waiters.

  loop.stopped = false
  while not loop.stopped:
    # Process I/O events
    discard loop.runOnce(timeoutMs = 100)

    # Run ready coroutines
    while hasPending():
      discard runNext()

    # Exit if no more work
    if loop.waiters.len == 0 and not hasPending():
      break

proc stop*(loop: EventLoop) =
  ## Stop the event loop. Causes run() to return.
  loop.stopped = true

# =============================================================================
# Global Event Loop Instance
# =============================================================================

var globalEventLoop* {.threadvar.}: EventLoop
  ## Thread-local global event loop instance.

proc getEventLoop*(): EventLoop =
  ## Get or create the thread-local event loop.
  if globalEventLoop.isNil:
    globalEventLoop = newEventLoop()
  globalEventLoop

# =============================================================================
# Note on Backend Implementation
# =============================================================================

## This event loop uses std/selectors which provides cross-platform I/O
## multiplexing with the best backend for each platform:
##
## - Linux: epoll (O(1) event retrieval)
## - macOS/BSD: kqueue (high-performance kernel event notification)
## - Windows: IOCP or select fallback
##
## The backends in backends/ directory are kept for reference and
## potential future custom implementations, but we leverage Nim's
## stdlib for production use (high quality, well-tested, cross-platform).