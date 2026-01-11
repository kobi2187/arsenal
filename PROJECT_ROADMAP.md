# Arsenal Project Roadmap
## Master Task List, Milestones & Dependencies

---

## Project Overview

**Goal**: Build a universal low-level Nim library - atomic, composable, swappable primitives for high-performance systems programming.

**Success Criteria**: Nim programs using Arsenal achieve performance parity with hand-tuned C/C++ while maintaining safety and ergonomics.

**Special emphasis on ergonomics at each layer, and especially at the final API level **


Both ERGONOMIC and FAST, freely using Nim features such as compile time when clauses, asm emit, and making implementation modules with the same api, that are imported at compile time based on latency max performance strategy, suited best to this computer's hardware (unless requesting portable impl). The api is the same, user gets best for free.

---

## Milestone Structure

```
PHASE A: Foundation
M0: Project Setup → M1: Core Infrastructure

PHASE B: Concurrency (Priority)
M2: Coroutines → M3: Lock-Free → M4: Channels → M5: I/O → M6: DSL → M7: Echo Server

PHASE C: Performance
M8: Allocators → M9: Hashing/Data Structures → M10: Compression → M11: Parsing

PHASE D: Advanced Compute
M12: Linear Algebra → M13: AI/ML → M14: Media Processing

PHASE E: Systems & Security
M15: Binary Parsing → M16: Forensics → M17: Embedded/Kernel → M18: Crypto

PHASE F: Release
M19: 1.0 Release
```

**Total: 19 milestones across 6 phases**

NOTES: work in waterfall manner. breadth first, leave notes to next implementor. finish one job/duty across all items and exit, then enter and achieve another aspect across all items. Each time doing a specific job in this layered approach.
Finally, implement and switch to feedback mode - test/impl iterations.

---

## Core Design Pattern: Unsafe + Safe Wrappers

Every module follows this pattern:

```nim
# UNSAFE PRIMITIVE (low-level, maximum control)
proc unsafeAlloc(size: int): ptr UncheckedArray[byte] {.inline.}

# SAFE WRAPPER (bounds-checked, tracked, idiomatic)
type MemoryArena = object
  blocks: seq[ptr UncheckedArray[byte]]
  sizes: seq[int]

proc alloc[T](arena: var MemoryArena, size: int = sizeof(T)): ptr T =
  let p = unsafeAlloc(size).cast[ptr T]
  arena.blocks.add(p)
  arena.sizes.add(size)
  p
```

**Why this matters:**
- Experts get zero-overhead primitives
- Beginners get safety by default
- Both can coexist in the same codebase
- Gradual optimization path: start safe, profile, replace hot paths

---

## Target Domains

| Domain | Key Requirements | Example Use Cases |
|--------|-----------------|-------------------|
| **Embedded Systems** | Register access, ISRs, real-time scheduling, minimal runtime | Microcontroller firmware, robotics, IoT |
| **Cyber Operations** | Memory inspection, binary parsing, packet crafting | Exploit dev, reverse engineering, pentesting |
| **Forensics** | Safe memory/disk access, artifact extraction, timeline analysis | Digital forensics, incident response |
| **High-Performance Computing** | SIMD, cache-aware, lock-free, parallelism | Scientific computing, ML, real-time |
| **Systems Programming** | OS kernel modules, drivers, filesystems | Custom kernels, device drivers |
| **Game Development** | High-perf math, memory pools, deterministic execution | Game engines, physics simulations |
| **Blockchain/Crypto** | Cryptographic primitives, secure memory, deterministic | Smart contracts, ZK proofs |

---

# Phase A: Foundation (Milestones 0-1)

## M0: Project Setup
**Dependencies**: None
**Effort**: Small

### Tasks
- [ ] **M0.1** Create directory structure
  ```
  arsenal/
  ├── src/arsenal/
  ├── tests/
  ├── benchmarks/
  ├── examples/
  ├── docs/
  └── vendor/  (for C sources)
  ```
- [ ] **M0.2** Create `arsenal.nimble` package file
- [ ] **M0.3** Create `.gitignore` for Nim projects
- [ ] **M0.4** Create `README.md` with vision statement
- [ ] **M0.5** Set up GitHub repository
- [ ] **M0.6** Create GitHub Actions CI skeleton (Linux/macOS/Windows)
- [ ] **M0.7** Create `CONTRIBUTING.md` guidelines

### Acceptance Criteria
- [ ] `nimble build` succeeds (empty project)
- [ ] CI runs on all 3 platforms
- [ ] Repository is public and documented

---

## M1: Core Infrastructure
**Dependencies**: M0
**Effort**: Medium

### Tasks

#### M1.1: CPU Feature Detection
- [ ] **M1.1.1** Create `src/arsenal/config.nim`
- [ ] **M1.1.2** Implement x86_64 CPUID parsing (SSE2, SSE4, AVX, AVX2, AVX512, AES-NI, POPCNT, BMI1, BMI2)
- [ ] **M1.1.3** Implement ARM64 feature detection (NEON, SVE, CRC32, AES)
- [ ] **M1.1.4** Create `CpuFeatures` object with all flags
- [ ] **M1.1.5** Implement `detectCpuFeatures()` proc
- [ ] **M1.1.6** Create compile-time `when` helpers for each feature
- [ ] **M1.1.7** Write unit tests for feature detection

