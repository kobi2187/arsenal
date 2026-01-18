# Arsenal Unified API Guide
## Consistent, Ergonomic Interface Across All Domains

Arsenal now provides **two API layers** for every domain:

1. **High-Level Unified API** - Consistent, ergonomic, discoverable
2. **Low-Level Implementation API** - Full control, all features

Both APIs work together seamlessly. You can start with the high-level API and drop down to low-level when needed.

---

## Philosophy

### Unified API (High-Level)
- **Consistent naming** across all domains
- **Builder pattern** for configuration
- **Presets** for common use cases
- **Zero-cost abstraction** (inlines to direct calls)
- **Nim-idiomatic** (`len()`, `items()`, operators)

### Implementation API (Low-Level)
- **Full feature access**
- **Direct control** over internals
- **Optimized paths** for specific use cases
- **Original research paper** algorithms unchanged

---

## Quick Start Examples

### 1. Sketching (Probabilistic Counting)

```nim
import arsenal/sketching

# High-level: Cardinality estimation
var unique = Cardinality.balanced()  # Preset: good accuracy/memory
unique.add("user_123")
unique.add("user_456")
echo unique.count()  # Estimated unique count

# High-level: Quantile estimation
var latency = Quantiles.balanced()
latency.add(42.5)
latency.add(100.0)
echo latency.p95()  # 95th percentile

# Low-level: Direct HyperLogLog access (when you need it)
import arsenal/sketching/cardinality/hyperloglog
var hll = initHyperLogLog(precision = 16)  # Higher precision
hll.registers[0] = 5  # Direct register access
echo hll.alphaMm2      # Access internals
```

**When to use which:**
- ✅ High-level: Most use cases, quick prototyping, consistent API
- ✅ Low-level: Need >18 precision, custom hash seeds, advanced tuning

---

### 2. Filters (Membership Testing)

```nim
import arsenal/filters

# High-level: Create filter from keys
let users = ["alice", "bob", "charlie"]
let filter = MembershipFilter.from(users)

echo filter.contains("alice")  # true
echo filter.contains("dave")   # false (or rare FP)

# Statistics
echo filter.memoryUsage()       # bytes
echo filter.falsePositiveRate() # ~0.39%

# Low-level: When you need 16-bit precision
import arsenal/sketching/membership/xorfilter
let filter16 = buildXorFilter16(users)  # ~0.0015% FP rate
```

**When to use which:**
- ✅ High-level: Standard membership testing, ~0.4% FP is acceptable
- ✅ Low-level: Need ultra-low FP rate, custom max attempts, direct filter control

---

### 3. Collections (Compressed Sets)

```nim
import arsenal/collections

# High-level: Compressed integer sets
var ids = IntSet.init()
ids.add(42)
ids.add(100)

echo ids.contains(42)  # true
echo ids.len()         # 2

# Set operations (clean operators)
let set1 = IntSet.from([1, 2, 3, 4, 5])
let set2 = IntSet.from([4, 5, 6, 7, 8])

let union = set1 + set2  # Union
let inter = set1 * set2  # Intersection
let diff = set1 - set2   # Difference

# Similarity metrics
echo set1.jaccard(set2)  # Jaccard similarity

# Low-level: Direct RoaringBitmap access
import arsenal/collections/roaring
var rb = initRoaringBitmap()
# Access container types, optimize, etc.
```

**When to use which:**
- ✅ High-level: Standard set operations, clean syntax, similarity metrics
- ✅ Low-level: Need container-level control, custom optimization, run containers

---

### 4. Caching (Eviction Policies)

```nim
import arsenal/caching

# High-level: Clean cache API
var cache = Cache[string, int].init(capacity = 1000)

# Assignment syntax
cache["key1"] = 100
cache["key2"] = 200

# Retrieval (Option-based)
if cache["key1"].isSome:
  echo cache["key1"].get()

# Or with default
echo cache.getOrDefault("key3", 0)  # Returns 0 if not found

# Statistics
echo cache.hitRate()     # Hit rate %
echo cache.utilization() # How full

# Low-level: Access S3-FIFO internals
import arsenal/caching/s3fifo
var s3 = initS3FIFOCache[string, int](1000)
# Access small/main/ghost queues directly
echo s3.small.len
echo s3.main.len
```

