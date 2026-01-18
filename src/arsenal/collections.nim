## Arsenal Collections - Unified High-Level API
## ==============================================
##
## This module provides a consistent, ergonomic API for all compressed
## collection types. It wraps the underlying implementations without
## modifying them.
##
## You can use either:
## - This high-level API (consistent, discoverable)
## - Direct implementation modules (full control, all features)
##
## Usage:
## ```nim
## import arsenal/collections
##
## # Create compressed set
## var ids = IntSet.new()
## ids.add(42)
## ids.add(100)
## ids.add(1000)
##
## # Test membership
## echo ids.contains(42)  # true
##
## # Set operations
## let union = ids1 + ids2
## let inter = ids1 * ids2
## ```

import arsenal/collections/roaring

export roaring  # Re-export for direct use if needed

# =============================================================================
# INT SET - Unified API for compressed integer sets
# =============================================================================

type
  IntSet* = object
    ## High-level API for compressed integer sets
    ##
    ## Wraps: RoaringBitmap
    ##
    ## Properties:
    ## - Lossless compression
    ## - Fast set operations (union, intersection, etc.)
    ## - Adaptive encoding based on density
    impl: RoaringBitmap

  IntSetBuilder* = object
    initialCapacity: int

# Constructors
proc new*(_: typedesc[IntSet]): IntSetBuilder =
  ## Create int set builder
  ##
  ## Example:
  ## ```nim
  ## var ids = IntSet.new()
  ##   .withInitialCapacity(1000)
  ##   .build()
  ## ```
  IntSetBuilder(initialCapacity: 0)

proc withInitialCapacity*(builder: IntSetBuilder, capacity: int): IntSetBuilder =
  ## Set initial capacity hint
  result = builder
  result.initialCapacity = capacity

proc build*(builder: IntSetBuilder): IntSet =
  ## Build int set from builder
  IntSet(impl: initRoaringBitmap())

proc init*(_: typedesc[IntSet]): IntSet {.inline.} =
  ## Direct construction (no builder)
  IntSet.new().build()

proc from*(_: typedesc[IntSet], values: openArray[uint32]): IntSet =
  ## Create from array of values
  ##
  ## Example:
  ## ```nim
  ## let ids = IntSet.from([1'u32, 2, 3, 4, 5])
  ## ```
  var s = IntSet.init()
  for v in values:
    s.add(v)
  s

proc from*(_: typedesc[IntSet], values: openArray[int]): IntSet =
  ## Create from array of int values
  var s = IntSet.init()
  for v in values:
    s.add(v.uint32)
  s

# Mutation operations
proc add*(s: var IntSet, value: uint32) {.inline.} =
  ## Add integer to set
  s.impl.add(value)

proc add*(s: var IntSet, value: int) {.inline.} =
  ## Add int to set (converted to uint32)
  s.impl.add(value.uint32)

proc remove*(s: var IntSet, value: uint32): bool {.inline.} =
  ## Remove integer from set
  ##
  ## Returns true if value was present
  s.impl.remove(value)

proc remove*(s: var IntSet, value: int): bool {.inline.} =
  ## Remove int from set
  s.impl.remove(value.uint32)

proc clear*(s: var IntSet) {.inline.} =
  ## Remove all elements
  s.impl.clear()

# Query operations
proc contains*(s: IntSet, value: uint32): bool {.inline.} =
  ## Test if value is in set
  s.impl.contains(value)

proc contains*(s: IntSet, value: int): bool {.inline.} =
  ## Test if int is in set
  s.impl.contains(value.uint32)

proc has*(s: IntSet, value: uint32): bool {.inline.} =
  ## Alias for contains()
  s.contains(value)

proc len*(s: IntSet): int {.inline.} =
  ## Number of elements in set
  s.impl.cardinality()

proc size*(s: IntSet): int {.inline.} =
  ## Alias for len()
  s.len()

proc isEmpty*(s: IntSet): bool {.inline.} =
  ## Check if set is empty
  s.impl.isEmpty()

# Set operations (immutable)
proc union*(s1, s2: IntSet): IntSet {.inline.} =
  ## Set union (all elements from both sets)
  IntSet(impl: s1.impl or s2.impl)

proc intersection*(s1, s2: IntSet): IntSet {.inline.} =
  ## Set intersection (common elements)
  IntSet(impl: s1.impl and s2.impl)

