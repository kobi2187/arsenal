## Atomic Operations with Memory Ordering
## ======================================
##
## Provides C++11-style atomic operations with explicit memory ordering.
## This is the foundation for all lock-free data structures.
##
## **PLATFORM SUPPORT:**
## - GCC/Clang (Linux, macOS): Fully supported ✓
## - MSVC (Windows): NOT IMPLEMENTED - falls back to non-atomic operations!
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

# Compile-time warning for unsupported platforms
when defined(vcc):
  {.warning: "MSVC atomics not implemented! Falling back to NON-ATOMIC operations. DO NOT use in production on Windows with MSVC. See atomic.nim TODOs.".}

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
    ##
    ## **LIMITATION**: Currently only works with integer types (int, uint, bool)
    ## due to GCC __atomic builtins compatibility.
    ##
    ## TODO: Add support for:
    ## - Floating point types (float32, float64) - requires different intrinsics
    ## - Pointer types (ptr T, ref T) - needs cast handling
    ## - Enum types - needs underlying type conversion
    ##
    ## T must fit in a machine word (up to 8 bytes on 64-bit systems).
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
  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_load_n(&`a`.value, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC intrinsics
    # For x86/x86_64: all loads are naturally Acquire
    # Relaxed: simple volatile read
    # SeqCst: volatile read + compiler barrier
    case order
    of Relaxed:
      {.emit: """
        `result` = *((volatile `T`*)&`a`.value);
      """.}
    of Acquire, AcqRel, SeqCst:
      # Use InterlockedCompareExchange as a load barrier (read same value)
      when T == int32:
        {.emit: """
          `result` = _InterlockedCompareExchange((long volatile*)&`a`.value, 0, 0);
        """.}
      elif T == int64:
        {.emit: """
          `result` = _InterlockedCompareExchange64((long long volatile*)&`a`.value, 0, 0);
        """.}
      else:
        {.emit: """
          `result` = *((volatile `T`*)&`a`.value);
        """.}
    else:
      {.emit: """
        `result` = *((volatile `T`*)&`a`.value);
      """.}
  else:
    # Fallback: volatile read (not fully atomic on all platforms)
    {.emit: """
      `result` = *((volatile `T`*)&`a`.value);
    """.}

proc store*[T](a: var Atomic[T], val: T, order: MemoryOrder = SeqCst) {.inline.} =
  ## Atomically store a new value.
  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      __atomic_store_n(&`a`->value, `val`, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedExchange for atomicity
    # MSVC intrinsics: all provide SeqCst semantics
    case order
    of Relaxed:
      # Simple volatile write (no barrier needed on x86/x64)
      {.emit: """
        *((volatile `T`*)&`a`.value) = `val`;
      """.}
    else:
      # Use _InterlockedExchange for proper atomicity
      when T == int32 or T == uint32:
        {.emit: """
          _InterlockedExchange((long volatile*)&`a`.value, (long)`val`);
        """.}
      elif T == int64 or T == uint64:
        {.emit: """
          _InterlockedExchange64((long long volatile*)&`a`.value, (long long)`val`);
        """.}
      else:
        {.emit: """
          *((volatile `T`*)&`a`.value) = `val`;
        """.}
  else:
    # Fallback: volatile write (not fully atomic)
    {.emit: """
      *((volatile `T`*)&`a`->value) = `val`;
    """.}

# =============================================================================
# Exchange
# =============================================================================

proc exchange*[T](a: var Atomic[T], val: T, order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically replace the value and return the old value.
  ##
  ## On x86: XCHG instruction (always has implicit lock prefix).
  ## On ARM: LDXR/STXR loop or SWPAL (ARMv8.1 LSE).
  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_exchange_n(&`a`->value, `val`, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedExchange intrinsic
    when T == int32 or T == uint32:
      {.emit: """
        `result` = _InterlockedExchange((long volatile*)&`a`.value, (long)`val`);
      """.}
    elif T == int64 or T == uint64:
      {.emit: """
        `result` = _InterlockedExchange64((long long volatile*)&`a`.value, (long long)`val`);
      """.}
    else:
      # Fallback for other types
      result = a.value
      a.value = val
  else:
    # Fallback: NOT atomic!
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
  ## On x86: CMPXCHG instruction with LOCK prefix.
  ## On ARM: LDXR/STXR loop or CASAL (ARMv8.1 LSE).
  ##
  ## Note: `expected` is updated to the actual value on failure,
  ## which is useful for CAS loops.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_compare_exchange_n(
        &`a`->value, `expected`, `desired`,
        0,  // strong (not weak)
        `successOrder`, `failureOrder`
      );
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedCompareExchange intrinsic
    when T == int32 or T == uint32:
      {.emit: """
        long old_val = _InterlockedCompareExchange(
          (long volatile*)&`a`.value,
          (long)`desired`,
          (long)`expected`
        );
        if (old_val == (long)`expected`) {
          `result` = 1;
        } else {
          `expected` = (typeof(`expected`))old_val;
          `result` = 0;
        }
      """.}
    elif T == int64 or T == uint64:
      {.emit: """
        long long old_val = _InterlockedCompareExchange64(
          (long long volatile*)&`a`.value,
          (long long)`desired`,
          (long long)`expected`
        );
        if (old_val == (long long)`expected`) {
          `result` = 1;
        } else {
          `expected` = (typeof(`expected`))old_val;
          `result` = 0;
        }
      """.}
    else:
      # Fallback for unsupported types
      if a.value == expected:
        a.value = desired
        result = true
      else:
        expected = a.value
        result = false
  else:
    # Fallback: NOT atomic!
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
  ## On x86: Identical to strong CAS (x86 doesn't have spurious failures).
  ## On ARM: Single LDXR/STXR attempt (no loop), can fail spuriously.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_compare_exchange_n(
        &`a`->value, `expected`, `desired`,
        1,  // weak
        `successOrder`, `failureOrder`
      );
    """.}
  elif defined(vcc):
    # Windows x86/x64: MSVC doesn't support weak CAS, use strong
    result = compareExchange(a, expected, desired, successOrder, failureOrder)
  else:
    # Fallback: same as strong
    result = compareExchange(a, expected, desired, successOrder, failureOrder)

# =============================================================================
# Fetch and Modify Operations
# =============================================================================

proc fetchAdd*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically add `val` to `a` and return the OLD value.
  ##
  ## On x86: LOCK XADD instruction.
  ## On ARM: LDADDAL (ARMv8.1) or LDXR/ADD/STXR loop.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_fetch_add(&`a`->value, `val`, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedExchangeAdd intrinsic
    when T == int32 or T == uint32:
      {.emit: """
        `result` = _InterlockedExchangeAdd((long volatile*)&`a`.value, (long)`val`);
      """.}
    elif T == int64 or T == uint64:
      {.emit: """
        `result` = _InterlockedExchangeAdd64((long long volatile*)&`a`.value, (long long)`val`);
      """.}
    else:
      # Fallback for unsupported types
      result = a.value
      a.value = a.value + val
  else:
    # Fallback: NOT atomic!
    result = a.value
    a.value = a.value + val

proc fetchSub*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically subtract `val` from `a` and return the OLD value.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_fetch_sub(&`a`->value, `val`, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedExchangeAdd with negated value
    when T == int32 or T == uint32:
      {.emit: """
        `result` = _InterlockedExchangeAdd((long volatile*)&`a`.value, -(long)`val`);
      """.}
    elif T == int64 or T == uint64:
      {.emit: """
        `result` = _InterlockedExchangeAdd64((long long volatile*)&`a`.value, -(long long)`val`);
      """.}
    else:
      # Fallback for unsupported types
      result = a.value
      a.value = a.value - val
  else:
    # Fallback: NOT atomic!
    result = a.value
    a.value = a.value - val

proc fetchAnd*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically AND `val` with `a` and return the OLD value.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_fetch_and(&`a`->value, `val`, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedAnd intrinsic
    when T == int32 or T == uint32:
      {.emit: """
        `result` = _InterlockedAnd((long volatile*)&`a`.value, (long)`val`);
      """.}
    elif T == int64 or T == uint64:
      {.emit: """
        `result` = _InterlockedAnd64((long long volatile*)&`a`.value, (long long)`val`);
      """.}
    else:
      # Fallback for unsupported types
      result = a.value
      a.value = a.value and val
  else:
    # Fallback: NOT atomic!
    result = a.value
    a.value = a.value and val

proc fetchOr*[T: SomeInteger](a: var Atomic[T], val: T,
                               order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically OR `val` with `a` and return the OLD value.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_fetch_or(&`a`->value, `val`, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedOr intrinsic
    when T == int32 or T == uint32:
      {.emit: """
        `result` = _InterlockedOr((long volatile*)&`a`.value, (long)`val`);
      """.}
    elif T == int64 or T == uint64:
      {.emit: """
        `result` = _InterlockedOr64((long long volatile*)&`a`.value, (long long)`val`);
      """.}
    else:
      # Fallback for unsupported types
      result = a.value
      a.value = a.value or val
  else:
    # Fallback: NOT atomic!
    result = a.value
    a.value = a.value or val

proc fetchXor*[T: SomeInteger](a: var Atomic[T], val: T,
                                order: MemoryOrder = SeqCst): T {.inline.} =
  ## Atomically XOR `val` with `a` and return the OLD value.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      `result` = __atomic_fetch_xor(&`a`->value, `val`, `order`);
    """.}
  elif defined(vcc):
    # Windows MSVC: Use _InterlockedXor intrinsic
    when T == int32 or T == uint32:
      {.emit: """
        `result` = _InterlockedXor((long volatile*)&`a`.value, (long)`val`);
      """.}
    elif T == int64 or T == uint64:
      {.emit: """
        `result` = _InterlockedXor64((long long volatile*)&`a`.value, (long long)`val`);
      """.}
    else:
      # Fallback for unsupported types
      result = a.value
      a.value = a.value xor val
  else:
    # Fallback: NOT atomic!
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
  ## On x86:
  ## - Relaxed: No-op (compiler barrier only)
  ## - Acquire/Release: No-op on x86 (implicitly ordered)
  ## - SeqCst: MFENCE instruction
  ##
  ## On ARM:
  ## - DMB (Data Memory Barrier) with appropriate options

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      __atomic_thread_fence(`order`);
    """.}
  else:
    # Fallback: compiler barrier only
    {.emit: """
      __asm__ __volatile__("" ::: "memory");
    """.}

proc atomicSignalFence*(order: MemoryOrder) {.inline.} =
  ## Fence for signal handler synchronization (same thread, async signal).
  ## Lighter than thread fence - only prevents compiler reordering.

  when defined(gcc) or defined(clang) or defined(llvm_gcc):
    {.emit: """
      __atomic_signal_fence(`order`);
    """.}
  else:
    # Fallback: compiler barrier
    {.emit: """
      __asm__ __volatile__("" ::: "memory");
    """.}

# =============================================================================
# Spin Hint
# =============================================================================

proc spinHint*() {.inline.} =
  ## Hint to the CPU that we're in a spin loop.
  ## Reduces power consumption and improves performance on hyperthreaded CPUs.
  ##
  ## On x86: PAUSE instruction
  ## On ARM: YIELD instruction
  ## On other platforms: No-op or compiler barrier.

  when defined(amd64) or defined(i386):
    {.emit: "__asm__ __volatile__(\"pause\");".}
  elif defined(arm) or defined(arm64):
    {.emit: "__asm__ __volatile__(\"yield\");".}
  else:
    # No-op on other architectures
    discard