#### M1.2: Strategy System
- [ ] **M1.2.1** Create `src/arsenal/strategies.nim`
- [ ] **M1.2.2** Define `OptimizationStrategy` enum (Throughput, Latency, Balanced, MinimalMemory)
- [ ] **M1.2.3** Implement threadvar `currentStrategy`
- [ ] **M1.2.4** Create `setStrategy()` / `getStrategy()` procs
- [ ] **M1.2.5** Create `withStrategy()` template for scoped strategy changes
- [ ] **M1.2.6** Write unit tests

#### M1.3: Benchmarking Framework
- [ ] **M1.3.1** Create `benchmarks/benchmark.nim`
- [ ] **M1.3.2** Implement high-resolution timer (RDTSC on x86, monotonic on ARM)
- [ ] **M1.3.3** Implement `bench()` template with warmup, iterations, statistics
- [ ] **M1.3.4** Implement result formatting (ops/sec, ns/op, percentiles)
- [ ] **M1.3.5** Create JSON output for CI tracking
- [ ] **M1.3.6** Create `benchmarks/run_all.nim` runner

#### M1.4: Platform Abstractions
- [ ] **M1.4.1** Create `src/arsenal/platform.nim`
- [ ] **M1.4.2** Define platform constants (OS, arch, pointer size)
- [ ] **M1.4.3** Create cache line size detection
- [ ] **M1.4.4** Create page size detection
- [ ] **M1.4.5** Create CPU count detection

### Acceptance Criteria
- [ ] `cpuFeatures.hasAVX2` correctly detects AVX2 on supporting CPUs
- [ ] `cpuFeatures.hasNEON` correctly detects NEON on ARM64
- [ ] `setStrategy(Latency)` changes thread-local strategy
- [ ] `bench("test") do: ...` produces timing output
- [ ] All tests pass on Linux x86_64, Linux ARM64, macOS, Windows

### Verification Tests
```nim
# config_test.nim
test "detect AVX2 on modern x86":
  let features = detectCpuFeatures()
  when defined(amd64):
    # Most modern CPUs have AVX2
    echo "AVX2: ", features.hasAVX2

# strategies_test.nim
test "thread-local strategy":
  setStrategy(Latency)
  check getStrategy() == Latency

  # Different thread has different strategy
  var otherThreadStrategy: OptimizationStrategy
  createThread(proc() =
    otherThreadStrategy = getStrategy()
  )
  joinThread()
  check otherThreadStrategy == Balanced  # Default
```

---

# Phase B: Concurrency Foundation (Milestones 2-6)

## M2: Coroutine Foundation
**Dependencies**: M1
**Effort**: Large
**Priority**: Critical Path

### Tasks

#### M2.1: libaco Binding (x86_64, ARM64)
- [✓] **M2.1.1** Download libaco source to `vendor/libaco/`
- [✓] **M2.1.2** Create `src/arsenal/concurrency/coroutines/libaco.nim`
- [✓] **M2.1.3** Define `AcoT`, `AcoShareStack`, `AcoAttr` types
- [✓] **M2.1.4** Bind `aco_thread_init()`, `aco_create()`, `aco_resume()`, `aco_yield()`, `aco_destroy()`
- [✓] **M2.1.5** Add `{.compile.}` pragmas for `aco.c` and `acosw.S`
- [✓] **M2.1.6** Test basic context switch works
- [ ] **M2.1.7** Benchmark context switch time (target: <20ns)

#### M2.2: minicoro Binding (Portable Fallback)
- [✓] **M2.2.1** Download minicoro source to `vendor/minicoro/`
- [✓] **M2.2.2** Create `src/arsenal/concurrency/coroutines/minicoro.nim`
- [✓] **M2.2.3** Bind `mco_coro`, `mco_create()`, `mco_resume()`, `mco_yield()`, `mco_destroy()`
- [ ] **M2.2.4** Test on Windows
- [ ] **M2.2.5** Benchmark context switch time

#### M2.3: Unified Coroutine Interface
- [✓] **M2.3.1** Create `src/arsenal/concurrency/coroutine.nim` (trait definition)
- [✓] **M2.3.2** Define `CoroutineBackend` concept
- [✓] **M2.3.3** Create `Coroutine` ref object wrapper
- [✓] **M2.3.4** Create `src/arsenal/concurrency/coroutines/backend.nim` (auto-selection)
- [✓] **M2.3.5** Implement platform dispatch:
  - Linux/macOS x86_64 → libaco
  - Linux ARM64 → libaco
  - macOS ARM64 → libaco
  - Windows → minicoro
- [✓] **M2.3.6** Create `newCoroutine(fn: proc())` factory
- [✓] **M2.3.7** Create `resume()`, `yield()`, `destroy()` procs

#### M2.4: Nim-Friendly Wrapper
- [✓] **M2.4.1** Create RAII `Coroutine` type with destructor
- [ ] **M2.4.2** Handle GC safety (mark coroutine stacks as roots if needed)
- [ ] **M2.4.3** Create `spawn(fn: proc())` that creates and immediately resumes
- [✓] **M2.4.4** Track current coroutine with threadvar `currentCoro`
- [✓] **M2.4.5** Implement `running()` to check if inside coroutine

### Acceptance Criteria
- [ ] Context switch benchmark: <20ns on x86_64, <50ns on ARM64
- [ ] Memory per coroutine: <256 bytes (excluding stack)
- [ ] Can create 100,000 coroutines without crashing
- [ ] Works on all target platforms
- [ ] No memory leaks (valgrind clean)