**When to use which:**
- ✅ High-level: Standard caching, clean syntax, statistics
- ✅ Low-level: Need to inspect queues, custom eviction logic, queue size tuning

---

### 5. Compression (Integer Encoding)

```nim
import arsenal/compression

# High-level: Single-call compress/decompress
let codec = IntCodec.init()
let values = [1'u32, 2, 3, 4, 5]

let compressed = codec.compress(values)
let decompressed = codec.decompress(compressed, count = 5)

# Delta encoding for sorted sequences
let deltaCodec = IntCodec.init(useDelta = true)
let sorted = [100'u32, 101, 102, 103, 104]
let smallCompressed = deltaCodec.compress(sorted)  # Very efficient!

# Low-level: Separate control/data streams
import arsenal/compression/streamvbyte
let (control, data) = encodeStreamVByte(values)
# Direct control over streams, SIMD paths, etc.
```

**When to use which:**
- ✅ High-level: Simple compression, delta encoding, single buffer
- ✅ Low-level: Need separate control/data, custom SIMD, zigzag encoding

---

### 6. Sorting (Algorithms)

```nim
import arsenal/sorting

# High-level: Clean Nim-style sorting
var arr = [5, 2, 8, 1, 9]

arr.sort()              # In-place (uses pdqsort)
let sorted = arr.sorted()  # Copy

arr.sortDescending()    # Reverse order
arr.sortStable()        # Preserve order of equal elements

# Custom comparison
type Person = object
  name: string
  age: int

var people = @[Person(name: "Alice", age: 30)]
people.sort(proc(a, b: Person): int = cmp(a.age, b.age))

# Utilities
echo arr.isSorted()     # Check if sorted

# Low-level: Direct pdqsort access
import arsenal/algorithms/sorting/pdqsort
var data = [9, 5, 2, 8, 1]
pdqsort(data)  # Direct call, full control
```

**When to use which:**
- ✅ High-level: Standard sorting, clean syntax, Nim idioms
- ✅ Low-level: Need specific pdqsort features, custom pivot selection

---

## API Patterns (Consistent Across All Domains)

### Construction

```nim
# Builder pattern (explicit)
var obj = Type.new(params)
  .withOption1(value)
  .withOption2(value)
  .build()

# Direct construction (concise)
var obj = Type.init(params)

# Presets (quickest)
var obj = Type.balanced()  # or .fast() or .accurate()

# From data (when applicable)
var obj = Type.from(data)
```

### Operations

```nim
# Mutation
obj.add(value)
obj.remove(value)
obj.clear()

# Query
obj.contains(value)  # bool
obj.get(key)         # Option[V]
obj.len()            # int (Nim-style)
obj.size()           # int (alias)
```

### Metadata

```nim
obj.memoryUsage()      # int (bytes)
obj.count()            # int (elements)
obj.expectedError()    # float64 (for sketches)
obj.falsePositiveRate()  # float64 (for filters)
obj.hitRate()          # float64 (for caches)
```

### Serialization

```nim
let bytes = obj.toBytes()
let restored = Type.fromBytes(bytes)
```

---

## Mixing High-Level and Low-Level

You can seamlessly mix both APIs:

```nim
import arsenal/sketching
import arsenal/sketching/cardinality/hyperloglog

# Start high-level
var unique = Cardinality.balanced()

# Drop to low-level when needed
unique.impl.registers[0] = 10  # Access underlying HyperLogLog

# Use high-level methods
echo unique.count()  # Still works!

# Serialize with high-level
let bytes = unique.toBytes()  # Convenient

# Deserialize to low-level
let hll = hyperloglog.fromBytes(bytes)  # Full control
```

---

## Performance

**The unified API has zero runtime cost:**

```nim
# These compile to IDENTICAL code:

# High-level
var unique = Cardinality.init(14)
unique.add("user")
let count = unique.count()

# Low-level
var hll = initHyperLogLog(14)
hll.add("user")
let count2 = hll.cardinality()
```

All high-level methods are `{.inline.}` and forward directly to implementations.

**Benchmark:** Identical performance (within measurement error)

---

## Complete Example: Analytics Pipeline

