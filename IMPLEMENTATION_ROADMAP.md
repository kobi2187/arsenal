# Arsenal Implementation Roadmap

Generated: 2026-01-31

## Overview

This document outlines all incomplete implementations discovered during compilation audit. Issues are categorized by priority, complexity, and type (binding vs. implementation vs. architecture-specific).

---

## BINDINGS TO IMPLEMENT (C Library Interop)

### Priority 1: Critical Core Functionality

#### 1.1 picohttpparser Binding
- **Status**: Bindings present, implementation stubbed
- **Files**: `src/arsenal/parsing/parsers/picohttpparser.nim`
- **Required action**:
  - [ ] Clone h2o/picohttpparser into vendor/
  - [ ] Verify C function signatures match importc declarations
  - [ ] Implement: `parseHttpRequest()` - parse request line + headers
  - [ ] Implement: `parseHttpResponse()` - parse status line + headers  
  - [ ] Implement: `parseHeaders()` - standalone header parsing
  - [ ] Implement: `parseMethod()` - HTTP method string→enum
  - [ ] Test with sample HTTP requests
- **Stub functions** (line 136, 145, 154, 187, 217, 233, 262):
  - parseHttpRequest() → err("Not implemented")
  - parseHttpResponse() → err("Not implemented")
  - parseHeaders() → err("Not implemented")
  - feed() (streaming) → err("Not implemented")
  - parseMethod() → returns hardcoded hmGet
  - Request formatting → returns ""
  - parseChunkSize() → err("Not implemented")

#### 1.2 simdjson Binding
- **Status**: Bindings present, all operations stubbed
- **Files**: `src/arsenal/parsing/parsers/simdjson.nim`
- **Required action**:
  - [ ] Clone simdjson/simdjson into vendor/
  - [ ] Verify C++ to Nim bindings (requires extern "C" wrapper or direct C bindings)
  - [ ] Implement: parser init/destroy
  - [ ] Implement: JSON parsing (parse, parseFile)
  - [ ] Implement: element access ([], at)
  - [ ] Implement: type extraction (getStr, getInt, getFloat, getBool, isNull)
  - [ ] Implement: iteration (items for arrays, pairs for objects)
  - [ ] Implement: validation
- **Stub functions** (lines 153, 167, 186, 199, 217, 226, 244, 258, 262, 266, 274, 294, 307, 327):
  - All parsing operations return none() or empty

#### 1.3 Zstandard (zstd) Compression Binding
- **Status**: Bindings present, implementation stubbed
- **Files**: `src/arsenal/compression/compressors/zstd.nim`
- **Required action**:
  - [ ] Verify zstd library installed or clone to vendor/
  - [ ] Implement: ZstdCompressor init/destroy (create context)
  - [ ] Implement: compress() - actually compress data using zstd_compress
  - [ ] Implement: ZstdDecompressor init/destroy
  - [ ] Implement: decompress() - actually decompress data
  - [ ] Implement: streaming compressor (initStream, compressChunk, finish)
- **Stub functions** (lines 179, 192, 208, 235, 240, 258, 288, 299, 308):
  - All return unimplemented data or errors

#### 1.4 xxHash64 Hashing Binding
- **Status**: Simple fallback implementation instead of real xxHash64
- **Files**: `src/arsenal/hashing/hasher.nim`, `src/arsenal/hashing/hashers/xxhash64.nim`
- **Required action**:
  - [ ] Clone Cyan4973/xxHash into vendor/xxhash/
  - [ ] Implement: proper xxHash64 algorithm (not XOR fallback)
  - [ ] Implement: incremental hashing (update/finish for streaming)
  - [ ] Replace stub "Stub - return simple hash" with real implementation
- **Stub implementations** (line 136, 175, 191):
  - hash() uses simple XOR
  - update() not implemented
  - finish() returns seed without finalization

---

## ASSEMBLY & ARCHITECTURE-SPECIFIC CODE

### Priority 1: Critical Performance Paths

#### 2.1 RTOS Context Switching (libaco)
- **Status**: Bindings present, C code compiled, assembly missing
- **Files**: `src/arsenal/embedded/rtos.nim`, `src/arsenal/concurrency/coroutines/libaco.nim`
- **Required action**:
  - [ ] Verify libaco/acosw.S assembly is platform-specific (x86_64, ARM64, etc.)
  - [ ] Test context switches on supported platforms
  - [ ] Document platform limitations
  - [ ] Implement ARM64 assembly variant if not present
