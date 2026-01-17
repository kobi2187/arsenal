# Arsenal Trait Definitions
## Unified interfaces across all domains

This defines the core traits/concepts that ensure API consistency across all Arsenal modules.

---

## Core Traits

```nim
# src/arsenal/traits.nim
## Core trait definitions for Arsenal
##
## These define the contracts that all implementations follow,
## ensuring a consistent API across the entire library.

import std/options

# ============================================================================
# SKETCHING - Probabilistic data structures for streaming statistics
# ============================================================================

type
  Sketch*[T] = concept sketch, var mutableSketch
    ## Approximate counting and statistics on streams
    ##
    ## Implementations: HyperLogLog, Count-Min Sketch, HyperBitBit
    ##
    ## Properties:
    ## - Sublinear space: O(log log n) to O(1/ε)
    ## - Streaming: one-pass processing
    ## - Mergeable: combine sketches from different streams

    # Mutation
    mutableSketch.add(T)                    ## Add element
    mutableSketch.add(T, weight: float64)   ## Add with weight
    mutableSketch.clear()                   ## Reset sketch

    # Query
    sketch.estimate() is int64              ## Primary estimate
    sketch.len() is int64                   ## Alias for estimate

    # Metadata
    sketch.size() is int                    ## Sketch size (registers/centroids)
    sketch.memoryUsage() is int             ## Memory in bytes
    sketch.expectedError() is float64       ## Expected relative error

    # Combining
    mutableSketch.merge(sketch.type)        ## Merge another sketch

    # Serialization
    sketch.toBytes() is seq[byte]
    sketch.type.fromBytes(openArray[byte]) is sketch.type

  QuantileSketch*[T] = concept sketch, var mutableSketch
    ## Quantile estimation on streams
    ##
    ## Implementations: t-Digest, Q-Digest, KLL
    ##
    ## Properties:
    ## - Approximate quantiles with bounded error
    ## - Particularly accurate at tails
    ## - Mergeable for distributed percentiles

    # Mutation
    mutableSketch.add(T)
    mutableSketch.add(T, weight: float64)
    mutableSketch.clear()

    # Query
    sketch.quantile(q: float64) is T        ## Get quantile (0.0-1.0)
    sketch.percentile(p: float64) is T      ## Alias (0-100)
    sketch.cdf(value: T) is float64         ## Cumulative distribution
    sketch.median() is T                    ## Shorthand for quantile(0.5)

    # Metadata
    sketch.count() is int64
    sketch.min() is T
    sketch.max() is T
    sketch.size() is int
    sketch.memoryUsage() is int

    # Combining
    mutableSketch.merge(sketch.type)

    # Serialization
    sketch.toBytes() is seq[byte]
    sketch.type.fromBytes(openArray[byte]) is sketch.type

# ============================================================================
# MEMBERSHIP - Probabilistic set membership testing
# ============================================================================

type
  Filter*[T] = concept filter
    ## Approximate membership testing (no false negatives)
    ##
    ## Implementations: Bloom, Xor, Cuckoo, Binary Fuse
    ##
    ## Properties:
    ## - No false negatives: if contains(x) == false, x definitely not in set
    ## - May have false positives: if contains(x) == true, x *probably* in set
    ## - Space-efficient: bits per element

    # Query (primary operation)
    filter.contains(T) is bool              ## Test membership
    filter.mightContain(T) is bool          ## Alias (clearer semantics)

    # Metadata
    filter.len() is int                     ## Number of elements
    filter.size() is int                    ## Filter size (array length)
    filter.memoryUsage() is int             ## Memory in bytes
    filter.falsePositiveRate() is float64   ## Expected FP rate
    filter.bitsPerKey() is float64          ## Space efficiency

    # Serialization
    filter.toBytes() is seq[byte]
    filter.type.fromBytes(openArray[byte]) is filter.type

# ============================================================================
# COLLECTIONS - Compressed sets and maps
# ============================================================================

type
  CompressedSet*[T] = concept set, var mutableSet
    ## Space-efficient set implementations
    ##
    ## Implementations: Roaring Bitmap, Elias-Fano, PFor
    ##
    ## Properties:
    ## - Lossless compression
    ## - Fast set operations
    ## - Adaptive encoding based on density

    # Mutation
    mutableSet.add(T)                       ## Add element
    mutableSet.remove(T) is bool            ## Remove element
    mutableSet.clear()                      ## Remove all

    # Query
    set.contains(T) is bool                 ## Test membership
    set.len() is int                        ## Element count
    set.isEmpty() is bool                   ## Check if empty

    # Set operations (immutable)
    set.union(set.type) is set.type         ## Set union
    set.intersection(set.type) is set.type  ## Set intersection
    set.difference(set.type) is set.type    ## Set difference
    set.symmetricDifference(set.type) is set.type  ## Symmetric diff

    # Set operations (operators)
    set `or` set.type is set.type           ## Union operator
    set `and` set.type is set.type          ## Intersection operator
    set `-` set.type is set.type            ## Difference operator
    set `xor` set.type is set.type          ## Symmetric diff operator

    # Metadata
    set.memoryUsage() is int                ## Memory in bytes

    # Iteration
    set.items() is iterator

    # Serialization
    set.toBytes() is seq[byte]
    set.type.fromBytes(openArray[byte]) is set.type

# ============================================================================
# COMPRESSION - Data encoding/decoding
# ============================================================================

type
  Codec*[T] = concept codec
    ## Encode and decode data
    ##
    ## Implementations: Stream VByte, PFor, Simple8b, Zstd
    ##
    ## Properties:
    ## - Lossless compression
    ## - Fast encode/decode
    ## - Specialized for data type

    # Core operations
    codec.encode(openArray[T]) is seq[byte]
    codec.decode(openArray[byte], count: int) is seq[T]

    # Metadata
    codec.compressionRatio(original, compressed: int) is float64
    codec.bitsPerElement(dataSize, count: int) is float64

  DeltaCodec*[T] = concept codec
    ## Codec with delta encoding support
    ##
    ## For sorted/monotonic sequences

    # All Codec operations plus:
    codec.encodeDelta(openArray[T]) is seq[byte]
    codec.decodeDelta(openArray[byte], count: int) is seq[T]

# ============================================================================
# CACHING - Cache with eviction policies
# ============================================================================

type
  Cache*[K, V] = concept cache, var mutableCache
    ## Cache with automatic eviction
    ##
    ## Implementations: S3-FIFO, LRU, ARC, TinyLFU
    ##
    ## Properties:
    ## - Bounded size
    ## - Automatic eviction
    ## - Fast lookup

    # Mutation
    mutableCache.put(K, V)                  ## Insert or update
    mutableCache.remove(K) is bool          ## Remove entry
    mutableCache.clear()                    ## Clear all

    # Query
    cache.get(K) is Option[V]               ## Get value
    cache.contains(K) is bool               ## Test membership
    cache.len() is int                      ## Current size
    cache.capacity() is int                 ## Maximum size
    cache.isEmpty() is bool                 ## Check if empty

    # Statistics
    cache.hitRate() is float64              ## Hit rate
    cache.missRate() is float64             ## Miss rate
    mutableCache.resetStats()               ## Reset counters

    # Iteration
    cache.pairs() is iterator

# ============================================================================
# SORTING - Sorting algorithms
# ============================================================================

type
  Sorter*[T] = concept sorter
    ## Sorting algorithm
    ##
    ## Implementations: pdqsort, timsort, radix sort

    # In-place sort
    sorter.sort(var openArray[T])
    sorter.sort(var openArray[T], cmp: proc)

    # Out-of-place sort
    sorter.sorted(openArray[T]) is seq[T]
    sorter.sorted(openArray[T], cmp: proc) is seq[T]

    # Partial sort
    sorter.partialSort(var openArray[T], k: int)

# ============================================================================
# HASHING - Hash functions
# ============================================================================

type
  Hasher*[T] = concept hasher
    ## Hash function
    ##
    ## Implementations: XXHash, WyHash, HighwayHash

    # Core operation
    hasher.hash(T) is uint64
    hasher.hash(openArray[byte]) is uint64

    # Streaming
    var h = hasher.new()
    h.update(T)
    h.finalize() is uint64

    # Metadata
    hasher.name() is string
```