### Verification Tests
```nim
test "basic context switch":
  var value = 0
  let coro = newCoroutine(proc() =
    value = 1
    coroYield()
    value = 2
  )
  check value == 0
  coro.resume()
  check value == 1
  coro.resume()
  check value == 2

test "100K coroutines":
  var count = 0
  var coros: seq[Coroutine]
  for i in 0..<100_000:
    coros.add newCoroutine(proc() =
      atomicInc(count)
      coroYield()
    )
  for c in coros:
    c.resume()
  check count == 100_000

benchmark "context switch":
  let c1 = newCoroutine(proc() =
    while true:
      coroYield()
  )
  bench("switch", iterations=1_000_000):
    c1.resume()
  # Should report <20ns/op
```

---

## M3: Lock-Free Primitives
**Dependencies**: M1
**Effort**: Medium

### Tasks

#### M3.1: Atomic Operations
- [✓] **M3.1.1** Create `src/arsenal/concurrency/atomics/atomic.nim`
- [✓] **M3.1.2** Define `Atomic[T]` generic type
- [✓] **M3.1.3** Implement `load()`, `store()` with memory ordering
- [✓] **M3.1.4** Implement `compareExchange()` (CAS)
- [✓] **M3.1.5** Implement `fetchAdd()`, `fetchSub()`, `fetchAnd()`, `fetchOr()`, `fetchXor()`
- [✓] **M3.1.6** Define `MemoryOrder` enum (Relaxed, Acquire, Release, AcqRel, SeqCst)
- [✓] **M3.1.7** Use `{.emit.}` for compiler intrinsics where needed
- [✓] **M3.1.8** Write comprehensive tests

#### M3.2: Spinlock
- [✓] **M3.2.1** Create `src/arsenal/concurrency/sync/spinlock.nim`
- [✓] **M3.2.2** Implement basic `Spinlock` (test-and-set)
- [✓] **M3.2.3** Implement `TicketLock` (fair, FIFO ordering)
- [✓] **M3.2.4** Add exponential backoff with PAUSE instruction
- [✓] **M3.2.5** Benchmark contention scenarios
- [✓] **M3.2.6** Test for correctness under high contention

#### M3.3: SPSC Queue (Single-Producer Single-Consumer)
- [✓] **M3.3.1** Create `src/arsenal/concurrency/queues/spsc.nim`
- [✓] **M3.3.2** Implement bounded ring buffer with atomic head/tail
- [✓] **M3.3.3** Implement `push()` returning bool (full check)
- [✓] **M3.3.4** Implement `pop()` returning Option[T]
- [✓] **M3.3.5** Implement `tryPush()`, `tryPop()` non-blocking variants
- [✓] **M3.3.6** Add cache line padding to prevent false sharing
- [✓] **M3.3.7** Benchmark throughput (target: >10M ops/sec)

#### M3.4: MPMC Queue (Multi-Producer Multi-Consumer)
- [✓] **M3.4.1** Create `src/arsenal/concurrency/queues/mpmc.nim`
- [✓] **M3.4.2** Implement Dmitry Vyukov's bounded MPMC queue
- [✓] **M3.4.3** Define `Cell` struct with sequence number
- [✓] **M3.4.4** Implement `push()`, `pop()` with CAS loops
- [✓] **M3.4.5** Handle ABA problem with sequence numbers
- [✓] **M3.4.6** Benchmark with varying producer/consumer counts

### Acceptance Criteria
- [ ] SPSC: >10M ops/sec single-threaded
- [ ] MPMC: >1M ops/sec with 4 producers + 4 consumers
- [ ] No data races (run with ThreadSanitizer)
- [ ] No memory ordering bugs (stress test on ARM64)
- [ ] Spinlock is fair (FIFO ticket ordering)

### Verification Tests
```nim
test "SPSC correctness":
  var queue = newSpscQueue[int](1024)
  var received: seq[int]

  # Producer thread
  let producer = spawn:
    for i in 0..<10000:
      while not queue.push(i): discard

  # Consumer thread
  let consumer = spawn:
    for i in 0..<10000:
      while true:
        if (let v = queue.pop(); v.isSome):
          received.add(v.get)
          break

  join(producer, consumer)
  check received == toSeq(0..<10000)

benchmark "SPSC throughput":
  var queue = newSpscQueue[int](65536)
  bench("push+pop", iterations=10_000_000):
    discard queue.push(42)
    discard queue.pop()
```

---

## M4: Channel System
**Dependencies**: M2, M3
**Effort**: Medium

### Tasks

#### M4.1: Unbuffered Channel
- [ ] **M4.1.1** Create `src/arsenal/concurrency/channels/unbuffered.nim`
- [ ] **M4.1.2** Define `Chan[T]` type (synchronous rendezvous)
- [ ] **M4.1.3** Implement `send()` that blocks until receiver ready
- [ ] **M4.1.4** Implement `recv()` that blocks until sender ready
- [ ] **M4.1.5** Use coroutine yield for blocking (not OS threads)
- [ ] **M4.1.6** Handle multiple waiting senders/receivers (queue them)
- [ ] **M4.1.7** Test ping-pong between coroutines

#### M4.2: Buffered Channel
- [ ] **M4.2.1** Create `src/arsenal/concurrency/channels/buffered.nim`
- [ ] **M4.2.2** Define `BufferedChan[T]` with capacity
- [ ] **M4.2.3** Use SPSC/MPMC queue internally
- [ ] **M4.2.4** Implement `send()` that blocks only when full
- [ ] **M4.2.5** Implement `recv()` that blocks only when empty
- [ ] **M4.2.6** Implement `trySend()`, `tryRecv()` non-blocking