- **Missing implementations** (lines 223, 242):
  - contextSwitch() - discard (no actual switching)
  - yield() - discard (no task yielding)

#### 2.2 ARM64 Syscall Wrappers
- **Status**: Stubs/TODOs for ARM64
- **Files**: `src/arsenal/kernel/syscalls.nim`
- **Required action**:
  - [ ] Implement syscall1-6 for ARM64 architecture
  - [ ] Use ARM64 ABI calling conventions
  - [ ] Test on ARM64 hardware or emulator
  - [ ] Document differences from x86_64
- **Stub implementations** (lines 243, 246):
  - syscall0() (ARM64) returns 0
  - syscall1-6 (ARM64) not implemented

#### 2.3 x86 CPUID Detection
- **Status**: TODO, no actual CPUID executed
- **Files**: `src/arsenal/platform/config.nim`
- **Required action**:
  - [ ] Implement CPUID execution via inline assembly or intrinsics
  - [ ] Extract CPU features (SSE2, SSE4.1, AVX, AVX2, etc.)
  - [ ] Test on various x86 processors
  - [ ] Provide fallback for non-x86
- **Stub implementations** (lines 145, 152, 153):
  - detectCpuFeatures() discard (no CPUID)

---

## EMBEDDED SYSTEMS & HAL

### Priority 2: Platform-Specific Features (Optional for desktop)

#### 3.1 RP2040 HAL (Raspberry Pi Pico)
- **Status**: GPIO/UART not implemented
- **Files**: `src/arsenal/embedded/hal.nim`
- **Required action**:
  - [ ] Implement GPIO setMode, read, write, toggle
  - [ ] Implement UART init and I/O
  - [ ] Implement delay() using timer
  - [ ] Implement getMillis() timer
  - [ ] Implement interrupt enable/disable
  - [ ] Test on actual RP2040 hardware
- **Error implementations** (lines 223, 267, 307, 344, 429, 430, 433, 469, 504, 527, 559, 572, 604, 615):
  - All return errors or discard

#### 3.2 RTOS Task Scheduling
- **Status**: No actual context switching, semaphore incomplete
- **Files**: `src/arsenal/embedded/rtos.nim`
- **Required action**:
  - [ ] Implement addTask() stack allocation
  - [ ] Implement contextSwitch() (architecture-specific)
  - [ ] Implement yield()
  - [ ] Implement Semaphore wait() with blocking
  - [ ] Implement Semaphore signal() with wake
  - [ ] Test multi-task scheduling
- **Stub implementations** (lines 129, 223, 224, 242, 309, 326):
  - Task management incomplete

#### 3.3 No-libc Embedded Support
- **Status**: Hardware-specific implementations needed
- **Files**: `src/arsenal/embedded/nolibc.nim`
- **Required action**:
  - [ ] Implement uintToStr() for bare metal
  - [ ] Implement putchar() for UART/serial
  - [ ] Implement __aeabi_uidiv() integer division
  - [ ] Implement __aeabi_idiv() signed division
- **Stub implementations** (lines 368, 412, 413, 445, 449):
  - All have "requires hardware-specific implementation" comments

---

## I/O & EVENT LOOPS

### Priority 2: Advanced I/O Features

#### 4.1 Linux epoll Backend
- **Status**: Partial implementation
- **Files**: `src/arsenal/io/backends/epoll.nim`
- **Required action**:
  - [ ] Complete removeFd() implementation
  - [ ] Test event loop operations
  - [ ] Verify correctness against epoll man page
- **Stub implementations** (line 123):
  - removeFd() - discard

#### 4.2 BSD kqueue Backend
- **Status**: Multiple stubs
- **Files**: `src/arsenal/io/backends/kqueue.nim`
- **Required action**:
  - [ ] Implement initKqueue() - call kqueue() syscall
  - [ ] Implement destroyKqueue() - proper cleanup
  - [ ] Implement addRead() - kevent registration
  - [ ] Implement addWrite() - kevent registration
  - [ ] Implement removeFd() - kevent removal
  - [ ] Test on macOS/BSD
- **Stub implementations** (lines 101, 113, 139, 153, 167):
  - All event loop operations incomplete

#### 4.3 Windows IOCP Backend
- **Status**: Multiple stubs
- **Files**: `src/arsenal/io/backends/iocp.nim`
- **Required action**:
  - [ ] Implement initIocp() - CreateIoCompletionPort
  - [ ] Implement destroyIocp() - cleanup
  - [ ] Implement associateHandle() - bind to IOCP
  - [ ] Implement post() - PostQueuedCompletionStatus
  - [ ] Test on Windows
