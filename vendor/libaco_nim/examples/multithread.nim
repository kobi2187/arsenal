import std/[locks, threads]
import aco

var threadCount = 0

proc workerThread(arg: pointer) {.thread.} =
  atomicInc(threadCount)
  let fn = cast[proc()](arg)
  aco_thread_init(nil)
  
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)
  let co = aco_create(main_co, sstk, 0, cast[aco_cofuncp_t](workerThread), nil)
  
  for i in 1..10:
    aco_resume(co)
  
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)
  
  atomicDec(threadCount)

proc main() =
  var threads: seq[Thread[void -> void]]
  let workers = 4
  
  for i in 0..<workers:
    var t = createThread(workerThread, nil)
    threads.add(t)
  
  for t in threads:
    joinThread(t)
  
  echo fmt"Created and completed {threads.len} threads, total {threadCount} iterations"
