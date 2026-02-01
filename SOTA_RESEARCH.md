# State-of-the-Art Algorithms Research for Arsenal

This document summarizes research on high-performance algorithms and data structures that could significantly enhance Arsenal's capabilities, focusing on areas where Nim's stdlib is lacking or where industry-standard implementations provide major benefits.

## Implementation Status

Detailed stubs with technical explanations have been created for:

| Algorithm | File | Status |
|-----------|------|--------|
| Binary Fuse Filter | `src/arsenal/sketching/membership/binary_fuse.nim` | Stub with core algorithm |
| Gorilla Compression | `src/arsenal/timeseries/gorilla.nim` | Stub with encoder/decoder |
| H3 Hexagonal Grid | `src/arsenal/geo/h3.nim` | Stub with type definitions |
| SIMD String Search | `src/arsenal/strings/simd_search.nim` | Stub with nimsimd integration |
| Delta-Stepping SSSP | `src/arsenal/graph/sssp.nim` | Stub with full algorithm |
| Harley-Seal Popcount | `src/arsenal/bits/popcount.nim` | Stub with CSA implementation |
| Lock-Free Skip List | `src/arsenal/concurrent/skiplist.nim` | Stub with CAS operations |

**Note:** For SIMD operations, use [nimsimd](https://github.com/guzba/nimsimd) which provides
SSE2/SSE4.2/AVX2/NEON intrinsics. For serialization, use existing libraries (flatty, msgpack, protobuf).

---

## Executive Summary

Arsenal already has solid foundations in:
- Sketching (XOR filter, HyperLogLog, T-Digest)
- Hashing (WyHash, XXHash64)
- Data structures (Swiss table, Roaring bitmaps)
- Concurrency (coroutines, MPMC/SPSC queues, channels)
- Audio/DSP (FFT, MDCT, resampling)

**Recommended Additions** (Priority Order):

| Priority | Category | Algorithm/Structure | Impact | Effort |
|----------|----------|---------------------|--------|--------|
| P0 | Spatial | H3 Hexagonal Grid | High | Medium |
| P0 | Filters | Binary Fuse Filter | High | Low |
| P0 | Strings | StringZilla-style SIMD | Very High | Medium |
| P1 | Time Series | Gorilla Compression | High | Low |
| P1 | Concurrent | Lock-Free Skip List | High | Medium |
| P1 | Graphs | Delta-Stepping SSSP | High | Medium |
| P2 | Encoding | SIMD Base64 | Medium | Low |
| P2 | Filters | Ribbon Filter | Medium | Medium |
| P2 | Trees | B-epsilon Tree | High | High |
| P2 | Bit Ops | Harley-Seal Popcount | Medium | Low |

---

## Category 1: Spatial/GIS Algorithms

### H3 Hexagonal Grid System
**Source:** [Uber H3](https://github.com/uber/h3) | [H3 Docs](https://h3geo.org/)

H3 is Uber's hexagonal hierarchical geospatial indexing system. Unlike S2 (squares) or Geohash (rectangles), hexagons have:
- **Uniform neighbors** - All 6 neighbors share an edge (no corner-only neighbors)
- **Better proximity analysis** - Hexagons approximate circles better than squares
- **Consistent cell area** - Less distortion than other projections

**Key Operations:**
```
latLngToCell(lat, lng, resolution) -> H3Index
cellToLatLng(h3Index) -> (lat, lng)
gridDisk(h3Index, k) -> seq[H3Index]  # k-ring neighbors
cellToChildren(h3Index, resolution) -> seq[H3Index]
cellsToMultiPolygon(cells) -> GeoJSON
```

**Use Cases:**
- Ride-sharing surge pricing zones
- Delivery radius calculations
- Spatial aggregation/heatmaps
- Cell tower coverage modeling

**Implementation Notes:**
- Core is ~15K LOC C, well-documented
- 16 resolution levels (0=continents, 15=~1m cells)
- 64-bit cell IDs enable efficient storage

### R*-Tree Spatial Index
**Source:** [Original Paper](https://www.researchgate.net/publication/221213205_R_Trees_A_Dynamic_Index_Structure_for_Spatial_Searching)

Arsenal could benefit from an R*-tree for:
- Range queries on 2D/3D point clouds
- Bounding box intersection tests
- Nearest neighbor searches

**Performance:** O(log N) for point queries, O(log N + K) for range queries returning K results.

---

## Category 2: Probabilistic Filters

### Binary Fuse Filter (Upgrade from XOR Filter)
**Paper:** [Binary Fuse Filters](https://arxiv.org/pdf/2201.01174)

Binary fuse filters improve on XOR filters:
- **13% overhead** vs theoretical minimum (XOR: 23%, Bloom: 44%)
- **2x faster construction** than XOR filters
- **Same query speed** as XOR filters

```nim
# API concept
type BinaryFuseFilter*[bits: static int] = object
  fingerprints: seq[uint]
  seed: uint64
  segmentLength: uint32

proc construct*[T](keys: openArray[T]): BinaryFuseFilter[8]
proc contains*(filter: BinaryFuseFilter, key: uint64): bool  # ~3 memory accesses
```

**Recommendation:** Replace or supplement current XOR filter with Binary Fuse.

### Ribbon Filter (For Very Tight Memory Constraints)
**Paper:** [Ribbon Filter](https://arxiv.org/pdf/2103.02515) (Meta/Facebook)

- **<1% space overhead** possible with load balancing
- Best for static sets where memory is extremely constrained
- Slower construction than Binary Fuse but smaller

---

## Category 3: String Algorithms (Major Gap)

### SIMD String Operations (StringZilla-style)
**Source:** [StringZilla](https://ashvardanian.com/posts/stringzilla/) | [GitHub](https://github.com/ashvardanian/StringZilla)

Standard libc `strstr` achieves ~1.5 GB/s. StringZilla achieves **10-15 GB/s** using SIMD.

**Key Insight:** If first 4 characters match, the rest likely matches too.

**Proposed Arsenal Module: `arsenal/strings/simd_search`**

```nim
# SIMD substring search
proc find*(haystack, needle: string): int  # ~10 GB/s
proc findAll*(haystack, needle: string): seq[int]
proc count*(haystack, needle: string): int

# SIMD string comparison
proc equals*(a, b: string): bool  # Vectorized comparison
proc startsWith*(s, prefix: string): bool  # Lemire's SIMD prefix
proc commonPrefixLen*(a, b: string): int

# Batch operations
proc findAny*(haystack: string, needles: openArray[string]): int
```

**Why This Matters:** Nim's stdlib string operations are scalar. This would provide 5-10x speedup for log parsing, text processing, bioinformatics.

### Vectorized Aho-Corasick
**Paper:** [SIMD Aho-Corasick using AVX2](https://scpe.org/index.php/scpe/article/view/1572)

Multi-pattern matching at near-memory-bandwidth speeds. Critical for:
- Malware signature scanning
- Network intrusion detection
- DNA sequence matching

---

## Category 4: Time Series Compression

### Gorilla Compression (Facebook/Meta)
**Paper:** [Gorilla: A Fast, Scalable, In-Memory Time Series Database](https://www.vldb.org/pvldb/vol8/p1816-teller.pdf)

Achieves **12x compression** for time series data (16 bytes → 1.37 bytes average).

**Two Key Techniques:**

1. **Delta-of-Delta Timestamps:**
   - 96% of timestamps compress to 1 bit
   - Exploits regular sampling intervals

2. **XOR Value Encoding:**
   - 51% of values compress to 1 bit (identical to previous)
   - ~30% compress to 26 bits (similar values)

**Proposed Module: `arsenal/timeseries/gorilla`**

```nim
type GorillaEncoder* = object
  prevTimestamp: int64
  prevDelta: int64
  prevValue: uint64
  buffer: BitBuffer

proc encode*(e: var GorillaEncoder, timestamp: int64, value: float64)
proc decode*(data: openArray[byte]): seq[(int64, float64)]

# Streaming interface
proc newGorillaBlock*(startTime: int64): GorillaBlock
proc append*(block: var GorillaBlock, ts: int64, val: float64)
proc finish*(block: var GorillaBlock): seq[byte]
```

**Use Cases:** IoT sensor data, metrics/monitoring, financial tick data.

---

## Category 5: Serialization (Major Gap)

### Zero-Copy Binary Formats
**Sources:** [FlatBuffers](https://flatbuffers.dev/benchmarks/) | [Cap'n Proto](https://capnproto.org/)

Current Arsenal uses yyjson for JSON. For binary protocols:

| Format | Encode | Decode | Zero-Copy | Schema |
|--------|--------|--------|-----------|--------|
| FlatBuffers | Fast | **Instant** | Yes | Yes |
| Cap'n Proto | Fast | **Instant** | Yes | Yes |
| MessagePack | Fast | Medium | No | No |
| Protocol Buffers | Medium | Medium | No | Yes |

**Key Benefit:** Zero-copy means no deserialization - read directly from buffer.

**Proposed Module: `arsenal/serialization/flatbuf`**

```nim
# Schema-less builder (like FlatBuffers FlexBuffers)
var builder = newFlexBuilder()
builder.startMap()
builder.add("name", "Alice")
builder.add("age", 30)
builder.add("scores", @[95, 87, 92])
builder.endMap()
let bytes = builder.finish()

# Zero-copy access
let root = getRoot(bytes)
echo root["name"].asString  # No copy, pointer into buffer
echo root["scores"][0].asInt
```

---

## Category 6: Graph Algorithms

### Delta-Stepping SSSP (Parallel Shortest Path)
**Paper:** [Delta-stepping: a parallelizable shortest path algorithm](https://www.sciencedirect.com/science/article/pii/S0196677403000762)

State-of-the-art parallel single-source shortest path:
- **1.3-2.6x faster** than existing implementations on social/web graphs
- **Scales to millions of vertices** with parallel processing
- Used by Neo4j, Apache Spark GraphX

**Proposed Module: `arsenal/graph/sssp`**

```nim
type Graph* = object
  # CSR format for cache efficiency
  offsets: seq[int]
  edges: seq[int]
  weights: seq[float32]

proc deltaSteppingSSSP*(g: Graph, source: int, delta: float32): seq[float32]
proc parallelSSSP*(g: Graph, source: int, numThreads: int): seq[float32]
```

**Recent Advances (2024):**
- **rho-Stepping:** Automatically selects optimal delta
- **Hyb-Stepping:** Combines degree heap with delta-stepping

---

## Category 7: SIMD Primitives

### SIMD Base64 (10x speedup)
**Source:** [lemire/fastbase64](https://github.com/lemire/fastbase64) | [Paper](https://arxiv.org/pdf/1910.05109)

Standard base64: ~1.8 cycles/byte. SIMD base64: **~0.2 cycles/byte**.

```nim
# Proposed arsenal/encoding/base64_simd
proc encode*(input: openArray[byte]): string   # 10x faster
proc decode*(input: string): seq[byte]         # 10x faster
proc encodeInPlace*(input: openArray[byte], output: var openArray[char])
```

Adopted by: Node.js, Bun, WebKit, Chromium.

### Harley-Seal Population Count
**Paper:** [Faster Population Counts Using AVX2](https://arxiv.org/pdf/1611.07612)

**2x faster than hardware POPCNT** for bulk operations using carry-save adders.

```nim
# Process 512 bytes at once
proc popcountBlock*(data: ptr UncheckedArray[byte], len: int): int
proc positionalPopcount*(data: openArray[uint16]): array[16, int]
```

**Use Cases:** Bitvector cardinality, Roaring bitmap operations, DNA k-mer counting.

---

## Category 8: Database Internals

### B-epsilon Tree (Write-Optimized)
**Paper:** [Introduction to B-epsilon-trees](https://www3.cs.stonybrook.edu/~bender/newpub/2015-BenderFaJa-login-wods.pdf)

B-epsilon trees add buffers to B-tree nodes for **100-1000x better write throughput**:
- Point queries: O(log_B N)
- Range queries: O(log_B N + K/B)
- Inserts: O((log_B N) / B^epsilon)  ← Much faster

**Use Cases:** Key-value stores, file systems, databases with heavy writes.

### Bf-Tree (2024 - Read-Write Optimized)
**Paper:** [PVLDB 2024](https://vldb.org/pvldb/vol17/p3442-hao.pdf)

**2x faster than both B-Trees and LSM-Trees** for point lookups while maintaining good write performance.

---

## Category 9: Memory Allocators

Arsenal already has mimalloc bindings. Consider adding:

### snmalloc
**Source:** [Microsoft/snmalloc](https://github.com/snmalloc/snmalloc)

- Matches mimalloc performance
- Better consistency across workloads
- Message-passing design (good for concurrent apps)

---

## Category 10: Concurrent Data Structures

### Lock-Free Skip List
**Source:** [LazySkipList Paper](https://people.csail.mit.edu/shanir/publications/LazySkipList.pdf)

Used by Redis, MemSQL, Discord for ordered concurrent maps.

```nim
type ConcurrentSkipList*[K, V] = object
  head: ptr Node[K, V]
  maxLevel: int

proc insert*[K, V](sl: var ConcurrentSkipList[K, V], key: K, value: V)
proc find*[K, V](sl: ConcurrentSkipList[K, V], key: K): Option[V]
proc delete*[K, V](sl: var ConcurrentSkipList[K, V], key: K): bool
proc range*[K, V](sl: ConcurrentSkipList[K, V], lo, hi: K): seq[(K, V)]
```

---

## Implementation Recommendations

### Phase 1: Quick Wins (Low effort, High impact)
1. **Binary Fuse Filter** - Drop-in upgrade from XOR filter
2. **Gorilla Time Series Compression** - Pure Nim, ~200 lines
3. **SIMD Base64** - Port from fastbase64, ~300 lines
4. **Harley-Seal Popcount** - Enhances Roaring bitmaps

### Phase 2: Major Features
1. **SIMD String Search** - Major performance win for text processing
2. **H3 Hexagonal Grid** - Opens GIS use cases
3. **Delta-Stepping SSSP** - Graph algorithm suite foundation
4. **Zero-Copy Serialization** - FlatBuffers-style binary format

### Phase 3: Advanced
1. **B-epsilon Tree** - Write-optimized storage
2. **Lock-Free Skip List** - Concurrent ordered map
3. **Vectorized Aho-Corasick** - Multi-pattern matching

---

## References

### Spatial
- [H3 GitHub](https://github.com/uber/h3)
- [S2 Geometry](https://s2geometry.io/)
- [R*-Tree Guide](https://www.numberanalytics.com/blog/r-trees-ultimate-guide-spatial-indexing)

### Filters
- [Binary Fuse Filters Paper](https://arxiv.org/pdf/2201.01174)
- [Ribbon Filter Paper](https://arxiv.org/pdf/2103.02515)
- [XOR Filters Paper](https://arxiv.org/pdf/1912.08258)

### Strings
- [StringZilla Blog](https://ashvardanian.com/posts/stringzilla/)
- [SIMD String Matching](https://dev.to/kherld/how-rfgrep-achieves-hardware-acceleration-simd-optimized-string-matching-1cdd)
- [Lemire's Prefix Matching](https://lemire.me/blog/2023/07/14/recognizing-string-prefixes-with-simd-instructions/)

### Time Series
- [Gorilla Paper](https://www.vldb.org/pvldb/vol8/p1816-teller.pdf)

### Serialization
- [FlatBuffers Benchmarks](https://flatbuffers.dev/benchmarks/)
- [cpp-serializers](https://github.com/thekvs/cpp-serializers)

### Graphs
- [Delta-Stepping Paper](https://www.sciencedirect.com/science/article/pii/S0196677403000762)
- [Efficient Stepping Algorithms](https://www.cs.ucr.edu/~ygu/papers/SPAA21/stepping.pdf)

### SIMD
- [fastbase64](https://github.com/lemire/fastbase64)
- [sse-popcount](https://github.com/WojciechMula/sse-popcount)
- [base64simd](https://github.com/WojciechMula/base64simd)

### Hash Tables
- [Hash Table Benchmarks](https://martin.ankerl.com/2019/04/01/hashmap-benchmarks-01-overview/)
- [C/C++ Hash Tables Benchmark](https://jacksonallan.github.io/c_cpp_hash_tables_benchmark/)

### Allocators
- [mimalloc Benchmarks](https://microsoft.github.io/mimalloc/bench.html)
- [mimalloc-bench](https://github.com/daanx/mimalloc-bench)

### Database Structures
- [B-epsilon Introduction](https://www3.cs.stonybrook.edu/~bender/newpub/2015-BenderFaJa-login-wods.pdf)
- [LSM-Tree Survey](https://arxiv.org/html/2402.10460v2)
- [Bf-Tree Paper](https://vldb.org/pvldb/vol17/p3442-hao.pdf)