- **Stub implementations** (lines 119, 131, 153, 193):
  - All operations incomplete

#### 4.4 Async Socket Operations
- **Status**: Most operations stubbed
- **Files**: `src/arsenal/io/socket.nim`
- **Required action**:
  - [ ] Implement newAsyncSocket() - set non-blocking + close-on-exec
  - [ ] Implement connect() - async connection
  - [ ] Implement bindAddr() - socket binding
  - [ ] Implement listen() - server listen
  - [ ] Implement accept() - accept connections
  - [ ] Implement send/recv/sendto/recvfrom operations
  - [ ] Test with event loop integration
- **Stub implementations** (lines 55, 99, 108, 116, 139, 169, 190, 198, 206, 218, 223, 228, 240, 248):
  - All async operations discard

---

## COMPRESSION

### Priority 1: Core Performance Feature

#### 5.1 Zstd Compression (see 1.3 above)

#### 5.2 Frame Format Encoding/Decoding
- **Status**: Stubbed
- **Files**: `src/arsenal/compression/compressor.nim`
- **Required action**:
  - [ ] Implement encodeFrame() - add framing metadata
  - [ ] Implement decodeFrame() - parse framing
- **Stub implementations** (lines 149, 162):
  - Frame operations incomplete

---

## HASHING

### Priority 1: Core Performance Feature

#### 6.1 xxHash64 Implementation (see 1.4 above)

#### 6.2 wyhash Implementation
- **Status**: Simple XOR fallback
- **Files**: `src/arsenal/hashing/hasher.nim`
- **Required action**:
  - [ ] Research wyhash algorithm (possibly header-only)
  - [ ] Implement proper wyhash64 algorithm
  - [ ] Replace simple XOR fallback with real implementation
- **Stub implementations** (line 252):
  - hash() uses simple XOR fallback

#### 6.3 FNV1a Hashing
- **Status**: Empty object, likely needs implementation
- **Files**: `src/arsenal/hashing/hasher.nim`
- **Required action**:
  - [ ] Implement FNV1a algorithm if not present
  - [ ] Verify against FNV reference

---

## MEMORY ALLOCATION

### Priority 2: Optimization (Optional)

#### 7.1 mimalloc Binding
- **Status**: Stubs, uses system malloc instead of mimalloc
- **Files**: `src/arsenal/memory/allocators/mimalloc.nim`
- **Required action**:
  - [ ] Implement actual mimalloc initialization
  - [ ] Implement heap creation/destruction
  - [ ] Use mimalloc functions instead of Nim's
  - [ ] Implement alignment handling
  - [ ] Test performance improvements
- **Stub implementations** (lines 75, 87, 99, 116, 149):
  - All use Nim's allocator instead of mimalloc

---

## CONCURRENCY & SYNCHRONIZATION

### Priority 2: Platform Support

#### 8.1 MSVC Atomic Operations
- **Status**: CRITICAL - Falls back to non-atomic operations
- **Files**: `src/arsenal/concurrency/atomics/atomic.nim`
- **Warning**: Line 29 - "MSVC atomics not implemented! Falling back to NON-ATOMIC operations"
- **Required action**:
  - [ ] Implement 15+ MSVC intrinsics (__InterlockedCompareExchange, etc.)
  - [ ] Test on Windows with MSVC compiler
  - [ ] Document this is a production risk until fixed
- **Impact**: Data corruption risk on Windows in multi-threaded code

#### 8.2 Channel Select Operation
- **Status**: TODO, not implemented
- **Files**: `src/arsenal/concurrency/channels/select.nim`
- **Required action**:
  - [ ] Implement selectChannel() - WaitForMultipleObjects equivalent
  - [ ] Test multi-channel operations
- **Stub implementations** (line 113):
  - selectChannel() incomplete

#### 8.3 Scheduler Operations
- **Status**: Stubbed
- **Files**: `src/arsenal/concurrency/scheduler.nim`
- **Required action**:
  - [ ] Implement scheduler operations (discard → real logic)
- **Stub implementations** (line 55):
  - Scheduler operations incomplete

#### 8.4 Coroutine Backend Operations
- **Status**: Stubbed
- **Files**: `src/arsenal/concurrency/coroutines/backend.nim`
- **Required action**:
  - [ ] Implement backend dispatch operations
