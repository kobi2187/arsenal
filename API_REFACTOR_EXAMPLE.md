# API Refactor Example
## Concrete transformation of HyperLogLog to unified API

This shows exactly how we'd transform one module (HyperLogLog) to the new unified API, demonstrating all patterns.

---

## Current API (Before)

```nim
# Current usage
import arsenal/sketching/cardinality/hyperloglog

var hll = initHyperLogLog(precision = 14)
hll.add("user_123")
hll.add("user_456")

let count = hll.cardinality()
let bytes = hll.toBytes()
let restored = fromBytes(bytes)

hll.merge(other)
```

---

## Proposed API (After)

### Layer 1: Direct Type API (Zero-Cost)

```nim
# src/arsenal/sketching/cardinality/hyperloglog.nim

type
  HyperLogLog* = object
    p: int
    m: int
    registers: seq[uint8]
    alphaMm2: float64

  HyperLogLogBuilder* = object
    precision: int
    hashSeed: uint64

# ============================================================================
# BUILDER PATTERN
# ============================================================================

proc new*(_: typedesc[HyperLogLog], precision: int = 14): HyperLogLogBuilder =
  ## Create builder for HyperLogLog
  ##
  ## Example:
  ##   var hll = HyperLogLog.new(14).build()
  HyperLogLogBuilder(precision: precision, hashSeed: 0)

proc withHashSeed*(builder: HyperLogLogBuilder, seed: uint64): HyperLogLogBuilder =
  ## Set custom hash seed (for reproducibility)
  result = builder
  result.hashSeed = seed

proc build*(builder: HyperLogLogBuilder): HyperLogLog =
  ## Construct HyperLogLog from builder
  # Implementation same as current initHyperLogLog
  result = ...

# Direct construction (backwards compat)
proc init*(_: typedesc[HyperLogLog], precision: int = 14): HyperLogLog {.inline.} =
  ## Direct construction without builder
  HyperLogLog.new(precision).build()

# ============================================================================
# CORE OPERATIONS (Sketch trait)
# ============================================================================

proc add*(hll: var HyperLogLog, value: string) =
  ## Add element to sketch
  # ... current implementation

proc add*(hll: var HyperLogLog, value: openArray[byte]) =
  ## Add raw bytes
  # ... current implementation

proc add*[T](hll: var HyperLogLog, value: T) =
  ## Add any hashable value
  # ... current implementation

proc estimate*(hll: HyperLogLog): int64 {.inline.} =
  ## Estimate cardinality (primary method)
  hll.cardinality()

proc cardinality*(hll: HyperLogLog): int64 =
  ## Estimate cardinality (alias for backwards compat)
  # ... current implementation

proc merge*(hll: var HyperLogLog, other: HyperLogLog) =
  ## Merge another HyperLogLog
  # ... current implementation

proc clear*(hll: var HyperLogLog) =
  ## Reset to empty state
  # ... current implementation

# ============================================================================
# METADATA (Sketch trait)
# ============================================================================

proc len*(hll: HyperLogLog): int64 {.inline.} =
  ## Element count (estimated)
  hll.estimate()

proc size*(hll: HyperLogLog): int {.inline.} =
  ## Number of registers
  hll.m

proc memoryUsage*(hll: HyperLogLog): int =
  ## Memory usage in bytes
  hll.m + 16

proc precision*(hll: HyperLogLog): int {.inline.} =
  ## Get precision parameter
  hll.p

proc expectedError*(hll: HyperLogLog): float64 =
  ## Expected relative error
  1.04 / sqrt(hll.m.float64)

# ============================================================================
# SERIALIZATION
# ============================================================================

proc toBytes*(hll: HyperLogLog): seq[byte] =
  ## Serialize to bytes
  # ... current implementation

proc fromBytes*(_: typedesc[HyperLogLog], data: openArray[byte]): HyperLogLog =
  ## Deserialize from bytes
  ##
  ## Example:
  ##   let hll = HyperLogLog.fromBytes(data)
  # ... current implementation

proc `$`*(hll: HyperLogLog): string =
  ## String representation
  # ... current implementation

# ============================================================================
# PRESETS (Convenience)
# ============================================================================

proc fast*(_: typedesc[HyperLogLog]): HyperLogLog {.inline.} =
  ## Fast preset: lower accuracy, less memory
  HyperLogLog.new(10).build()

proc balanced*(_: typedesc[HyperLogLog]): HyperLogLog {.inline.} =
  ## Balanced preset: good accuracy/memory trade-off (default)
  HyperLogLog.new(14).build()

proc accurate*(_: typedesc[HyperLogLog]): HyperLogLog {.inline.} =
  ## Accurate preset: high accuracy, more memory
  HyperLogLog.new(16).build()
```