```nim
import arsenal/sketching
import arsenal/filters
import arsenal/caching
import std/times

type
  Analytics = object
    uniqueUsers: Cardinality
    latencies: Quantiles
    knownBots: MembershipFilter
    recentUsers: Cache[string, int]

proc newAnalytics(botList: seq[string]): Analytics =
  Analytics(
    uniqueUsers: Cardinality.balanced(),
    latencies: Quantiles.balanced(),
    knownBots: MembershipFilter.from(botList),
    recentUsers: Cache[string, int].init(10_000)
  )

proc processRequest(a: var Analytics, userId: string, latencyMs: float64) =
  # Skip bots (fast filter check)
  if a.knownBots.contains(userId):
    return

  # Track unique users (sketch)
  a.uniqueUsers.add(userId)

  # Track latency distribution (sketch)
  a.latencies.add(latencyMs)

  # Cache recent users
  a.recentUsers[userId] = epochTime().int

proc summary(a: var Analytics): string =
  result = "Analytics Summary:\n"
  result &= "  Unique users: " & $a.uniqueUsers.count() & "\n"
  result &= "  Median latency: " & $a.latencies.median() & " ms\n"
  result &= "  P95 latency: " & $a.latencies.p95() & " ms\n"
  result &= "  P99 latency: " & $a.latencies.p99() & " ms\n"
  result &= "  Cache hit rate: " & $(a.recentUsers.hitRate() * 100) & "%\n"

# Usage
var analytics = newAnalytics(@["bot1", "bot2", "bot3"])

for request in requests:
  analytics.processRequest(request.userId, request.latency)

echo analytics.summary()
```

**Clean, composable, and performant!**

---

## Migration Guide

### From Low-Level to Unified API

```nim
# OLD (low-level only)
import arsenal/sketching/cardinality/hyperloglog
var hll = initHyperLogLog(14)
hll.add("user")
echo hll.cardinality()

# NEW (unified high-level)
import arsenal/sketching
var unique = Cardinality.balanced()  # Clearer intent
unique.add("user")
echo unique.count()  # More intuitive

# BOTH WORK! (backwards compatible)
```

### When to Keep Low-Level

Keep using low-level APIs when you need:
- Features not exposed in high-level API
- Direct access to internal state
- Custom algorithms or modifications
- Maximum control over every detail

The low-level APIs are **not deprecated** - they're still the foundation!

---

## Summary

### Choose High-Level When:
- ✅ You want consistent API across domains
- ✅ You value discoverability (autocomplete)
- ✅ You prefer Nim idioms (`len()`, operators)
- ✅ You want presets (`.balanced()`, `.fast()`)
- ✅ You're prototyping or building quickly

### Choose Low-Level When:
- ✅ You need every feature/option
- ✅ You want direct control over internals
- ✅ You're implementing custom algorithms
- ✅ You need absolute maximum performance
- ✅ You're familiar with the papers

### Best Practice:
**Start high-level, drop to low-level only when needed.**

The APIs compose perfectly - use whichever fits your current task!

---

## API Reference Summary

| Domain | High-Level Module | Low-Level Module | Main Type |
|--------|-------------------|------------------|-----------|
| Sketching | `arsenal/sketching` | `arsenal/sketching/cardinality/hyperloglog` | `Cardinality` |
| Quantiles | `arsenal/sketching` | `arsenal/sketching/quantiles/tdigest` | `Quantiles` |
| Filters | `arsenal/filters` | `arsenal/sketching/membership/xorfilter` | `MembershipFilter` |
| Collections | `arsenal/collections` | `arsenal/collections/roaring` | `IntSet` |
| Caching | `arsenal/caching` | `arsenal/caching/s3fifo` | `Cache[K,V]` |
| Compression | `arsenal/compression` | `arsenal/compression/streamvbyte` | `IntCodec` |
| Sorting | `arsenal/sorting` | `arsenal/algorithms/sorting/pdqsort` | (functions) |

---

## Next Steps

1. **Browse Examples**: Each unified module has complete examples in `when isMainModule`
2. **Run Demos**: `nim c -r src/arsenal/sketching.nim`
3. **Read Papers**: Low-level modules link to original research papers
4. **Mix APIs**: Start high-level, explore low-level as needed

Enjoy the clean, consistent Arsenal API! 🎯
