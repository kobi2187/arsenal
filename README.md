# Arsenal

A pure Nim systems programming library for building high-performance applications. Arsenal provides low-level primitives with C-competitive performance while maintaining Nim's safety and ergonomics.

## What is Arsenal?

Arsenal is a collection of systems programming modules covering:

- **Async I/O** - Event loop with epoll/kqueue/IOCP backends and coroutine-based async sockets
- **Concurrency** - Coroutines (libaco/minicoro), lock-free queues (MPMC, SPSC), Go-style channels
- **Hashing** - WyHash (15-18 GB/s), XXHash64 for fast non-cryptographic hashing
- **Binary Parsing** - PE (Windows) and Mach-O (macOS) format parsers
- **Audio/DSP** - FFT, MDCT/IMDCT, resampling, ring buffers for real-time audio
- **Collections** - Roaring bitmaps, Swiss tables, efficient data structures
- **Embedded** - No-libc runtime, HAL for STM32F4 and RP2040
- **Compression** - LZ4 and Zstandard bindings

All modules compile cross-platform with stubs for unavailable features, ensuring zero build failures.

## Quick Setup

### Installation

```bash
nimble install arsenal
```

Or add to your `.nimble` file:
```nim
requires "arsenal"
```

### Dependencies (optional)

For compression support:
```bash
# Ubuntu/Debian
sudo apt-get install liblz4-dev libzstd-dev

# macOS
brew install lz4 zstd
```

## Usage Patterns

### Async I/O with Coroutines

Arsenal provides coroutine-based async I/O that integrates with an event loop:

```nim
import arsenal/io/eventloop
import arsenal/io/socket
import arsenal/concurrency/scheduler

# Create event loop and socket
let loop = getEventLoop()
let sock = newAsyncSocket(loop)

# In a coroutine context:
proc handleConnection() =
  sock.connect("example.com", Port(80))
  discard sock.write("GET / HTTP/1.0\r\n\r\n")

  var buffer: array[1024, byte]
  let bytesRead = sock.read(buffer)
  echo "Received: ", bytesRead, " bytes"
  sock.close()

# Spawn and run
let coro = spawn(handleConnection)
loop.run()
```

### Fast Hashing

WyHash provides 15-18 GB/s hashing for checksums and hash tables:

```nim
import arsenal/hashing/hasher

# One-shot hash
var h = initWyHash()
h.update(myData)
let hash = h.finish()

# Streaming hash for large files
var hasher = initWyHash()
for chunk in file.chunks(4096):
  hasher.update(chunk)
echo "Hash: ", hasher.finish().toHex
```

### Binary Format Parsing

Parse PE and Mach-O binaries on any platform:

```nim
import arsenal/binary/formats/pe

let data = readFile("kernel32.dll")
let pe = parsePE(data)

# List imported DLLs and functions
for dll in pe.imports:
  echo "DLL: ", dll.name
  for fn in dll.functions:
    echo "  - ", fn.name

# List exports
for exp in pe.exports:
  echo "Export: ", exp.name, " (ordinal ", exp.ordinal, ")"
```

### Coroutines

Lightweight cooperative threading with ~10-50ns context switches:

```nim
import arsenal/concurrency/coroutines/coroutine
import arsenal/concurrency/scheduler

# Create coroutines
let worker = newCoroutine(proc() =
  echo "Working..."
  coroYield()  # Suspend execution
  echo "Resumed!"
)

worker.resume()  # Prints "Working..."
worker.resume()  # Prints "Resumed!"

# Or use the scheduler
let task = spawn(proc() =
  for i in 1..3:
    echo "Task iteration ", i
    coroYield()
)
runAll()
```

### Lock-Free Data Structures

```nim
import arsenal/concurrency/channels

# Go-style channels
var ch = newChannel[int](bufferSize = 10)
ch.send(42)
let value = ch.recv()

# MPMC queue (multi-producer, multi-consumer)
import arsenal/concurrency/mpmc
var queue = newMpmcQueue[string](capacity = 1024)
queue.push("hello")
let msg = queue.pop()
```

### Audio/DSP Processing