#### M4.3: Channel Operations
- [ ] **M4.3.1** Create `src/arsenal/concurrency/channels/channel.nim` (unified interface)
- [ ] **M4.3.2** Implement `close()` to signal no more values
- [ ] **M4.3.3** Implement `isClosed()` check
- [ ] **M4.3.4** Implement `len()` for buffered channels
- [ ] **M4.3.5** Handle send-on-closed (raise or return error)
- [ ] **M4.3.6** Handle recv-on-closed (return none or zero value)

#### M4.4: Select Statement Foundation
- [ ] **M4.4.1** Create `src/arsenal/concurrency/channels/select.nim`
- [ ] **M4.4.2** Define `SelectCase` type
- [ ] **M4.4.3** Implement `selectReady()` to find first ready channel
- [ ] **M4.4.4** Implement blocking `select()` that yields until one ready
- [ ] **M4.4.5** Support default case (non-blocking)
- [ ] **M4.4.6** Test select with multiple channels

### Acceptance Criteria
- [ ] Unbuffered channel: send/recv complete atomically
- [ ] Buffered channel: non-blocking when not full/empty
- [ ] Channels work across 1000+ coroutines
- [ ] No deadlocks in ping-pong tests
- [ ] Select correctly picks first ready channel

### Verification Tests
```nim
test "unbuffered channel ping-pong":
  let ch = newChan[int]()
  var sum = 0

  spawn:
    for i in 1..100:
      ch.send(i)

  spawn:
    for i in 1..100:
      sum += ch.recv()

  runScheduler()
  check sum == 5050

test "select multiple channels":
  let ch1 = newChan[int]()
  let ch2 = newChan[string]()
  var result = ""

  spawn:
    sleep(10)
    ch2.send("hello")

  spawn:
    select:
      recv ch1 as v:
        result = "int: " & $v
      recv ch2 as v:
        result = "str: " & v

  runScheduler()
  check result == "str: hello"
```

---

## M5: I/O Integration
**Dependencies**: M2, M4
**Effort**: Large

### Tasks

#### M5.1: Event Loop Foundation
- [ ] **M5.1.1** Create `src/arsenal/io/eventloop.nim`
- [ ] **M5.1.2** Define `EventLoop` object
- [ ] **M5.1.3** Implement registration of file descriptors
- [ ] **M5.1.4** Implement `run()` main loop
- [ ] **M5.1.5** Integrate with coroutine scheduler (yield on I/O wait)

#### M5.2: epoll Backend (Linux)
- [ ] **M5.2.1** Create `src/arsenal/io/backends/epoll.nim`
- [ ] **M5.2.2** Wrap `epoll_create1()`, `epoll_ctl()`, `epoll_wait()`
- [ ] **M5.2.3** Implement `addFd()`, `removeFd()`, `modifyFd()`
- [ ] **M5.2.4** Implement `poll()` with timeout
- [ ] **M5.2.5** Handle edge-triggered vs level-triggered

#### M5.3: kqueue Backend (macOS/BSD)
- [ ] **M5.3.1** Create `src/arsenal/io/backends/kqueue.nim`
- [ ] **M5.3.2** Wrap `kqueue()`, `kevent()`
- [ ] **M5.3.3** Implement same interface as epoll backend
- [ ] **M5.3.4** Test on macOS

#### M5.4: IOCP Backend (Windows)
- [ ] **M5.4.1** Create `src/arsenal/io/backends/iocp.nim`
- [ ] **M5.4.2** Wrap `CreateIoCompletionPort()`, `GetQueuedCompletionStatus()`
- [ ] **M5.4.3** Handle Windows async model differences
- [ ] **M5.4.4** Test on Windows

#### M5.5: Async Socket Wrapper
- [ ] **M5.5.1** Create `src/arsenal/io/socket.nim`
- [ ] **M5.5.2** Implement `AsyncSocket` type
- [ ] **M5.5.3** Implement `connect()` that yields until connected
- [ ] **M5.5.4** Implement `read()` that yields until data available
- [ ] **M5.5.5** Implement `write()` that yields until buffer drained
- [ ] **M5.5.6** Implement `accept()` for server sockets
- [ ] **M5.5.7** Handle non-blocking mode setup

### Acceptance Criteria
- [ ] Event loop processes 100K events/sec
- [ ] Sockets work on Linux, macOS, Windows
- [ ] No busy-waiting (proper sleep when no events)
- [ ] Coroutines correctly yield on I/O

### Verification Tests
```nim
test "async socket echo":
  let server = newAsyncSocket()
  server.bindAddr(Port(0))
  server.listen()
  let port = server.getLocalAddr().port

  spawn:
    let client = server.accept()
    let data = client.read(1024)
    client.write(data)
    client.close()

  spawn:
    let client = newAsyncSocket()
    client.connect("127.0.0.1", port)
    client.write("hello")
    let response = client.read(1024)
    check response == "hello"

  runScheduler()
```

---

## M6: Go-Style DSL
**Dependencies**: M2, M4
**Effort**: Medium

### Tasks

#### M6.1: `go` Macro
- [ ] **M6.1.1** Create `src/arsenal/concurrency/dsl/go_macro.nim`
- [ ] **M6.1.2** Implement `go` block macro:
  ```nim
  go:
    echo "in coroutine"
  ```
