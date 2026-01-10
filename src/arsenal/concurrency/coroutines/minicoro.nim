## minicoro Backend - Portable Coroutine Library
## ==============================================
##
## Bindings to minicoro - a minimal, portable coroutine library.
## Works on all platforms including Windows.
##
## Features:
## - Single header library (easy to integrate)
## - Portable across architectures
## - Good performance (~20-50ns switches)
##
## Limitations:
## - Slightly slower than libaco
## - Dedicated stacks (more memory usage)

{.pragma: mcoImport, importc, header: "<minicoro.h>".}

# =============================================================================
# minicoro Types (Direct Bindings)
# =============================================================================

type
  mco_coro* {.mcoImport.} = object
    ## Opaque coroutine handle

  mco_desc* {.mcoImport.} = object
    ## Coroutine creation descriptor
    func*: proc(coro: ptr mco_coro) {.cdecl.}  ## Entry point
    user_data*: pointer                         ## User data
    stack_size*: csize_t                        ## Stack size in bytes

  mco_state* {.mcoImport.} = enum
    ## Coroutine states
    MCO_DEAD
    MCO_NORMAL
    MCO_SUSPENDED

# =============================================================================
# minicoro Functions (Direct Bindings)
# =============================================================================

proc mco_create*(coro: ptr ptr mco_coro, desc: ptr mco_desc): cint {.mcoImport.}
  ## Create a new coroutine.
  ## coro: Output parameter for coroutine handle
  ## desc: Creation parameters
  ## Returns 0 on success

proc mco_resume*(coro: ptr mco_coro): cint {.mcoImport.}
  ## Resume a coroutine.
  ## Returns 0 on success

proc mco_yield*(coro: ptr mco_coro): cint {.mcoImport.}
  ## Yield from current coroutine.

proc mco_status*(coro: ptr mco_coro): mco_state {.mcoImport.}
  ## Get current coroutine status.

proc mco_running*(): ptr mco_coro {.mcoImport.}
  ## Get currently running coroutine, or nil.

proc mco_destroy*(coro: ptr mco_coro) {.mcoImport.}
  ## Destroy a coroutine.

# =============================================================================
# Nim-Friendly Wrappers
# =============================================================================

type
  MiniCoroutine* = object
    ## Nim wrapper for minicoro
    handle: ptr mco_coro
    state: CoroutineState

proc create*(co: var MiniCoroutine, fn: proc() {.nimcall.}, userData: pointer, stackSize: int) =
  ## Create a coroutine.
  ## IMPLEMENTATION:
  ## 1. Create C-compatible wrapper function
  ## 2. Set up mco_desc
  ## 3. Call mco_create()
  ## 4. Set initial state

  proc wrapper(coro: ptr mco_coro) {.cdecl.} =
    # Call user's fn with userData
    # Set state management

  var desc: mco_desc
  desc.func = wrapper
  desc.user_data = userData
  desc.stack_size = stackSize.csize_t

  let res = mco_create(addr co.handle, addr desc)
  if res != 0:
    raise newException(CoroutineError, "Failed to create coroutine")

  co.state = csReady

proc resume*(co: var MiniCoroutine) =
  ## Resume coroutine.
  ## IMPLEMENTATION:
  ## 1. Call mco_resume()
  ## 2. Update state based on mco_status()

  let res = mco_resume(co.handle)
  if res != 0:
    raise newException(CoroutineError, "Failed to resume coroutine")

  let status = mco_status(co.handle)
  co.state = case status
    of MCO_DEAD: csFinished
    of MCO_SUSPENDED: csSuspended
    of MCO_NORMAL: csRunning

proc destroy*(co: var MiniCoroutine) =
  ## Destroy coroutine.
  ## IMPLEMENTATION:
  ## 1. Call mco_destroy()
  ## 2. Set handle = nil

  if co.handle != nil:
    mco_destroy(co.handle)
    co.handle = nil
  co.state = csFinished

proc state*(co: MiniCoroutine): CoroutineState =
  ## Get coroutine state.
  co.state

# Global yield function
proc coroYield*() =
  ## Yield from current coroutine.
  ## IMPLEMENTATION:
  ## 1. Get current coroutine with mco_running()
  ## 2. Call mco_yield()

  let current = mco_running()
  if current != nil:
    discard mco_yield(current)

# Header and library setup
{.passC: "-Ivendor/minicoro".}
{.passL: "-Lvendor/minicoro -lminicoro".}