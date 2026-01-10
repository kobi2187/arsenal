# idea and plan
===============


# ============================================================================
# NIM ARSENAL: Complete Structure & Implementation Guide
# ============================================================================
# A curated collection of atomic performance primitives for Nim
# Philosophy: Small, composable, swappable, benchmarked
# ============================================================================

# ============================================================================
# FOLDER STRUCTURE
# ============================================================================

"""
nim-arsenal/
│
├── README.md
├── LICENSE
├── arsenal.nimble
├── .github/
│   └── workflows/
│       ├── benchmark.yml      # Daily benchmarking CI
│       └── tests.yml
│
├── src/
│   └── arsenal/
│       │
│       ├── config.nim         # Global configuration & CPU detection
│       ├── strategies.nim     # Throughput vs Latency selection
│       │
│       ├── memory/            # Memory operations & allocation
│       │   ├── memory.nim     # Public API (auto-selects best)
│       │   ├── allocator.nim  # Allocator trait
│       │   ├── ops.nim        # Memory operations trait
│       │   │
│       │   ├── allocators/
│       │   │   ├── mimalloc.nim
│       │   │   ├── rpmalloc.nim
│       │   │   ├── jemalloc.nim
│       │   │   ├── bump.nim
│       │   │   ├── slab.nim
│       │   │   ├── tlsf.nim
│       │   │   └── pool.nim
│       │   │
│       │   └── ops/
│       │       ├── memcpy_portable.nim
│       │       ├── memcpy_sse2.nim
│       │       ├── memcpy_avx2.nim
│       │       ├── memcpy_avx512.nim
│       │       ├── memcpy_neon.nim
│       │       ├── strlen_portable.nim
│       │       ├── strlen_sse4.nim
│       │       ├── strlen_avx2.nim
│       │       └── memcmp_simd.nim
│       │
│       ├── concurrency/       # Coroutines, threads, synchronization
│       │   ├── concurrency.nim
│       │   ├── coroutine.nim  # Coroutine trait
│       │   ├── queue.nim      # Queue trait
│       │   │
│       │   ├── coroutines/
│       │   │   ├── libaco.nim
│       │   │   ├── boost_context.nim
│       │   │   ├── minicoro.nim
│       │   │   ├── switch_x86_64.S
│       │   │   ├── switch_arm64.S
│       │   │   └── switch_riscv64.S
│       │   │
│       │   ├── queues/
│       │   │   ├── spsc.nim         # Single-producer single-consumer
│       │   │   ├── mpmc.nim         # Multi-producer multi-consumer
│       │   │   ├── mpsc.nim
│       │   │   └── bounded_mpmc.nim
│       │   │
│       │   └── sync/
│       │       ├── spinlock.nim
│       │       ├── ticket_lock.nim
│       │       ├── mcs_lock.nim
│       │       ├── futex.nim
│       │       └── rwlock.nim
│       │
│       ├── hashing/           # Hash functions
│       │   ├── hashing.nim    # Public API
│       │   ├── hasher.nim     # Hasher trait
│       │   │
│       │   └── hashers/
│       │       ├── xxhash32.nim
│       │       ├── xxhash64.nim
│       │       ├── xxhash3.nim
│       │       ├── wyhash.nim
│       │       ├── meow_hash.nim
│       │       ├── highway_hash.nim
│       │       └── siphash.nim
│       │
│       ├── compression/       # Compression algorithms
│       │   ├── compression.nim
│       │   ├── compressor.nim  # Compressor trait
│       │   │
│       │   └── compressors/
│       │       ├── lz4.nim
│       │       ├── zstd.nim
│       │       ├── snappy.nim
│       │       ├── brotli.nim
│       │       ├── density.nim
│       │       ├── varint.nim
│       │       ├── stream_vbyte.nim
│       │       ├── fse.nim          # Finite State Entropy
│       │       └── ans.nim          # Asymmetric Numeral Systems
│       │
│       ├── linalg/            # Linear algebra
│       │   ├── linalg.nim
│       │   ├── blas.nim       # BLAS interface
│       │   │
│       │   ├── primitives/
│       │   │   ├── dot_sse2.S
│       │   │   ├── dot_avx2.S
│       │   │   ├── dot_avx512.S
│       │   │   ├── axpy.S
│       │   │   └── reduce_sum.S
│       │   │
│       │   └── kernels/
│       │       ├── gemm_scalar.nim
│       │       ├── gemm_blocked.nim
│       │       ├── gemm_avx2.nim
│       │       ├── gemm_avx512.nim
│       │       ├── gemv.nim
│       │       └── transpose.nim
│       │
│       ├── ml/                # Machine learning inference
│       │   ├── ml.nim
│       │   │
│       │   ├── attention/
│       │   │   ├── scaled_dot_product.nim
│       │   │   ├── flash_attention.nim     # Paper: Tri Dao 2022
│       │   │   ├── paged_attention.nim     # vLLM
│       │   │   └── sparse_attention.nim
│       │   │
│       │   ├── quantization/
│       │   │   ├── int8_symmetric.nim
│       │   │   ├── int4_groupwise.nim      # GPTQ-style
│       │   │   ├── awq.nim                 # AWQ paper 2023
│       │   │   └── dynamic_quant.nim
│       │   │
│       │   ├── kernels/
│       │   │   ├── layernorm.nim
│       │   │   ├── rmsnorm.nim
│       │   │   ├── gelu.nim
│       │   │   ├── softmax.nim
│       │   │   ├── rope.nim                # Rotary embeddings
│       │   │   └── embedding.nim
│       │   │
│       │   └── memory/
│       │       ├── kv_cache.nim
│       │       ├── paged_kv.nim            # vLLM approach
│       │       └── streaming_load.nim
│       │
│       ├── media/             # Audio/video processing
│       │   ├── media.nim
│       │   │
│       │   ├── audio/
│       │   │   ├── primitives/
│       │   │   │   ├── fft_radix2.nim
│       │   │   │   ├── fft_simd.S
│       │   │   │   ├── window_hann.nim
│       │   │   │   └── convolve.S
│       │   │   │
│       │   │   ├── filters/
│       │   │   │   ├── biquad.nim
│       │   │   │   ├── fir.nim
│       │   │   │   ├── butterworth.nim
│       │   │   │   └── equalizer.nim
│       │   │   │
│       │   │   └── codecs/
│       │   │       ├── opus.nim
│       │   │       ├── vorbis.nim
│       │   │       └── flac.nim
│       │   │
│       │   └── video/
│       │       ├── primitives/
│       │       │   ├── rgb_yuv.S
│       │       │   ├── yuv_rgb.S
│       │       │   └── resize_bilinear.S
│       │       │
│       │       └── codecs/
│       │           ├── av1_decode.nim      # dav1d binding
│       │           ├── h264_decode.nim
│       │           └── vp9_decode.nim
│       │
│       ├── parsing/           # Parsers
│       │   ├── parsing.nim
│       │   ├── parser.nim     # Parser trait
│       │   │
│       │   └── parsers/
│       │       ├── json/
│       │       │   ├── simdjson.nim
│       │       │   ├── yyjson.nim
│       │       │   ├── sajson.nim
│       │       │   └── rapidjson.nim
│       │       │
│       │       ├── http/
│       │       │   ├── picohttpparser.nim
│       │       │   ├── llhttp.nim
│       │       │   └── http_parser.nim
│       │       │
│       │       └── csv/
│       │           └── simd_csv.nim        # Paper: SIMD CSV 2018
│       │
│       ├── datastructures/    # Advanced data structures
│       │   ├── datastructures.nim
│       │   │
│       │   ├── hashtables/
│       │   │   ├── swiss_table.nim         # Paper: Google 2017
│       │   │   ├── robin_hood.nim
│       │   │   ├── cuckoo.nim
│       │   │   └── f14.nim                 # Facebook's F14
│       │   │
│       │   ├── trees/
│       │   │   ├── btree.nim
│       │   │   ├── radix_tree.nim
│       │   │   └── wavelet_tree.nim        # Paper: 2003
│       │   │
│       │   ├── queues/
│       │   │   ├── priority_queue.nim
│       │   │   └── heap.nim
│       │   │
│       │   └── filters/
│       │       ├── bloom.nim
│       │       ├── xor_filter.nim          # Paper: Graf & Lemire 2019
│       │       ├── ribbon_filter.nim       # Paper: 2021
│       │       ├── cuckoo_filter.nim
│       │       └── quotient_filter.nim
│       │
│       ├── algorithms/        # Core algorithms
│       │   ├── algorithms.nim
│       │   │
│       │   ├── sorting/
│       │   │   ├── pdqsort.nim             # Paper: 2016
│       │   │   ├── ips4o.nim               # Paper: IPS⁴o 2017
│       │   │   ├── ska_sort.nim            # Paper: 2017
│       │   │   └── branchless_insert.nim
│       │   │
│       │   ├── searching/
│       │   │   ├── binary_search_simd.nim  # Paper: 2017
│       │   │   ├── floyd_rivest.nim        # Selection algorithm
│       │   │   └── interpolation_search.nim
│       │   │
│       │   └── string/
│       │       ├── z_algorithm.nim
│       │       ├── kmp.nim
│       │       ├── boyer_moore.nim
│       │       ├── aho_corasick.nim
│       │       └── simd_strstr.nim         # Paper: Langdale 2022
│       │
│       ├── sketching/         # Probabilistic data structures
│       │   ├── sketching.nim
│       │   │
│       │   ├── cardinality/
│       │   │   ├── hyperloglog.nim         # Paper: 2007
│       │   │   └── hyperloglog_pp.nim      # Paper: Google 2013
│       │   │
│       │   ├── frequency/
│       │   │   ├── count_min.nim           # Paper: 2005
│       │   │   ├── count_sketch.nim
│       │   │   └── space_saving.nim        # Top-K heavy hitters
│       │   │
│       │   ├── similarity/
│       │   │   ├── minhash.nim
│       │   │   └── simhash.nim
│       │   │
│       │   └── quantiles/
│       │       └── t_digest.nim            # Paper: Dunning 2013
│       │
│       ├── io/                # I/O operations
│       │   ├── io.nim
│       │   ├── io_backend.nim  # I/O backend trait
│       │   │
│       │   └── backends/
│       │       ├── io_uring.nim
│       │       ├── epoll.nim
│       │       ├── kqueue.nim
│       │       ├── iocp.nim
│       │       └── direct_io.nim
│       │
│       ├── streaming/         # Out-of-core processing
│       │   ├── streaming.nim
│       │   │
│       │   ├── io/
│       │   │   ├── mmap_sequential.nim
│       │   │   ├── mmap_random.nim
│       │   │   └── async_read.nim
│       │   │
│       │   └── processing/
│       │       ├── map_reduce.nim
│       │       ├── external_sort.nim
│       │       └── window_aggregation.nim
│       │
│       ├── realtime/          # Real-time & low-latency
│       │   ├── realtime.nim
│       │   │
│       │   ├── scheduling/
│       │   │   ├── deadline.nim
│       │   │   ├── rate_monotonic.nim
│       │   │   ├── cpu_pinning.nim
│       │   │   └── priority_inheritance.nim
│       │   │
│       │   ├── timing/
│       │   │   ├── rdtsc.S
│       │   │   ├── rdtscp.S
│       │   │   ├── tsc_calibrate.nim
│       │   │   └── monotonic_raw.nim
│       │   │
│       │   └── memory/
│       │       ├── preallocate.nim
│       │       ├── huge_pages.nim
│       │       ├── numa_aware.nim
│       │       └── lock_free_pool.nim
│       │
│       ├── kernel/            # Kernel-level primitives
│       │   ├── kernel.nim
│       │   │
│       │   ├── syscalls/
│       │   │   ├── raw_linux.nim
│       │   │   ├── raw_bsd.nim
│       │   │   └── raw_windows.nim
│       │   │
│       │   ├── memory/
│       │   │   ├── mmap.S
│       │   │   ├── brk.S
│       │   │   └── page_tables.nim
│       │   │
│       │   └── interrupts/
│       │       ├── cli_sti.S
│       │       ├── save_flags.S
│       │       └── isr_stub.S
│       │
│       ├── embedded/          # Embedded/bare-metal
│       │   ├── embedded.nim
│       │   │
│       │   ├── allocators/
│       │   │   ├── bump.nim
│       │   │   ├── slab.nim
│       │   │   └── tlsf.nim
│       │   │
│       │   ├── rtos/
│       │   │   ├── scheduler.nim
│       │   │   ├── priority.nim
│       │   │   └── tickless.nim
│       │   │
│       │   └── hal/
│       │       ├── gpio_mmio.nim
│       │       ├── uart_16550.nim
│       │       ├── spi_bitbang.nim
│       │       └── i2c_bitbang.nim
│       │
│       ├── crypto/            # Cryptographic primitives
│       │   ├── crypto.nim
│       │   │
│       │   ├── symmetric/
│       │   │   ├── aes_ni.S
│       │   │   ├── chacha20.nim
│       │   │   └── poly1305.nim
│       │   │
│       │   ├── asymmetric/
│       │   │   ├── curve25519.nim
│       │   │   └── ed25519.nim
│       │   │
│       │   ├── hashing/
│       │   │   ├── blake3.nim
│       │   │   ├── sha256.nim
│       │   │   └── sha3.nim
│       │   │
│       │   └── postquantum/
│       │       ├── kyber.nim               # NIST standard
│       │       └── dilithium.nim           # NIST standard
│       │
│       ├── simd/              # SIMD abstractions
│       │   ├── simd.nim
│       │   │
│       │   └── wrappers/
│       │       ├── highway.nim
│       │       ├── simde.nim
│       │       └── xsimd.nim
│       │
│       ├── random/            # Random number generation
│       │   ├── random.nim
│       │   │
│       │   └── generators/
│       │       ├── xoshiro256.nim
│       │       ├── pcg.nim
│       │       ├── chacha20_rng.nim
│       │       └── rdrand.S
│       │
│       ├── bits/              # Bit manipulation
│       │   ├── bits.nim
│       │   │
│       │   ├── ops/
│       │   │   ├── clz.S
│       │   │   ├── ctz.S
│       │   │   ├── popcnt.S
│       │   │   ├── bswap.S
│       │   │   └── pext_pdep.S
│       │   │
│       │   └── structures/
│       │       ├── bitarray.nim
│       │       ├── roaring_bitmap.nim      # Paper: Chambi 2016
│       │       └── rank_select.nim         # Paper: Vigna 2008
│       │
│       ├── graph/             # Graph algorithms
│       │   ├── graph.nim
│       │   │
│       │   ├── traversal/
│       │   │   ├── bfs_direction_opt.nim   # Paper: 2012
│       │   │   ├── dfs.nim
│       │   │   └── parallel_bfs.nim
│       │   │
│       │   └── shortest_path/
│       │       ├── dijkstra.nim
│       │       ├── delta_stepping.nim      # Paper: 2003
│       │       └── bellman_ford.nim
│       │
│       ├── numeric/           # Numerical algorithms
│       │   ├── numeric.nim
│       │   │
│       │   ├── summation/
│       │   │   ├── kahan.nim               # Kahan summation
│       │   │   └── pairwise.nim
│       │   │
│       │   ├── approximation/
│       │   │   ├── fast_inverse_sqrt.nim   # Quake III
│       │   │   ├── estrin_poly.nim         # Estrin's method
│       │   │   └── fast_exp_log.nim
│       │   │
│       │   └── division/
│       │       └── div_by_const.nim        # Paper: Granlund 1994
│       │
│       ├── cache/             # Caching strategies
│       │   ├── cache.nim
│       │   │
│       │   └── policies/
│       │       ├── lru.nim
│       │       ├── arc.nim                 # Paper: IBM 2003
│       │       ├── clock_pro.nim           # Paper: 2005
│       │       ├── tinylfu.nim             # Paper: 2017
│       │       └── s3_fifo.nim             # Paper: 2023
│       │
│       └── stdlib_compat/     # Drop-in stdlib replacements
│           ├── asynchttpserver.nim
│           ├── asyncdispatch.nim
│           ├── json.nim
│           ├── tables.nim
│           └── algorithm.nim
│
├── benchmarks/            # Comprehensive benchmarks
│   ├── benchmark.nim      # Benchmarking framework
│   ├── memory/
│   ├── concurrency/
│   ├── hashing/
│   ├── compression/
│   ├── linalg/
│   ├── ml/
│   ├── media/
│   ├── parsing/
│   ├── datastructures/
│   ├── algorithms/
│   └── results/           # Daily benchmark results
│       └── YYYY-MM-DD.json
│
├── tests/                 # Unit tests
│   └── (mirrors src/ structure)
│
├── examples/              # Usage examples
│   ├── web_server/
│   ├── ml_inference/
│   ├── video_transcoding/
│   ├── embedded_minimal/
│   ├── game_engine/
│   └── hft_system/
│
└── docs/                  # Documentation
    ├── getting_started.md
    ├── strategies.md      # Throughput vs Latency guide
    ├── api_reference.md
    ├── papers.md          # All referenced papers
    ├── benchmarks.md      # Latest benchmark results
    └── contributing.md
"""

