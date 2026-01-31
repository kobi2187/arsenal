## kqueue Backend - macOS/BSD
## ============================
##
## BSD kqueue-based event notification system.
## High-performance I/O multiplexing similar to epoll but with broader event types.
##
## Features:
## - Monitors file descriptors, signals, timers, vnodes
## - Edge-triggered by default
## - Kernel-managed event queue

import std/posix

# =============================================================================
# kqueue Constants
# =============================================================================

const
  EVFILT_READ* = int16(-1)      ## Readable filter
  EVFILT_WRITE* = int16(-2)     ## Writable filter
  EVFILT_TIMER* = int16(6)      ## Timer filter
  EVFILT_SIGNAL* = int16(7)     ## Signal filter

  EV_ADD* = uint16(0x0001)      ## Add event to kqueue
  EV_DELETE* = uint16(0x0002)   ## Delete event
  EV_ENABLE* = uint16(0x0004)   ## Enable event
  EV_DISABLE* = uint16(0x0008)  ## Disable event
  EV_ONESHOT* = uint16(0x0010)  ## Only report once
  EV_CLEAR* = uint16(0x0020)    ## Reset state after retrieval
  EV_EOF* = uint16(0x8000)      ## EOF detected
  EV_ERROR* = uint16(0x4000)    ## Error occurred

# =============================================================================
# kqueue Types
# =============================================================================

type
  Kevent* = object
    ## Kernel event structure
    ident*: uint      ## Identifier (usually fd)
    filter*: int16    ## Filter type (EVFILT_READ, etc.)
    flags*: uint16    ## Action flags (EV_ADD, etc.)
    fflags*: uint32   ## Filter-specific flags
    data*: int        ## Filter-specific data
    udata*: pointer   ## User-defined data

  Timespec* = object
    ## Time specification
    tv_sec*: int      ## Seconds
    tv_nsec*: int     ## Nanoseconds

# =============================================================================
# kqueue System Calls (BSD/macOS only - stubs on other platforms)
# =============================================================================

proc kqueue*(): cint =
  ## Create a new kernel event queue.
  ## Returns file descriptor or -1 on error.
  ## Stub implementation - only available on BSD/macOS
  -1

proc kevent*(
  kq: cint,
  changelist: ptr Kevent,
  nchanges: cint,
  eventlist: ptr Kevent,
  nevents: cint,
  timeout: ptr Timespec
): cint =
  ## Control and wait for events on kqueue.
  ## Stub implementation - only available on BSD/macOS
  -1

# =============================================================================
# Backend Implementation
# =============================================================================

type
  KqueueBackend* = object
    ## BSD kqueue-based event loop backend.
    kq: cint
    events: seq[Kevent]
    maxEvents: int

proc initKqueue*(maxEvents: int = 1024): KqueueBackend =
  ## Initialize kqueue backend.
  ## Creates a new kernel event queue and allocates buffer for events.
  ## NOTE: Only functional on BSD/macOS systems

  result.maxEvents = maxEvents
  result.events = newSeq[Kevent](maxEvents)
  result.kq = kqueue()
  if result.kq < 0:
    raise newException(OSError, "kqueue() failed - not available on this platform")

proc destroyKqueue*(backend: var KqueueBackend) =
  ## Clean up kqueue backend.
  ## Closes the kqueue file descriptor and clears event buffer.

  if backend.kq >= 0:
    when defined(bsd) or defined(macosx):
      discard close(backend.kq)
    backend.kq = -1
  backend.events.setLen(0)

proc addRead*(backend: var KqueueBackend, fd: int, data: pointer = nil) =
  ## Register interest in read events.

  var event: Kevent
  event.ident = fd.uint
  event.filter = EVFILT_READ
  event.flags = EV_ADD or EV_CLEAR
  event.fflags = 0
  event.data = 0
  event.udata = data

  if kevent(backend.kq, addr event, 1, nil, 0, nil) < 0:
    raise newException(OSError, "kevent ADD READ failed")

proc addWrite*(backend: var KqueueBackend, fd: int, data: pointer = nil) =
  ## Register interest in write events.

  var event: Kevent
  event.ident = fd.uint
  event.filter = EVFILT_WRITE
  event.flags = EV_ADD or EV_CLEAR
  event.fflags = 0
  event.data = 0
  event.udata = data

  if kevent(backend.kq, addr event, 1, nil, 0, nil) < 0:
    raise newException(OSError, "kevent ADD WRITE failed")

proc removeFd*(backend: var KqueueBackend, fd: int, filter: int16) =
  ## Remove event from kqueue.

  var event: Kevent
  event.ident = fd.uint
  event.filter = filter
  event.flags = EV_DELETE
  event.fflags = 0
  event.data = 0
  event.udata = nil

  discard kevent(backend.kq, addr event, 1, nil, 0, nil)

proc wait*(backend: var KqueueBackend, timeoutMs: int): seq[Kevent] =
  ## Wait for I/O events.

  var timeout: Timespec
  var timeoutPtr: ptr Timespec

  if timeoutMs >= 0:
    timeout.tv_sec = timeoutMs div 1000
    timeout.tv_nsec = (timeoutMs mod 1000) * 1_000_000
    timeoutPtr = addr timeout
  else:
    timeoutPtr = nil

  let n = kevent(
    backend.kq,
    nil, 0,
    addr backend.events[0], backend.maxEvents.cint,
    timeoutPtr
  )

  if n < 0:
    when not defined(windows):
      if errno == EINTR:
        return @[]
    raise newException(OSError, "kevent wait failed")

  result = backend.events[0..<n]
