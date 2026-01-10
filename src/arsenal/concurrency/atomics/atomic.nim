## Atomic Operations with Memory Ordering
## ======================================
##
## Provides C++11-style atomic operations with explicit memory ordering.
## This is the foundation for all lock-free data structures.
##
## Memory Ordering Guide:
## - `Relaxed`: No ordering guarantees. Use for counters where order doesn't matter.
## - `Acquire`: Reads after this see writes before the corresponding Release.
## - `Release`: Writes before this are visible after the corresponding Acquire.
## - `AcqRel`: Both Acquire and Release (for read-modify-write operations).
## - `SeqCst`: Total ordering. Safest but slowest. Use when unsure.
##
## Usage:
## ```nim
## var counter = Atomic[int].init(0)
## counter.fetchAdd(1, Relaxed)
## let value = counter.load(Acquire)
## ```

import std/options

type
  MemoryOrder* = enum
    ## Memory ordering constraints for atomic operations.
    ## Maps directly to C++11 memory model.

    Relaxed = 0
      ## No synchronization. Only guarantees atomicity.
      ## Use for: statistics counters, progress indicators.

    Consume = 1
      ## Data-dependent ordering (rarely used, often treated as Acquire).

    Acquire = 2
      ## Prevents reads/writes from being reordered before this load.
      ## Pairs with Release on another thread.

    Release = 3
      ## Prevents reads/writes from being reordered after this store.
      ## Pairs with Acquire on another thread.

    AcqRel = 4
      ## Combines Acquire and Release. For read-modify-write operations.

    SeqCst = 5
      ## Sequential consistency. All SeqCst operations appear in a single
      ## total order agreed upon by all threads. Safest, but may be slower.

  Atomic*[T] = object
    ## Atomic wrapper for type T.
    ## T must be a primitive type (int, uint, ptr, bool, enum) that fits
    ## in a machine word (up to 8 bytes on 64-bit systems).
    ##
    ## For larger types, use locks or split into multiple atomics.
    value: T

# =============================================================================
# Initialization
# =============================================================================

proc init*[T](val: T): Atomic[T] {.inline.} =
  ## Create an atomic with initial value.
  result.value = val

proc init*[T](_: typedesc[Atomic[T]], val: T): Atomic[T] {.inline.} =
  ## Alternative initialization syntax: `Atomic[int].init(0)`
  result.value = val

# =============================================================================
# Load / Store
# =============================================================================