```nim
import arsenal/media/dsp/fft
import arsenal/media/dsp/mdct

# FFT for spectrum analysis
var fft = newFFT(1024)
let spectrum = fft.forward(audioSamples)

# MDCT for audio codec work (MP3, AAC, Vorbis, Opus)
var mdct = newMDCT(512)
let coeffs = mdct.transform(windowedSamples)
```

### Embedded Systems

No-libc runtime for bare metal development:

```nim
import arsenal/embedded/hal

# STM32F4 GPIO blink
proc main() {.exportc.} =
  gpioSetMode(GPIOA, PA5, GPIO_MODE_OUTPUT)
  while true:
    gpioWrite(GPIOA, PA5, HIGH)
    delayMs(500)
    gpioWrite(GPIOA, PA5, LOW)
    delayMs(500)

# RP2040 UART
var uart = UART.init(id = 0, baudRate = 115200)
uart.write("Hello from RP2040!\n")
```

### Roaring Bitmaps

Compressed integer sets with fast operations:

```nim
import arsenal/collections/roaring

var bitmap = newRoaringBitmap()
bitmap.add(1)
bitmap.add(100)
bitmap.add(1_000_000)

var other = newRoaringBitmap()
other.add(100)
other.add(200)

let intersection = bitmap and other  # {100}
let union = bitmap or other          # {1, 100, 200, 1000000}
echo "Cardinality: ", bitmap.cardinality()
```

## Module Overview

| Category | Modules | Status |
|----------|---------|--------|
| **I/O** | Event loop, async sockets, epoll/kqueue/IOCP | Production |
| **Concurrency** | Coroutines, scheduler, channels, MPMC/SPSC queues | Production |
| **Hashing** | WyHash, XXHash64 | Production |
| **Binary** | PE parser, Mach-O parser | Production |
| **Audio/DSP** | FFT, MDCT, resampling, ring buffer | Production |
| **Collections** | Roaring bitmaps, Swiss tables | Production |
| **Embedded** | STM32F4 HAL, RP2040 HAL, no-libc runtime | Production |
| **Compression** | LZ4, Zstandard (C bindings) | Production |
| **RTOS Scheduler** | Multi-arch context switching | Pending |

## Performance

| Operation | Throughput | Notes |
|-----------|------------|-------|
| WyHash | 15-18 GB/s | Pure Nim, 64-byte blocks |
| LZ4 compress | ~500 MB/s | C binding |
| LZ4 decompress | ~2 GB/s | C binding |
| Coroutine switch | ~10-50 ns | libaco/minicoro backend |
| FFT (N=1024) | ~10-50 us | Radix-2 Cooley-Tukey |

## Platform Support

| Platform | I/O Backend | Status |
|----------|-------------|--------|
| Linux | epoll | Full support |
| macOS | kqueue | Full support |
| Windows | IOCP | Full support |
| STM32F4 | Bare metal | HAL available |
| RP2040 | Bare metal | HAL available |

All modules compile on all platforms. Unavailable backends return appropriate error codes.

## Building

```bash
# Development
nimble build

# Release (optimized)
nim c -d:release src/arsenal.nim

# Run tests
nimble test
```

## Documentation

- `OPTIMIZATION_AND_STUBS_GUIDE.md` - Optimization patterns and stub system
- `PHASE_1_COMPLETION_SUMMARY.md` - I/O architecture details
- `PHASE_2_ESCALATION_REQUIREMENTS.md` - RTOS scheduler specifications

Generate API docs:
```bash
nim doc src/arsenal/hashing/hasher.nim
nim doc src/arsenal/io/socket.nim
```

## Contributing

Priority areas:
1. **RTOS Scheduler** - Context switching assembly for x86_64, ARM64, RISC-V
2. **SIMD Integration** - nimsimd integration when Nim 2.0+ available
3. **MCU Expansion** - Additional HAL targets (STM32H7, nRF52, etc.)

## License

MIT License

## Acknowledgments

- WyHash by Wang Yi
- Roaring Bitmaps by Chambi et al.
- libaco/minicoro for coroutine backends
- Cooley-Tukey FFT algorithm
