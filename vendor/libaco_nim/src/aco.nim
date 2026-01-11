{.compile: "../libaco/aco.c".}
{.compile: "../libaco/acosw.S".}
{.passC: "-O2 -fPIC -DNDEBUG -I../libaco".}

type
  aco_cofuncp_t* = pointer

  aco_save_stack* {.importc: "aco_save_stack_t", header: "aco.h".} = object
    `ptr`*: pointer
    sz*: csize_t
    valid_sz*: csize_t
    max_cpsz*: csize_t
    ct_save*: csize_t
    ct_restore*: csize_t

  aco_share_stack* {.importc: "aco_share_stack_t", header: "aco.h".} = object
    `ptr`*: pointer
    sz*: csize_t
    align_highptr*: pointer
    align_retptr*: pointer
    align_validsz*: csize_t
    align_limit*: csize_t
    owner*: ptr aco_t
    guard_page_enabled*: char
    real_ptr*: pointer
    real_sz*: csize_t
    when defined(aco_use_valgrind):
      valgrind_stk_id*: culong

  aco_t* {.importc: "aco_t", header: "aco.h".} = object
    main_co*: ptr aco_t
    arg*: pointer
    is_end*: char
    fp*: aco_cofuncp_t
    save_stack*: aco_save_stack
    share_stack*: ptr aco_share_stack

  aco_save_stack_t* = ptr aco_save_stack
  aco_share_stack_t* = ptr aco_share_stack
  aco_t_ptr* = ptr aco_t

var aco_gtls_co* {.importc, threadvar.}: ptr aco_t

proc aco_thread_init*(last_word_co_fp: aco_cofuncp_t = nil) {.cdecl, importc: "aco_thread_init", header: "aco.h".}

proc aco_share_stack_new*(sz: csize_t): ptr aco_share_stack {.cdecl, importc: "aco_share_stack_new", header: "aco.h".}

proc aco_share_stack_new2*(sz: csize_t, guard_page_enabled: char): ptr aco_share_stack {.cdecl, importc: "aco_share_stack_new2", header: "aco.h".}

proc aco_share_stack_destroy*(sstk: ptr aco_share_stack) {.cdecl, importc: "aco_share_stack_destroy", header: "aco.h".}

proc aco_create*(main_co: ptr aco_t, share_stack: ptr aco_share_stack, save_stack_sz: csize_t, fp: aco_cofuncp_t, arg: pointer): ptr aco_t {.cdecl, importc: "aco_create", header: "aco.h".}

proc aco_resume*(resume_co: ptr aco_t) {.cdecl, importc: "aco_resume", header: "aco.h".}

proc aco_yield*() {.cdecl, importc: "aco_yield", header: "aco.h".}

proc aco_yield1*(co: ptr aco_t) {.cdecl, importc: "aco_yield1", header: "aco.h".}

proc aco_get_co*(): ptr aco_t {.cdecl, importc: "aco_get_co", header: "aco.h".}

proc aco_get_arg*(): pointer {.cdecl, importc: "aco_get_arg", header: "aco.h".}

proc aco_destroy*(co: ptr aco_t) {.cdecl, importc: "aco_destroy", header: "aco.h".}

proc aco_is_main_co*(co: ptr aco_t): bool {.cdecl, importc: "aco_is_main_co", header: "aco.h".}

proc aco_exit*() =
  let co = aco_get_co()
  co[].is_end = 1.char
  co[].share_stack.owner = nil
  co[].share_stack.align_validsz = 0
  aco_yield1(co)