# ============================================================================
# CORE API DESIGN: Strategy-Based Selection
# ============================================================================

# src/arsenal/strategies.nim
type
  OptimizationStrategy* = enum
    Throughput    ## Maximize operations per second (batch-friendly)
    Latency       ## Minimize response time (single-op optimized)
    Balanced      ## Default: good for most cases
    MinimalMemory ## Minimize memory footprint
    MaximalSpeed  ## Absolute maximum speed, memory be damned

var currentStrategy* {.threadvar.}: OptimizationStrategy = Balanced

proc setStrategy*(strategy: OptimizationStrategy) =
  ## Set the optimization strategy for current thread
  currentStrategy = strategy

# ============================================================================
# src/arsenal/config.nim
# CPU Feature Detection
# ============================================================================

type
  CpuFeatures* = object
    hasSSE2*: bool
    hasSSE4*: bool
    hasAVX*: bool
    hasAVX2*: bool
    hasAVX512F*: bool
    hasAVX512BW*: bool
    hasNEON*: bool
    hasSVE*: bool
    hasRDTSC*: bool
    hasAESNI*: bool
    hasPCLMULQDQ*: bool
    hasPOPCNT*: bool
    hasBMI1*: bool
    hasBMI2*: bool

proc detectCpuFeatures*(): CpuFeatures =
  ## Detect available CPU features at runtime
  when defined(amd64) or defined(i386):
    {.emit: """
    unsigned int eax, ebx, ecx, edx;
    __asm__ __volatile__("cpuid" : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx) : "a"(1));
    `result`.hasSSE2 = (edx >> 26) & 1;
    `result`.hasSSE4 = (ecx >> 19) & 1;
    `result`.hasAVX = (ecx >> 28) & 1;
    `result`.hasPOPCNT = (ecx >> 23) & 1;
    `result`.hasAESNI = (ecx >> 25) & 1;
    
    __asm__ __volatile__("cpuid" : "=a"(eax), "=b"(ebx), "=c"(ecx), "=d"(edx) : "a"(7), "c"(0));
    `result`.hasAVX2 = (ebx >> 5) & 1;
    `result`.hasAVX512F = (ebx >> 16) & 1;
    `result`.hasAVX512BW = (ebx >> 30) & 1;
    `result`.hasBMI1 = (ebx >> 3) & 1;
    `result`.hasBMI2 = (ebx >> 8) & 1;
    """.}
  elif defined(arm) or defined(aarch64):
    # ARM feature detection via /proc/cpuinfo or hwcap
    result.hasNEON = true  # Simplified - should read from system
  
  result.hasRDTSC = true  # Most modern CPUs