- [ ] **M6.1.3** Implement `go` expression macro:
  ```nim
  go echo "in coroutine"
  ```
- [ ] **M6.1.4** Capture variables correctly (by value or ref)
- [ ] **M6.1.5** Handle return values (return channel?)

#### M6.2: Channel Operators
- [ ] **M6.2.1** Implement `<-` operator for receive:
  ```nim
  let value = <-channel
  ```
- [ ] **M6.2.2** Implement `channel <- value` for send (if syntax allows)
- [ ] **M6.2.3** Or use method syntax: `channel.send(value)`, `channel.recv()`

#### M6.3: Select Macro
- [ ] **M6.3.1** Create `src/arsenal/concurrency/dsl/select_macro.nim`
- [ ] **M6.3.2** Implement `select` block:
  ```nim
  select:
    case ch1.recv() as v:
      echo "got ", v
    case ch2.recv() as v:
      echo "got ", v
    default:
      echo "nothing ready"
  ```
- [ ] **M6.3.3** Transform into proper select call
- [ ] **M6.3.4** Handle send cases too

#### M6.4: Scheduler Integration
- [ ] **M6.4.1** Create `src/arsenal/concurrency/scheduler.nim`
- [ ] **M6.4.2** Implement global scheduler with work queue
- [ ] **M6.4.3** Implement `runScheduler()` / `runForever()`
- [ ] **M6.4.4** Implement `runUntilComplete()`
- [ ] **M6.4.5** Handle scheduler shutdown gracefully

### Acceptance Criteria
- [ ] `go { ... }` spawns coroutine
- [ ] `<-channel` receives value
- [ ] `select` picks ready channel
- [ ] Code reads like Go but runs on Nim

### Verification Tests
```nim
test "go-style prime sieve":
  # Classic Go example
  proc generate(ch: Chan[int]) =
    var i = 2
    while true:
      ch.send(i)
      inc i

  proc filter(src, dst: Chan[int], prime: int) =
    while true:
      let i = src.recv()
      if i mod prime != 0:
        dst.send(i)

  let ch = newChan[int]()
  go generate(ch)

  var primes: seq[int]
  var src = ch
  for _ in 0..<10:
    let prime = src.recv()
    primes.add(prime)
    let dst = newChan[int]()
    go filter(src, dst, prime)
    src = dst

  check primes == @[2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
```

---

## M7: First Application - Echo Server
**Dependencies**: M5, M6
**Effort**: Small
**Milestone Type**: Integration Test

### Tasks
- [ ] **M7.1** Create `examples/echo_server/`
- [ ] **M7.2** Implement TCP echo server using Arsenal primitives
- [ ] **M7.3** Handle 10,000 concurrent connections
- [ ] **M7.4** Benchmark with `wrk` or similar tool
- [ ] **M7.5** Measure memory usage per connection
- [ ] **M7.6** Compare performance vs Go, Rust tokio, Node.js
- [ ] **M7.7** Document results in `examples/echo_server/BENCHMARK.md`

### Acceptance Criteria
- [ ] Handles 10K concurrent connections
- [ ] Memory: <1KB per idle connection
- [ ] Throughput: >100K req/sec on single core
- [ ] Latency p99: <1ms
- [ ] No connection drops under load

### Verification
```bash
# Run server
./echo_server --port 8080

# Benchmark (separate terminal)
wrk -t4 -c10000 -d30s http://127.0.0.1:8080/

# Expected output:
# Requests/sec: >100000
# Latency p99: <1ms
```

---

# Phase C: Performance Primitives (Milestones 8-11)

## M8: Allocators
**Dependencies**: M1
**Effort**: Medium

### Tasks

#### M8.1: Allocator Trait
- [✓] **M8.1.1** Create `src/arsenal/memory/allocator.nim`
- [✓] **M8.1.2** Define `Allocator` concept
- [✓] **M8.1.3** Define `alloc()`, `dealloc()`, `realloc()` interface

#### M8.2: Bump Allocator (Pure Nim)
- [✓] **M8.2.1** Create `src/arsenal/memory/allocators/bump.nim`
- [✓] **M8.2.2** Implement linear allocation (~50 lines)
- [✓] **M8.2.3** Implement `reset()` to reuse buffer
- [✓] **M8.2.4** Benchmark allocation speed

#### M8.3: Pool Allocator (Pure Nim)
- [✓] **M8.3.1** Create `src/arsenal/memory/allocators/pool.nim`
- [✓] **M8.3.2** Implement fixed-size block pool
- [✓] **M8.3.3** Use free list for O(1) alloc/dealloc

#### M8.4: mimalloc Binding
- [ ] **M8.4.1** Download mimalloc to `vendor/mimalloc/`
- [ ] **M8.4.2** Create `src/arsenal/memory/allocators/mimalloc.nim`
- [ ] **M8.4.3** Bind `mi_malloc()`, `mi_free()`, `mi_realloc()`
- [ ] **M8.4.4** Benchmark vs system malloc

#### M8.5: Strategy-Based Selection
- [ ] **M8.5.1** Create `src/arsenal/memory/memory.nim` (public API)
- [ ] **M8.5.2** Select allocator based on strategy:
  - Throughput → mimalloc
  - Latency → rpmalloc (later)
  - MinimalMemory → bump or pool

