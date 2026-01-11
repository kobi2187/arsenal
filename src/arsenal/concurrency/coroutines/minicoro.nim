## minicoro Backend - Portable Coroutine Library
## ==============================================
##
## Bindings to minicoro - a single-header, portable coroutine library.
## Works on all platforms including Windows.
##
## Features:
## - Single header library (easy to integrate)
## - Cross-platform (Windows, Linux, macOS, ARM, RISC-V, WebAssembly)
## - Good performance (~20-50ns context switches)
## - Supports custom allocators
## - Storage system for passing values
##
## Usage:
## - On Unix: uses assembly (x86_64, ARM64, RISC-V) or ucontext fallback
## - On Windows: uses assembly (x86_64) or Windows fibers

import std/os

# =============================================================================
# Compile minicoro (header-only, needs MINICORO_IMPL defined once)
# =============================================================================

const minicoroPath = currentSourcePath().parentDir() / ".." / ".." / ".." / ".." / "vendor" / "minicoro"

# Create a C file that includes minicoro.h with MINICORO_IMPL
# This is the standard way to use header-only libraries
{.emit: """
#define MINICORO_IMPL
#include "minicoro.h"
""".}

{.passC: "-I" & minicoroPath.}

# =============================================================================
# minicoro Types
# =============================================================================

type
  McoState* {.importc: "mco_state", header: "minicoro.h".} = enum
    ## Coroutine states
    MCO_DEAD = 0      ## Finished or uninitialized
    MCO_NORMAL = 1    ## Active but not running (resumed another)
    MCO_RUNNING = 2   ## Currently executing
    MCO_SUSPENDED = 3 ## Suspended (yielded or not started)

  McoResult* {.importc: "mco_result", header: "minicoro.h".} = enum
    ## Result codes from minicoro operations
    MCO_SUCCESS = 0
    MCO_GENERIC_ERROR
    MCO_INVALID_POINTER
    MCO_INVALID_COROUTINE
    MCO_NOT_SUSPENDED
    MCO_NOT_RUNNING
    MCO_MAKE_CONTEXT_ERROR
    MCO_SWITCH_CONTEXT_ERROR
    MCO_NOT_ENOUGH_SPACE
    MCO_OUT_OF_MEMORY
    MCO_INVALID_ARGUMENTS
    MCO_INVALID_OPERATION
    MCO_STACK_OVERFLOW

  McoFunc* = proc(co: ptr McoCoro) {.cdecl.}
    ## Coroutine entry function type

  McoCoro* {.importc: "mco_coro", header: "minicoro.h", incompleteStruct.} = object
    ## Opaque coroutine handle

  McoDesc* {.importc: "mco_desc", header: "minicoro.h".} = object
    ## Coroutine creation descriptor
    `func`*: McoFunc       ## Entry point function
    user_data*: pointer    ## User data pointer
    alloc_cb*: pointer     ## Custom allocator (optional)
    dealloc_cb*: pointer   ## Custom deallocator (optional)
    allocator_data*: pointer
    storage_size*: csize_t ## Storage buffer size
    coro_size*: csize_t    ## Internal
    stack_size*: csize_t   ## Stack size in bytes

# =============================================================================
# minicoro Functions
# =============================================================================

proc mco_desc_init*(fn: McoFunc, stack_size: csize_t): McoDesc {.cdecl, importc, header: "minicoro.h".}
  ## Initialize a coroutine descriptor.
  ## stack_size: 0 for default (56KB), or custom size

proc mco_create*(out_co: ptr ptr McoCoro, desc: ptr McoDesc): McoResult {.cdecl, importc, header: "minicoro.h".}
  ## Create a new coroutine.
  ## out_co: Output pointer for coroutine handle
  ## desc: Creation parameters
  ## Returns MCO_SUCCESS on success

proc mco_destroy*(co: ptr McoCoro): McoResult {.cdecl, importc, header: "minicoro.h".}
  ## Destroy a coroutine. Must be DEAD or SUSPENDED.

proc mco_resume*(co: ptr McoCoro): McoResult {.cdecl, importc, header: "minicoro.h".}
  ## Resume a suspended coroutine.

proc mco_yield*(co: ptr McoCoro): McoResult {.cdecl, importc, header: "minicoro.h".}
  ## Yield from current coroutine.

proc mco_status*(co: ptr McoCoro): McoState {.cdecl, importc, header: "minicoro.h".}
  ## Get coroutine state.

proc mco_get_user_data*(co: ptr McoCoro): pointer {.cdecl, importc, header: "minicoro.h".}
  ## Get user data set during creation.

proc mco_running*(): ptr McoCoro {.cdecl, importc, header: "minicoro.h".}
  ## Get the currently running coroutine, or nil.

proc mco_result_description*(res: McoResult): cstring {.cdecl, importc, header: "minicoro.h".}
  ## Get description string for a result code.

# Storage API for passing data between yield/resume
proc mco_push*(co: ptr McoCoro, src: pointer, len: csize_t): McoResult {.cdecl, importc, header: "minicoro.h".}
proc mco_pop*(co: ptr McoCoro, dest: pointer, len: csize_t): McoResult {.cdecl, importc, header: "minicoro.h".}
proc mco_peek*(co: ptr McoCoro, dest: pointer, len: csize_t): McoResult {.cdecl, importc, header: "minicoro.h".}
proc mco_get_bytes_stored*(co: ptr McoCoro): csize_t {.cdecl, importc, header: "minicoro.h".}

# =============================================================================
# Nim Helper Functions
# =============================================================================

proc isDead*(co: ptr McoCoro): bool {.inline.} =
  mco_status(co) == MCO_DEAD

proc isSuspended*(co: ptr McoCoro): bool {.inline.} =
  mco_status(co) == MCO_SUSPENDED

proc isRunning*(co: ptr McoCoro): bool {.inline.} =
  mco_status(co) == MCO_RUNNING

proc checkResult*(res: McoResult) {.inline.} =
  ## Raise exception on error
  if res != MCO_SUCCESS:
    raise newException(CatchableError, "minicoro error: " & $mco_result_description(res))

template mcoYield*() =
  ## Yield from current coroutine (convenience)
  discard mco_yield(mco_running())