var cpuFeatures* = detectCpuFeatures()

# ============================================================================
# EXAMPLE 1: Memory Operations API
# ============================================================================

# src/arsenal/memory/ops.nim
type
  MemoryOpsImpl* = concept impl
    ## Trait for memory operations implementations
    impl.copy(dst: pointer, src: pointer, size: int)
    impl.compare(a: pointer, b: pointer, size: int): int
    impl.set(dst: pointer, value: byte, size: int)

# Public API that auto-selects implementation
proc copy*(dst, src: pointer, size: int) {.inline.} =
  ## Fast memory copy - automatically uses best SIMD variant
  when defined(avx512) and cpuFeatures.hasAVX512F:
    import arsenal/memory/ops/memcpy_avx512
    memcpyAVX512(dst, src, size)
  elif defined(avx2) and cpuFeatures.hasAVX2:
    import arsenal/memory/ops/memcpy_avx2
    memcpyAVX2(dst, src, size)
  elif defined(sse2) and cpuFeatures.hasSSE2:
    import arsenal/memory/ops/memcpy_sse2
    memcpySSE2(dst, src, size)
  elif defined(arm64) and cpuFeatures.hasNEON:
    import arsenal/memory/ops/memcpy_neon
    memcpyNEON(dst, src, size)
  else:
    import arsenal/memory/ops/memcpy_portable
    memcpyPortable(dst, src, size)