### Acceptance Criteria
- [ ] Bump: 1 billion allocs/sec
- [ ] Pool: 100M allocs/sec
- [ ] mimalloc: 10-50% faster than system malloc

---

## M9: Hashing & Data Structures
**Dependencies**: M1
**Effort**: Large

### Tasks

#### M9.1: Hasher Trait
- [ ] **M9.1.1** Create `src/arsenal/hashing/hasher.nim`
- [ ] **M9.1.2** Define `Hasher` concept

#### M9.2: xxHash (Pure Nim)
- [ ] **M9.2.1** Create `src/arsenal/hashing/hashers/xxhash64.nim`
- [ ] **M9.2.2** Implement xxHash64 algorithm (~100 lines)
- [ ] **M9.2.3** Benchmark (target: >10 GB/s)

#### M9.3: wyhash (Pure Nim)
- [ ] **M9.3.1** Create `src/arsenal/hashing/hashers/wyhash.nim`
- [ ] **M9.3.2** Implement wyhash algorithm (~80 lines)
- [ ] **M9.3.3** Benchmark (target: >15 GB/s)

#### M9.4: Swiss Tables (Pure Nim)
- [ ] **M9.4.1** Create `src/arsenal/datastructures/hashtables/swiss_table.nim`
- [ ] **M9.4.2** Implement control byte array
- [ ] **M9.4.3** Implement SIMD probing (SSE2/NEON)
- [ ] **M9.4.4** Implement insert, lookup, delete
- [ ] **M9.4.5** Benchmark vs std/tables (target: 2x faster)

#### M9.5: Xor Filter (Pure Nim)
- [ ] **M9.5.1** Create `src/arsenal/datastructures/filters/xor_filter.nim`
- [ ] **M9.5.2** Implement 3-hash construction (~200 lines)
- [ ] **M9.5.3** Benchmark space vs Bloom filter

#### M9.6: Bloom Filter (Pure Nim)
- [ ] **M9.6.1** Create `src/arsenal/datastructures/filters/bloom.nim`
- [ ] **M9.6.2** Implement basic Bloom filter (~100 lines)

### Acceptance Criteria
- [ ] xxHash64: >10 GB/s
- [ ] wyhash: >15 GB/s
- [ ] Swiss Tables: 2x faster than std/tables
- [ ] Xor Filter: 30% smaller than Bloom at same FPR

---

## M10: Compression
**Dependencies**: M1
**Effort**: Medium

### Tasks

#### M10.1: LZ4 Binding
- [ ] **M10.1.1** Download LZ4 to `vendor/lz4/`
- [ ] **M10.1.2** Create `src/arsenal/compression/compressors/lz4.nim`
- [ ] **M10.1.3** Bind `LZ4_compress_default()`, `LZ4_decompress_safe()`
- [ ] **M10.1.4** Create Nim-friendly wrapper
- [ ] **M10.1.5** Benchmark (target: >4 GB/s decompress)

#### M10.2: Zstd Binding
- [ ] **M10.2.1** Download Zstd to `vendor/zstd/`
- [ ] **M10.2.2** Create `src/arsenal/compression/compressors/zstd.nim`
- [ ] **M10.2.3** Bind compression/decompression functions
- [ ] **M10.2.4** Support compression levels
- [ ] **M10.2.5** Benchmark ratio vs speed

#### M10.3: Varint (Pure Nim)
- [ ] **M10.3.1** Create `src/arsenal/compression/compressors/varint.nim`
- [ ] **M10.3.2** Implement variable-length integer encoding
- [ ] **M10.3.3** Implement SIMD-accelerated version

### Acceptance Criteria
- [ ] LZ4 decompress: >4 GB/s
- [ ] Zstd: better ratio than LZ4 at comparable speed

---

## M11: Parsing
**Dependencies**: M1
**Effort**: Medium

### Tasks

#### M11.1: simdjson Binding
- [ ] **M11.1.1** Download simdjson to `vendor/simdjson/`
- [ ] **M11.1.2** Create `src/arsenal/parsing/parsers/json/simdjson.nim`
- [ ] **M11.1.3** Bind parser, document, element types
- [ ] **M11.1.4** Create Nim-friendly API
- [ ] **M11.1.5** Benchmark (target: >2 GB/s)

#### M11.2: yyjson Binding
- [ ] **M11.2.1** Download yyjson to `vendor/yyjson/`
- [ ] **M11.2.2** Create `src/arsenal/parsing/parsers/json/yyjson.nim`
- [ ] **M11.2.3** Bind read/write functions
- [ ] **M11.2.4** Better for small JSON objects

#### M11.3: picohttpparser Binding
- [ ] **M11.3.1** Download picohttpparser to `vendor/picohttpparser/`
- [ ] **M11.3.2** Create `src/arsenal/parsing/parsers/http/picohttpparser.nim`
- [ ] **M11.3.3** Bind `phr_parse_request()`, `phr_parse_response()`

### Acceptance Criteria
- [ ] simdjson: >2 GB/s on large JSON
- [ ] yyjson: faster for <1KB JSON
- [ ] picohttpparser: >1M requests/sec parse rate

---

# Phase D: Advanced Domains (Milestones 12-15)


## M14: Media Processing
**Dependencies**: M1
**Effort**: Large

### Tasks
- [ ] **M14.1** Implement FFT (radix-2)
- [ ] **M14.2** Implement biquad filter
- [ ] **M14.3** Bind libopus
- [ ] **M14.4** Bind dav1d (AV1 decoder)
- [ ] **M14.5** Implement RGB/YUV conversion (SIMD)