proc difference*(s1, s2: IntSet): IntSet {.inline.} =
  ## Set difference (elements in s1 but not s2)
  IntSet(impl: s1.impl - s2.impl)

proc symmetricDifference*(s1, s2: IntSet): IntSet {.inline.} =
  ## Symmetric difference (elements in either set but not both)
  IntSet(impl: s1.impl xor s2.impl)

# Set operations (operators)
proc `+`*(s1, s2: IntSet): IntSet {.inline.} =
  ## Union operator
  s1.union(s2)

proc `*`*(s1, s2: IntSet): IntSet {.inline.} =
  ## Intersection operator
  s1.intersection(s2)

proc `-`*(s1, s2: IntSet): IntSet {.inline.} =
  ## Difference operator
  s1.difference(s2)

proc `xor`*(s1, s2: IntSet): IntSet {.inline.} =
  ## Symmetric difference operator
  s1.symmetricDifference(s2)

# Subset/superset testing
proc isSubset*(s1, s2: IntSet): bool =
  ## Check if s1 is a subset of s2 (all elements of s1 are in s2)
  (s1.difference(s2)).isEmpty()

proc isSuperset*(s1, s2: IntSet): bool =
  ## Check if s1 is a superset of s2 (s1 contains all elements of s2)
  s2.isSubset(s1)

proc isDisjoint*(s1, s2: IntSet): bool =
  ## Check if sets have no common elements
  s1.intersection(s2).isEmpty()

# Similarity metrics
proc jaccard*(s1, s2: IntSet): float64 =
  ## Jaccard similarity coefficient (0.0 to 1.0)
  ##
  ## J(A,B) = |A ∩ B| / |A ∪ B|
  let interSize = s1.intersection(s2).len()
  let unionSize = s1.union(s2).len()
  if unionSize == 0: 0.0 else: interSize.float64 / unionSize.float64

proc overlap*(s1, s2: IntSet): float64 =
  ## Overlap coefficient (0.0 to 1.0)
  ##
  ## overlap(A,B) = |A ∩ B| / min(|A|, |B|)
  let interSize = s1.intersection(s2).len()
  let minSize = min(s1.len(), s2.len())
  if minSize == 0: 0.0 else: interSize.float64 / minSize.float64

# Metadata
proc memoryUsage*(s: IntSet): int {.inline.} =
  ## Memory usage in bytes
  s.impl.memoryUsage()

proc compressionRatio*(s: IntSet): float64 =
  ## Compression ratio compared to naive bitmap
  ##
  ## uncompressed size / compressed size
  if s.len() == 0: 0.0
  else:
    let uncompressed = s.len() * 4  # 4 bytes per uint32
    uncompressed.float64 / s.memoryUsage().float64

# Iteration
iterator items*(s: IntSet): uint32 =
  ## Iterate over all values in ascending order
  for value in s.impl.items():
    yield value

# Serialization
proc toBytes*(s: IntSet): seq[byte] {.inline.} =
  ## Serialize to bytes
  s.impl.toBytes()

proc fromBytes*(_: typedesc[IntSet], data: openArray[byte]): IntSet =
  ## Deserialize from bytes
  IntSet(impl: RoaringBitmap.fromBytes(data))

proc `$`*(s: IntSet): string =
  ## String representation
  "IntSet(len=" & $s.len() &
    ", memory=" & $s.memoryUsage() & "B" &
    ", compression=" & $s.compressionRatio().formatFloat(ffDecimal, 2) & "×)"

# =============================================================================
# CONVENIENCE CONSTRUCTORS
# =============================================================================

template newIntSet*(): IntSet =
  ## Quick constructor
  IntSet.init()

template intSet*(values: openArray[uint32]): IntSet =
  ## Quick constructor from values
  IntSet.from(values)

template intSet*(values: openArray[int]): IntSet =
  ## Quick constructor from int values
  IntSet.from(values)