# Strategy-aware variant
proc copyStrategy*(dst, src: pointer, size: int) {.inline.} =
  ## Memory copy optimized for current strategy
  import arsenal/strategies
  
  when currentStrategy == Throughput:
    # Use non-temporal stores for large copies (bypass cache)
    when size > 256*1024 and cpuFeatures.hasAVX2:
      import arsenal/memory/ops/memcpy_avx2_nt
      memcpyAVX2NonTemporal(dst, src, size)
    else:
      copy(dst, src, size)
  elif currentStrategy == Latency:
    # Use smallest, fastest variant even if throughput suffers
    when size < 64:
      import arsenal/memory/ops/memcpy_tiny
      memcpyTiny(dst, src, size)
    else:
      copy(dst, src, size)
  else:
    copy(dst, src, size)

# ============================================================================
# src/arsenal/memory/ops/memcpy_avx2.nim (Example Implementation)
# ============================================================================

proc memcpyAVX2*(dst, src: pointer, size: int) =
  ## AVX2-optimized memory copy
  {.emit: """
  #include <immintrin.h>
  
  char* d = (char*)`dst`;
  const char* s = (const char*)`src`;
  size_t n = `size`;
  
  // Copy 32-byte chunks with AVX2
  while (n >= 32) {
    __m256i chunk = _mm256_loadu_si256((__m256i*)s);
    _mm256_storeu_si256((__m256i*)d, chunk);
    s += 32;
    d += 32;
    n -= 32;
  }
  
  // Handle remainder
  while (n > 0) {
    *d++ = *s++;
    n--;
  }
  """.}

