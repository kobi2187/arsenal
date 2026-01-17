# External Dependencies for Arsenal Bindings

This document lists external C/C++ libraries required for various Arsenal modules. Arsenal follows a pragmatic approach: implement in pure Nim when performant, bind to best-in-class C/C++ libraries when appropriate.

---

## Core Philosophy

Arsenal uses **best-in-class external libraries** when:
1. The library is industry-standard and battle-tested
2. Pure Nim reimplementation would not achieve better performance
3. The library has a clean, stable API

Arsenal implements **pure Nim** when:
1. The implementation is straightforward and performant
2. No external dependencies are needed
3. Cross-platform portability is critical

---

## Required Dependencies (Production)

### Cryptography: libsodium

**Status**: ✅ Bindings implemented (`src/arsenal/crypto/primitives.nim`)

**Purpose**: Cryptographic primitives (ChaCha20, Ed25519, BLAKE2b, etc.)

**Why**: Industry-standard cryptographic library with constant-time operations

**Installation**:
```bash
# Debian/Ubuntu
sudo apt-get install libsodium-dev

# macOS
brew install libsodium

# Fedora/RHEL
sudo dnf install libsodium-devel

# Windows (vcpkg)
vcpkg install libsodium
```

**Version**: >= 1.0.18

**License**: ISC License (permissive)

**Website**: https://libsodium.org

---

## Optional Dependencies (Performance Enhancements)

### Compression: LZ4

**Status**: 📝 Binding stub ready (`src/arsenal/compression/compressors/lz4.nim`)

**Purpose**: Ultra-fast compression (~4 GB/s decompression)

**Why**: Industry-standard for high-speed compression

**Installation**:
```bash
# Debian/Ubuntu
sudo apt-get install liblz4-dev

# macOS
brew install lz4

# Fedora/RHEL
sudo dnf install lz4-devel

# Windows (vcpkg)
vcpkg install lz4
```

**Version**: >= 1.9.0

**License**: BSD 2-Clause

**Website**: https://lz4.org

**Binding Effort**: Low (simple C API)

**Implementation Priority**: Implement when applications need fast compression

---

### Compression: Zstandard (Zstd)

**Status**: 📝 Binding stub ready (`src/arsenal/compression/compressors/zstd.nim`)

**Purpose**: High-ratio compression with good speed

**Why**: Facebook's best-in-class compressor, better compression than LZ4

**Installation**:
```bash
# Debian/Ubuntu
sudo apt-get install libzstd-dev

# macOS
brew install zstd

# Fedora/RHEL
sudo dnf install libzstd-devel

# Windows (vcpkg)
vcpkg install zstd
```

**Version**: >= 1.5.0

**License**: BSD/GPLv2 dual license

**Website**: https://facebook.github.io/zstd/

**Binding Effort**: Low-Medium (C API)

**Implementation Priority**: Implement when applications need high-ratio compression

---

### JSON Parsing: simdjson

**Status**: 📝 Binding stub ready (`src/arsenal/parsing/parsers/simdjson.nim`)

**Purpose**: Fastest JSON parser (2-4 GB/s)

**Why**: Uses SIMD for parallel processing, industry-leading performance

**Installation**:
```bash
# From source (C++17 required)
git clone https://github.com/simdjson/simdjson.git
cd simdjson
mkdir build && cd build
cmake .. && make
sudo make install

# macOS
brew install simdjson

# Windows (vcpkg)
vcpkg install simdjson
```

**Version**: >= 3.0.0

**License**: Apache 2.0

**Website**: https://simdjson.org

**Binding Effort**: Medium (C++ API, requires C++ compiler)

**Implementation Priority**: Implement when applications need fast JSON parsing

---

### HTTP Parsing: picohttpparser

**Status**: 📝 Binding stub ready (`src/arsenal/parsing/parsers/picohttpparser.nim`)

**Purpose**: Zero-copy HTTP header parser

**Why**: Fast, simple, widely used in high-performance servers

**Installation**:
```bash
# Usually bundled (single-header library)
# Can be included directly in vendor/
wget https://raw.githubusercontent.com/h2o/picohttpparser/master/picohttpparser.h
wget https://raw.githubusercontent.com/h2o/picohttpparser/master/picohttpparser.c
```

**Version**: Latest from GitHub

**License**: MIT

