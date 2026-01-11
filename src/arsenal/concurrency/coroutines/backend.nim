## Coroutine Backend Dispatcher
## ============================

import std/os
import ../../platform/config
import ./libaco
import ./minicoro

export libaco
export minicoro

# =============================================================================
# Backend Selection
# =============================================================================

type
  CoroutineBackendKind* = enum
    cbLibaco
    cbMinicoro

const SelectedBackend* = when defined(windows):
  cbMinicoro
elif defined(linux) or defined(macosx):
  # Use libaco on supported Unix platforms
  cbLibaco
else:
  cbMinicoro

const
  # Stack sizes
  DefaultStackSize* = 64 * 1024  ## 64KB default stack
  MinStackSize* = 2 * 1024       ## 2KB minimum
  MaxStackSize* = 8 * 1024 * 1024  ## 8MB maximum

# =============================================================================
# Unified Backend Type
# =============================================================================

type
  UnifiedBackend* = object
    ## Wraps the selected backend implementation
    when SelectedBackend == cbLibaco:
      handle*: ptr libaco.AcoHandle
      stack*: ptr libaco.AcoShareStack
    else:
      handle*: ptr minicoro.McoCoro
      desc*: minicoro.McoDesc

# =============================================================================
# Global State
# =============================================================================

var
  mainCo {.threadvar.}: UnifiedBackend
  backendInitialized {.threadvar.}: bool
  libacoSharedStack {.threadvar.}: ptr libaco.AcoShareStack

# =============================================================================
# Backend Operations
# =============================================================================

proc initBackend*() =
  ## Initialize coroutine backend for current thread.
  if backendInitialized: return
  
  when SelectedBackend == cbLibaco:
    libaco.aco_thread_init(nil)
    mainCo.handle = libaco.aco_create(nil, nil, 0, nil, nil)
    # mainCo.stack is nil for main coroutine
    # Create the shared stack once per thread
    libacoSharedStack = libaco.aco_share_stack_new(DefaultStackSize.csize_t)
    
  else:
    # minicoro doesn't need explicit thread init, but we can set up main context if needed
    discard
  
  backendInitialized = true

proc createBackend*(fn: pointer, stackSize: int, userData: pointer): UnifiedBackend =
  ## Create a new coroutine backend
  if not backendInitialized:
    initBackend()

  when SelectedBackend == cbLibaco:
    if mainCo.handle == nil:
      stderr.writeLine("FATAL: mainCo.handle is nil in createBackend")
      quit(1)
      
    # Use the thread-local shared stack
    # Note: We ignore stackSize argument for now and use default shared stack size
    # If custom stack size is needed, we'd need multiple shared stacks or a pool
    result.stack = libacoSharedStack
    
    # Create coroutine
    # Note: fn must be AcoFuncPtr compatible
    result.handle = libaco.aco_create(
      mainCo.handle,
      result.stack,
      0,
      cast[libaco.AcoFuncPtr](fn),
      userData
    )
  else:
    var desc: minicoro.McoDesc
    desc.func = cast[minicoro.McoFunc](fn)
    desc.user_data = userData
    desc.stack_size = stackSize.csize_t
    
    let res = minicoro.mco_create(addr result.handle, addr desc)
    if res != minicoro.MCO_SUCCESS:
      raise newException(ValueError, "Failed to create minicoro coroutine: " & $res)

proc resume*(backend: UnifiedBackend) =
  when SelectedBackend == cbLibaco:
    libaco.aco_resume(backend.handle)
  else:
    let res = minicoro.mco_resume(backend.handle)
    if res != minicoro.MCO_SUCCESS:
      raise newException(ValueError, "Failed to resume minicoro coroutine: " & $res)

proc yieldBackend*() =
  when SelectedBackend == cbLibaco:
    libaco.aco_yield()
  else:
    minicoro.mcoYield()

proc exitBackend*() =
  ## Exit the current coroutine (called when function finishes)
  when SelectedBackend == cbLibaco:
    libaco.aco_exit()
  else:
    # minicoro doesn't need explicit exit, just return
    discard

proc destroy*(backend: var UnifiedBackend) =
  when SelectedBackend == cbLibaco:
    if backend.handle != nil:
      libaco.aco_destroy(backend.handle)
      backend.handle = nil
    # Do NOT destroy shared stack here, it is reused
    backend.stack = nil
  else:
    if backend.handle != nil:
      minicoro.mco_destroy(backend.handle)
      backend.handle = nil

proc isFinished*(backend: UnifiedBackend): bool {.inline.} =
  when SelectedBackend == cbLibaco:
    libaco.isEnded(backend.handle)
  else:
    minicoro.isDead(backend.handle)

proc getUserData*(backend: UnifiedBackend): pointer {.inline.} =
  when SelectedBackend == cbLibaco:
    libaco.getArg(backend.handle)
  else:
    minicoro.mco_get_user_data(backend.handle)