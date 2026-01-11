## CPU Feature Detection & Platform Configuration
## ==============================================
##
## Provides runtime and compile-time detection of CPU features
## for optimal code path selection.
##
## Usage:
## ```nim
## let features = detectCpuFeatures()
## if features.hasAVX2:
##   useAVX2Implementation()
## else:
##   useScalarImplementation()
## ```

import std/[os, osproc]

type
  CpuVendor* = enum
    cvUnknown = "Unknown"
    cvIntel = "Intel"
    cvAMD = "AMD"
    cvARM = "ARM"
    cvApple = "Apple"

  CpuFeatures* = object
    ## Runtime-detected CPU capabilities.
    ## All fields are `false` by default until `detectCpuFeatures()` is called.
    vendor*: CpuVendor
    brandString*: string

    # x86/x86_64 features
    hasSSE*: bool
    hasSSE2*: bool
    hasSSE3*: bool
    hasSSSE3*: bool
    hasSSE41*: bool
    hasSSE42*: bool
    hasAVX*: bool
    hasAVX2*: bool
    hasAVX512F*: bool      ## AVX-512 Foundation
    hasAVX512BW*: bool     ## AVX-512 Byte/Word
    hasAVX512VL*: bool     ## AVX-512 Vector Length
    hasFMA*: bool          ## Fused Multiply-Add
    hasBMI1*: bool         ## Bit Manipulation Instructions 1
    hasBMI2*: bool         ## Bit Manipulation Instructions 2 (PEXT, PDEP)
    hasPopcnt*: bool       ## Population Count
    hasLzcnt*: bool        ## Leading Zero Count
    hasAESNI*: bool        ## AES-NI instructions
    hasCLMUL*: bool        ## Carry-less Multiplication (for CRC)
    hasRDRAND*: bool       ## Hardware RNG
    hasRDSEED*: bool       ## Hardware RNG seed
    hasRDTSC*: bool        ## Timestamp Counter
    hasRDTSCP*: bool       ## Ordered Timestamp Counter

    # ARM features
    hasNEON*: bool         ## ARM SIMD
    hasSVE*: bool          ## Scalable Vector Extension
    hasSVE2*: bool
    hasCRC32*: bool        ## Hardware CRC32
    hasAES*: bool          ## ARM AES instructions
    hasSHA1*: bool
    hasSHA256*: bool
    hasAtomics*: bool      ## ARMv8.1 atomics (LSE)

    # Cache info
    l1DataCacheSize*: int  ## L1 data cache size in bytes
    l1ICacheSize*: int     ## L1 instruction cache size
    l2CacheSize*: int      ## L2 cache size in bytes
    l3CacheSize*: int      ## L3 cache size in bytes
    cacheLineSize*: int    ## Cache line size (typically 64 bytes)

  PlatformInfo* = object
    ## Static platform information available at compile time.
    os*: string
    arch*: string
    ptrSize*: int
    pageSize*: int
    cpuCount*: int

# =============================================================================
# Compile-Time Platform Constants
# =============================================================================

const
  IsX86* = defined(i386) or defined(amd64)
  IsX64* = defined(amd64)
  IsARM* = defined(arm) or defined(arm64)
  IsARM64* = defined(arm64)
  IsWindows* = defined(windows)
  IsLinux* = defined(linux)
  IsMacOS* = defined(macosx)
  IsBSD* = defined(freebsd) or defined(openbsd) or defined(netbsd)
  IsPosix* = defined(posix)

  DefaultCacheLineSize* = 64
  DefaultPageSize* = 4096

# =============================================================================
# CPU Feature Detection
# =============================================================================

proc detectCpuFeatures*(): CpuFeatures =
  ## Detects CPU features at runtime using CPUID (x86) or system APIs (ARM).
  ##
  ## IMPLEMENTATION NOTES:
  ##
  ## For x86/x86_64:
  ## 1. Use CPUID instruction via inline asm or `{.emit.}`
  ## 2. Call CPUID with EAX=0 to get vendor string
  ## 3. Call CPUID with EAX=1, check ECX/EDX for SSE, AVX, etc.
  ## 4. Call CPUID with EAX=7, ECX=0 for AVX2, BMI, AVX-512
  ## 5. For AVX, also check XGETBV to verify OS support
  ##
  ## Example x86_64 implementation:
  ## ```nim
  ## var eax, ebx, ecx, edx: uint32
  ## {.emit: """
  ##   __asm__ __volatile__ (
  ##     "cpuid"
  ##     : "=a"(`eax`), "=b"(`ebx`), "=c"(`ecx`), "=d"(`edx`)
  ##     : "a"(1), "c"(0)
  ##   );
  ## """.}
  ## result.hasSSE2 = (edx and (1 shl 26)) != 0
  ## result.hasAVX = (ecx and (1 shl 28)) != 0
  ## ```
  ##
  ## For ARM64:
  ## - Linux: Read `/proc/cpuinfo` or use `getauxval(AT_HWCAP)`
  ## - macOS: Use `sysctlbyname("hw.optional.neon", ...)`
  ## - Windows: Use `IsProcessorFeaturePresent()`
  ##
  ## For cache sizes:
  ## - x86: CPUID leaf 0x04 (deterministic cache params)
  ## - Linux: Read `/sys/devices/system/cpu/cpu0/cache/index*/size`
  ## - macOS: `sysctlbyname("hw.l1dcachesize", ...)`

  result = CpuFeatures(
    vendor: cvUnknown,
    cacheLineSize: DefaultCacheLineSize
  )

  when IsX64:
    # TODO: Implement CPUID detection
    # For now, assume modern baseline
    result.hasSSE2 = true
    result.hasRDTSC = true
  elif IsARM64:
    result.hasNEON = true  # Always available on ARM64

  # Stub - needs platform-specific implementation
  discard

proc getPlatformInfo*(): PlatformInfo =
  ## Returns static platform information.
  result = PlatformInfo(
    os: hostOS,
    arch: hostCPU,
    ptrSize: sizeof(pointer),
    pageSize: DefaultPageSize,
    cpuCount: countProcessors()
  )

# =============================================================================
# Feature Check Templates (Compile-Time)
# =============================================================================

template withSSE2*(body: untyped) =
  ## Execute body only if SSE2 is available (compile-time check).
  when defined(amd64) or defined(i386):
    body

template withAVX2*(body: untyped) =
  ## Execute body only if compiled with AVX2 support.
  ## Use `-d:avx2` or `-march=haswell` when compiling.
  when defined(avx2):
    body

template withNEON*(body: untyped) =
  ## Execute body only if NEON is available.
  when defined(arm64) or defined(arm):
    body

# =============================================================================
# Global Feature Cache
# =============================================================================

var cpuFeaturesCache: CpuFeatures
var cpuFeaturesInitialized = false

proc getCpuFeatures*(): CpuFeatures =
  ## Returns cached CPU features. Thread-safe after first call.
  ## Call this instead of `detectCpuFeatures()` for repeated access.
  if not cpuFeaturesInitialized:
    cpuFeaturesCache = detectCpuFeatures()
    cpuFeaturesInitialized = true
  result = cpuFeaturesCache
