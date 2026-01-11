import aco
import std/[sequtils, os]

proc scheduler() =
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk1 = aco_share_stack_new(0)
  let sstk2 = aco_share_stack_new(0)
  
  var cos = newSeq[ptr aco_t](3)
  cos[0] = aco_create(main_co, sstk1, 0, cast[aco_cofuncp_t](coroutine1), nil)
  cos[1] = aco_create(main_co, sstk1, 0, cast[aco_cofuncp_t](coroutine2), nil)
  cos[2] = aco_create(main_co, sstk2, 0, cast[aco_cofuncp_t](coroutine3), nil)
  
  var idx = 0
  while idx < 6:
    for i in 0..<cos.len:
      aco_resume(cos[i])
    inc(idx)
  
  echo "\nFinal stats:"
  for i, co in cos:
    let owner = aco_private.getShareStackOwner(co.share_stack)
    echo fmt"  Coroutine {i}: owner={owner != nil}, finished={aco_private.isCoroutineEnded(co)}"
  
  echo fmt"Save stack stats for coroutine 0:"
  echo fmt"  Max copy size: {aco_private.getSaveStackMaxCopySize(cos[0])} bytes"
  echo fmt"  Save count: {aco_private.getSaveStackSaveCount(cos[0])}"
  echo fmt"  Restore count: {aco_private.getSaveStackRestoreCount(cos[0])}"
  
  for i in 1..<cos.len:
    aco_destroy(cos[i])
  aco_destroy(main_co)
    aco_share_stack_destroy(sstk1)
  aco_share_stack_destroy(sstk2)

proc main() =
  aco_thread_init(nil)
  scheduler()