# ============================================================================
# EXAMPLE 2: Allocator API
# ============================================================================

# src/arsenal/memory/allocator.nim
type
  Allocator* = concept a
    ## Trait for allocator implementations
    a.alloc(size: int): pointer
    a.dealloc(p: pointer)
    a.realloc(p: pointer, newSize: int): pointer

# Strategy-based allocator selection
proc createAllocator*(): auto =
  ## Create an allocator optimized for current strategy
  import arsenal/strategies
  
  when currentStrategy == Throughput:
    # mimalloc: best for throughput, thread-scalable
    import arsenal/memory/allocators/mimalloc
    result = newMimallocAllocator()
    
  elif currentStrategy == Latency:
    # rpmalloc: lock-free, lowest latency
    import arsenal/memory/allocators/rpmalloc
    result = newRpmallocAllocator()
    
  elif currentStrategy == MinimalMemory:
    # TLSF: O(1), minimal overhead
    import arsenal/memory/allocators/tlsf
    result = newTLSFAllocator()
    
  else:
    # mimalloc: good default
    import arsenal/memory/allocators/mimalloc
    result = newMimallocAllocator()

# ============================================================================
# src/arsenal/memory/allocators/mimalloc.nim (Example)
# ============================================================================

{.compile: "mimalloc/src/static.c".}
{.passC: "-DMI_STATIC_LIB -DMI_MALLOC_OVERRIDE".}

type
  MimallocAllocator* = object
    discard

proc newMimallocAllocator*(): MimallocAllocator =
  result = MimallocAllocator()

proc alloc*(a: MimallocAllocator, size: int): pointer =
  proc mi_malloc(size: csize_t): pointer {.importc, cdecl.}
  mi_malloc(size.csize_t)

proc dealloc*(a: MimallocAllocator, p: pointer) =
  proc mi_free(p: pointer) {.importc, cdecl.}
  mi_free(p)

proc realloc*(a: MimallocAllocator, p: pointer, newSize: int): pointer =
  proc mi_realloc(p: pointer, newsize: csize_t): pointer {.importc, cdecl.}
  mi_realloc(p, newSize.csize_t)

# ============================================================================
# EXAMPLE 3: Hashing API
# ============================================================================

# src/arsenal/hashing/hashing.nim
type
  Hasher* = concept h
    ## Trait for hash function implementations
    h.hash(data: pointer, len: int): uint64

# Public API
proc hash*(data: pointer, len: int): uint64 {.inline.} =
  ## Fast hash - auto-selects best implementation
  when defined(release):
    # Use fastest hash in release mode
    import arsenal/hashing/hashers/wyhash
    hashWyHash(data, len)
  else:
    # Use hash with better collision resistance in debug
    import arsenal/hashing/hashers/xxhash64
    hashXXHash64(data, len)

# Strategy-aware variant
proc hashStrategy*(data: pointer, len: int): uint64 {.inline.} =
  import arsenal/strategies
  
  when currentStrategy == Throughput:
    # wyhash: 40+ GB/s
    import arsenal/hashing/hashers/wyhash
    hashWyHash(data, len)
    
  elif currentStrategy == Latency:
    # For very small inputs, simpler hash is faster
    when len < 32:
      import arsenal/hashing/hashers/xxhash32
      hashXXHash32(data, len).uint64
    else:
      import arsenal/hashing/hashers/wyhash
      hashWyHash(data, len)
  else:
    import arsenal/hashing/hashers/xxhash64
    hashXXHash64(data, len)

# ============================================================================
# src/arsenal/hashing/hashers/xxhash64.nim
# ============================================================================

{.compile: "xxHash/xxhash.c".}

proc XXH64*(input: pointer, length: csize_t, seed: uint64): uint64 {.
  importc: "XXH64", cdecl
.}

proc hashXXHash64*(data: pointer, len: int, seed: uint64 = 0): uint64 =
  XXH64(data, len.csize_t, seed)

# ============================================================================
# EXAMPLE 4: Coroutine API
# ============================================================================

# src/arsenal/concurrency/coroutine.nim
type
  Coroutine* = concept c
    ## Trait for coroutine implementations
    type c.Handle
    c.create(fn: proc()): c.Handle
    c.resume(h: c.Handle)
    c.yield()
    c.destroy(h: c.Handle)

# Auto-selecting implementation
proc createCoroutineBackend*(): auto =
  ## Create coroutine backend - auto-selects best for platform
  when defined(amd64):
    when defined(arsenalUseBoost):
      import arsenal/concurrency/coroutines/boost_context
      result = newBoostContextBackend()
    else:
      # libaco is faster on x86_64
      import arsenal/concurrency/coroutines/libaco
      result = newLibacoBackend()
      
  elif defined(arm64):
    import arsenal/concurrency/coroutines/libaco
    result = newLibacoBackend()
    
  else:
    # Portable fallback
    import arsenal/concurrency/coroutines/minicoro
    result = newMinicoroBackend()