# =============================================================================
# EXAMPLE USAGE
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "Arsenal Collections - Unified API Demo"
  echo "======================================="
  echo ""

  # Basic set operations
  echo "1. Basic Set Operations"
  echo "----------------------"

  var ids = IntSet.init()

  # Add some values
  ids.add(1)
  ids.add(100)
  ids.add(1000)
  ids.add(10000)

  echo "Created set: ", ids
  echo "Contains 100: ", ids.contains(100)
  echo "Contains 500: ", ids.contains(500)
  echo ""

  # Set operations
  echo "2. Set Operations"
  echo "----------------"

  var set1 = IntSet.from([1, 2, 3, 4, 5])
  var set2 = IntSet.from([4, 5, 6, 7, 8])

  echo "Set1: ", toSeq(set1.items())
  echo "Set2: ", toSeq(set2.items())
  echo ""

  let union = set1 + set2
  let inter = set1 * set2
  let diff1 = set1 - set2
  let diff2 = set2 - set1
  let symDiff = set1 xor set2

  echo "Union (set1 + set2): ", toSeq(union.items())
  echo "Intersection (set1 * set2): ", toSeq(inter.items())
  echo "Difference (set1 - set2): ", toSeq(diff1.items())
  echo "Difference (set2 - set1): ", toSeq(diff2.items())
  echo "Symmetric diff (set1 xor set2): ", toSeq(symDiff.items())
  echo ""

  # Similarity metrics
  echo "3. Similarity Metrics"
  echo "--------------------"

  echo "Jaccard similarity: ", set1.jaccard(set2).formatFloat(ffDecimal, 3)
  echo "Overlap coefficient: ", set1.overlap(set2).formatFloat(ffDecimal, 3)
  echo ""

  echo "Subset tests:"
  let subset = IntSet.from([1, 2])
  echo "  {1,2} ⊆ {1,2,3,4,5}: ", subset.isSubset(set1)
  echo "  {1,2,3,4,5} ⊆ {1,2}: ", set1.isSubset(subset)
  echo "  {1,2,3,4,5} ⊇ {1,2}: ", set1.isSuperset(subset)
  echo ""

  # Compression efficiency
  echo "4. Compression Efficiency"
  echo "------------------------"

  # Dense set (consecutive values)
  var dense = IntSet.init()
  for i in 0..<10_000:
    dense.add(i.uint32)

  echo "Dense set (0..9999):"
  echo "  Elements: ", dense.len()
  echo "  Memory: ", dense.memoryUsage(), " bytes"
  echo "  Uncompressed: ", dense.len() * 4, " bytes (4 bytes per uint32)"
  echo "  Compression: ", dense.compressionRatio().formatFloat(ffDecimal, 2), "×"
  echo ""

  # Sparse set (every 1000th value)
  var sparse = IntSet.init()
  for i in 0..<10_000:
    if i mod 1000 == 0:
      sparse.add(i.uint32)

  echo "Sparse set (every 1000th):"
  echo "  Elements: ", sparse.len()
  echo "  Memory: ", sparse.memoryUsage(), " bytes"
  echo "  Uncompressed: ", sparse.len() * 4, " bytes"
  echo "  Compression: ", sparse.compressionRatio().formatFloat(ffDecimal, 2), "×"
  echo ""

  # Performance benchmark
  echo "5. Performance Benchmark"
  echo "-----------------------"

  let numOps = 100_000
  var perfSet = IntSet.init()

  echo "Adding ", numOps, " random integers..."
  let addStart = cpuTime()
  randomize(42)
  for i in 0..<numOps:
    perfSet.add(rand(1_000_000).uint32)
  let addTime = cpuTime() - addStart

  echo "  Time: ", (addTime * 1000).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (numOps.float64 / addTime / 1_000_000).formatFloat(ffDecimal, 2), " M ops/sec"
  echo ""

  echo "Membership tests for ", numOps, " queries..."
  let queryStart = cpuTime()
  var found = 0
  for i in 0..<numOps:
    if perfSet.contains(rand(1_000_000).uint32):
      inc found
  let queryTime = cpuTime() - queryStart

  echo "  Time: ", (queryTime * 1000).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (numOps.float64 / queryTime / 1_000_000).formatFloat(ffDecimal, 2), " M ops/sec"
  echo "  Found: ", found, " / ", numOps
  echo ""

  echo "Final set:"
  echo "  Unique elements: ", perfSet.len()
  echo "  Memory: ", (perfSet.memoryUsage().float64 / 1024).formatFloat(ffDecimal, 2), " KB"
  echo "  Compression: ", perfSet.compressionRatio().formatFloat(ffDecimal, 2), "×"
  echo ""

  echo "All demos completed!"
