# Arsenal Examples

Comprehensive examples demonstrating Arsenal's capabilities across different domains.

## Quick Start

```bash
# Compile and run an example
nim c -r examples/swiss_table_cache.nim

# For embedded examples (requires cross-compiler)
nim c --cpu:arm --os:standalone -d:stm32f4 examples/embedded_blinky.nim
```

---

## Examples by Domain

### 🔌 Embedded Systems

Arsenal enables bare-metal programming with Nim, bringing modern language features to microcontrollers.

#### `embedded_blinky.nim` - GPIO LED Control

**Description**: Classic "blinky" LED example demonstrating GPIO control on bare-metal hardware.

**Features**:
- Basic GPIO operations (write, toggle)
- Multiple blink patterns (simple, SOS morse code)
- Precise timing with software delays
- Platform support: STM32F4, RP2040

**Hardware Requirements**:
- STM32F4 Discovery board OR Raspberry Pi Pico (RP2040)
- LED + 330Ω resistor (or use built-in LED)

**Compilation**:
```bash
# For STM32F4 (ARM Cortex-M4)
nim c --cpu:arm --os:standalone --gc:none --noMain \
  -d:stm32f4 -d:bare_metal --noLinking \
  --passC:"-mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16" \
  examples/embedded_blinky.nim

# Link with your linker script
arm-none-eabi-gcc -o firmware.elf embedded_blinky.o \
  -T stm32f4.ld -nostdlib -lgcc

# Flash to device
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
  -c "program firmware.elf verify reset exit"
```

**Key Concepts**:
- Volatile memory-mapped I/O
- GPIO configuration and control
- Freestanding (no OS) programming
- Startup code requirements

**Performance**: GPIO toggle in 1-2 CPU cycles (~10-50 ns @ 16-72 MHz)

---

#### `embedded_uart_echo.nim` - Serial Communication

**Description**: Serial echo server with interactive command shell for embedded systems.

**Features**:
- UART initialization and configuration (115200 baud)
- Character echo and line buffering
- Command processing shell (LED control, status reporting)
- Helper functions for printing integers, hex values
- Transmit and receive with polling

**Hardware Requirements**:
- STM32F4 board
- USB-Serial adapter (FTDI, CP2102, etc.)
- Terminal program (screen, minicom, PuTTY)

**Wiring**:
```
USB-Serial    STM32F4
----------    --------
TX       -->  PA10 (USART1_RX)
RX       <--  PA9  (USART1_TX)
GND      ---  GND
```

**Terminal Setup**:
```bash
# Linux/macOS
screen /dev/ttyUSB0 115200

# Or with minicom
minicom -D /dev/ttyUSB0 -b 115200
```

**Commands** (in command shell version):
- `help` - Show available commands
- `led on` - Turn LED on
- `led off` - Turn LED off
- `led toggle` - Toggle LED state
- `status` - Show system status

**Key Concepts**:
- UART peripheral configuration
- Baud rate calculation
- No-libc string operations (strlen, strcmp)
- Integer to string conversion
- Command parsing

**Performance**: 115200 bps = ~11,520 bytes/sec (~87 μs per character)

---

### ⚡ High-Performance Computing

Arsenal provides best-in-class performance for data-intensive applications.

#### `hash_file_checksum.nim` - File Integrity Verification

**Description**: Compute checksums of files using high-performance hash functions (XXHash64, WyHash).

**Features**:
- Incremental hashing (handles files larger than RAM)
- Progress reporting for large files
- Multiple hash algorithms (XXHash64, WyHash)
- Benchmark mode for comparing algorithms
- Verification mode for integrity checking
- Human-readable output (GB/s throughput, formatted sizes)

**Usage**:
```bash
# Compute checksums
nim c -r examples/hash_file_checksum.nim video.mp4

# Output:
# XXHash64: 0x1234567890ABCDEF  (1.2s, 8.3 GB/s)
# WyHash:   0xFEDCBA0987654321  (0.7s, 14.2 GB/s)

# Benchmark mode
nim c -r examples/hash_file_checksum.nim --bench largefile.bin

# Verify file integrity
nim c -r examples/hash_file_checksum.nim --verify download.iso \
  0x1234567890ABCDEF wyhash
```

**Use Cases**:
1. **File Integrity**: Verify downloads, detect corruption
2. **Deduplication**: Find duplicate files by hash
3. **Backup Verification**: Check backup integrity
4. **Data Pipelines**: Checksum verification in ETL workflows

**Performance**:
- XXHash64: 8-10 GB/s (single core)
- WyHash: 15-18 GB/s (single core)
- Memory usage: ~64 KB (incremental hashing)

**Key Concepts**:
- Incremental hashing for large files
- Streaming computation
- I/O vs CPU bottlenecks
- Progress reporting

**Comparison**:
| Algorithm | Speed | Use Case |
|-----------|-------|----------|
| WyHash | 15-18 GB/s | Fastest non-crypto, best for checksums |
| XXHash64 | 8-10 GB/s | Widely adopted, excellent distribution |
| MD5 | ~300 MB/s | Legacy, broken for security |
| SHA-256 | ~200 MB/s | Cryptographic, slow but secure |

---

#### `swiss_table_cache.nim` - LRU Cache Implementation

**Description**: High-performance LRU (Least Recently Used) cache using Swiss Table.

**Features**:
- Fast O(1) lookups with Swiss Table
- LRU eviction policy (removes least recently used)
- Cache hit/miss statistics
- Four practical examples:
  1. Simple string cache
  2. Web API response caching
  3. Computation memoization (Fibonacci)
  4. Database query caching

