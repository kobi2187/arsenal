import aco
import aco_private
import std/strformat

proc co_fp0() =
  var ct = 0
  echo fmt"co: starting, save_stack: {cast[int](getShareStackPtr(getThreadCoroutine().share_stack))} share_stack: {cast[int](getShareStackPtr(getThreadCoroutine().share_stack))} yield_count: 0"
  while ct < 6:
    echo fmt"co: yield_count: {ct}"
    aco_yield()
    inc(cast[ptr int](aco_get_arg())[])
    inc(ct)
  echo fmt"co: exiting"
  aco_yield()

proc main() =
  aco_thread_init(nil)

  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)

  var co_ct_arg_point_to_me: int = 0
  let co = aco_create(main_co, sstk, 0, cast[aco_cofuncp_t](co_fp0), addr(co_ct_arg_point_to_me))

  var ct = 0
  while ct < 6:
    doAssert not isCoroutineEnded(co)
    echo fmt"main_co: yield to co: {cast[int](co)} count: {ct}"
    aco_resume(co)
    doAssert co_ct_arg_point_to_me == ct
    inc(ct)

  echo fmt"main_co: yield to co: {cast[int](co)} count: {ct}"
  aco_resume(co)
  doAssert co_ct_arg_point_to_me == ct
  doAssert isCoroutineEnded(co)

  echo fmt"main_co: finished"
  
  aco_destroy(co)

  aco_share_stack_destroy(sstk)

  aco_destroy(main_co)

when isMainModule:
  main()