---

## Generic Functions Using Traits

```nim
# ============================================================================
# GENERIC FUNCTIONS - Work with any implementation
# ============================================================================

# Sketching
proc estimateCardinality*[T](sketch: Sketch[T]): int64 =
  sketch.estimate()

proc errorBound*[T](sketch: Sketch[T]): float64 =
  sketch.estimate().float64 * sketch.expectedError()

proc compressionRatio*[T](sketch: Sketch[T]): float64 =
  sketch.estimate().float64 / sketch.memoryUsage().float64

# Quantiles
proc p50*[T](sketch: QuantileSketch[T]): T =
  sketch.quantile(0.5)

proc p95*[T](sketch: QuantileSketch[T]): T =
  sketch.quantile(0.95)

proc p99*[T](sketch: QuantileSketch[T]): T =
  sketch.quantile(0.99)

proc iqr*[T](sketch: QuantileSketch[T]): T =
  ## Interquartile range
  sketch.quantile(0.75) - sketch.quantile(0.25)

# Filters
proc spaceEfficiency*[T](filter: Filter[T]): float64 =
  ## How many bits per key?
  filter.bitsPerKey()

proc accuracy*[T](filter: Filter[T]): float64 =
  ## Accuracy (1 - false positive rate)
  1.0 - filter.falsePositiveRate()

# Collections
proc jaccard*[T](a, b: CompressedSet[T]): float64 =
  ## Jaccard similarity
  let inter = (a and b).len()
  let union = (a or b).len()
  if union == 0: 0.0 else: inter.float64 / union.float64

proc overlap*[T](a, b: CompressedSet[T]): float64 =
  ## Overlap coefficient
  let inter = (a and b).len()
  let minSize = min(a.len(), b.len())
  if minSize == 0: 0.0 else: inter.float64 / minSize.float64

# Caches
proc efficiency*[K, V](cache: Cache[K, V]): float64 =
  ## Cache efficiency (hit rate)
  cache.hitRate()

proc utilizationRate*[K, V](cache: Cache[K, V]): float64 =
  ## How full is the cache?
  cache.len().float64 / cache.capacity().float64
```