- **Stub implementations** (lines 75, 133):
  - Backend operations incomplete

---

## PLATFORM-SPECIFIC ISSUES

### Priority 2: Feature Parity

#### 9.1 Socket Binding Enhancements
- **Status**: Minor type inconsistencies fixed
- **Files**: `src/arsenal/network/sockets.nim`
- **Fixed in compilation**: Enum ordering, type consistency
- **Status**: Mostly working, verify with tests

---

## MINOR/OPTIMIZATION

### Priority 3: Nice-to-Have

#### 10.1 Fixed-Point Math Optimization
- **Status**: Uses float fallback for sin()
- **Files**: `src/arsenal/numeric/fixed.nim`
- **Required action**:
  - [ ] Implement sin() using lookup table or Taylor series
  - [ ] Benchmark against float version
  - [ ] Add other fixed-point trig functions if useful
- **Stub implementations** (line 164):
  - sin() uses float

#### 10.2 Forensics Memory Analysis
- **Status**: Multiple operations stubbed
- **Files**: `src/arsenal/forensics/artifacts.nim`, `src/arsenal/forensics/memory.nim`
- **Required action**:
  - [ ] Implement memory forensics analysis
  - [ ] Implement artifact extraction
- **Stub implementations** (multiple lines):
  - Memory analysis incomplete

#### 10.3 Binary Format Parsing
- **Status**: PE and Mach-O parsing stubbed
- **Files**: `src/arsenal/binary/formats/pe.nim`, `src/arsenal/binary/formats/macho.nim`
- **Required action**:
  - [ ] Implement PE file parsing
  - [ ] Implement Mach-O file parsing
- **Stub implementations** (multiple lines):
  - Format parsing incomplete

#### 10.4 Collections/Roaring Bitmap
- **Status**: Some bitmap operations stubbed
- **Files**: `src/arsenal/collections/roaring.nim`
- **Required action**:
  - [ ] Implement stubbed bitmap operations
- **Stub implementations** (lines 305, 361):
  - Bitmap operations incomplete

---

## LIBRARY CLONING CHECKLIST

### Required Vendor Code to Clone

- [ ] **picohttpparser** - `git clone https://github.com/h2o/picohttpparser vendor/picohttpparser`
- [ ] **simdjson** - `git clone https://github.com/simdjson/simdjson vendor/simdjson`
- [ ] **xxHash** - `git clone https://github.com/Cyan4973/xxHash vendor/xxhash`
- [ ] **Zstandard** - `git clone https://github.com/facebook/zstd vendor/zstd` (or use system package)
- [ ] **LZ4** - Already available or system package

### Already Present

- [x] **libaco** - vendor/libaco/
- [x] **minicoro** - vendor/minicoro/
- [x] **libaco_nim** - vendor/libaco_nim/ (Nim wrapper)

---

## PRIORITY SUMMARY

### Immediate (Blocking compilation/functionality)
1. ✅ **DONE**: Fix compilation errors (14 errors fixed)
2. **NEXT**: Clone required third-party libraries
3. **NEXT**: Implement HTTP parsing (picohttpparser)
4. **NEXT**: Implement JSON parsing (simdjson)
5. **NEXT**: Fix hashing implementations (xxHash64, wyhash)

### Short-term (Critical for basic functionality)
6. Complete compression implementations (Zstd)
7. Implement remaining I/O backends (epoll, kqueue, IOCP)
8. Fix MSVC atomic operations (Windows support)
9. Implement embedded HAL for RP2040

### Medium-term (Feature completeness)
10. Implement RTOS context switching
11. Add ARM64 syscall support
12. Complete concurrency primitives

### Long-term (Optimization)
13. Implement fixed-point math optimizations
14. Add mimalloc binding usage
15. Complete forensics and binary parsing

---

## STATISTICS

- **Total incomplete implementations**: 80+
- **Bindings needing implementation**: 5 major (picohttpparser, simdjson, zstd, xxHash64, wyhash)
- **Assembly/arch-specific**: 3 (context switching, ARM64 syscalls, CPUID)
- **Embedded HAL**: 14 functions
- **I/O backends**: 12+ functions
- **Easy fixes**: 30+ (obvious algorithms)
- **Complex work**: 50+ (architecture-specific, C bindings)

---

## NEXT STEPS

1. **Create vendor clones** for required libraries
2. **Compare C signatures** against Nim importc declarations
3. **Implement easy stubs** (algorithms, data structures)
4. **Test bindings** with sample data
5. **Create PR** with implementations
