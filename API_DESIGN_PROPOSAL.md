# Arsenal API Design Proposal
## Unified, Ergonomic Interface Options

After analyzing the current implementations, here are **3 API design options** ranging from pragmatic to sophisticated:

---

## Current State Analysis

### Issues with Current APIs

```nim
# INCONSISTENT CONSTRUCTORS
var hll = initHyperLogLog(14)           # init* prefix
let filter = buildXorFilter8(keys)      # build* prefix
var rb = initRoaringBitmap()            # init* prefix
let (ctrl, data) = encodeStreamVByte()  # functional

# INCONSISTENT METHOD NAMES
hll.cardinality()      # full word
filter.contains()      # full word
rb.cardinality()       # same as HLL, good!
td.quantile(0.95)      # full word
cache.get(key)         # short word

# INCONSISTENT PATTERNS
hll.add(value)                    # mutable receiver
let filter = buildXorFilter8()    # immutable builder
rb.add(value)                     # mutable receiver
let encoded = encode()            # functional
```

---

## Option 1: **Trait-Based Unified API** (Recommended)

### Philosophy
- Define **domain-specific traits** for each category
- Consistent methods across implementations
- Fluent builders where appropriate
- Manager classes for common workflows

### Core Traits

```nim
# ============================================================================
# TRAIT DEFINITIONS
# ============================================================================

type
  # Sketching (approximate counting/statistics)
  Sketch*[T] = concept sketch, var mutableSketch
    ## Probabilistic data structures for streaming statistics
    mutableSketch.add(T)              # Add element
    sketch.estimate() is int64        # Get estimate
    sketch.size() is int              # Memory usage
    sketch.merge(Sketch[T])           # Merge sketches
    sketch.clear()                    # Reset

  # Membership testing (approximate set)
  Filter*[T] = concept filter
    ## Probabilistic membership testing
    filter.contains(T) is bool
    filter.mightContain(T) is bool    # Alias for clarity
    filter.falsePositiveRate() is float64
    filter.size() is int              # Number of elements
    filter.memoryUsage() is int

  # Collections (compressed sets/maps)
  CompressedSet*[T] = concept set, var mutableSet
    ## Space-efficient set implementations
    mutableSet.add(T)
    mutableSet.remove(T) is bool
    set.contains(T) is bool
    set.len() is int
    set.union(CompressedSet[T]) is CompressedSet[T]
    set.intersection(CompressedSet[T]) is CompressedSet[T]

  # Compression codecs
  Codec*[T] = concept codec
    ## Encode/decode data
    codec.encode(openArray[T]) is seq[byte]
    codec.decode(openArray[byte]) is seq[T]
    codec.compressionRatio() is float64

  # Caching
  Cache*[K, V] = concept cache, var mutableCache
    ## Cache with eviction policies
    cache.get(K) is Option[V]
    mutableCache.put(K, V)
    mutableCache.remove(K) is bool
    cache.len() is int
    cache.hitRate() is float64
```

### Unified Constructor Pattern

```nim
# ============================================================================
# BUILDER PATTERN - Fluent, Discoverable
# ============================================================================

# Sketching
var hll = HyperLogLog.new(precision = 14)
  .withHasher(XXHash64)       # Optional
  .build()

var digest = TDigest.new(compression = 100)
  .withScaleFunction(K2)
  .build()

# Membership
let filter = XorFilter8.new()
  .withKeys(["alice", "bob", "charlie"])
  .build()

# Alternative functional style for immutable filters
let filter2 = XorFilter8.from(keys)  # Shorthand

# Collections
var bitmap = RoaringBitmap.new()
  .withInitialCapacity(1000)
  .build()

# Caching
var cache = S3FIFOCache[string, int].new(capacity = 1000)
  .withSmallRatio(0.1)
  .build()

# Compression
let codec = StreamVByte.new()
  .withDeltaEncoding()
  .build()
```

### Unified Method Names