---

## Domain-Specific Extensions

```nim
# ============================================================================
# SKETCHING EXTENSIONS
# ============================================================================

type
  CardinalitySketch* = Sketch[string] or Sketch[int] or Sketch[uint64]
    ## Specialized for cardinality estimation
    ##
    ## Additional requirements:
    ## - Sublinear space: O(log log n)
    ## - Error relative to cardinality

  FrequencySketch*[T] = concept sketch
    ## Track element frequencies
    ##
    ## Implementations: Count-Min Sketch, Count Sketch
    ##
    ## All Sketch operations plus:
    sketch.frequency(T) is int64            ## Estimate frequency
    sketch.topK(k: int) is seq[(T, int64)]  ## Top K frequent elements

# ============================================================================
# FILTER EXTENSIONS
# ============================================================================

type
  StaticFilter*[T] = concept filter
    ## Filter that cannot be modified after construction
    ##
    ## Implementations: Xor Filter, Binary Fuse Filter
    ##
    ## All Filter operations except mutation

  DynamicFilter*[T] = concept filter, var mutableFilter
    ## Filter that supports insertion/deletion
    ##
    ## Implementations: Bloom Filter, Cuckoo Filter
    ##
    ## All Filter operations plus:
    mutableFilter.add(T)
    mutableFilter.remove(T) is bool

# ============================================================================
# COLLECTION EXTENSIONS
# ============================================================================

type
  CompressedMap*[K, V] = concept map, var mutableMap
    ## Compressed key-value store
    ##
    ## All CompressedSet[K] operations plus:
    map.get(K) is Option[V]
    mutableMap.put(K, V)

  CompressedSequence*[T] = concept seq
    ## Compressed sequence with random access
    ##
    ## Implementations: Elias-Fano, PFor-Delta
    seq.get(index: int) is T
    seq.len() is int
    seq.items() is iterator
```