### Acceptance Criteria
- [ ] FFT matches numpy.fft output
- [ ] Audio processing: <5ms latency achievable

---

## M15: Binary Parsing & Cyber
**Dependencies**: M1
**Effort**: Medium

### Tasks

#### M15.1: Executable Format Parsing
- [ ] **M15.1.1** Create `src/arsenal/binary/formats/pe.nim` - PE/COFF parser
- [ ] **M15.1.2** Create `src/arsenal/binary/formats/elf.nim` - ELF parser
- [ ] **M15.1.3** Create `src/arsenal/binary/formats/macho.nim` - Mach-O parser
- [ ] **M15.1.4** Define common `ExecutableFile` trait
- [ ] **M15.1.5** Extract sections, symbols, imports, exports

#### M15.2: Packet Crafting
- [ ] **M15.2.1** Create `src/arsenal/binary/network/packet.nim`
- [ ] **M15.2.2** Implement TCP/UDP/ICMP packet types
- [ ] **M15.2.3** Implement `craftTCP()`, `craftUDP()` procs
- [ ] **M15.2.4** Raw socket send/receive

#### M15.3: Endianness & Serialization
- [ ] **M15.3.1** Create `src/arsenal/binary/endian.nim`
- [ ] **M15.3.2** Implement `htons`, `ntohs`, `htonl`, `ntohl`
- [ ] **M15.3.3** Create safe binary reader with cursor

### Acceptance Criteria
- [ ] Can parse PE, ELF, Mach-O files
- [ ] Can craft and send raw packets
- [ ] Zero-copy parsing where possible

---

## M16: Forensics & Recovery
**Dependencies**: M15
**Effort**: Medium

### Tasks

#### M16.1: Memory Forensics
- [ ] **M16.1.1** Create `src/arsenal/forensics/memory.nim`
- [ ] **M16.1.2** Implement `dumpProcess()` (Linux: /proc/pid/mem, Windows: ReadProcessMemory)
- [ ] **M16.1.3** Implement memory region enumeration
- [ ] **M16.1.4** Pattern scanning in memory

#### M16.2: Disk Carving
- [ ] **M16.2.1** Create `src/arsenal/forensics/carving.nim`
- [ ] **M16.2.2** Define file signature database (JPEG, PNG, PDF, ZIP, etc.)
- [ ] **M16.2.3** Implement `carveFiles()` with signature matching
- [ ] **M16.2.4** Handle fragmented files

#### M16.3: Artifact Extraction
- [ ] **M16.3.1** Create `src/arsenal/forensics/artifacts.nim`
- [ ] **M16.3.2** String extraction from binaries
- [ ] **M16.3.3** Timestamp parsing (filesystem, EXIF)
- [ ] **M16.3.4** Registry hive parsing (Windows)

### Acceptance Criteria
- [ ] Can dump process memory on Linux/Windows
- [ ] Can carve JPEGs from disk image
- [ ] Can extract strings from arbitrary binary

---

## M17: Embedded/Kernel Support
**Dependencies**: M1, M8
**Effort**: Large

### Tasks
- [ ] **M17.1** Raw syscall wrappers (no libc)
- [ ] **M17.2** Minimal printf (no malloc)
- [ ] **M17.3** TLSF allocator
- [ ] **M17.4** Basic RTOS scheduler
- [ ] **M17.5** GPIO/UART HAL examples
- [ ] **M17.6** Interrupt handling (enable/disable)
- [ ] **M17.7** Register access types

### Acceptance Criteria
- [ ] Can compile to bare metal (no OS)
- [ ] Works on Cortex-M4
- [ ] <10KB binary for blink example

---

## M18: Crypto Primitives
**Dependencies**: M1, M3
**Effort**: Medium

### Tasks
- [ ] **M18.1** Create `src/arsenal/crypto/` structure
- [ ] **M18.2** Implement ChaCha20 (pure Nim, ~250 lines)
- [ ] **M18.3** Implement Poly1305 (pure Nim, ~200 lines)
- [ ] **M18.4** Implement Curve25519 (bind donna or pure Nim)
- [ ] **M18.5** Implement Ed25519 signatures
- [ ] **M18.6** Implement BLAKE3 (pure Nim or binding)
- [ ] **M18.7** Secure memory wiping (`secureZero`)
- [ ] **M18.8** Constant-time comparison

### Acceptance Criteria
- [ ] Passes official test vectors
- [ ] Constant-time operations (no timing side channels)
- [ ] `secureZero` actually clears memory (not optimized away)


## M12: Linear Algebra Foundation (Decision: Delayed to later)
**Dependencies**: M1
**Effort**: Large

### Tasks
- [ ] **M12.1** Create `src/arsenal/linalg/` structure
- [ ] **M12.2** Implement SIMD dot product (SSE2, AVX2, NEON)
- [ ] **M12.3** Implement naive GEMM
- [ ] **M12.4** Implement cache-blocked GEMM
- [ ] **M12.5** Implement vectorized GEMM (AVX2)
- [ ] **M12.6** Benchmark vs OpenBLAS

### Acceptance Criteria
- [ ] GEMM achieves >50% of theoretical peak FLOPS
- [ ] Scales well with matrix size

---

## M13: AI/ML Primitives  (Decision: Delayed to Last, only do the primitives)
**Dependencies**: M12
**Effort**: Large

