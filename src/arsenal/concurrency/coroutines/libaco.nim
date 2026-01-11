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

import std/os

when defined(windows):
  {.error: "libaco backend not supported on Windows - use minicoro instead".}

# =============================================================================
# Compile libaco source files
# =============================================================================

const libacoPath = currentSourcePath().parentDir() / ".." / ".." / ".." / ".." / "vendor" / "libaco"

{.compile: libacoPath / "aco.c".}
{.compile: libacoPath / "acosw.S".}
{.passC: "-O2 -fPIC -DNDEBUG -I" & libacoPath.}

# =============================================================================
# libaco Types (Direct Bindings)
# =============================================================================

type
  AcoFuncPtr* = pointer
    ## C function pointer type for coroutine entry points

  AcoSaveStack* {.importc: "aco_save_stack_t", header: "aco.h".} = object
    ## Per-coroutine save stack for copy-on-switch
    `ptr`*: pointer
    sz*: csize_t
    valid_sz*: csize_t
    max_cpsz*: csize_t
    ct_save*: csize_t
    ct_restore*: csize_t

  AcoShareStack* {.importc: "aco_share_stack_t", header: "aco.h".} = object
    ## Shared stack for multiple coroutines (memory efficient)
    `ptr`*: pointer
    sz*: csize_t
    align_highptr*: pointer
    align_retptr*: pointer
    align_validsz*: csize_t
    align_limit*: csize_t
    owner*: ptr AcoHandle
    guard_page_enabled*: char
    real_ptr*: pointer
    real_sz*: csize_t
    when defined(aco_use_valgrind):
      valgrind_stk_id*: culong

  AcoHandle* {.importc: "aco_t", header: "aco.h".} = object
    ## Opaque coroutine handle
    main_co*: ptr AcoHandle
    arg*: pointer
    is_end*: char
    fp*: AcoFuncPtr
    save_stack*: AcoSaveStack
    share_stack*: ptr AcoShareStack

# Type aliases for C compatibility
type
  aco_save_stack_t* = ptr AcoSaveStack
  aco_share_stack_t* = ptr AcoShareStack
  aco_t* = ptr AcoHandle
  aco_cofuncp_t* = AcoFuncPtr

# =============================================================================
# Thread-local current coroutine
# =============================================================================

var acoCurrentCo* {.importc: "aco_gtls_co", threadvar.}: ptr AcoHandle

# =============================================================================
# libaco Functions (Direct Bindings)
# =============================================================================

proc aco_thread_init*(last_word_co_fp: AcoFuncPtr = nil) {.cdecl, importc, header: "aco.h".}
  ## Initialize libaco for the current thread.
  ## Must be called once per thread before creating coroutines.

proc aco_share_stack_new*(sz: csize_t): ptr AcoShareStack {.cdecl, importc, header: "aco.h".}
  ## Create a new shared stack.
  ## sz: Size in bytes (0 for default 2MB)

proc aco_share_stack_new2*(sz: csize_t, guard_page_enabled: char): ptr AcoShareStack {.cdecl, importc, header: "aco.h".}
  ## Create a new shared stack with guard page control.

proc aco_share_stack_destroy*(sstk: ptr AcoShareStack) {.cdecl, importc, header: "aco.h".}
  ## Destroy a shared stack.

proc aco_create*(
  main_co: ptr AcoHandle,
  share_stack: ptr AcoShareStack,
  save_stack_sz: csize_t,
  fp: AcoFuncPtr,
  arg: pointer
): ptr AcoHandle {.cdecl, importc, header: "aco.h".}
  ## Create a new coroutine.
  ## main_co: Main coroutine for this thread (nil to create main)
  ## share_stack: Shared stack (nil for main coroutine)
  ## save_stack_sz: Save stack size hint (0 for default)
  ## fp: Entry point function
  ## arg: User argument accessible via aco_get_arg()

proc aco_resume*(resume_co: ptr AcoHandle) {.cdecl, importc, header: "aco.h".}
  ## Resume a coroutine. Returns when coroutine yields or exits.

proc aco_yield*() {.cdecl, importc, header: "aco.h".}
  ## Yield from current coroutine back to resumer.

proc aco_yield1*(co: ptr AcoHandle) {.cdecl, importc, header: "aco.h".}
  ## Yield with explicit coroutine handle.

proc aco_get_co*(): ptr AcoHandle {.cdecl, importc, header: "aco.h".}
  ## Get the currently running coroutine.

proc aco_get_arg*(): pointer {.cdecl, importc, header: "aco.h".}
  ## Get the argument passed to aco_create.

proc aco_destroy*(co: ptr AcoHandle) {.cdecl, importc, header: "aco.h".}
  ## Destroy a coroutine and free its resources.

proc aco_is_main_co*(co: ptr AcoHandle): bool {.cdecl, importc, header: "aco.h".}
  ## Check if coroutine is the main coroutine.

# =============================================================================
# Nim Helper Functions
# =============================================================================

proc aco_exit*() {.inline.} =
  ## Exit the current coroutine (mark as finished and yield).
  ## Call this at the end of your coroutine function.
  let co = aco_get_co()
  co[].is_end = 1.char
  co[].share_stack.owner = nil
  co[].share_stack.align_validsz = 0
  aco_yield1(co)

proc isEnded*(co: ptr AcoHandle): bool {.inline.} =
  ## Check if coroutine has finished execution.
  co[].is_end != 0.char

proc getArg*(co: ptr AcoHandle): pointer {.inline.} =
  ## Get the argument passed during creation.
  co[].arg

proc getShareStackSize*(sstk: ptr AcoShareStack): csize_t {.inline.} =
  ## Get the allocated size of the share stack.
  sstk[].sz

proc isGuardPageEnabled*(sstk: ptr AcoShareStack): bool {.inline.} =
  ## Check if guard page is enabled.
  sstk[].guard_page_enabled != 0.char

proc getOwner*(sstk: ptr AcoShareStack): ptr AcoHandle {.inline.} =
  ## Get the coroutine currently using this share stack.
  sstk[].owner