## epoll Backend - Linux
## =====================
##
## Linux epoll-based event notification system.
## High-performance I/O multiplexing for thousands of file descriptors.
##
## Features:
## - O(1) event retrieval (vs O(n) for select/poll)
## - Edge-triggered and level-triggered modes
## - Kernel-managed interest lists

{.pragma: epollImport, importc, header: "<sys/epoll.h>".}

# =============================================================================
# epoll Constants
# =============================================================================

const
  EPOLL_CTL_ADD* {.epollImport.}: cint  ## Add fd to epoll
  EPOLL_CTL_MOD* {.epollImport.}: cint  ## Modify fd's events
  EPOLL_CTL_DEL* {.epollImport.}: cint  ## Remove fd from epoll

  EPOLLIN* {.epollImport.}: uint32      ## Readable
  EPOLLOUT* {.epollImport.}: uint32     ## Writable
  EPOLLERR* {.epollImport.}: uint32     ## Error condition
  EPOLLHUP* {.epollImport.}: uint32     ## Hangup
  EPOLLET* {.epollImport.}: uint32      ## Edge-triggered mode
  EPOLLONESHOT* {.epollImport.}: uint32 ## One-shot mode

# =============================================================================
# epoll Types
# =============================================================================

type
  EpollEvent* {.epollImport, importc: "struct epoll_event".} = object
    events*: uint32     ## Event mask
    data*: EpollData    ## User data

  EpollData* {.epollImport, importc: "epoll_data_t", union.} = object
    ## User data associated with fd
    fd*: cint
    u32*: uint32
    u64*: uint64
    `ptr`*: pointer

# =============================================================================
# epoll System Calls
# =============================================================================

proc epoll_create1*(flags: cint): cint {.epollImport.}
  ## Create an epoll instance.
  ## flags: EPOLL_CLOEXEC or 0

proc epoll_ctl*(epfd: cint, op: cint, fd: cint, event: ptr EpollEvent): cint {.epollImport.}
  ## Control interface for epoll.
  ## epfd: epoll file descriptor
  ## op: EPOLL_CTL_ADD/MOD/DEL
  ## fd: file descriptor to modify
  ## event: event configuration

proc epoll_wait*(epfd: cint, events: ptr EpollEvent, maxevents: cint, timeout: cint): cint {.epollImport.}
  ## Wait for events on epoll instance.
  ## Returns number of ready file descriptors, or -1 on error.
  ## timeout: milliseconds to wait (-1 = infinite)

# =============================================================================
# Backend Implementation
# =============================================================================

type
  EpollBackend* = object
    ## Linux epoll-based event loop backend.
    epfd: cint
    events: seq[EpollEvent]
    maxEvents: int

proc initEpoll*(maxEvents: int = 1024): EpollBackend =
  ## Initialize epoll backend.
  result.maxEvents = maxEvents
  result.events = newSeq[EpollEvent](maxEvents)
  result.epfd = epoll_create1(0)
  if result.epfd < 0:
    raise newException(OSError, "epoll_create1 failed")

proc destroyEpoll*(backend: var EpollBackend) =
  ## Clean up epoll backend.
  when defined(linux):
    if backend.epfd >= 0:
      {.emit: """
      #include <unistd.h>
      close(`backend`.epfd);
      """.}
      backend.epfd = -1

proc addFd*(backend: var EpollBackend, fd: int, events: uint32, data: pointer = nil) =
  ## Add file descriptor to epoll interest list.
  var event: EpollEvent
  event.events = events
  if data != nil:
    event.data.`ptr` = data
  else:
    event.data.fd = fd.cint

  if epoll_ctl(backend.epfd, EPOLL_CTL_ADD, fd.cint, addr event) < 0:
    raise newException(OSError, "epoll_ctl ADD failed")

proc modifyFd*(backend: var EpollBackend, fd: int, events: uint32, data: pointer = nil) =
  ## Modify events for file descriptor.
  var event: EpollEvent
  event.events = events
  if data != nil:
    event.data.`ptr` = data
  else:
    event.data.fd = fd.cint

  if epoll_ctl(backend.epfd, EPOLL_CTL_MOD, fd.cint, addr event) < 0:
    raise newException(OSError, "epoll_ctl MOD failed")

proc removeFd*(backend: var EpollBackend, fd: int) =
  ## Remove file descriptor from epoll.
  if epoll_ctl(backend.epfd, EPOLL_CTL_DEL, fd.cint, nil) < 0:
    # Ignore errors - fd might already be closed
    discard

proc wait*(backend: var EpollBackend, timeoutMs: int): seq[EpollEvent] =
  ## Wait for I/O events.
  ## Returns array of ready events.
  let n = epoll_wait(
    backend.epfd,
    addr backend.events[0],
    backend.maxEvents.cint,
    timeoutMs.cint
  )

  if n < 0:
    # Check for EINTR (interrupted by signal)
    when defined(linux):
      var errno: cint
      {.emit: """
      #include <errno.h>
      `errno` = errno;
      """.}
      const EINTR = 4  # Standard EINTR value on Linux
      if errno == EINTR:
        return @[]  # Interrupted by signal, return empty
    raise newException(OSError, "epoll_wait failed")

  if n == 0:
    return @[]  # Timeout

  result = newSeq[EpollEvent](n)
  for i in 0..<n:
    result[i] = backend.events[i]