### Tasks
- [ ] **M13.1** Implement LayerNorm kernel
- [ ] **M13.2** Implement Softmax (numerically stable)
- [ ] **M13.3** Implement GELU approximation
- [ ] **M13.4** Implement RoPE embeddings
- [ ] **M13.5** Implement INT8 quantization
- [ ] **M13.6** Implement attention kernel
- [ ] **M13.7** Bind GGML for advanced inference

### Acceptance Criteria
- [ ] Kernels match PyTorch output numerically
- [ ] INT8 inference: 2-4x speedup vs FP32



---

## M19: 1.0 Release
**Dependencies**: All previous milestones
**Effort**: Medium

### Tasks
- [ ] **M16.1** API stabilization review
- [ ] **M16.2** Complete documentation
- [ ] **M16.3** Write tutorials
- [ ] **M16.4** Performance regression tests in CI
- [ ] **M16.5** Security audit for crypto primitives
- [ ] **M16.6** Announce on Nim forum, Reddit, HN

### Acceptance Criteria
- [ ] All tests pass on all platforms
- [ ] No known major bugs
- [ ] Documentation covers all public APIs
- [ ] At least 3 example applications
- [ ] Benchmark results published

---

# Dependency Graph (Text Format)

```
M0: Project Setup
 │
 ▼
M1: Core Infrastructure ─────────────────────────────────────────────────┐
 │          │           │           │           │                        │
 ▼          ▼           ▼           ▼           ▼                        │
M2:Coro    M3:Lock    M8:Alloc    M9:Hash    M15:Binary                  │
 │          │           │           │           │                        │
 │          │           │           ▼           ▼                        │
 │          │           │         M10:Comp   M16:Forensics               │
 │          │           │           │                                    │
 │          │           │           ▼                                    │
 │          │           │         M11:Parse                              │
 │          │           │                                                │
 ├──────────┼───────────┤                                                │
 │          │           │                                                │
 ▼          ▼           │                                                │
M4:Chan    M5:I/O      │                                                │
 │          │           │                                                │
 ├──────────┤           │                                                │
 ▼          │           │                                                │
M6:DSL     │           │                                                │
 │          │           │                                                │
 ▼          ▼           ▼                                                │
M7: Echo Server (Integration Test) ─────────────────────────────────────┤
                        │                                                │
                        ▼                                                │
                      M12:LinAlg                                         │
                        │                                                │
                        ▼                                                │
                      M13:AI/ML                                          │
                        │                                                │
                        ▼                                                │
                      M14:Media                                          │
                        │                                                │
                        ▼                                                │
                      M17:Embedded ←── M18:Crypto                        │
                        │                │                               │
                        └────────────────┼───────────────────────────────┤
                                         ▼                               │
                                      M19: 1.0 Release ◄─────────────────┘
```

**Legend:**
- M2:Coro = Coroutines, M3:Lock = Lock-Free, M4:Chan = Channels
- M5:I/O = I/O Integration, M6:DSL = Go-Style DSL
- M8:Alloc = Allocators, M9:Hash = Hashing/Data Structures
- M10:Comp = Compression, M11:Parse = Parsing
- M12:LinAlg = Linear Algebra, M13:AI/ML = AI/ML Primitives
- M14:Media = Media Processing, M15:Binary = Binary Parsing
- M16:Forensics = Forensics & Recovery, M17:Embedded = Embedded/Kernel
- M18:Crypto = Crypto Primitives

---

# Quick Reference: What Each Milestone Delivers

| Milestone | Deliverable | Key Metric |
|-----------|-------------|------------|
| **M0** | Project structure | Builds on all platforms |
| **M1** | CPU detection, strategies, benchmarks | Feature flags work |
| **M2** | Coroutine context switching | <20ns switch |
| **M3** | Lock-free queues, atomics | >10M ops/sec SPSC |
| **M4** | Go-style channels | Correct sync semantics |
| **M5** | Async I/O (epoll/kqueue/IOCP) | 100K events/sec |
| **M6** | `go {}`, `select`, scheduler | Code reads like Go |
| **M7** | Echo server example | 10K connections, >100K req/sec |
| **M8** | Allocators (bump, pool, mimalloc) | 10-50% faster than malloc |
| **M9** | Hashing, Swiss Tables, filters | 2x faster than std/tables |
| **M10** | LZ4, Zstd compression | >4 GB/s decompress |
| **M11** | JSON, HTTP parsing | >2 GB/s JSON parse |
| **M12** | BLAS primitives | >50% peak FLOPS |
| **M13** | ML inference kernels | INT8 working |
| **M14** | Audio/video processing | Real-time capable |
| **M15** | PE/ELF/Mach-O parsing, packets | Zero-copy parsing |
| **M16** | Memory dump, disk carving | Forensics toolkit |
| **M17** | Bare metal, RTOS, GPIO | Runs without OS |
| **M18** | ChaCha20, Ed25519, BLAKE3 | Constant-time ops |
| **M19** | 1.0 release | Production ready |

---

# Risk Register

| Risk | Impact | Mitigation |
|------|--------|------------|
| libaco doesn't work on Windows | High | Use minicoro as fallback (already planned) |
| SIMD code has subtle bugs on ARM | Medium | Extensive testing on real ARM64 hardware |
| GC interferes with coroutines | High | Test with --gc:arc, document requirements |
| API breaks between milestones | Medium | Mark early APIs as experimental |
| Performance not competitive | High | Continuous benchmarking, compare to C |