proc load*[T](a: Atomic[T], order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically load the current value.
  ##
  ## IMPLEMENTATION:
  ## Use GCC/Clang `__atomic_load_n` builtin:
  ## ```nim
  ## {.emit: """
  ##   `result` = __atomic_load_n(&`a`.value, `order`);
  ## """.}
  ## ```
  ##
  ## Or for MSVC on Windows:
  ## - `InterlockedCompareExchange` with same value for SeqCst
  ## - `_InterlockedCompareExchange_acq` for Acquire
  ## - Simple volatile read for Relaxed (on x86)
  ##
  ## Note: On x86, loads are naturally Acquire (except for SeqCst which
  ## needs MFENCE or locked instruction).

  # Stub - use volatile read as placeholder
  result = a.value

proc store*[T](a: var Atomic[T], val: T, order: MemoryOrder = SeqCst) {.inline.} =
  ## Atomically store a new value.
  ##
  ## IMPLEMENTATION:
  ## Use GCC/Clang `__atomic_store_n` builtin:
  ## ```nim
  ## {.emit: """
  ##   __atomic_store_n(&`a`.value, `val`, `order`);
  ## """.}
  ## ```
  ##
  ## On x86:
  ## - Relaxed/Release: Simple MOV (x86 stores are naturally Release)
  ## - SeqCst: XCHG or MOV + MFENCE

  # Stub - use volatile write as placeholder
  a.value = val

# =============================================================================
# Exchange
# =============================================================================

proc exchange*[T](a: var Atomic[T], val: T, order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically replace the value and return the old value.
  ##
  ## IMPLEMENTATION:
  ## Use `__atomic_exchange_n`:
  ## ```nim
  ## {.emit: """
  ##   `result` = __atomic_exchange_n(&`a`.value, `val`, `order`);
  ## """.}
  ## ```
  ##
  ## On x86: XCHG instruction (always has implicit lock prefix).
  ## On ARM: LDXR/STXR loop or SWPAL (ARMv8.1 LSE).

  result = a.value
  a.value = val

# =============================================================================
# Compare and Exchange (CAS)
# =============================================================================

proc compareExchange*[T](a: var Atomic[T], expected: var T, desired: T,
                         successOrder: MemoryOrder = SeqCst,
                         failureOrder: MemoryOrder = SeqCst): bool {.inline.} =
  ## Strong compare-and-exchange.
  ## If `a == expected`, sets `a = desired` and returns true.
  ## Otherwise, sets `expected = a` (current value) and returns false.
  ##
  ## IMPLEMENTATION:
  ## Use `__atomic_compare_exchange_n`:
  ## ```nim
  ## {.emit: """
  ##   `result` = __atomic_compare_exchange_n(
  ##     &`a`.value, &`expected`, `desired`,
  ##     false,  // strong (not weak)
  ##     `successOrder`, `failureOrder`
  ##   );
  ## """.}
  ## ```
  ##
  ## On x86: CMPXCHG instruction with LOCK prefix.
  ## On ARM: LDXR/STXR loop or CASAL (ARMv8.1 LSE).
  ##
  ## Note: `expected` is updated to the actual value on failure,
  ## which is useful for CAS loops.

  if a.value == expected:
    a.value = desired
    result = true
  else:
    expected = a.value
    result = false

proc compareExchangeWeak*[T](a: var Atomic[T], expected: var T, desired: T,
                             successOrder: MemoryOrder = SeqCst,
                             failureOrder: MemoryOrder = SeqCst): bool {.inline.} =
  ## Weak compare-and-exchange. May fail spuriously even if values match.
  ## Use in loops where you'll retry anyway - can be faster on some platforms.
  ##
  ## IMPLEMENTATION:
  ## Same as strong CAS but with `weak=true`:
  ## ```nim
  ## {.emit: """
  ##   `result` = __atomic_compare_exchange_n(
  ##     &`a`.value, &`expected`, `desired`,
  ##     true,  // weak
  ##     `successOrder`, `failureOrder`
  ##   );
  ## """.}
  ## ```
  ##
  ## On x86: Identical to strong CAS (x86 doesn't have spurious failures).
  ## On ARM: Single LDXR/STXR attempt (no loop), can fail spuriously.

  # Same as strong for stub
  compareExchange(a, expected, desired, successOrder, failureOrder)

# =============================================================================
# Fetch and Modify Operations
# =============================================================================

proc fetchAdd*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically add `val` to `a` and return the OLD value.
  ##
  ## IMPLEMENTATION:
  ## Use `__atomic_fetch_add`:
  ## ```nim
  ## {.emit: """
  ##   `result` = __atomic_fetch_add(&`a`.value, `val`, `order`);
  ## """.}
  ## ```
  ##
  ## On x86: LOCK XADD instruction.
  ## On ARM: LDADDAL (ARMv8.1) or LDXR/ADD/STXR loop.

  result = a.value
  a.value = a.value + val

proc fetchSub*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically subtract `val` from `a` and return the OLD value.
  ##
  ## IMPLEMENTATION: Use `__atomic_fetch_sub`.

  result = a.value
  a.value = a.value - val

proc fetchAnd*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically AND `val` with `a` and return the OLD value.
  ##
  ## IMPLEMENTATION: Use `__atomic_fetch_and`.

  result = a.value
  a.value = a.value and val

proc fetchOr*[T: SomeInteger](a: var Atomic[T], val: T,
                               order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically OR `val` with `a` and return the OLD value.
  ##
  ## IMPLEMENTATION: Use `__atomic_fetch_or`.

  result = a.value
  a.value = a.value or val

proc fetchXor*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically XOR `val` with `a` and return the OLD value.
  ##
  ## IMPLEMENTATION: Use `__atomic_fetch_xor`.

  result = a.value
  a.value = a.value xor val

# =============================================================================
# Convenience Operations
# =============================================================================

proc `+=`*[T: SomeInteger](a: var Atomic[T], val: T) {.inline.} =
  ## Convenience: `a += 1` is `a.fetchAdd(1, Relaxed)`
  discard a.fetchAdd(val, Relaxed)

proc `-=`*[T: SomeInteger](a: var Atomic[T], val: T) {.inline.} =
  ## Convenience: `a -= 1` is `a.fetchSub(1, Relaxed)`
  discard a.fetchSub(val, Relaxed)

proc inc*[T: SomeInteger](a: var Atomic[T], order: MemoryOrder = Relaxed) {.inline.} =
  ## Atomic increment.
  discard a.fetchAdd(1, order)

proc dec*[T: SomeInteger](a: var Atomic[T], order: MemoryOrder = Relaxed) {.inline.} =
  ## Atomic decrement.
  discard a.fetchSub(1, order)

# =============================================================================
# Memory Fences
# =============================================================================

proc atomicThreadFence*(order: MemoryOrder) {.inline.} =
  ## Memory fence (barrier) without an atomic operation.
  ##
  ## IMPLEMENTATION:
  ## Use `__atomic_thread_fence`:
  ## ```nim
  ## {.emit: """
  ##   __atomic_thread_fence(`order`);
  ## """.}
  ## ```
  ##
  ## On x86:
  ## - Relaxed: No-op (compiler barrier only)
  ## - Acquire/Release: No-op on x86 (implicitly ordered)
  ## - SeqCst: MFENCE instruction
  ##
  ## On ARM:
  ## - DMB (Data Memory Barrier) with appropriate options

  discard  # Stub

proc atomicSignalFence*(order: MemoryOrder) {.inline.} =
  ## Fence for signal handler synchronization (same thread, async signal).
  ## Lighter than thread fence - only prevents compiler reordering.
  ##
  ## IMPLEMENTATION:
  ## Use `__atomic_signal_fence` - typically just a compiler barrier.

  discard  # Stub

# =============================================================================
# Spin Hint
# =============================================================================

proc spinHint*() {.inline.} =
  ## Hint to the CPU that we're in a spin loop.
  ## Reduces power consumption and improves performance on hyperthreaded CPUs.
  ##
  ## IMPLEMENTATION:
  ## On x86: PAUSE instruction
  ## ```nim
  ## {.emit: "__asm__ __volatile__(\"pause\");".}
  ## ```
  ##
  ## On ARM: YIELD instruction
  ## ```nim
  ## {.emit: "__asm__ __volatile__(\"yield\");".}
  ## ```
  ##
  ## On other platforms: No-op or compiler barrier.

  discard  # Stub
