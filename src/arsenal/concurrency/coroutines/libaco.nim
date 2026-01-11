## libaco Backend - Asymmetric Coroutine Library
## ============================================
##
## Bindings to libaco - a fast, hand-coded context-switching library.
## Supports x86_64, ARM64 on Linux/macOS.
##
## Features:
## - Extremely fast context switches (~10-20ns)
## - Shared stacks (memory efficient)
## - No dynamic memory allocation after setup
##
## Limitations:
## - Not available on Windows (use minicoro instead)
## - Requires assembly code (different per architecture)

{.pragma: acoImport, importc, header: "<aco.h>".}

# =============================================================================
# libaco Types (Direct Bindings)
# =============================================================================

type
  aco_t* {.acoImport.} = object
    ## Opaque coroutine handle

  aco_share_stack_t* {.acoImport.} = object
    ## Shared stack for multiple coroutines

  aco_attr_t* {.acoImport.} = object
    ## Coroutine creation attributes

# =============================================================================
# libaco Functions (Direct Bindings)
# =============================================================================

proc aco_thread_init*(thread_main_co: ptr aco_t): cint {.acoImport.}
  ## Initialize libaco for the current thread.
  ## Must be called once per thread before creating coroutines.
  ## thread_main_co: Optional main coroutine handle (can be nil)

proc aco_create*(
  main_co: ptr aco_t,
  share_stack: ptr aco_share_stack_t,
  save_stack_size: csize_t,
  pfn: proc() {.cdecl.},
  arg: pointer
): ptr aco_t {.acoImport.}
  ## Create a new coroutine.
  ## main_co: Main coroutine for this thread
  ## share_stack: Shared stack (can be nil for dedicated stack)
  ## save_stack_size: Size for dedicated stack (0 for shared)
  ## pfn: Entry point function
  ## arg: Argument passed to pfn

proc aco_resume*(co: ptr aco_t) {.acoImport.}
  ## Resume a coroutine. Returns when coroutine yields or exits.

proc aco_yield*() {.acoImport.}
  ## Yield from current coroutine back to resumer.

proc aco_destroy*(co: ptr aco_t) {.acoImport.}
  ## Destroy a coroutine and free its resources.

proc aco_get_co*(): ptr aco_t {.acoImport.}
  ## Get the currently running coroutine.

# =============================================================================
# Shared Stack Management
# =============================================================================

proc aco_share_stack_new*(stack_size: csize_t): ptr aco_share_stack_t {.acoImport.}
  ## Create a new shared stack.
  ## stack_size: Size in bytes (must be multiple of page size)

proc aco_share_stack_destroy*(share_stack: ptr aco_share_stack_t) {.acoImport.}
  ## Destroy a shared stack.

# =============================================================================
# Nim-Friendly Wrappers
# =============================================================================

import ./coroutine

type
  AcoCoroutine* = object
    ## Nim wrapper for libaco coroutine
    handle: ptr aco_t
    state: CoroutineState

  AcoSharedStack* = object
    ## Nim wrapper for shared stack
    handle: ptr aco_share_stack_t

proc create*(stack: var AcoSharedStack, size: int) =
  ## Create a shared stack.
  ## IMPLEMENTATION:
  ## 1. Round size up to page boundary
  ## 2. Call aco_share_stack_new()
  ## 3. Store handle

  stack.handle = aco_share_stack_new(size.csize_t)

proc destroy*(stack: var AcoSharedStack) =
  ## Destroy a shared stack.
  ## IMPLEMENTATION:
  ## 1. Check handle != nil
  ## 2. Call aco_share_stack_destroy()
  ## 3. Set handle = nil

  if stack.handle != nil:
    aco_share_stack_destroy(stack.handle)
    stack.handle = nil

proc create*(co: var AcoCoroutine, mainCo: ptr aco_t, stack: ptr AcoSharedStack, fn: proc() {.nimcall.}, arg: pointer) =
  ## Create a coroutine.
  ## IMPLEMENTATION:
  ## 1. Create C-compatible wrapper function
  ## 2. Call aco_create()
  ## 3. Set initial state

  # Wrapper needed because libaco expects C calling convention
  proc wrapper() {.cdecl.} =
    # Set current coroutine
    # Call user's fn
    # Set state to finished

  co.handle = aco_create(mainCo, stack.handle, 0, wrapper, arg)
  co.state = csReady

proc resume*(co: var AcoCoroutine) =
  ## Resume coroutine.
  ## IMPLEMENTATION:
  ## 1. Assert state is ready/suspended
  ## 2. Set state = running
  ## 3. Call aco_resume()
  ## 4. Update state based on result

  co.state = csRunning
  aco_resume(co.handle)
  # After resume returns, check if coroutine finished

proc destroy*(co: var AcoCoroutine) =
  ## Destroy coroutine.
  ## IMPLEMENTATION:
  ## 1. Call aco_destroy()
  ## 2. Set handle = nil
  ## 3. Set state = finished

  if co.handle != nil:
    aco_destroy(co.handle)
    co.handle = nil
  co.state = csFinished

proc state*(co: AcoCoroutine): CoroutineState =
  ## Get coroutine state.
  co.state

# Compile-time checks
when defined(windows):
  {.error: "libaco backend not supported on Windows - use minicoro instead".}

# Header and library setup
when defined(macosx):
  {.passL: "-L/opt/homebrew/lib -laco".}
  {.passC: "-I/opt/homebrew/include".}
elif defined(linux):
  {.passL: "-laco".}
else:
  {.error: "Unsupported platform for libaco".}