---

## Usage Examples

```nim
# ============================================================================
# USING TRAITS FOR GENERIC CODE
# ============================================================================

import arsenal/traits

# Generic function works with any Sketch
proc analyzeStream*[T](data: openArray[T], sketch: var Sketch[T]) =
  for value in data:
    sketch.add(value)

  echo "Estimated count: ", sketch.estimate()
  echo "Expected error: ", sketch.expectedError() * 100, "%"
  echo "Memory usage: ", sketch.memoryUsage(), " bytes"

# Generic function works with any Filter
proc checkMembership*[T](elements: openArray[T], filter: Filter[T]): seq[bool] =
  result = newSeq[bool](elements.len)
  for i, elem in elements:
    result[i] = filter.contains(elem)

# Generic function works with any Cache
proc warmupCache*[K, V](data: openArray[(K, V)], cache: var Cache[K, V]) =
  for (key, value) in data:
    cache.put(key, value)

  echo "Cache utilization: ", cache.len(), "/", cache.capacity()
  echo "Hit rate: ", cache.hitRate() * 100, "%"

# Usage with concrete types
var hll = HyperLogLog.balanced()
analyzeStream(users, hll)

var filter = XorFilter8.from(keys)
let membership = checkMembership(queries, filter)

var cache = S3FIFOCache[string, int].new(1000).build()
warmupCache(initialData, cache)
```

---

## Benefits of Trait-Based Design

### 1. Polymorphism Without Overhead
```nim
# Can swap implementations without changing code
proc analyze(sketch: var Sketch[string]) =
  sketch.add("data")
  echo sketch.estimate()

var hll = HyperLogLog.balanced()
analyze(hll)  # Works

var hyperbitbit = HyperBitBit.new()
analyze(hyperbitbit)  # Also works
```

### 2. Testability
```nim
# Mock implementations for testing
type MockSketch = object
  count: int

proc add(m: var MockSketch, value: string) =
  inc m.count

proc estimate(m: MockSketch): int64 =
  m.count

# MockSketch automatically implements Sketch trait
var mock = MockSketch()
analyzeStream(testData, mock)
```

### 3. Documentation
```nim
# Trait serves as documentation
# Shows exactly what operations are required
# IDEs can show trait requirements
```

### 4. Future-Proof
```nim
# New implementations automatically work with existing generic code
type NewFancySketch = object
  # ...

# Just implement the Sketch trait methods
# All generic functions now work with NewFancySketch
```

---

## Implementation Strategy

### Phase 1: Define Traits
1. Create `src/arsenal/traits.nim`
2. Define core traits
3. Add generic utility functions

### Phase 2: Update Existing Types
1. Ensure all types satisfy traits
2. Add missing methods
3. Rename for consistency

### Phase 3: Documentation
1. Document which traits each type implements
2. Add examples using traits
3. Show swappability

### Phase 4: Generic Libraries
1. Build libraries using traits
2. Analytics module
3. Benchmarking framework

---

This trait system ensures:
- ✅ Consistency across all modules
- ✅ Swappable implementations
- ✅ Generic algorithms
- ✅ Clear contracts
- ✅ Zero runtime cost (compile-time concepts)
- ✅ Excellent IDE support
- ✅ Self-documenting code
