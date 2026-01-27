# Arsenal

Systems programming for Nim. Arsenal bridges the gap between Nim's high-level features and low-level systems work, providing **ergonomic, fast abstractions** for concurrency, embedded development, audio processing, and performance-critical code.

## Philosophy

**Bridge the gap.** Nim is a high-level language, but systems programming requires low-level control. Arsenal provides:

- **Ergonomic Nim APIs** over low-level primitives (whether pure Nim or C bindings)
- **Performance-competitive** implementations using the right tool for each job
- **Idiomatic Nim** interfaces that feel natural and compile to fast code
- **Everything you need** to do systems programming without leaving Nim

**Implementation strategy:**
- Pure Nim where practical and fast (hash functions, lock-free queues, audio processing)
- C bindings where they're the right tool (coroutines need assembly, LZ4 is battle-tested)
- Always wrapped in **ergonomic, type-safe Nim abstractions**

**The key:** You write Nim code. Arsenal handles the low-level details, whether that's pure Nim implementations or efficient C binding wrappers.

## What Arsenal Provides

### Concurrency
- **Coroutines**: libaco (Linux/Mac), minicoro (Windows) with Go-style `go {}` syntax
- **Channels**: Unbuffered and buffered, with `select` statement
- **Lock-free queues**: SPSC (fast, cache-friendly), MPMC (Vyukov's algorithm)
- **Atomics & Spinlocks**: C++11-style memory ordering, ticket locks, RW locks

### Embedded Systems
- **No-libc runtime**: memcpy, memset, string operations, intToStr (pure Nim)
- **HAL**: GPIO, UART, MMIO, delays for STM32F4 and RP2040 (pure Nim)
- **Direct hardware access** without libc dependency

### Audio Processing
- **FFT/MDCT**: Radix-2 Cooley-Tukey FFT, IMDCT for MP3/AAC/Vorbis/Opus
- **Format conversion**: PCM (int8/16/24/32 ↔ float32/64), interleaving, dithering
- **Resampling**: Linear, sinc, polyphase (44.1k↔48k streaming)
- **Mixing**: Multi-track, panning, crossfading, normalization
- **Streaming**: Lock-free ring buffer for real-time audio

### Performance Primitives
- **Hash functions**: XXHash64 (8-10 GB/s), WyHash (15-18 GB/s) - pure Nim
- **Swiss table**: Google's dense hash map with SIMD control bytes
- **Allocators**: Bump allocator, pool allocator
- **Compression**: LZ4 bindings (~500 MB/s)

### Low-Level
- **Bit operations**: CLZ, CTZ, popcount, rotate with compiler intrinsics
- **SIMD**: SSE2, AVX2 (x86), NEON (ARM) wrappers
- **Fixed-point**: Q16.16, Q32.32 arithmetic
- **Raw sockets**: POSIX TCP/UDP primitives
- **Filesystem**: Direct syscall I/O, mmap, directory operations

### Math
- **BLAS**: Level 1/2/3 (dot, gemv, gemm) pure Nim

**All modules provide idiomatic Nim interfaces**, regardless of underlying implementation.

## Implemented Algorithms & Papers

Arsenal implements proven algorithms from academic research and industry:

**Concurrency:**
- **Vyukov's MPMC queue** - Lock-free multi-producer/multi-consumer (Dmitry Vyukov, 2011)
- **Go-style CSP** - Communicating Sequential Processes (Hoare, 1978)
- **libaco coroutines** - Fast asymmetric coroutine switching

**Data Structures:**
- **Swiss table** - Google's dense hash map with SIMD control bytes (Abseil, 2018)
- **Lock-free SPSC** - Cache-friendly single-producer/single-consumer queue

**Hashing:**
- **XXHash64** - Fast non-cryptographic hash (Yann Collet)
- **WyHash** - Fastest portable hash function (Wang Yi, 2019)

**Audio/DSP:**
- **Cooley-Tukey FFT** - Radix-2 decimation-in-time (1965)
- **MDCT/IMDCT** - Modified DCT for lossy codecs (Princen, Bradley, 1987)
- **Sinc interpolation** - Windowed sinc resampling (Shannon sampling theorem)
- **Polyphase filters** - Efficient sample rate conversion
- **TPDF dithering** - Triangular probability density function dithering

**Embedded:**
- **Memory-mapped I/O** - Direct hardware register access
- **No-libc runtime** - Freestanding C replacements

All implementations are documented with references and optimized for Nim.

## Installation

```bash
nimble install arsenal
```

Or add to your `.nimble` file:
```nim
requires "arsenal"
```

## Usage Examples

### Concurrency

Arsenal provides Go-style concurrency using coroutines and channels:

```nim
import arsenal/concurrency/[coroutines, channels, dsl]

# Create channels
var ch = newChannel[int](buffered = true, capacity = 10)

# Spawn coroutines with 'go' syntax
go:
  for i in 1..5:
    ch.send(i)
  ch.close()

go:
  while true:
    let val = ch.recv()
    if val.isNone:
      break
    echo "Received: ", val.get()

# Run scheduler
run()
```

**Pros:**
- Familiar syntax for Go developers
- Lightweight coroutines (<1KB stack)
- Works on x86_64 and ARM64

**Cons:**
- Not as mature as async/await
- Windows support via minicoro (slower than libaco)
- Requires manual scheduler management

### Audio Processing

Basic building blocks for audio applications:

```nim
import arsenal/media/audio/[format, resampling, mixing]

# Convert audio format
var pcmInt16 = readWavFile("input.wav")  # Your code
var pcmFloat = newSeq[float32](pcmInt16.len)
int16ToFloat32(pcmInt16, pcmFloat)

# Resample from 44.1kHz to 48kHz
var resampler = initResampler(
  inputRate = 44100,
  outputRate = 48000,
  quality = QualityMedium  # Good balance of speed/quality
)
let resampled = resampler.process(pcmFloat)

# Mix with another track and apply volume
var track2 = loadAudioTrack()  # Your code
var mixed = newSeq[float32](resampled.len)
mixWeighted(resampled, track2, mixed, 0.7'f32, 0.3'f32)
applyGainDb(mixed, -3.0)  # Reduce by 3dB

# Write output
writeWavFile("output.wav", mixed)  # Your code
```

**Pros:**
- Pure Nim implementations are easy to modify
- Covers common audio processing needs
- Good enough for prototyping and small projects

**Cons:**
- Resampling quality isn't as good as libsamplerate or SpeexDSP
- No SIMD optimizations yet (planned)
- FFT limited to power-of-2 sizes
- Missing video processing

### Embedded Systems

Write firmware without libc:

```nim
import arsenal/embedded/[hal, nolibc]

# STM32F4 GPIO blink
proc main() {.exportc: "main".} =
  # Configure GPIO
  let ledPin = PA5  # Arduino-compatible pin
  gpioSetMode(GPIOA, ledPin, GPIO_MODE_OUTPUT)

  # Blink loop
  while true:
    gpioWrite(GPIOA, ledPin, HIGH)
    delayMs(500)
    gpioWrite(GPIOA, ledPin, LOW)
    delayMs(500)

# Compile with:
# nim c -d:release -d:danger --os:any --cpu:arm \
#   --gcc.exe:arm-none-eabi-gcc --gcc.linkerexe:arm-none-eabi-gcc \
#   blink.nim
```

**Pros:**
- No libc dependency (smaller binaries)
- Works on STM32F4 and RP2040
- Direct hardware access

**Cons:**
- Limited to two MCU families
- No RTOS features yet
- Requires cross-compilation knowledge
- Documentation assumes you know embedded development

### Lock-Free Data Structures

SPSC queue for producer-consumer patterns:

```nim
import arsenal/concurrency/queues

# Single Producer, Single Consumer queue
var queue = SpscQueue[int].init(capacity = 1024)

# Producer thread
proc producer() =
  for i in 1..1000:
    while not queue.push(i):
      cpuRelax()  # Spin until space available

# Consumer thread
proc consumer() =
  while true:
    let val = queue.pop()
    if val.isSome:
      process(val.get())
    else:
      break
```

**Pros:**
- Lock-free (no mutex overhead)
- Fast for single producer/consumer (10M+ ops/sec)
- Simple API

**Cons:**
- Only SPSC (single producer/single consumer)
- MPMC queue is slower than expected
- Fixed size (can't grow)

### Hash Functions and Tables

Fast hashing for checksums and hash tables:

```nim
import arsenal/hashing/hashers/wyhash
import arsenal/datastructures/swiss_table

# Fast file checksum
proc checksumFile(path: string): uint64 =
  var hasher = initWyHash()
  var file = open(path)
  defer: file.close()

  var buffer: array[4096, byte]
  while true:
    let bytesRead = file.readBytes(buffer, 0, buffer.len)
    if bytesRead == 0:
      break
    hasher.update(buffer.toOpenArray(0, bytesRead - 1))

  result = hasher.finish()

# Swiss table (Google's dense hash table design)
var cache = SwissTable[string, JsonNode].init()
cache.insert("user:123", parseJson("""{"name": "Alice"}"""))

let user = cache.lookup("user:123")
if user.isSome:
  echo user.get()
```

**Pros:**
- WyHash is very fast (15-18 GB/s)
- Swiss table has good cache locality
- Incremental hashing for large data

**Cons:**
- Swiss table not as optimized as it could be
- No SIMD acceleration yet
- Hash functions not cryptographically secure

## Module Status

| Module | Status | Implementation | Notes |
|--------|--------|----------------|-------|
| **Concurrency** |
| Coroutines, channels | ✅ Works | C binding (libaco/minicoro) | Nim interface, C context switching |
| Lock-free SPSC queue | ✅ Works | Pure Nim | Fast, 10M+ ops/sec |
| Lock-free MPMC queue | ⚠️ Slower | Pure Nim | Room for optimization |
| **Embedded** |
| No-libc runtime | ✅ Works | Pure Nim | memcpy, memset, string ops |
| HAL (STM32F4, RP2040) | ✅ Works | Pure Nim | Direct hardware access |
| **Audio** |
| FFT/MDCT | ✅ Works | Pure Nim | Power-of-2, can add SIMD |
| Format conversion | ✅ Works | Pure Nim | Fast enough for real-time |
| Resampling | ⚠️ Adequate | Pure Nim | Can optimize further |
| Ring buffer | ✅ Works | Pure Nim | Lock-free SPSC |
| **Performance** |
| Hash functions | ✅ Fast | Pure Nim | 15-18 GB/s, competitive with C |
| Swiss table | ⚠️ Ok | Pure Nim | Good, can optimize more |
| Custom allocators | ✅ Works | Pure Nim | Bump, Pool |
| LZ4 compression | ✅ Works | C binding | Industry standard |
| **Low-Level** |
| Bit operations | ✅ Fast | Pure Nim | Compiler intrinsics |
| SIMD wrappers | ✅ Works | Pure Nim | SSE2, AVX2, NEON |
| Fixed-point math | ✅ Fast | Pure Nim | Same speed as integers |
| Raw sockets | ✅ Works | Pure Nim | POSIX wrappers |
| **Math** |
| BLAS basics | ⚠️ Slow | Pure Nim | Learning tool, needs optimization |

Legend:
- ✅ Works/Fast: Tested, functional, performance competitive
- ⚠️ Notes: Works but room for improvement
- Pure Nim: No C dependencies
- C binding: Uses established C library

## When to Use Arsenal

**Use Arsenal when you want to:**
- Do systems programming in Nim with ergonomic, fast APIs
- Access low-level features without leaving Nim's type system
- Build embedded systems, audio apps, or performance-critical code
- Use C-level performance with Nim-level ergonomics
- Prototype systems-level code quickly
- Learn systems programming concepts with clear implementations

**Arsenal provides:**
- The best of both worlds: fast C bindings where needed, pure Nim where practical
- Consistent, idiomatic Nim interfaces across all modules
- Performance competitive with manual C code
- Clear implementations you can understand and modify

**Consider alternatives when:**
- You need features beyond our scope (full video codecs, complete cryptography)
- You need battle-tested production code in specific domains (we're newer)
- You need mature ecosystems with extensive tooling

## Performance

Arsenal focuses on **ergonomic Nim APIs with competitive performance**, using the right implementation strategy for each problem:

**Fast (competitive with C):**
- Hash functions: WyHash 15-18 GB/s, XXHash64 8-10 GB/s (pure Nim, optimized algorithms)
- Lock-free SPSC queue: 10M+ ops/sec (pure Nim, cache-friendly)
- Coroutine switches: ~10-20ns (libaco/minicoro with Nim wrapper)
- LZ4: ~500 MB/s compress, ~2 GB/s decompress (C binding, battle-tested)
- Bit operations: Compiler intrinsics (pure Nim wrappers)
- Fixed-point math: Integer speed (pure Nim)

**Good for real-time use:**
- Audio processing (FFT, MDCT, resampling): Pure Nim, adequate quality
- Format conversion: Fast enough for real-time
- Swiss table: Good cache locality
- Embedded HAL: Direct hardware access

**Work in progress:**
- BLAS: Functional, suitable for N < 100 (pure Nim, can optimize)
- MPMC queue: Works, has contention under heavy load

**Philosophy:** We use C bindings when they're clearly superior (libaco, LZ4), and pure Nim when we can match or beat C performance. All code is wrapped in idiomatic Nim APIs.

Always benchmark for your use case. Performance is hardware-dependent.

## Documentation

Each module has inline documentation. View with `nim doc`:

```bash
nim doc src/arsenal/concurrency/channels.nim
```

Examples in `examples/` demonstrate practical usage. Tests in `tests/` show detailed API usage.

## Building

```bash
# Development build
nimble build

# Release build (faster)
nim c -d:release src/arsenal.nim

# Run tests
nimble test

# Run benchmarks
nim c -d:release -r benchmarks/bench_hash_functions.nim
```

## Platform Support

**Tested:**
- Linux (x86_64, ARM64)
- macOS (x86_64, ARM64)
- Windows (x86_64) - partial (coroutines via minicoro)

**Embedded:**
- STM32F4 (Cortex-M4)
- RP2040 (Cortex-M0+)

## Complementary Libraries

Arsenal provides systems-level building blocks. For complete solutions, consider:

**Concurrency alternatives:**
- `std/asyncdispatch`, `chronos` - Async/await for I/O-heavy workloads
- `malebolgia` - Structured concurrency

**Audio ecosystem:**
- libsamplerate - Production-grade resampling (Arsenal: prototyping/learning)
- libsndfile - Audio file I/O (Arsenal: format conversion)
- PortAudio - Cross-platform audio I/O (Arsenal: processing primitives)

**Math/ML:**
- Intel MKL, OpenBLAS - Heavily optimized BLAS for large matrices
- Arsenal's BLAS: Learning tool and small matrices (N < 100)

**Embedded:**
- Zephyr, FreeRTOS - Full RTOS (Arsenal: minimal HAL for bare metal)

**Arsenal's role:** Provide the building blocks and bridges between Nim and low-level systems. For complete applications, combine with ecosystem libraries.

## Contributing

Arsenal's mission is proving that **pure Nim can match C performance** for systems programming. Contributions welcome.

**High-impact areas:**
- SIMD optimizations (audio, math, hashing - stay in pure Nim with intrinsics)
- Algorithm improvements (better MPMC queue, FFT optimizations)
- Benchmarking and profiling (find bottlenecks, compare with C)
- More embedded MCU support (expand HAL to more chips)
- Documentation and examples

**Philosophy for contributions:**
- Pure Nim first (avoid C bindings unless truly necessary)
- Performance matters (but clarity shouldn't be sacrificed unnecessarily)
- Benchmark everything (show Nim can compete)
- Document trade-offs (when C bindings are justified)

See `CONTRIBUTING.md` for guidelines.

## License

MIT License - see `LICENSE` file.

## Vision

Arsenal exists to demonstrate that **Nim can be as fast as C** for systems programming, without requiring developers to leave their language.

We're building:
- A pure Nim alternative to dropping to C
- Performance-competitive implementations for common tasks
- A proving ground that Nim can do low-level work at C speeds
- A resource for learning systems programming in Nim

**Current status:** Already competitive in many areas (hashing, queues, embedded). Ongoing work to close gaps in others (SIMD audio, optimized BLAS). The goal is to never need C bindings for performance.

## Credits

Arsenal builds on excellent work from the Nim ecosystem:

**Integrated libraries:**
- **libaco/minicoro** - Fast coroutine context switching
- **LZ4** - Industry-standard compression

**Recommended companions:**
- **nimsimd** (https://github.com/guzba/nimsimd) - Comprehensive SIMD (SSE, AVX, FMA, BMI) - More complete than Arsenal's basic wrappers
- **nimcrypto** (https://github.com/cheatfate/nimcrypto) - Pure Nim cryptography (SHA, BLAKE2, AES) - For when you need crypto
- **nim-libsodium** (https://github.com/FedericoCeratto/nim-libsodium) - Battle-tested libsodium bindings - Production crypto
- **nim-intops** (https://github.com/vacp2p/nim-intops) - Overflow-safe integer ops for bignum/crypto

**Algorithms from:**
- Go's concurrency model (channels, select)
- Google's Swiss table design (dense hash maps)
- Academic papers (Cooley-Tukey FFT, MDCT, Vyukov's MPMC queue)
- Nim's philosophy: fast, expressive, compile-time power

**Note on SIMD:** Arsenal provides basic SSE2/AVX2/NEON wrappers. For production use, consider **nimsimd** which offers comprehensive coverage (SSE through AVX2, FMA, BMI1/2) and is battle-tested in Pixie, Crunchy, and Noisy.

**Note on Crypto:** Arsenal has documented stubs. For actual cryptography, use **nimcrypto** (pure Nim, educational) or **nim-libsodium** (production-grade). Arsenal focuses on systems programming primitives, not cryptography.

Thanks to the Nim community for feedback and contributions. Arsenal stands on the shoulders of these excellent libraries.
