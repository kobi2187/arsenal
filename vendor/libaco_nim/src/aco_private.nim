import aco

proc getThreadCoroutine*(): ptr aco_t {.inline, raises: [].} =
  cast[ptr aco_t](cast[pointer](aco_gtls_co))

proc getCoroutineArg*(co: ptr aco_t): pointer {.inline, raises: [].} =
  co[].arg

proc isCoroutineEnded*(co: ptr aco_t): bool {.inline, raises: [].} =
  co[].is_end != 0.char

proc getCoroutineFunction*(co: ptr aco_t): aco_cofuncp_t {.inline, raises: [].} =
  co[].fp

proc getSaveStackMaxCopySize*(co: ptr aco_t): uint {.inline, raises: [].} =
  co[].save_stack.max_cpsz.uint

proc getSaveStackSaveCount*(co: ptr aco_t): uint {.inline, raises: [].} =
  co[].save_stack.ct_save.uint

proc getSaveStackRestoreCount*(co: ptr aco_t): uint {.inline, raises: [].} =
  co[].save_stack.ct_restore.uint

proc getShareStackOwner*(sstk: aco_share_stack_t): ptr aco_t {.inline, raises: [].} =
  sstk.owner

proc getShareStackSize*(sstk: aco_share_stack_t): uint {.inline, raises: [].} =
  sstk[].sz.uint

proc getShareStackPtr*(sstk: aco_share_stack_t): pointer {.inline, raises: [].} =
  sstk[].`ptr`

proc getShareStackAlignmentHighPtr*(sstk: aco_share_stack_t): pointer {.inline, raises: [].} =
  sstk[].align_highptr

proc isShareStackGuardPageEnabled*(sstk: aco_share_stack_t): bool {.inline, raises: [].} =
  sstk[].guard_page_enabled != 0.char