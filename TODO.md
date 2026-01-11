# Arsenal TODO List
## Known Limitations and Future Work

This file tracks known limitations, incomplete implementations, and future enhancements.
When you find a limitation or cut corners in implementation, add it here!

---

## Atomic Operations (`src/arsenal/concurrency/atomics/atomic.nim`)

### Type Support Limitations
- [ ] **Float types not supported** (float32, float64)
  - Current error: "operand type 'NF *' is incompatible with __atomic_load_n"
  - Solution: Use union-based type punning or memcpy for float atomics
  - Test case: `tests/test_atomics.nim` - "LIMITATION: float types not supported yet"

- [ ] **Pointer types not supported** (ptr T, ref T)
  - Needs proper casting to integer types for atomic operations
  - Test case: `tests/test_atomics.nim` - "LIMITATION: pointer types not supported yet"

- [ ] **Enum types not supported**
  - Should convert to underlying integer type
  - Test case: `tests/test_atomics.nim` - "LIMITATION: enum types not supported yet"

### Platform Support Limitations
- [ ] **MSVC/Windows intrinsics not implemented**
  - Currently falls back to NON-ATOMIC operations on Windows with MSVC!
  - All operations have `TODO` comments with required intrinsics:
    - `load()`: Should use `_InterlockedCompareExchange_acq` for Acquire
    - `store()`: Should use `_InterlockedExchange` for SeqCst
    - `exchange()`: Should use `_InterlockedExchange` family
    - `compareExchange()`: Should use `_InterlockedCompareExchange` family
    - `fetchAdd()`: Should use `_InterlockedExchangeAdd` family
    - `fetchSub()`: Should use `_InterlockedExchangeAdd` with negative
    - `fetchAnd()`: Should use `_InterlockedAnd` family
    - `fetchOr()`: Should use `_InterlockedOr` family
    - `fetchXor()`: Should use `_InterlockedXor` family
  - See: https://docs.microsoft.com/en-us/cpp/intrinsics/compiler-intrinsics
  - **CRITICAL**: Windows builds are currently UNSAFE for concurrent use!

### Missing Features
- [ ] Weak memory ordering optimization for ARM
  - Currently treats all as strong, could be more efficient

- [ ] Lock-free size detection at compile time
  - Should detect if type T is lock-free on target platform

---

## Spinlocks (`src/arsenal/concurrency/sync/spinlock.nim`)

### Features
- [✓] Basic spinlock - Complete
- [✓] Ticket lock (fair) - Complete
- [✓] RW spinlock - Complete
- [✓] Exponential backoff - Complete

### Future Enhancements
- [ ] Adaptive spinning (yield to OS after N iterations)
  - Currently spins indefinitely
  - Config system exists but not fully utilized

- [ ] Lock statistics (contention metrics)
  - Useful for debugging performance issues

---

## Queues (`src/arsenal/concurrency/queues/`)

### SPSC Queue
- [✓] Core implementation - Complete
- [✓] Cache line padding - Complete
- [ ] **Threading tests commented out**
  - Tests hang in some scenarios
  - Need to investigate and fix
  - File: `tests/test_spsc.nim` - marked as "TODO: Debug and re-enable threaded tests"

### MPMC Queue
- [✓] Core implementation - Complete
- [✓] Multi-threaded tests - Complete
- [ ] Benchmark suite for acceptance criteria
  - Target: >1M ops/sec with 4 producers + 4 consumers
  - Need formal benchmark harness

---

## Ergonomic API (`src/arsenal/concurrency.nim`)

### Current Status
- [✓] Smart constructors - Complete
- [✓] RAII patterns - Complete
- [✓] Type-safe wrappers - Complete

### Limitations Inherited from Primitives
- [ ] atomic() doesn't work with float (see Atomics section)
- [ ] No async/await integration (requires M2: Coroutines)

---

## Testing Infrastructure

### Missing Tests
- [ ] **ThreadSanitizer runs**
  - Acceptance criteria requires TSan clean
  - Need CI integration

- [ ] **ARM64 testing**
  - Memory ordering bugs more likely on ARM
  - Need ARM CI runner or cross-compilation tests

- [ ] **Performance benchmarks**
  - Many acceptance criteria specify throughput targets
  - Need benchmark harness (see M1: Benchmarking Framework in roadmap)

---

## Documentation

### Incomplete
- [ ] Performance characteristics for each primitive
  - SPSC: >10M ops/sec claimed but not benchmarked
  - MPMC: >1M ops/sec claimed but not benchmarked
  - Spinlock: contention behavior not documented

- [ ] Migration guide from std/locks
  - When to use which primitive?
  - Performance comparison

- [ ] Safety guide
  - Common pitfalls with lock-free programming
  - Memory ordering gotchas

---

## Future Milestones (From Roadmap)

### M2: Coroutines (Dependency for M4)
- [ ] libaco binding (x86_64, ARM64)
- [ ] minicoro binding (Windows fallback)
- [ ] Unified coroutine interface
- [ ] <20ns context switch target

### M4: Channels
- [ ] Unbuffered channels (needs M2)
- [ ] Buffered channels (can use SPSC/MPMC)
- [ ] Select statement

---

## How to Use This File

1. **When you find a limitation**: Add it here with:
   - Clear description of the problem
   - Why it was left incomplete (time, complexity, etc.)
   - Test case that demonstrates it (even if disabled)
   - Potential solution approach

2. **When you cut corners**: Document it! Examples:
   - "Changed test instead of fixing implementation" (yeah, but actually don't modify tests just to make them pass)
   - "Used naive algorithm, optimize later"
   - "Hardcoded value, should be configurable"

3. **When you fix something**: Move it to a DONE section or delete it

4. **Link to this from code**: Use comments like:
   ```nim
   # TODO: Support float types - see TODO.md "Atomic Operations"
   ```

---

## DONE (Archive of completed items)

- [✓] M3.1: Atomic Operations (basic integer support)
- [✓] M3.2: Spinlocks (all variants)
- [✓] M3.3: SPSC Queue (single-threaded verified)
- [✓] M3.4: MPMC Queue (multi-threaded verified)
- [✓] Ergonomic API layer
