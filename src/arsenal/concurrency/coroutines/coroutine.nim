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

  CoroutineBackend* = concept c
    ## Concept for coroutine backend implementations.
    ## Different backends (libaco, minicoro, etc.) must satisfy this interface.

    c.create(fn: CoroutineProc, stackSize: int): c
    c.resume()
    c.destroy()
    c.state(): CoroutineState

  Coroutine* = ref object
    ## High-level coroutine wrapper providing a safe interface.
    ## Automatically manages the underlying backend.
    state*: CoroutineState
    entryPoint: CoroutineProc
    # Backend-specific handle stored here
    # When implementing:
    # - For libaco: aco_t pointer
    # - For minicoro: mco_coro pointer

const
  DefaultStackSize* = 64 * 1024  ## 64KB default stack
  MinStackSize* = 2 * 1024       ## 2KB minimum
  MaxStackSize* = 8 * 1024 * 1024  ## 8MB maximum

# =============================================================================
# Coroutine Creation
# =============================================================================

proc newCoroutine*(fn: CoroutineProc, stackSize: int = DefaultStackSize): Coroutine =
  ## Create a new coroutine with the given entry point.
  ##
  ## IMPLEMENTATION:
  ## 1. Allocate Coroutine object
  ## 2. Call backend-specific creation:
  ##
  ## For libaco:
  ## ```nim
  ## # First, ensure thread is initialized (once per thread)
  ## if not acoThreadInitialized:
  ##   aco_thread_init(nil)
  ##   mainCo = aco_create(nil, nil, 0, nil, nil)  # main context
  ##   acoThreadInitialized = true
  ##
  ## # Create shared stack (can be reused across coroutines)
  ## let stack = aco_share_stack_new(stackSize)
  ##
  ## # Create coroutine
  ## # The wrapper function captures `fn` and calls it
  ## result.handle = aco_create(mainCo, stack, 0, wrapperFn, result)
  ## ```
  ##
  ## For minicoro:
  ## ```nim
  ## var desc: mco_desc
  ## desc.func = wrapperFn
  ## desc.user_data = cast[pointer](result)
  ## desc.stack_size = stackSize
  ## mco_create(addr result.handle, addr desc)
  ## ```
  ##
  ## The wrapper function should:
  ## 1. Set state to csRunning
  ## 2. Call the user's `fn`
  ## 3. Set state to csFinished when done

  result = Coroutine(
    state: csReady,
    entryPoint: fn
  )
  # TODO: Initialize backend

proc newCoroutine*(fn: proc() {.nimcall.}, stackSize: int = DefaultStackSize): Coroutine =
  ## Overload for non-closure procedures.
  ## Wraps in a closure for compatibility.
  let closureFn: CoroutineProc = proc() = fn()
  newCoroutine(closureFn, stackSize)

# =============================================================================
# Coroutine Operations
# =============================================================================

proc resume*(c: Coroutine) =
  ## Resume execution of a suspended coroutine.
  ## Returns when the coroutine yields or finishes.
  ##
  ## IMPLEMENTATION:
  ## For libaco:
  ## ```nim
  ## assert c.state in {csReady, csSuspended}
  ## c.state = csRunning
  ## aco_resume(c.handle)
  ## # When we return here, coroutine yielded or finished
  ## ```
  ##
  ## For minicoro:
  ## ```nim
  ## mco_resume(c.handle)
  ## c.state = if mco_status(c.handle) == MCO_DEAD:
  ##   csFinished
  ## else:
  ##   csSuspended
  ## ```

  if c.state == csFinished:
    raise newException(CoroutineError, "Cannot resume finished coroutine")
  if c.state == csRunning:
    raise newException(CoroutineError, "Coroutine is already running")

  c.state = csRunning
  # TODO: Backend-specific resume
  c.state = csSuspended  # or csFinished

proc isFinished*(c: Coroutine): bool {.inline.} =
  ## Check if coroutine has completed execution.
  c.state == csFinished

proc isRunning*(c: Coroutine): bool {.inline.} =
  ## Check if coroutine is currently executing.
  c.state == csRunning

proc isSuspended*(c: Coroutine): bool {.inline.} =
  ## Check if coroutine is suspended and can be resumed.
  c.state == csSuspended

# =============================================================================
# Yield (Called from within a coroutine)
# =============================================================================

proc coroYield*() =
  ## Yield execution back to the caller of `resume()`.
  ## Can only be called from within a running coroutine.
  ##
  ## IMPLEMENTATION:
  ## For libaco:
  ## ```nim
  ## aco_yield()
  ## ```
  ##
  ## For minicoro:
  ## ```nim
  ## mco_yield(mco_running())
  ## ```
  ##
  ## This switches context back to whoever called resume().
  ## When resume() is called again, execution continues after this yield.

  # TODO: Backend-specific yield
  discard

# =============================================================================
# Current Coroutine
# =============================================================================

var currentCoroutine {.threadvar.}: Coroutine
  ## The currently running coroutine in this thread, or nil if in main context.

proc running*(): Coroutine =
  ## Get the currently running coroutine, or nil if not in a coroutine.
  ##
  ## IMPLEMENTATION:
  ## For libaco: `aco_get_co()` returns current, compare to mainCo
  ## For minicoro: `mco_running()` returns current or nil
  currentCoroutine

proc inCoroutine*(): bool {.inline.} =
  ## Check if currently executing within a coroutine.
  running() != nil

# =============================================================================
# Cleanup
# =============================================================================

proc destroy*(c: Coroutine) =
  ## Explicitly destroy a coroutine and free its resources.
  ## Usually not needed - GC finalizer handles this.
  ##
  ## IMPLEMENTATION:
  ## For libaco:
  ## ```nim
  ## if c.handle != nil:
  ##   aco_destroy(c.handle)
  ##   c.handle = nil
  ## ```
  ##
  ## For minicoro:
  ## ```nim
  ## mco_destroy(c.handle)
  ## ```

  c.state = csFinished
  # TODO: Backend-specific cleanup

# =============================================================================
# Finalizer
# =============================================================================

proc `=destroy`*(c: Coroutine) =
  ## Destructor - clean up backend resources.
  if c != nil and c.state != csFinished:
    # TODO: Backend cleanup
    discard