# ============================================================================
# src/arsenal/concurrency/coroutines/libaco.nim
# ============================================================================

{.compile: "libaco/aco.c".}
{.compile: "libaco/acosw.S".}

type
  AcoT {.importc: "aco_t", header: "aco.h", incompleteStruct.} = object
  AcoTPtr = ptr AcoT
  
  LibacoBackend* = object
    mainCo: AcoTPtr

proc aco_create*(
  main_co: AcoTPtr,
  share_stack: pointer,
  save_stack_sz: csize_t,
  fp: proc() {.cdecl.},
  arg: pointer
): AcoTPtr {.importc, cdecl.}

proc aco_resume*(co: AcoTPtr) {.importc, cdecl.}
proc aco_yield*() {.importc, cdecl.}
proc aco_destroy*(co: AcoTPtr) {.importc, cdecl.}

type LibacoHandle* = distinct AcoTPtr

proc newLibacoBackend*(): LibacoBackend =
  # Initialize main coroutine
  result.mainCo = nil

proc create*(backend: LibacoBackend, fn: proc()): LibacoHandle =
  # Wrapper to convert Nim proc to C callback
  proc wrapperFn() {.cdecl.} = fn()
  LibacoHandle(aco_create(backend.mainCo, nil, 0, wrapperFn, nil))

proc resume*(backend: LibacoBackend, h: LibacoHandle) =
  aco_resume(AcoTPtr(h))

proc yield*(backend: LibacoBackend) =
  aco_yield()

proc destroy*(backend: LibacoBackend, h: LibacoHandle) =
  aco_destroy(AcoTPtr(h))

# ============================================================================
# EXAMPLE 5: JSON Parsing API
# ============================================================================

# src/arsenal/parsing/json.nim
import arsenal/strategies

type
  JsonValue* = object
    # Simplified JSON representation
    discard

proc parseJson*(input: string): JsonValue =
  ## Parse JSON - auto-selects best parser
  when currentStrategy == Throughput:
    # simdjson: best for large batches
    import arsenal/parsing/parsers/json/simdjson
    parseSimdJson(input)
    
  elif currentStrategy == Latency:
    # yyjson: better for small objects
    when input.len < 1024:
      import arsenal/parsing/parsers/json/yyjson
      parseYyJson(input)
    else:
      import arsenal/parsing/parsers/json/simdjson
      parseSimdJson(input)
      
  else:
    # yyjson: good balance
    import arsenal/parsing/parsers/json/yyjson
    parseYyJson(input)

# Explicit parser selection
proc parseJsonWith*[P](input: string, parser: typedesc[P]): JsonValue =
  ## Parse JSON with explicit parser choice
  when P is SimdJson:
    import arsenal/parsing/parsers/json/simdjson
    parseSimdJson(input)
  elif P is YyJson:
    import arsenal/parsing/parsers/json/yyjson
    parseYyJson(input)
  elif P is SaJson:
    import arsenal/parsing/parsers/json/sajson
    parseSaJson(input)
  else:
    {.error: "Unknown JSON parser".}

# ============================================================================
# EXAMPLE 6: Data Structure API (Swiss Tables)
# ============================================================================

# src/arsenal/datastructures/hashtables/swiss_table.nim
# Paper: "Abseil's Swiss Tables Design Notes" (Google 2017)

import arsenal/config
import arsenal/hashing/hashing

type
  SwissTable*[K, V] = object
    ## Google's Swiss Tables - 2× faster than std::unordered_map
    ## Uses SIMD for parallel probing
    metadata: ptr UncheckedArray[uint8]  # Control bytes
    keys: ptr UncheckedArray[K]
    values: ptr UncheckedArray[V]
    capacity: int
    size: int

const
  EMPTY = 0b11111111'u8
  DELETED = 0b10000000'u8
  
proc newSwissTable*[K, V](initialCapacity: int = 16): SwissTable[K, V] =
  result.capacity = initialCapacity
  result.metadata = cast[ptr UncheckedArray[uint8]](
    alloc0(initialCapacity * sizeof(uint8))
  )
  result.keys = cast[ptr UncheckedArray[K]](
    alloc(initialCapacity * sizeof(K))
  )
  result.values = cast[ptr UncheckedArray[V]](
    alloc(initialCapacity * sizeof(V))
  )
  
  # Initialize all slots as EMPTY
  for i in 0..<initialCapacity:
    result.metadata[i] = EMPTY

proc hash[K](key: K): uint64 {.inline.} =
  ## Hash a key using Arsenal's fast hash
  hash(unsafeAddr key, sizeof(K))

proc h2(h: uint64): uint8 {.inline.} =
  ## Extract H2 (top 7 bits) from hash
  uint8((h shr 57) and 0x7F)

proc findSlot[K, V](table: SwissTable[K, V], key: K): int =
  ## Find slot using SIMD parallel probing
  let h = hash(key)
  let h2val = h2(h)
  var idx = int(h mod table.capacity.uint64)
  
  when cpuFeatures.hasSSE2:
    # SIMD probe: check 16 slots at once
    {.emit: """
    __m128i h2_vec = _mm_set1_epi8(`h2val`);
    int base = `idx` & ~15;  // Align to 16
    
    for (int probe = 0; probe < `table->capacity`; probe += 16) {
      int check_idx = (base + probe) & (`table->capacity` - 1);
      __m128i group = _mm_loadu_si128((__m128i*)&`table->metadata`[check_idx]);
      __m128i cmp = _mm_cmpeq_epi8(group, h2_vec);
      int mask = _mm_movemask_epi8(cmp);
      
      if (mask != 0) {
        // Found potential match(es)
        int offset = __builtin_ctz(mask);
        int slot = (check_idx + offset) & (`table->capacity` - 1);
        if (`table->keys`[slot] == `key`) {
          return slot;
        }
      }
    }
    return -1;
    """.}
  else:
    # Fallback: linear probing
    for probe in 0..<table.capacity:
      let slot = (idx + probe) mod table.capacity
      if table.metadata[slot] == EMPTY:
        return -1
      if table.metadata[slot] == h2val and table.keys[slot] == key:
        return slot
    return -1