### Usage Examples

```nim
# ============================================================================
# USAGE: Various styles all supported
# ============================================================================

import arsenal/sketching/cardinality/hyperloglog

# Style 1: Builder pattern (most explicit)
var hll1 = HyperLogLog.new(precision = 14)
  .withHashSeed(12345)
  .build()

# Style 2: Direct construction (concise)
var hll2 = HyperLogLog.new(14).build()

# Style 3: Preset (fastest to write)
var hll3 = HyperLogLog.balanced()

# Style 4: Old style (backwards compat)
var hll4 = HyperLogLog.init(14)

# All work the same way
hll1.add("user_123")
hll2.add(42)
hll3.add([1'u8, 2, 3])

# Unified query methods
echo hll1.estimate()      # Primary method
echo hll1.cardinality()   # Alias (backwards compat)
echo hll1.len()           # Nim-style

# Serialization
let bytes = hll1.toBytes()
let restored = HyperLogLog.fromBytes(bytes)

# Merging
hll1.merge(hll2)
```

---

## Layer 2: Domain Module (Convenience)

```nim
# src/arsenal/sketching.nim
## High-level sketching module with unified exports

import arsenal/sketching/cardinality/hyperloglog
import arsenal/sketching/quantiles/tdigest
import arsenal/sketching/membership/xorfilter

export hyperloglog, tdigest, xorfilter

# Convenience constructors (auto-import sugar)
template newHyperLogLog*(precision: int = 14): HyperLogLog =
  HyperLogLog.new(precision).build()

template newTDigest*(compression: float64 = 100.0): TDigest =
  TDigest.new(compression).build()

# Usage
import arsenal/sketching

var hll = newHyperLogLog(14)  # Clean, simple
var td = newTDigest(100)      # No builder ceremony
```

---

## Layer 3: Manager Pattern (Workflows)

```nim
# src/arsenal/analytics/stream_analyzer.nim
## Manager for analyzing streams with multiple sketches

import arsenal/sketching

type
  StreamAnalyzer* = object
    cardinality: HyperLogLog
    quantiles: TDigest
    observations: int

  AnalyzerBuilder* = object
    cardinalityPrecision: int
    quantileCompression: float64

# Builder
proc new*(_: typedesc[StreamAnalyzer]): AnalyzerBuilder =
  AnalyzerBuilder(
    cardinalityPrecision: 14,
    quantileCompression: 100.0
  )

proc withCardinalityPrecision*(b: AnalyzerBuilder, p: int): AnalyzerBuilder =
  result = b
  result.cardinalityPrecision = p

proc withQuantileCompression*(b: AnalyzerBuilder, c: float64): AnalyzerBuilder =
  result = b
  result.quantileCompression = c

proc build*(b: AnalyzerBuilder): StreamAnalyzer =
  StreamAnalyzer(
    cardinality: HyperLogLog.new(b.cardinalityPrecision).build(),
    quantiles: TDigest.new(b.quantileCompression).build(),
    observations: 0
  )

# Operations
proc observe*(sa: var StreamAnalyzer, value: float64) =
  ## Add observation to all sketches
  sa.cardinality.add($value.int)
  sa.quantiles.add(value)
  inc sa.observations

proc uniqueCount*(sa: StreamAnalyzer): int64 =
  sa.cardinality.estimate()

proc percentile*(sa: var StreamAnalyzer, p: float64): float64 =
  sa.quantiles.quantile(p)

proc summary*(sa: var StreamAnalyzer): string =
  ## Get summary statistics
  result = "Observations: " & $sa.observations & "\n"
  result &= "Unique: " & $sa.uniqueCount() & "\n"
  result &= "P50: " & $sa.percentile(0.5) & "\n"
  result &= "P95: " & $sa.percentile(0.95) & "\n"
  result &= "P99: " & $sa.percentile(0.99) & "\n"

# Usage
import arsenal/analytics

var analyzer = StreamAnalyzer.new()
  .withCardinalityPrecision(16)
  .withQuantileCompression(200)
  .build()

for value in dataStream:
  analyzer.observe(value)

echo analyzer.summary()
```

