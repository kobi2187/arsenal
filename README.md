# Arsenal

A collection of high-performance systems programming libraries written in **pure Nim**. Arsenal aims to provide the fastest possible implementations without requiring C bindings, keeping you in Nim-land for low-level work.

## Philosophy

**Stay in Nim.** Arsenal's goal is to provide performance-competitive pure Nim implementations for systems programming tasks, so you don't have to drop to C or C bindings.

**Where we are:**
- Hash functions (XXHash64, WyHash) - Pure Nim, competitive with C (15-18 GB/s)
- Lock-free queues (SPSC) - Pure Nim, fast (10M+ ops/sec)
- Audio processing (FFT, MDCT, resampling) - Pure Nim, adequate for many uses
- Embedded HAL - Pure Nim, direct hardware access without libc
- Bit operations - Pure Nim wrappers over compiler intrinsics

**Where we use C bindings** (and why):
- Coroutines: libaco/minicoro (context switching requires assembly)
- LZ4: Industry-standard compression (complex, well-optimized C code)

**The goal:** Expand pure Nim implementations and optimize them to match or beat C alternatives, so Nim developers can stay in their language of choice.

## What Arsenal Provides

- **Concurrency**: Coroutines, channels, lock-free queues, Go-style syntax
- **Embedded**: No-libc runtime, HAL for STM32F4/RP2040, direct hardware access
- **Audio**: FFT, MDCT, format conversion, resampling, mixing - all pure Nim
- **Performance**: Custom allocators, hash functions, Swiss table - all pure Nim
- **Low-level**: Raw sockets, syscalls, SIMD wrappers, bit operations - all pure Nim

**Current status:** Most modules are pure Nim. Performance is competitive for many tasks, with room for optimization (SIMD, algorithmic improvements). Some areas are works in progress.

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
- Stay in pure Nim without C bindings
- Understand and modify low-level implementations
- Build embedded systems without libc
- Prototype systems-level code quickly
- Have full control over your dependency stack
- Learn systems programming concepts in Nim

**Consider alternatives when:**
- You need absolute maximum performance right now (though we're working on it)
- You need battle-tested production code (we're newer, less field-tested)
- You need features beyond our scope (full video codecs, cryptography, complete BLAS)

**The tradeoff:** Arsenal prioritizes staying in Nim and code clarity over cutting-edge optimization. But we're getting faster - benchmarks and PRs welcome.

## Performance: Pure Nim vs C

Arsenal's pure Nim implementations are competitive with C in many areas:

**Pure Nim, competitive with C:**
- Hash functions: WyHash 15-18 GB/s, XXHash64 8-10 GB/s (close to C implementations)
- Lock-free SPSC queue: 10M+ ops/sec (cache-friendly design)
- Bit operations: Uses compiler intrinsics, same speed as C
- Coroutine switches: ~10-20ns (via libaco, but interface is pure Nim)
- Fixed-point math: Same speed as integer operations

**Pure Nim, good for many uses:**
- Audio resampling: Adequate quality, room for SIMD optimization
- FFT/MDCT: Correct, works well, could benefit from SIMD
- Swiss table: Good cache locality, could be more optimized
- Audio format conversion: Fast enough for real-time

**Pure Nim, work in progress:**
- BLAS: Functional but slow, good for learning (N < 100)
- MPMC queue: Works but has contention issues

**The opportunity:** Most of our "adequate" code can be sped up with SIMD, better algorithms, and profiling. Contributions welcome. The goal is matching or beating C while staying in pure Nim.

Always benchmark for your use case. Performance is hardware-dependent and continuously improving.

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

## If You Need C-Level Performance Today

Arsenal aims for competitive performance in pure Nim, but we're honest: some C libraries are currently faster. If maximum performance is critical right now:

**Concurrency:**
- `std/asyncdispatch`, `chronos` - Mature Nim async/await
- `malebolgia` - Structured concurrency (pure Nim)

**Audio:**
- libsamplerate (C binding) - Higher quality resampling
- libsndfile (C binding) - Audio file I/O
- Arsenal's pure Nim implementations work well for prototyping

**Math:**
- Intel MKL, OpenBLAS (C bindings) - Heavily optimized BLAS
- Arsenal's pure Nim BLAS is fine for N < 100, learning

**Embedded:**
- Zephyr, FreeRTOS (C) - Full RTOS with many features
- Arsenal's HAL is minimal but pure Nim

**Our position:** We're building toward pure Nim implementations that match C performance. We're not there yet everywhere, but for many tasks (hashing, queues, audio processing), Arsenal's pure Nim code is fast enough and keeps you in Nim.

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

Built on ideas from:
- Go's concurrency model (channels, select)
- Google's Swiss table design (dense hash maps)
- Various DSP textbooks (audio algorithms)
- Nim's philosophy: fast, expressive, compile-time power

Thanks to the Nim community for feedback and contributions. Special thanks to developers proving that pure Nim can match C performance.
