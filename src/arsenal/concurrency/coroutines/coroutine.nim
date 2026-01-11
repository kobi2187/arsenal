## Coroutine - Lightweight Cooperative Threading
## =============================================
##
## Coroutines are lightweight, cooperatively-scheduled execution contexts.
## Unlike OS threads, coroutines:
## - Have tiny stacks (2-64KB vs 1-8MB for threads)
## - Switch in ~10-50ns (vs ~1-10µs for threads)
## - Don't require kernel involvement
## - Must explicitly yield control
##
## Arsenal provides multiple backends:
## - libaco: Best performance on x86_64/ARM64 (Unix)
## - minicoro: Portable fallback for Windows and others
## - (Future) Pure Nim implementation using inline ASM
##
## Usage:
## ```nim
## # Create a coroutine
## let coro = newCoroutine(proc() =
##   echo "Hello from coroutine!"
##   coroYield()  # Suspend execution
##   echo "Resumed!"
## )
##
## coro.resume()  # Prints "Hello from coroutine!"
## coro.resume()  # Prints "Resumed!"
## # Coroutine is now finished
## ```

import std/options
import ./backend

type
  CoroutineState* = enum
    ## Current state of a coroutine.
    csReady       ## Created but never resumed
    csRunning     ## Currently executing
    csSuspended   ## Yielded, waiting to be resumed
    csFinished    ## Execution completed

  CoroutineError* = object of CatchableError
    ## Error raised when coroutine operations fail.

  CoroutineProc* = proc() {.closure, gcsafe.}
    ## The type of procedure a coroutine executes.
    ## Must be a closure (captures environment) and GC-safe.

  CoroutineObj = object
    ## Internal coroutine object
    state*: CoroutineState
    entryPoint: CoroutineProc
    backend: UnifiedBackend

proc `=destroy`*(c: var CoroutineObj) =
  ## Destructor - clean up backend resources.
  if c.backend.handle != nil:
    backend.destroy(c.backend)

type
  Coroutine* = ref CoroutineObj
    ## High-level coroutine wrapper providing a safe interface.
    ## Automatically manages the underlying backend.
  
# =============================================================================
# Current Coroutine (Thread Local)
# =============================================================================

var currentCoroutine {.threadvar.}: Coroutine
  ## The currently running coroutine in this thread, or nil if in main context.

proc running*(): Coroutine =
  ## Get the currently running coroutine, or nil if not in a coroutine.
  currentCoroutine

proc inCoroutine*(): bool =
  ## Check if currently executing within a coroutine.
  currentCoroutine != nil

# =============================================================================
# Trampoline (C -> Nim bridge)
# =============================================================================

when backend.SelectedBackend == backend.cbLibaco:
  proc trampoline() {.cdecl.} =
    ## Trampoline for libaco (no args, get arg from context)
    let co = backend.aco_get_co()
    let arg = backend.getArg(co)
    let coro = cast[Coroutine](arg)
    
    try:
      coro.entryPoint()
    except CatchableError as e:
      stderr.writeLine("Error in coroutine: " & e.msg)
    finally:
      coro.state = csFinished
      backend.exitBackend()

else:
  proc trampoline(co: ptr backend.McoCoro) {.cdecl.} =
    ## Trampoline for minicoro (takes coroutine pointer)
    let arg = backend.mco_get_user_data(co)
    let coro = cast[Coroutine](arg)
    
    try:
      coro.entryPoint()
    except CatchableError as e:
      stderr.writeLine("Error in coroutine: " & e.msg)
    finally:
      coro.state = csFinished
      # minicoro just returns

# =============================================================================
# Coroutine Creation
# =============================================================================

proc newCoroutine*(fn: CoroutineProc, stackSize: int = backend.DefaultStackSize): Coroutine =
  ## Create a new coroutine with the given entry point.
  
  new(result)
  result.state = csReady
  result.entryPoint = fn
  
  # Create backend with trampoline
  # We pass `result` (the Coroutine object) as user data
  result.backend = backend.createBackend(
    cast[pointer](trampoline), 
    stackSize, 
    cast[pointer](result)
  )

proc newCoroutine*(fn: proc() {.nimcall, gcsafe.}, stackSize: int = backend.DefaultStackSize): Coroutine =
  ## Overload for non-closure procedures.
  let closureFn: CoroutineProc = proc() = fn()
  newCoroutine(closureFn, stackSize)

# =============================================================================
# Coroutine Operations
# =============================================================================

proc resume*(c: Coroutine) =
  ## Resume execution of a suspended coroutine.
  
  if c.state == csFinished:
    raise newException(CoroutineError, "Cannot resume finished coroutine")
  if c.state == csRunning:
    raise newException(CoroutineError, "Coroutine is already running")

  # Update state
  c.state = csRunning
  
  # Set current coroutine threadvar
  let prevCoro = currentCoroutine
  currentCoroutine = c
  
  try:
    # Resume backend
    backend.resume(c.backend)
  finally:
    # Restore previous coroutine
    currentCoroutine = prevCoro
    
    # Update state after return
    if backend.isFinished(c.backend):
      c.state = csFinished
    else:
      c.state = csSuspended

proc isFinished*(c: Coroutine): bool {.inline.} = c.state == csFinished
proc isRunning*(c: Coroutine): bool {.inline.} = c.state == csRunning
proc isSuspended*(c: Coroutine): bool {.inline.} = c.state == csSuspended

# =============================================================================
# Yield
# =============================================================================

proc coroYield*() =
  ## Yield execution back to the caller of `resume()`.
  
  let c = currentCoroutine
  if c == nil:
    raise newException(CoroutineError, "Cannot yield outside a coroutine")
  
  c.state = csSuspended
  backend.yieldBackend()
  c.state = csRunning

# =============================================================================
# Current Coroutine
# =============================================================================

# Moved to top of file


# =============================================================================
# Cleanup
# =============================================================================

proc destroy*(c: Coroutine) =
  ## Explicitly destroy a coroutine.
  if c.backend.handle != nil:
    backend.destroy(c.backend)
  c.state = csFinished



