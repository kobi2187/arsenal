# Arsenal

A collection of low-level systems programming libraries for Nim. Arsenal provides building blocks for concurrency, embedded development, audio processing, and performance-critical code.

## What is this?

Arsenal is a library collection focused on areas where Nim's standard library is minimal or absent. It's written in pure Nim where practical, with C bindings where established libraries exist (LZ4, libaco).

**What it provides:**
- Concurrency primitives (coroutines, channels, lock-free queues)
- Embedded systems support (no-libc runtime, HAL for STM32F4/RP2040)
- Audio processing basics (FFT, MDCT, format conversion, resampling)
- Performance utilities (custom allocators, hash functions, bit operations)
- Low-level primitives (raw sockets, syscall wrappers, SIMD)

**What it's not:**
- Not a replacement for Nim's standard library (we use and extend it)
- Not a comprehensive audio/video codec library (provides building blocks)
- Not production-hardened (works, but limited real-world testing)
- Not optimized to the max (pure Nim implementations prioritize clarity)

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

| Module | Status | Notes |
|--------|--------|-------|
| **Concurrency** |
| Coroutines, channels | ✅ Works | libaco (Linux/Mac), minicoro (Windows) |
| Lock-free SPSC queue | ✅ Works | Good performance |
| Lock-free MPMC queue | ⚠️ Slower than expected | Vyukov algorithm, room for improvement |
| **Embedded** |
| No-libc runtime | ✅ Works | memcpy, memset, basic string ops |
| HAL (STM32F4, RP2040) | ✅ Works | GPIO, UART, basic peripherals |
| **Audio** |
| FFT/MDCT | ✅ Works | Power-of-2 sizes only |
| Format conversion | ✅ Works | Common PCM formats |
| Resampling | ⚠️ Adequate | Quality ok, not best-in-class |
| Ring buffer | ✅ Works | Lock-free SPSC |
| **Performance** |
| Hash functions | ✅ Works | XXHash64, WyHash |
| Swiss table | ⚠️ Ok | Functional, not fully optimized |
| Custom allocators | ✅ Works | Bump, Pool |
| **Low-Level** |
| Bit operations | ✅ Works | CLZ, CTZ, popcount with intrinsics |
| SIMD wrappers | ✅ Works | SSE2, AVX2, NEON basics |
| Fixed-point math | ✅ Works | Q16.16, Q32.32 |
| Raw sockets | ✅ Works | POSIX wrappers |
| **Math** |
| BLAS basics | ⚠️ Slow | Pure Nim, use for learning only |

Legend:
- ✅ Works: Tested and functional
- ⚠️ Notes: Works but has caveats
- 📝 Stub: Interface defined, implementation incomplete

## When to Use Arsenal

**Good for:**
- Learning systems programming in Nim
- Prototyping audio applications
- Embedded firmware where libc is unavailable
- Projects needing Go-style concurrency
- When you want to understand implementations (pure Nim code)

**Not good for:**
- Production audio/video apps (use established libraries)
- High-performance linear algebra (use BLAS/LAPACK bindings)
- Cryptography (use libsodium or OpenSSL)
- When you need maximum performance (our code prioritizes clarity)

## Performance Notes

**Where we're fast:**
- Hash functions (near C speed due to simple algorithms)
- Lock-free SPSC queue (cache-friendly)
- Bit operations (compiler intrinsics)
- Coroutine switches (~10-20ns)

**Where we're adequate:**
- Audio resampling (usable, not exceptional)
- Swiss table lookups (good, not great)
- Fixed-point math (close to integer speed)

**Where we're slow:**
- BLAS (pure Nim, use for N < 100 only)
- MPMC queue (contention issues)
- FFT (no SIMD, plan-once overhead)

Always benchmark for your use case. Performance claims are approximate and hardware-dependent.

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

## Alternatives

Before using Arsenal, consider these alternatives:

**For concurrency:**
- `std/asyncdispatch`, `chronos` - Mature async/await (probably better)
- `malebolgia` - Structured concurrency

**For audio:**
- libsamplerate - Better resampling
- libsndfile - Audio I/O
- PortAudio - Cross-platform audio

**For performance:**
- Intel MKL, OpenBLAS - Fast BLAS
- Google's Abseil - C++ containers
- mimalloc - Fast allocator

**For embedded:**
- Zephyr - Full RTOS
- FreeRTOS - Industry standard

Arsenal is useful when you want pure Nim code, need to understand implementations, or have specific requirements not met by existing libraries.

## Contributing

Contributions welcome. See `CONTRIBUTING.md` for guidelines.

Focus areas:
- SIMD optimizations for audio/math
- More embedded MCU support
- Better MPMC queue implementation
- Documentation and examples

## License

MIT License - see `LICENSE` file.

## Credits

Built on ideas from:
- Go's concurrency model
- Google's Swiss table design
- libaco coroutine library
- Various DSP textbooks

Thanks to the Nim community for feedback and contributions.