**Usage**:
```bash
nim c -r examples/swiss_table_cache.nim

# Output shows:
# - Cache hit rates
# - Performance improvements
# - Speedup factors (10-1000x typical)
```

**Example Output**:
```
Example 2: Web API Response Cache
==================================
Making API requests with caching...
  GET /users -> 200 (cached: false)
  GET /posts -> 200 (cached: false)
  GET /comments -> 200 (cached: false)
  GET /users -> 200 (cached: true)    # Cache hit!
  GET /posts -> 200 (cached: true)    # Cache hit!
  GET /users -> 200 (cached: true)    # Cache hit!

Total time: 300.0 ms
Without cache: ~600 ms
Speedup: 2.0x

Cache Statistics:
  Entries:   3 / 100
  Hits:      3
  Misses:    3
  Hit Rate:  50.0%
  Evictions: 0
```

**Use Cases**:
1. **Web APIs**: Cache HTTP responses (reduce latency by 10-100x)
2. **Database Queries**: Cache query results (save 10-100ms per hit)
3. **Computations**: Memoization (save milliseconds to hours)
4. **File Metadata**: Cache stat() results
5. **DNS Resolution**: Cache hostname lookups
6. **Configuration**: Cache parsed config files

**Performance**:
- Lookup: 10-30 million ops/sec (10-30 ns per lookup)
- Insert: 5-10 million ops/sec
- Memory overhead: ~17 bytes per entry + key + value size

**Key Concepts**:
- LRU eviction policy
- Cache hit rate optimization
- Swiss Table internals
- When to use caching

**Advanced Patterns** (shown in comments):
- **TTL Cache**: Time-to-live expiration
- **Write-Through Cache**: Update cache and backing store
- **Multi-Level Cache**: L1 (small/fast) + L2 (large/slower)

**When to Cache**:
- ✅ Expensive operations (I/O, network, computation)
- ✅ Hit rate > 30% expected
- ✅ Data doesn't change frequently
- ❌ Data changes constantly
- ❌ Low hit rate (< 30%)
- ❌ Memory constrained

---

## Running Examples

### Standard Examples (Desktop/Server)

```bash
# Compile with optimizations
nim c -d:release examples/hash_file_checksum.nim

# Run
./hash_file_checksum myfile.bin
```

### Embedded Examples (Cross-compilation)

**Prerequisites**:
- ARM GCC toolchain: `apt-get install gcc-arm-none-eabi`
- OpenOCD for flashing: `apt-get install openocd`
- ST-Link or similar programmer

**Build Process**:

1. **Compile to object file**:
```bash
nim c --cpu:arm --os:standalone --gc:none --noMain \
  -d:stm32f4 --noLinking \
  --passC:"-mcpu=cortex-m4 -mthumb" \
  examples/embedded_blinky.nim
```

2. **Link with startup code**:
```bash
arm-none-eabi-gcc -o firmware.elf \
  embedded_blinky.o startup_stm32f4.o \
  -T stm32f4.ld -nostdlib -lgcc
```

3. **Flash to device**:
```bash
openocd -f interface/stlink.cfg -f target/stm32f4x.cfg \
  -c "program firmware.elf verify reset exit"
```

**Platform-Specific Notes**:

**STM32F4**:
- Requires startup code (reset vector, stack setup, .data/.bss init)
- Requires linker script (memory layout)
- Clock configuration needed (default 16 MHz HSI)

**RP2040 (Raspberry Pi Pico)**:
- Bootloader via USB (UF2 format)
- No external programmer needed
- Drag-and-drop firmware.uf2 to device

---

## Performance Tips

### Hash Functions
- Use **WyHash** for maximum speed (15-18 GB/s)
- Use **XXHash64** for compatibility (8-10 GB/s)
- Use incremental hashing for files > 100 MB
- Chunk size 64 KB optimal for I/O

### Caching
- Monitor hit rate (aim for > 70%)
- Size cache to working set (not total data)
- Consider TTL for stale data
- Use Swiss Table for speed

### Embedded
- Enable optimizations: `-d:release --opt:size`
- Use word-aligned operations
- Minimize flash writes
- Consider DMA for high-throughput I/O

---

## Next Steps

1. **Modify Examples**: Change parameters, add features
2. **Run Benchmarks**: See `benchmarks/` directory
3. **Read Tests**: See `tests/` for comprehensive test coverage
4. **Check Documentation**: Each module has detailed inline docs

---

## Troubleshooting

### Embedded Examples

**Problem**: `nim: command not found` during cross-compilation
- **Solution**: Ensure Nim is in PATH, use full path to nim binary

**Problem**: Undefined reference to `_start`
- **Solution**: Provide startup code with reset vector

**Problem**: LED doesn't blink
- **Solution**: Check GPIO clock enabled, pin configuration, LED polarity

**Problem**: UART garbage characters
- **Solution**: Verify baud rate calculation, check crystal frequency

### Desktop Examples

**Problem**: File hash doesn't match expected
- **Solution**: Ensure same hash algorithm, check for file corruption

**Problem**: Cache hit rate is low
- **Solution**: Increase cache size, check access patterns, verify LRU logic

---

## Contributing Examples

Want to add an example? Follow these guidelines:

1. **Comprehensive Documentation**: Explain what, why, how
2. **Compilation Instructions**: Step-by-step for all platforms
3. **Performance Metrics**: Show expected results
4. **Use Cases**: Real-world applications
5. **Troubleshooting**: Common issues and solutions

See existing examples as templates!
