## Arsenal - Universal Low-Level Nim Library
## ==========================================
##
## Arsenal provides atomic, composable, swappable primitives for
## high-performance systems programming in Nim.
##
## Core Modules:
## - `arsenal/platform` - CPU detection, platform constants, optimization strategies
## - `arsenal/concurrency` - Coroutines, channels, lock-free structures
## - `arsenal/memory` - Allocators, SIMD memory ops
## - `arsenal/hashing` - High-performance hash functions
## - `arsenal/datastructures` - Swiss Tables, filters, etc.
## - `arsenal/compression` - LZ4, Zstd compression
## - `arsenal/parsing` - simdjson, HTTP parsers
## - `arsenal/crypto` - Cryptographic primitives (libsodium)
## - `arsenal/random` - High-quality RNGs (PCG, SplitMix64, crypto)
## - `arsenal/numeric` - Fixed-point, saturating arithmetic
## - `arsenal/simd` - SIMD intrinsics (SSE, AVX, NEON)
## - `arsenal/time` - High-resolution timing (RDTSC, monotonic)
## - `arsenal/network` - Raw sockets, low-level networking
## - `arsenal/filesystem` - Raw filesystem ops via syscalls
## - `arsenal/kernel` - Raw syscalls, no-libc operations
## - `arsenal/embedded` - RTOS, HAL, bare metal support
## - `arsenal/bits` - Bit manipulation primitives
##
## Design Pattern:
## Every module provides both unsafe primitives (maximum control)
## and safe wrappers (bounds-checked, tracked, idiomatic).

# Platform
import arsenal/platform/config
import arsenal/platform/strategies

# Concurrency
import arsenal/concurrency/atomics/atomic
import arsenal/concurrency/sync/spinlock
import arsenal/concurrency/queues/spsc
import arsenal/concurrency/queues/mpmc
import arsenal/concurrency/coroutines/coroutine
import arsenal/concurrency/channels/channel
import arsenal/concurrency/dsl/go_macro

# Memory
import arsenal/memory/allocator

# Hashing
import arsenal/hashing/hasher

# Data Structures
import arsenal/datastructures/hashtables/swiss_table

# Utilities
import arsenal/bits/bitops

# Compression
import arsenal/compression/compressor

# Parsing
import arsenal/parsing/parser

# Crypto
when not defined(arsenal_no_crypto):
  import arsenal/crypto/primitives as crypto_primitives

# Random
import arsenal/random/rng

# Numeric
import arsenal/numeric/fixed

# SIMD
when defined(amd64) or defined(i386) or defined(arm) or defined(arm64):
  import arsenal/simd/intrinsics

# Time
import arsenal/time/clock

# Network
when not defined(bare_metal):
  import arsenal/network/sockets

# Filesystem
when not defined(bare_metal):
  import arsenal/filesystem/rawfs

# Kernel
when defined(linux):
  import arsenal/kernel/syscalls

# Embedded
when defined(embedded) or defined(bare_metal):
  import arsenal/embedded/nolibc
  import arsenal/embedded/rtos
  import arsenal/embedded/hal

# Export all public APIs
export config, strategies
export atomic, spinlock, spsc, mpmc
export coroutine, channel, go_macro
export allocator
export hasher
export swiss_table
export bitops
export compressor
export parser

when not defined(arsenal_no_crypto):
  export crypto_primitives

export rng
export fixed

when defined(amd64) or defined(i386) or defined(arm) or defined(arm64):
  export intrinsics

export clock

when not defined(bare_metal):
  export sockets
  export rawfs

when defined(linux):
  export syscalls

when defined(embedded) or defined(bare_metal):
  export nolibc, rtos, hal