```nim
# ============================================================================
# CONSISTENT METHOD NAMING
# ============================================================================

# ADD/INSERT operations → add()
sketch.add(value)
bitmap.add(42)
cache.put(key, value)  # put() for key-value, add() for sets

# QUERY operations → contains() / get()
filter.contains(value)
bitmap.contains(42)
cache.get(key)

# SIZE operations → len() / size() / memoryUsage()
sketch.len()           # Element count (exact or estimate)
sketch.size()          # Memory in elements/centroids
sketch.memoryUsage()   # Memory in bytes

# STATISTICS → specific to domain
sketch.estimate()      # HyperLogLog cardinality
digest.quantile(0.95)  # t-Digest percentile
cache.hitRate()        # S3-FIFO hit rate
filter.falsePositiveRate()  # Xor filter FPR

# SERIALIZATION → toBytes() / fromBytes()
let bytes = sketch.toBytes()
let restored = HyperLogLog.fromBytes(bytes)
```

---

## Option 2: **Manager Pattern + Low-Level API**

### Philosophy
- High-level managers orchestrate common workflows
- Low-level types for direct control
- Manager handles integration and best practices

```nim
# ============================================================================
# HIGH-LEVEL MANAGERS
# ============================================================================

type
  SketchManager* = object
    ## Manages multiple sketch types for different use cases
    cardinalityEstimator*: HyperLogLog
    quantileEstimator*: TDigest

  FilterManager* = object
    ## Manages filters with automatic selection
    filters*: Table[string, AnyFilter]

  CacheManager* = object
    ## Multi-tier caching with automatic eviction
    l1*: S3FIFOCache[K, V]
    l2*: Option[S3FIFOCache[K, V]]

# Usage - High Level
var sketches = SketchManager.new()
  .forCardinality(precision = 14)
  .forQuantiles(compression = 100)
  .build()

# Add data through manager
sketches.observe(user_id)        # Automatically updates both sketches

# Query through manager
echo "Unique users: ", sketches.uniqueCount()
echo "P95 latency: ", sketches.percentile(0.95)

# Usage - Low Level (direct access)
sketches.cardinalityEstimator.add(value)  # Direct control
sketches.quantileEstimator.quantile(0.99)

# ============================================================================
# SPECIALIZED MANAGERS
# ============================================================================

# Cache Manager with automatic tiering
var cacheManager = CacheManager[string, Data].new()
  .withL1(capacity = 1000, policy = S3FIFO)
  .withL2(capacity = 10000, policy = LRU)
  .withMetrics()
  .build()

# Automatic L1 → L2 promotion
let data = cacheManager.get("key")  # Checks L1, then L2

# Compression Manager with automatic codec selection
var compression = CompressionManager.new()
  .forIntegers(codec = StreamVByte)
  .forStrings(codec = Zstd)
  .withDeltaEncoding(enabled = true)
  .build()

# Automatic codec selection based on type
let compressed = compression.compress(integers)  # Uses StreamVByte
let compressed2 = compression.compress(strings)  # Uses Zstd
```

---

## Option 3: **Domain-Specific Modules** (Simplest)

### Philosophy
- Each domain has consistent internal API
- Simple imports, clear namespaces
- No complex abstractions

```nim
# ============================================================================
# DOMAIN MODULES WITH CONSISTENT STYLE
# ============================================================================

# Sketching module
import arsenal/sketching

# Unified style within domain
var cardinality = newHyperLogLog(precision = 14)
var quantiles = newTDigest(compression = 100)

cardinality.add(value)
quantiles.add(value)

echo cardinality.estimate()
echo quantiles.percentile(0.95)

# Membership module
import arsenal/filters

var filter = newXorFilter8(keys)
echo filter.contains("alice")
echo filter.stats()  # Unified stats() method

# Collections module
import arsenal/collections

var bitmap = newRoaring()
bitmap.add(42)
echo bitmap.contains(42)

# Compression module
import arsenal/compression

let (ctrl, data) = streamvbyte.encode(values)
let decoded = streamvbyte.decode(ctrl, data, count)

# Caching module
import arsenal/caching

var cache = newS3FIFO[string, int](capacity = 1000)
cache.put("key", 100)
echo cache.get("key")
```

