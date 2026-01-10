# Arsenal

**Universal Low-Level Nim Library for High-Performance Systems Programming**

[![CI](https://github.com/yourusername/arsenal/workflows/CI/badge.svg)](https://github.com/yourusername/arsenal/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Arsenal provides atomic, composable, swappable primitives that achieve **performance parity with hand-tuned C/C++** while maintaining safety and ergonomics.

## Philosophy

**Both ERGONOMIC and FAST**: Freely using Nim features like compile-time `when` clauses, `asm` emit, and platform-specific implementations selected at compile-time based on detected hardware capabilities.

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

# Detect CPU capabilities
let cpu = detectCpuFeatures()
if cpu.hasAVX2:
  echo "AVX2 available!"

# Optimization strategies
setStrategy(Throughput)  # Optimize for max ops/sec

# Use in performance-critical sections
withStrategy(Latency):
  criticalOperation()
```

## Roadmap Overview

### Phase A: Foundation ✅
- [x] M0: Project setup
- [x] M1: Core infrastructure (CPU detection, strategies)

### Phase B: Concurrency (Priority)
- [ ] M2: Coroutines (libaco/minicoro bindings)
- [ ] M3: Lock-free primitives (atomics, spinlocks, queues)
- [ ] M4: Channel system (CSP-style communication)
- [ ] M5: I/O integration (epoll/kqueue/IOCP)
- [ ] M6: Go-style DSL (`go`, `select`)
- [ ] M7: Echo server (integration test)

### Phase C: Performance
- [ ] M8: Allocators (bump, pool, mimalloc)
- [ ] M9: Hashing & data structures (xxHash, Swiss tables)
- [ ] M10: Compression (LZ4, Zstd)
- [ ] M11: Parsing (simdjson, HTTP)

### Phase D: Advanced Domains
- [ ] M12: Linear algebra (SIMD GEMM)
- [ ] M13: AI/ML primitives
- [ ] M14: Media processing (FFT, audio/video)
- [ ] M15: Binary parsing (PE/ELF forensics)
- [ ] M16: Forensics & recovery
- [ ] M17: Embedded/kernel support
- [ ] M18: Cryptography (ChaCha20, Ed25519)

### Phase E: Release
- [ ] M19: 1.0 release

See [PROJECT_ROADMAP.md](PROJECT_ROADMAP.md) for detailed milestones.

## Performance Targets

| Component | Target Metric |
|-----------|---------------|
| Coroutine switch | <20ns |
| SPSC queue | >10M ops/sec |
| Memory allocators | 10-50% faster than malloc |
| Hash functions | >10 GB/s |
| Swiss tables | 2x faster than std/tables |

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