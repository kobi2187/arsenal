# Arsenal

**Universal Low-Level Nim Library for High-Performance Systems Programming**

[![CI](https://github.com/yourusername/arsenal/workflows/CI/badge.svg)](https://github.com/yourusername/arsenal/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Arsenal provides atomic, composable, swappable primitives that achieve **performance parity with hand-tuned C/C++** while maintaining safety and ergonomics.

## Philosophy

**Both ERGONOMIC and FAST**: Freely using Nim features like compile-time `when` clauses, `asm` emit, and platform-specific implementations selected at compile-time based on detected hardware capabilities.

**Leverage stdlib, add missing pieces**: Arsenal re-exports and builds upon Nim's excellent standard library:
- Uses `std/monotimes` for cross-platform timing, adds RDTSC for cycle-accurate measurement
- Uses `std/random` (Xoshiro256+), adds PCG32 and CryptoRNG alternatives
- Uses `std/memfiles` for mmap, adds raw syscall file I/O
- Uses `std/net` for networking, adds raw socket primitives

Every module follows the **Unsafe + Safe Wrapper** pattern:
- **Unsafe primitives**: Maximum control, zero-overhead
- **Safe wrappers**: Bounds-checked, tracked, idiomatic

## Target Domains

| Domain | Use Cases |
|--------|-----------|
| **Embedded Systems** | Firmware, IoT, robotics |
| **Cyber Operations** | Exploit dev, forensics, packet crafting |
| **High-Performance Computing** | Scientific computing, ML inference |
| **Systems Programming** | OS kernels, device drivers |
| **Game Development** | Physics engines, real-time systems |
| **Blockchain/Crypto** | Smart contracts, zero-knowledge proofs |

## Quick Start

```bash
# Install Nim 2.0+
# Clone repository
git clone https://github.com/yourusername/arsenal.git
cd arsenal

# Install dependencies
nimble install -y

# Build
nimble build

# Run tests
nimble test

# Run benchmarks
nimble bench
```

## Basic Usage

```nim
import arsenal

# High-performance hash table (SIMD-accelerated)
var table = SwissTable[string, int].init()
table["hello"] = 42

# Go-style concurrency
go:
  echo "Running in coroutine!"

# Lock-free queues
var queue = SpscQueue[int].init(1024)
queue.push(42)
echo queue.pop()  # Some(42)

# Optimization strategies
setStrategy(Throughput)  # Optimize for max ops/sec
withStrategy(Latency):
  criticalOperation()

# CPU feature detection
let cpu = getCpuFeatures()
if cpu.hasAVX2:
  echo "Using AVX2 optimizations!"
```

## Module Overview

| Module | Status | Description |
|--------|--------|-------------|
| **Platform** | | |
| `platform/config` | ✅ Complete | CPU feature detection (CPUID, NEON) |
| `platform/strategies` | ✅ Complete | Optimization strategy selection |
| **Concurrency** | | |
| `concurrency/atomics` | 📝 Documented | C++11-style atomics with memory ordering |
| `concurrency/sync/spinlock` | 📝 Documented | Ticket lock, RW spinlock |
| `concurrency/queues` | 📝 Documented | SPSC, MPMC lock-free queues |
| `concurrency/coroutines` | 📝 Documented | libaco/minicoro backends |
| `concurrency/channels` | 📝 Documented | Go-style channels & select |
| `concurrency/dsl` | 📝 Documented | `go {}` macro and scheduler |
| **I/O** | | |
| `io/eventloop` | 📝 Documented | epoll/kqueue/IOCP backends |
| **Memory** | | |
| `memory/allocator` | 📝 Documented | Bump, Pool, System allocators |
| **Hashing** | | |
| `hashing/hasher` | 📝 Documented | xxHash64, wyhash, fnv1a |
| **Data Structures** | | |
| `datastructures/swiss_table` | 📝 Documented | SIMD hash table |
| **Compression** | | |
| `compression/lz4` | 📝 Documented | LZ4 compression bindings |
| `compression/zstd` | 📝 Documented | Zstandard compression bindings |
| **Parsing** | | |
| `parsing/simdjson` | 📝 Documented | SIMD JSON parser (2-4 GB/s) |
| `parsing/picohttpparser` | 📝 Documented | Zero-copy HTTP parser |
| **Cryptography** | | |
| `crypto/primitives` | 📝 Documented | ChaCha20, Ed25519, SHA-256, BLAKE2b (libsodium) |
| **Random** | | |
| `random/rng` | 📝 Documented | PCG32, SplitMix64, CryptoRNG |
| **Numeric** | | |
| `numeric/fixed` | 📝 Documented | Fixed-point Q16.16/Q32.32, saturating arithmetic |
| **SIMD** | | |
| `simd/intrinsics` | 📝 Documented | SSE2/AVX2 (x86), NEON (ARM) intrinsics |
| **Time** | | |
| `time/clock` | 📝 Documented | RDTSC, CLOCK_MONOTONIC, high-res timers |
| **Network** | | |
| `network/sockets` | 📝 Documented | Raw POSIX sockets, TCP/UDP primitives |
| **Filesystem** | | |
| `filesystem/rawfs` | 📝 Documented | Direct syscall file I/O, mmap |
| **Kernel/Low-Level** | | |
| `kernel/syscalls` | 📝 Documented | Raw syscalls (no libc) x86_64/ARM64 |
| **Embedded** | | |
| `embedded/nolibc` | 📝 Documented | No-libc primitives (memcpy, strlen, etc.) |
| `embedded/rtos` | 📝 Documented | Minimal RTOS (scheduler, semaphores, queues) |
| `embedded/hal` | 📝 Documented | Hardware abstraction (GPIO, UART, SPI) |
| **Utilities** | | |
| `bits/bitops` | 📝 Documented | CLZ, CTZ, popcount, rotate |

**Legend:** ✅ = Implemented | 📝 = Documented stubs ready for implementation

## Current Status

**All modules have documented stubs with detailed implementation notes.**
Each `proc` includes `## IMPLEMENTATION:` sections showing exactly how to implement it.

### Phase A: Foundation ✅ COMPLETE
- [x] M0: Project setup
- [x] M1: Core infrastructure (CPU detection, strategies)

### Phase B: Concurrency ✅ STUBS DOCUMENTED
- [x] M2: Coroutines (libaco/minicoro bindings)
- [x] M3: Lock-free primitives (atomics, spinlocks, queues)
- [x] M4: Channel system (unbuffered, buffered, select)
- [x] M5: I/O integration (epoll/kqueue/IOCP backends)
- [x] M6: Go-style DSL (`go` macro, scheduler)
- [ ] M7: Echo server (integration test) - TODO

### Phase C: Performance ✅ STUBS DOCUMENTED
- [x] M8: Allocators (bump, pool, mimalloc concepts)
- [x] M9: Hashing & data structures (xxHash64, wyhash, Swiss tables)
- [x] M10: Compression (LZ4, Zstd bindings)
- [x] M11: Parsing (simdjson, picohttpparser bindings)

### Phase D: Primitives & Low-Level ✅ STUBS DOCUMENTED
- [x] M18: Cryptography (libsodium bindings: ChaCha20, Ed25519, BLAKE2b)
- [x] Random: PCG32, SplitMix64, CSPRNG
- [x] Numeric: Fixed-point Q16.16/Q32.32, saturating arithmetic
- [x] SIMD: SSE2/AVX2/NEON intrinsics wrappers
- [x] Time: RDTSC, CLOCK_MONOTONIC, high-res timers
- [x] Network: Raw POSIX sockets
- [x] Filesystem: Raw syscall file I/O, mmap
- [x] M17: Embedded/kernel (syscalls, no-libc, RTOS, HAL)

### Phase E: Advanced Domains (Deferred - Foundation First)
- [ ] M12: Linear algebra (SIMD GEMM) - Deferred
- [ ] M13: AI/ML primitives - Deferred
- [ ] M14: Media processing (FFT, audio/video)
- [ ] M15: Binary parsing (PE/ELF forensics)
- [ ] M16: Forensics & recovery

### Phase F: Release
- [ ] M19: 1.0 release

See [PROJECT_ROADMAP.md](PROJECT_ROADMAP.md) for detailed milestones.

## Performance Targets

| Component | Target Metric |
|-----------|---------------|
| **Concurrency** | |
| Coroutine switch | <20ns |
| SPSC queue | >10M ops/sec |
| **Memory** | |
| Memory allocators | 10-50% faster than malloc |
| **Hashing** | |
| Hash functions (xxHash64) | >10 GB/s |
| Swiss tables | 2x faster than std/tables |
| **Compression** | |
| LZ4 compression | ~500 MB/s compress, ~2 GB/s decompress |
| Zstd compression | 100-700 MB/s (level-dependent) |
| **Parsing** | |
| simdjson parsing | 2-4 GB/s |
| HTTP parsing (picohttpparser) | ~1 GB/s headers |
| **Cryptography** | |
| ChaCha20 encryption | ~1 GB/s |
| Ed25519 sign/verify | ~50K ops/sec |
| BLAKE2b hash | ~1 GB/s |
| **Random** | |
| PCG32 RNG | ~1 ns/number |
| **Numeric** | |
| Fixed-point Q16.16 add/sub | ~0.3 ns (same as int) |
| Fixed-point Q16.16 mul/div | ~1-2 ns |
| **SIMD** | |
| SSE2 vector add (4x float32) | 4x speedup vs scalar |
| AVX2 vector add (8x float32) | 8x speedup vs scalar |
| **Time** | |
| RDTSC resolution | ~0.3 ns (1 CPU cycle) |
| CLOCK_MONOTONIC | ~20 ns (syscall overhead) |
| **I/O** | |
| Raw syscall overhead | ~50 ns |
| Memory-mapped file access | ~10 ns |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development guidelines.

## License

MIT License - see [LICENSE](LICENSE) file.

## Acknowledgments

Inspired by:
- Go's concurrency model
- Rust's ownership system
- C++'s performance primitives
- Nim's compile-time power