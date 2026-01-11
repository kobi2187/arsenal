## Benchmark: Compare libaco vs std/coro context switch performance
##
## Compile with: nim c -d:release -d:nimCoroutines -r benchmarks/bench_coroutines.nim

import std/times

# =============================================================================
# libaco benchmark
# =============================================================================

import ../src/arsenal/concurrency/coroutines/libaco

var libacoCounter = 0
var mainCo: ptr AcoHandle
var sharedStack: ptr AcoShareStack

proc libacoCoroBench() {.cdecl.} =
  while true:
    inc libacoCounter
    aco_yield()

proc libacoBench() =
  echo "=== libaco Benchmark ==="
  
  aco_thread_init(nil)
  mainCo = aco_create(nil, nil, 0, nil, nil)
  sharedStack = aco_share_stack_new(0)
  
  let co = aco_create(mainCo, sharedStack, 0, cast[AcoFuncPtr](libacoCoroBench), nil)
  
  const iterations = 1_000_000
  libacoCounter = 0
  
  let start = cpuTime()
  for _ in 0..<iterations:
    aco_resume(co)
  let elapsed = cpuTime() - start
  
  let nsPerSwitch = (elapsed * 1_000_000_000.0) / float(iterations)
  echo "✓ ", iterations, " context switches in ", elapsed * 1000, " ms"
  echo "✓ ", nsPerSwitch, " ns per switch"
  echo "✓ libacoCounter = ", libacoCounter
  echo ""

# =============================================================================
# std/coro benchmark
# =============================================================================

import std/coro

var stdCoroCounter = 0
var stdCoroRunning = true

proc stdCoroBenchProc() =
  while stdCoroRunning:
    inc stdCoroCounter
    suspend()

proc stdCoroBench() =
  echo "=== std/coro Benchmark ==="
  
  stdCoroCounter = 0
  stdCoroRunning = true
  
  let c = start(stdCoroBenchProc)
  
  const iterations = 1_000_000
  
  let startTime = cpuTime()
  for _ in 0..<iterations:
    run()  # Resume all coroutines
  let elapsed = cpuTime() - startTime
  
  stdCoroRunning = false
  
  let nsPerSwitch = (elapsed * 1_000_000_000.0) / float(iterations)
  echo "✓ ", iterations, " context switches in ", elapsed * 1000, " ms"
  echo "✓ ", nsPerSwitch, " ns per switch"
  echo "✓ stdCoroCounter = ", stdCoroCounter
  echo ""

# =============================================================================
# Main
# =============================================================================

when isMainModule:
  echo "\n=== Coroutine Backend Comparison ===\n"
  
  libacoBench()
  stdCoroBench()
  
  echo "=== Comparison Complete ===\n"