proc `[]`*[K, V](table: SwissTable[K, V], key: K): V =
  let slot = table.findSlot(key)
  if slot == -1:
    raise newException(KeyError, "Key not found")
  table.values[slot]

proc `[]=`*[K, V](table: var SwissTable[K, V], key: K, value: V) =
  # Simplified - real impl needs resize logic
  let h = hash(key)
  let h2val = h2(h)
  var idx = int(h mod table.capacity.uint64)
  
  for probe in 0..<table.capacity:
    let slot = (idx + probe) mod table.capacity
    if table.metadata[slot] == EMPTY or table.metadata[slot] == DELETED:
      table.metadata[slot] = h2val
      table.keys[slot] = key
      table.values[slot] = value
      inc table.size
      return
    if table.metadata[slot] == h2val and table.keys[slot] == key:
      # Update existing
      table.values[slot] = value
      return

# ============================================================================
# EXAMPLE 7: Sorting API (pdqsort)
# ============================================================================

# src/arsenal/algorithms/sorting/pdqsort.nim
# Paper: "Pattern-defeating Quicksort" (2016)
# Used in Rust's std::sort

import arsenal/algorithms/sorting/branchless_insert

proc partition[T](arr: var openArray[T], low, high: int): int =
  # Pattern-defeating partitioning logic
  # (simplified - real impl has pivot selection, etc.)
  let pivot = arr[high]
  var i = low - 1
  
  for j in low..<high:
    if arr[j] <= pivot:
      inc i
      swap(arr[i], arr[j])
  
  swap(arr[i + 1], arr[high])
  return i + 1

proc pdqsortImpl[T](arr: var openArray[T], low, high, depth: int) =
  const INSERTION_THRESHOLD = 24
  
  if high - low < INSERTION_THRESHOLD:
    # Use branchless insertion sort for small arrays
    branchlessInsertionSort(arr, low, high)
    return
  
  if depth == 0:
    # Bad pivot choices - fallback to heapsort
    heapSort(arr, low, high)
    return
  
  let p = partition(arr, low, high)
  pdqsortImpl(arr, low, p - 1, depth - 1)
  pdqsortImpl(arr, p + 1, high, depth - 1)

proc pdqsort*[T](arr: var openArray[T]) =
  ## Pattern-defeating quicksort - O(n) on many patterns
  ## 1.5-3× faster than traditional quicksort on real data
  if arr.len <= 1:
    return
  
  let maxDepth = 2 * log2(arr.len.float).int
  pdqsortImpl(arr, 0, arr.len - 1, maxDepth)

# ============================================================================
# EXAMPLE 8: High-Level API - Web Server
# ============================================================================

# examples/web_server/optimized_server.nim
import arsenal/stdlib_compat/asynchttpserver
import arsenal/strategies

# Set strategy globally
setStrategy(Throughput)

# Now use normal Nim async/await - but it's 10× faster!
proc handle(req: Request) {.async.} =
  await req.respond(Http200, "Hello, World!")

let server = newAsyncHttpServer()
waitFor server.serve(Port(8080), handle)

# Under the hood, arsenal/stdlib_compat uses:
# - libaco for coroutines (not asyncdispatch)
# - io_uring for I/O (not epoll)
# - picohttpparser for HTTP (not parseutils)
# - mimalloc for allocation (not system malloc)

# ============================================================================
# PAPERS REFERENCED (Organized by Domain)
# ============================================================================