---

## Trait/Concept Definition

```nim
# src/arsenal/traits/sketch.nim
## Sketch trait for all probabilistic data structures

type
  Sketch*[T] = concept sketch, var mutableSketch
    ## A sketch is a probabilistic data structure for streaming statistics

    # Mutation
    mutableSketch.add(T)
    mutableSketch.clear()

    # Query
    sketch.estimate() is int64
    sketch.len() is int64

    # Metadata
    sketch.size() is int
    sketch.memoryUsage() is int

    # Serialization
    sketch.toBytes() is seq[byte]

    # Merging
    mutableSketch.merge(sketch.type)

# Generic functions work with any sketch
proc estimateCardinality*[T](sketch: Sketch[T]): int64 =
  sketch.estimate()

proc compressionRatio*[T](sketch: Sketch[T]): float64 =
  sketch.len().float64 / sketch.memoryUsage().float64
```

---

## Side-by-Side Comparison

### OLD (Current)
```nim
var hll = initHyperLogLog(14)
hll.add("user")
let count = hll.cardinality()
let bytes = hll.toBytes()
let hll2 = fromBytes(bytes)
```

### NEW (Unified)
```nim
# Option A: Builder
var hll = HyperLogLog.new(14).build()

# Option B: Preset
var hll = HyperLogLog.balanced()

# Option C: Backwards compat
var hll = HyperLogLog.init(14)

# All use same methods
hll.add("user")
let count = hll.estimate()        # Primary
let count2 = hll.cardinality()    # Alias
let count3 = hll.len()            # Nim-style

# Serialization more discoverable
let bytes = hll.toBytes()
let hll2 = HyperLogLog.fromBytes(bytes)
```

---

## Migration Guide

### Breaking Changes
- `initHyperLogLog()` → `HyperLogLog.new().build()` or `HyperLogLog.init()`
- Standalone `fromBytes()` → `HyperLogLog.fromBytes()`

### Non-Breaking Additions
- Added `.estimate()` (primary method)
- Added `.len()` (Nim convention)
- Added presets: `.fast()`, `.balanced()`, `.accurate()`
- Added builder: `.new()`, `.withHashSeed()`, `.build()`

### Backwards Compatibility Layer
```nim
# Keep old API working
proc initHyperLogLog*(precision: int = 14): HyperLogLog {.deprecated: "Use HyperLogLog.new(p).build()".} =
  HyperLogLog.init(precision)

proc fromBytes*(data: openArray[byte]): HyperLogLog {.deprecated: "Use HyperLogLog.fromBytes()".} =
  HyperLogLog.fromBytes(data)
```

---

## Benefits of New API

1. **Discoverable**: `HyperLogLog.` shows all constructors/presets via autocomplete
2. **Consistent**: All types follow same pattern
3. **Flexible**: Multiple construction styles supported
4. **Zero-cost**: Builders inline to direct construction
5. **Testable**: Builders allow dependency injection
6. **Nim-idiomatic**: Uses `len()`, standard naming
7. **Backwards compatible**: Old API still works (with deprecation warnings)

---

## Implementation Checklist

- [ ] Add `HyperLogLogBuilder` type
- [ ] Add `.new()` constructor
- [ ] Add `.build()` method
- [ ] Add `.estimate()` as primary method
- [ ] Add `.len()` Nim convention
- [ ] Add presets: `.fast()`, `.balanced()`, `.accurate()`
- [ ] Move `fromBytes()` to type method
- [ ] Add deprecation warnings to old API
- [ ] Update tests
- [ ] Update documentation
- [ ] Add examples

---

This same pattern applies to all other types:
- `TDigest.new(compression).build()`
- `XorFilter8.new().from(keys)`
- `RoaringBitmap.new().build()`
- `S3FIFOCache[K,V].new(capacity).build()`
- `StreamVByte.new().withDeltaEncoding().build()`

Should I proceed with implementing this unified API?