---

## Recommended Hybrid Approach

Combine the best of all options:

```nim
# ============================================================================
# RECOMMENDED: TRAITS + BUILDERS + MANAGERS
# ============================================================================

# Layer 1: Core types with traits (low-level, direct)
import arsenal/sketching/hyperloglog
var hll = HyperLogLog.new(14).build()
hll.add(value)
echo hll.estimate()

# Layer 2: Builders for ergonomics (mid-level)
import arsenal/sketching
var digest = sketching.newTDigest()
  .withCompression(100)
  .withScaleFunction(K2)
  .build()

# Layer 3: Managers for workflows (high-level)
import arsenal/analytics
var analytics = Analytics.new()
  .trackCardinality(precision = 14)
  .trackQuantiles(compression = 100)
  .build()

analytics.observe(event)
echo analytics.summary()  # Unified reporting
```

---

## Naming Conventions

### Unified Across All Options

```nim
# CONSTRUCTORS
TypeName.new(args)         # Builder entry point
newTypeName(args)          # Direct construction
TypeName.from(data)        # From existing data
TypeName.fromBytes(bytes)  # Deserialization

# MUTATION
obj.add(element)           # Add to collection/sketch
obj.put(key, value)        # Add to key-value store
obj.remove(element)        # Remove from collection
obj.clear()                # Remove all

# QUERY
obj.contains(element)      # Membership test
obj.get(key)               # Retrieve value
obj.len()                  # Element count
obj.size()                 # Size in elements/items
obj.memoryUsage()          # Size in bytes

# STATISTICS
obj.estimate()             # Approximate count
obj.quantile(q)            # Percentile
obj.hitRate()              # Cache hit rate
obj.falsePositiveRate()    # Filter FPR

# SERIALIZATION
obj.toBytes()              # Serialize
obj.toString()             # Debug representation
TypeName.fromBytes(bytes)  # Deserialize

# OPERATIONS
obj.merge(other)           # Combine sketches/filters
obj.union(other)           # Set union
obj.intersection(other)    # Set intersection
```

---

## Implementation Priority

### Phase 1: Unify Existing (Quick Wins)
1. Rename `buildXorFilter8` → `XorFilter8.new().from(keys)`
2. Add `.estimate()` alias for `.cardinality()` in HyperLogLog
3. Standardize `toBytes/fromBytes` across all types
4. Add `.len()` methods consistently

### Phase 2: Add Builders
1. Implement fluent builders for all types
2. Add validation in builders
3. Support presets (`.fast()`, `.balanced()`, `.compact()`)

### Phase 3: Add Managers (Optional)
1. Create domain managers
2. Add automatic workflows
3. Implement metrics/monitoring

---

## Example: Before & After

### BEFORE (Current)
```nim
var hll = initHyperLogLog(14)
hll.add("user_123")
echo hll.cardinality()

let filter = buildXorFilter8(["alice", "bob"])
echo filter.contains("alice")

var rb = initRoaringBitmap()
rb.add(42)
echo rb.cardinality()
```

### AFTER (Unified)
```nim
var hll = HyperLogLog.new(14).build()
hll.add("user_123")
echo hll.estimate()  # or .cardinality(), both work

let filter = XorFilter8.new().from(["alice", "bob"])
echo filter.contains("alice")

var rb = RoaringBitmap.new().build()
rb.add(42)
echo rb.len()  # Consistent with Nim's len()
```

---

## Questions for You

1. **Which option appeals most?** Trait-based, Manager pattern, or Domain modules?

2. **Builder verbosity?** Do you want:
   - Concise: `HyperLogLog.new(14)`
   - Fluent: `HyperLogLog.new(14).withHasher(...).build()`
   - Both?

3. **Manager layer?** Should we add high-level managers, or keep it simple with just unified traits?

4. **Breaking changes OK?** Can we rename existing APIs or should we maintain backwards compat?

5. **Performance sensitivity?** Should builders compile to zero-cost, or is small overhead OK for ergonomics?

Let me know your preferences and I'll implement the unified API!
