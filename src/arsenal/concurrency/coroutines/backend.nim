## Coroutine Backend Dispatcher
## ============================
##
## Automatically selects the best available coroutine backend
## based on platform and CPU features.
##
## Selection Logic:
## 1. Linux/macOS x86_64/ARM64: libaco (fastest)
## 2. Windows or other platforms: minicoro (portable)
## 3. Future: Pure Nim ASM implementation

import std/os
import ../../platform/config
import ./libaco
import ./minicoro
import ./coroutine

# =============================================================================
# Backend Selection
# =============================================================================

type
  CoroutineBackendKind* = enum
    cbLibaco
    cbMinicoro
    cbPureNim  # Future

proc selectBackend*(): CoroutineBackendKind =
  ## Select the best backend for current platform.
  ## IMPLEMENTATION:
  ## Check platform and available libraries

  when defined(windows):
    cbMinicoro
  elif defined(linux) or defined(macosx):
    # Check if libaco is available
    # For now, assume available
    cbLibaco
  else:
    cbMinicoro

# =============================================================================
# Unified Backend Interface
# =============================================================================

type
  CoroutineBackend* = object
    ## Unified backend interface
    case kind: CoroutineBackendKind
    of cbLibaco:
      libacoCo: libaco.AcoCoroutine
      libacoStack: libaco.AcoSharedStack
    of cbMinicoro:
      minicoroCo: minicoro.MiniCoroutine
    of cbPureNim:
      discard  # Future

proc createBackend*(fn: CoroutineProc, stackSize: int): CoroutineBackend =
  ## Create backend-specific coroutine.
  ## IMPLEMENTATION:
  ## 1. Select backend
  ## 2. Initialize appropriate backend

  let backend = selectBackend()
  result.kind = backend

  case backend
  of cbLibaco:
    # Initialize libaco backend
    # Create shared stack
    # Create coroutine
    discard
  of cbMinicoro:
    # Initialize minicoro backend
    result.minicoroCo.create(fn, nil, stackSize)
  of cbPureNim:
    # Future pure Nim implementation
    discard

proc resume*(backend: var CoroutineBackend) =
  ## Resume backend coroutine.
  case backend.kind
  of cbLibaco:
    backend.libacoCo.resume()
  of cbMinicoro:
    backend.minicoroCo.resume()
  of cbPureNim:
    discard

proc destroy*(backend: var CoroutineBackend) =
  ## Destroy backend coroutine.
  case backend.kind
  of cbLibaco:
    backend.libacoCo.destroy()
  of cbMinicoro:
    backend.minicoroCo.destroy()
  of cbPureNim:
    discard

proc state*(backend: CoroutineBackend): CoroutineState =
  ## Get backend coroutine state.
  case backend.kind
  of cbLibaco:
    backend.libacoCo.state()
  of cbMinicoro:
    backend.minicoroCo.state()
  of cbPureNim:
    csFinished

# =============================================================================
# Global Backend State
# =============================================================================

var
  mainCoroutine {.threadvar.}: CoroutineBackend
    ## Main coroutine for each thread

  backendInitialized {.threadvar.}: bool
    ## Whether backend is initialized for this thread

proc initBackend*() =
  ## Initialize coroutine backend for current thread.
  ## IMPLEMENTATION:
  ## For libaco: Call aco_thread_init()
  ## For minicoro: No initialization needed

  if backendInitialized:
    return

  let backend = selectBackend()
  case backend
  of cbLibaco:
    # Initialize libaco thread
    discard
  of cbMinicoro:
    # No initialization needed
    discard
  of cbPureNim:
    discard

  backendInitialized = true

proc getMainCoroutine*(): CoroutineBackend =
  ## Get main coroutine for current thread.
  mainCoroutine