**Website**: https://github.com/h2o/picohttpparser

**Binding Effort**: Low (simple C API)

**Implementation Priority**: Implement when building high-performance HTTP servers

---

### Allocator: mimalloc

**Status**: 📝 Binding stub ready (`src/arsenal/memory/allocators/mimalloc.nim`)

**Purpose**: General-purpose allocator (10-20% faster than malloc)

**Why**: Microsoft's high-performance allocator

**Installation**:
```bash
# From source
git clone https://github.com/microsoft/mimalloc.git
cd mimalloc
mkdir build && cd build
cmake .. && make
sudo make install

# macOS
brew install mimalloc

# Windows (vcpkg)
vcpkg install mimalloc
```

**Version**: >= 2.0

**License**: MIT

**Website**: https://microsoft.github.io/mimalloc/

**Binding Effort**: Low (C API)

**Implementation Priority**: Optional enhancement (Bump/Pool allocators already implemented)

---

## Platform-Specific Dependencies

### Linux: libaco (Coroutines)

**Status**: ✅ Integrated (`vendor/libaco/`, bound in `src/arsenal/concurrency/coroutines/libaco.nim`)

**Purpose**: Ultra-fast coroutine context switching (<20ns)

**Why**: Fastest coroutine library for x86_64 and ARM64

**Installation**: Bundled in vendor/ directory (no external install needed)

**License**: Apache 2.0

**Website**: https://github.com/hnes/libaco

**Note**: Compiled directly with Arsenal, no separate installation required

---

### Windows: minicoro (Coroutines)

**Status**: ✅ Integrated (`vendor/minicoro/`, bound in `src/arsenal/concurrency/coroutines/minicoro.nim`)

**Purpose**: Portable coroutine fallback for Windows

**Why**: Cross-platform coroutine library with Windows support

**Installation**: Bundled in vendor/ directory (no external install needed)

**License**: MIT

**Website**: https://github.com/edubart/minicoro

**Note**: Compiled directly with Arsenal, no separate installation required

---

## Development/Testing Dependencies

### Benchmarking: Google Benchmark (Optional)

**Status**: Not yet integrated

**Purpose**: Microbenchmarking framework

**Installation**:
```bash
# From source
git clone https://github.com/google/benchmark.git
cd benchmark
cmake -E make_directory "build"
cmake -E chdir "build" cmake -DCMAKE_BUILD_TYPE=Release ../
cmake --build "build" --config Release
```

**License**: Apache 2.0

**Priority**: Future enhancement for formal benchmarking

---

## Dependency Summary Table

| Library | Status | Purpose | Required? | Effort | Priority |
|---------|--------|---------|-----------|--------|----------|
| **libsodium** | ✅ Implemented | Cryptography | Optional | N/A | High (security) |
| **libaco** | ✅ Bundled | Coroutines (Linux) | No (bundled) | N/A | N/A (complete) |
| **minicoro** | ✅ Bundled | Coroutines (Windows) | No (bundled) | N/A | N/A (complete) |
| **LZ4** | 📝 Stub ready | Fast compression | No | Low | Medium |
| **Zstd** | 📝 Stub ready | High-ratio compression | No | Low-Med | Medium |
| **simdjson** | 📝 Stub ready | Fast JSON parsing | No | Medium | Medium |
| **picohttpparser** | 📝 Stub ready | HTTP parsing | No | Low | Low-Med |
| **mimalloc** | 📝 Stub ready | General allocator | No | Low | Low (optional) |

---

## Installation Scripts

### Ubuntu/Debian (All Optional Dependencies)
```bash
#!/bin/bash
sudo apt-get update
sudo apt-get install -y \
    libsodium-dev \
    liblz4-dev \
    libzstd-dev \
    cmake \
    g++

# simdjson (from source)
git clone https://github.com/simdjson/simdjson.git /tmp/simdjson
cd /tmp/simdjson
mkdir build && cd build
cmake .. && make && sudo make install
```

### macOS (Homebrew)
```bash
#!/bin/bash
brew install \
    libsodium \
    lz4 \
    zstd \
    simdjson
```

### Fedora/RHEL
```bash
#!/bin/bash
sudo dnf install -y \
    libsodium-devel \
    lz4-devel \
    libzstd-devel \
    cmake \
    gcc-c++
```

---

## Build Configuration

### Nim Compiler Flags