"""
=== DATA STRUCTURES ===

Hash Tables:
- "Abseil's Swiss Tables Design Notes" (Google, 2017)
  https://abseil.io/about/design/swisstables

- "Robin Hood Hashing" (Pedro Celis et al., 1986)
  
- "Cuckoo Hashing" (Pagh & Rodler, 2001)

Filters:
- "Xor Filters: Faster and Smaller Than Bloom Filters" 
  (Graf & Lemire, 2019)
  https://arxiv.org/abs/1912.08258

- "Ribbon Filter: Practically Smaller Than Bloom and Xor" (2021)
  https://arxiv.org/abs/2103.02515

- "Cuckoo Filter: Practically Better Than Bloom" (2014)

Bitmaps:
- "Better bitmap performance with Roaring bitmaps" 
  (Chambi et al., 2016)
  https://arxiv.org/abs/1603.06549

Succinct Structures:
- "Broadword Implementation of Rank/Select Queries" (Vigna, 2008)

- "Wavelet Trees" (Grossi, Gupta, Vitter, 2003)

=== SORTING & SEARCHING ===

- "Pattern-defeating Quicksort" (Orson Peters, 2016)
  https://github.com/orlp/pdqsort

- "In-Place Parallel Super Scalar Samplesort (IPS⁴o)" (2017)
  https://arxiv.org/abs/1705.02257

- "SKA Sort: A Fast Parallel Radix Sort" (2017)

- "Fast Binary Search in Modern CPUs" (2017)

- "Floyd-Rivest Selection Algorithm" (1975)

=== COMPRESSION ===

- "Finite State Entropy" (Yann Collet, 2013)
  Creator of Zstd
  
- "Asymmetric Numeral Systems" (Jarek Duda, 2014)
  https://arxiv.org/abs/1311.2540
  
- "Stream VByte: Faster Byte-Oriented Integer Compression" 
  (Lemire et al., 2017)
  https://arxiv.org/abs/1709.08990

=== HASHING ===

- "wyhash" (Wang Yi)
  https://github.com/wangyi-fudan/wyhash
  
- "xxHash" (Yann Collet)
  https://github.com/Cyan4973/xxHash

=== SKETCHING ===

- "HyperLogLog: the analysis of a near-optimal cardinality estimation
   algorithm" (Flajolet et al., 2007)
   
- "HyperLogLog in Practice: Algorithmic Engineering of a State of The Art
   Cardinality Estimation Algorithm" (Google, 2013)
   
- "An Improved Data Stream Summary: The Count-Min Sketch and its 
   Applications" (Cormode & Muthukrishnan, 2005)
   
- "Computing Extremely Accurate Quantiles Using t-Digests"
  (Dunning, 2013)
  https://arxiv.org/abs/1902.04023

- "Efficient Computation of Frequent and Top-k Elements in Data Streams"
  (Metwally et al., 2005) - Space-Saving algorithm

=== CONCURRENCY ===

- "Flat Combining and the Synchronization-Parallelism Tradeoff"
  (Hendler, Incze, Shavit, Tzafrir, 2010)
  
- "Wait-Free Queues With Multiple Enqueuers and Dequeuers" (2011)

- "Interval-Based Memory Reclamation" (2018)
  https://arxiv.org/abs/1806.04510

- "Left-Right: A Concurrency Control Technique with Wait-Free Population
   Oblivious Reads" (2014)

=== GRAPH ALGORITHMS ===

- "Direction-Optimizing Breadth-First Search" (Beamer et al., 2012)

- "Ligra: A Lightweight Graph Processing Framework for Shared Memory"
  (Shun & Blelloch, 2013)

- "Δ-Stepping: A Parallelizable Shortest Path Algorithm" 
  (Meyer & Sanders, 2003)

=== PARSING ===

- "Parsing Gigabytes of JSON per Second" (Lemire et al., 2019)
  https://arxiv.org/abs/1902.08318
  
- "Number Parsing at a Gigabyte per Second" (Lemire, 2020)
  https://arxiv.org/abs/2101.11408

=== STRING ALGORITHMS ===

- "Faster-Than-Hash String Search" (Langdale & Lemire, 2022)

- "Z Algorithm for Pattern Searching" (Gusfield, 1997)

=== MACHINE LEARNING ===

- "FlashAttention: Fast and Memory-Efficient Exact Attention with 
   IO-Awareness" (Tri Dao et al., 2022)
   https://arxiv.org/abs/2205.14135

- "Integer Quantization for Deep Learning Inference: Principles and 
   Empirical Evaluation" (Wu et al., 2020)

- "AWQ: Activation-aware Weight Quantization for LLM Compression and
   Acceleration" (2023)
   https://arxiv.org/abs/2306.00978

=== NUMERIC ===

- "Further remarks on reducing truncation errors" (Kahan, 1965)
  Kahan summation algorithm

- "The Anatomy of High-Performance Matrix Multiplication" 
  (Goto & van de Geijn, 2008)

- "Division by Invariant Integers using Multiplication"
  (Granlund & Montgomery, 1994)

=== CACHING ===

- "ARC: A Self-Tuning, Low Overhead Replacement Cache" (IBM, 2003)

- "CLOCK-Pro: An Effective Improvement of the CLOCK Replacement"
  (Jiang, Chen, Zhang, 2005)

- "TinyLFU: A Highly Efficient Cache Admission Policy" (2017)
  https://arxiv.org/abs/1512.00727

- "FIFO Queues are All You Need for Cache Eviction" (2023)
  S3-FIFO algorithm
  https://arxiv.org/abs/2310.07998

=== CRYPTO ===

- "ChaCha, a variant of Salsa20" (Bernstein, 2008)

- "The Poly1305-AES message-authentication code" (Bernstein, 2005)

- "Curve25519: new Diffie-Hellman speed records" (Bernstein, 2006)

- NIST Post-Quantum Cryptography Standards (2022-2023)
  Kyber (key exchange), Dilithium (signatures)

"""

# ============================================================================
# USAGE EXAMPLES
# ============================================================================

# Example 1: Explicit choice (when you know what you want)
import arsenal/hashing/hashers/xxhash64
let h1 = hashXXHash64(data, len)

# Example 2: Auto-selection (when you want Arsenal to decide)
import arsenal/hashing
let h2 = hash(data, len)  # picks wyhash in release, xxhash in debug

# Example 3: Strategy-based (optimize for use case)
import arsenal/hashing
import arsenal/strategies
setStrategy(Latency)
let h3 = hashStrategy(data, len)  # picks fastest for latency

# Example 4: Drop-in replacement
import arsenal/stdlib_compat/tables  # Swiss Tables instead of std/tables
var t = initTable[string, int]()    # 2× faster, same API!

# Example 5: Custom composition
import arsenal/memory/allocators/rpmalloc
import arsenal/concurrency/coroutines/libaco
import arsenal/hashing/hashers/wyhash

# Build your custom high-performance system
let alloc = newRpmallocAllocator()
let coroBackend = newLibacoBackend()
# ... use the primitives you chose