When using external libraries, add appropriate flags:

```bash
# With libsodium
nim c --passL:"-lsodium" your_program.nim

# With LZ4
nim c --passL:"-llz4" your_program.nim

# With Zstd
nim c --passL:"-lzstd" your_program.nim

# With simdjson (C++17 required)
nim cpp --passC:"-std=c++17" --passL:"-lsimdjson" your_program.nim

# With mimalloc
nim c --passL:"-lmimalloc" your_program.nim
```

### NimScript Configuration

Add to your `.nimble` file or `config.nims`:

```nim
when defined(useSodium):
  switch("passL", "-lsodium")

when defined(useLZ4):
  switch("passL", "-llz4")

when defined(useZstd):
  switch("passL", "-lzstd")

when defined(useSimdjson):
  switch("passL", "-lsimdjson")
  when defined(cpp):
    switch("passC", "-std=c++17")
```

Usage:
```bash
nim c -d:useSodium -d:useLZ4 your_program.nim
```

---

## Static Linking

For distributable binaries without runtime dependencies:

### Linux (Static Linking)
```bash
# Static libsodium
nim c --passL:"-static -lsodium" --dynlibOverride:sodium your_program.nim

# Static LZ4
nim c --passL:"-static -llz4" --dynlibOverride:lz4 your_program.nim
```

### Windows (Static Linking with vcpkg)
```bash
vcpkg install libsodium:x64-windows-static
nim c --passC:"-DSODIUM_STATIC" --passL:"libsodium.lib" your_program.nim
```

---

## Docker Image with All Dependencies

```dockerfile
FROM ubuntu:22.04

# Install Nim
RUN apt-get update && apt-get install -y wget xz-utils gcc
RUN wget https://nim-lang.org/download/nim-2.0.0-linux_x64.tar.xz
RUN tar xf nim-2.0.0-linux_x64.tar.xz -C /opt
ENV PATH="/opt/nim-2.0.0/bin:${PATH}"

# Install Arsenal dependencies
RUN apt-get install -y \
    libsodium-dev \
    liblz4-dev \
    libzstd-dev \
    cmake \
    g++

# Install simdjson from source
RUN git clone https://github.com/simdjson/simdjson.git /tmp/simdjson && \
    cd /tmp/simdjson && \
    mkdir build && cd build && \
    cmake .. && make && make install && \
    rm -rf /tmp/simdjson

WORKDIR /arsenal
COPY . .

# Build Arsenal
RUN nimble install -y
```

---

## Troubleshooting

### Library Not Found
```
Error: cannot open shared object file: libsodium.so.23
```

**Solution**: Ensure library is installed and in LD_LIBRARY_PATH:
```bash
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH
ldconfig  # Update library cache (requires root)
```

### Header Not Found
```
Error: cannot open file '<sodium.h>'
```

**Solution**: Install development package:
```bash
# Development packages include headers
sudo apt-get install libsodium-dev  # Not just libsodium23
```

### Version Mismatch
```
Error: libsodium version too old
```

**Solution**: Build latest from source:
```bash
wget https://download.libsodium.org/libsodium/releases/libsodium-1.0.19.tar.gz
tar xf libsodium-1.0.19.tar.gz
cd libsodium-1.0.19
./configure && make && sudo make install
```

---

## License Compatibility

All external dependencies use permissive licenses compatible with MIT:

- **libsodium**: ISC License ✅
- **LZ4**: BSD 2-Clause ✅
- **Zstd**: BSD/GPLv2 (use BSD) ✅
- **simdjson**: Apache 2.0 ✅
- **picohttpparser**: MIT ✅
- **mimalloc**: MIT ✅
- **libaco**: Apache 2.0 ✅
- **minicoro**: MIT ✅

No GPL dependencies in default build, ensuring Arsenal can be used in proprietary software.

---

## Future Dependencies (Under Consideration)

### GGML (AI/ML Inference)
- Purpose: Fast LLM inference
- License: MIT
- Website: https://github.com/ggerganov/ggml
- Status: Deferred to Phase E

### OpenBLAS (Linear Algebra)
- Purpose: Optimized BLAS operations
- License: BSD 3-Clause
- Website: https://www.openblas.net/
- Status: Deferred to Phase E

---

**Last Updated**: 2026-01-17
**Arsenal Version**: Pre-1.0 (Development)
