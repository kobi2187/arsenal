## Xor Filters
## ===========
##
## Space-efficient probabilistic data structure for approximate membership testing.
## Faster and more space-efficient than Bloom filters and Cuckoo filters.
##
## Paper: "Xor Filters: Faster and Smaller Than Bloom and Cuckoo Filters"
##        Graf & Lemire (2019)
##        arXiv:1912.08258
##        Journal of Experimental Algorithmics, Vol. 25
##        https://arxiv.org/abs/1912.08258
##
## Key Properties:
## - **Space efficiency**: ~9 bits per key (vs ~10 bits for Bloom filter at same FP rate)
## - **Query speed**: Faster than Bloom filters (3 memory accesses, ~48 instructions)
## - **False positive rate**: ~0.39% with 8-bit fingerprints
## - **Static**: Must be reconstructed to add/remove elements
##
## Algorithm:
## 1. Maps each key to 3 locations using hash functions h0, h1, h2
## 2. Uses "peeling" algorithm to construct filter (acyclic 3-partite hypergraph)
## 3. Stores fingerprints such that: B[h0(x)] ⊕ B[h1(x)] ⊕ B[h2(x)] = fingerprint(x)
## 4. Query: Check if XOR of 3 locations equals fingerprint
##
## Applications:
## - Database query optimization (bloom filter replacement)
## - Cache filtering
## - Deduplication systems
## - Network packet filtering
##
## Usage:
## ```nim
## import arsenal/sketching/membership/xorfilter
##
## # Build filter from set of keys
## let keys = ["alice", "bob", "charlie", "david"]
## let filter = buildXorFilter8(keys)
##
## # Test membership
## assert filter.contains("alice")   # true
## assert not filter.contains("eve") # false (or rare false positive)
## ```

import std/[hashes, math, algorithm]

# =============================================================================
# Constants
# =============================================================================

const
  # Array size multiplier for construction (empirically determined)
  # Array size = ⌊1.23 * n + 32⌋ gives >90% construction success
  SizeFactor = 1.23
  SizeOffset = 32

  # Maximum construction attempts before giving up
  MaxIterations = 100

# =============================================================================
# Types
# =============================================================================

type
  XorFilter8* = object
    ## Xor filter with 8-bit fingerprints (~0.39% false positive rate)
    seed: uint64         ## Hash seed
    blockLength: int     ## Size of each of 3 blocks (total array size = 3 * blockLength)
    fingerprints: seq[uint8]  ## Fingerprint array (3 blocks)

  XorFilter16* = object
    ## Xor filter with 16-bit fingerprints (~0.0015% false positive rate)
    seed: uint64
    blockLength: int
    fingerprints: seq[uint16]

  XorFilter32* = object
    ## Xor filter with 32-bit fingerprints (virtually zero false positives)
    seed: uint64
    blockLength: int
    fingerprints: seq[uint32]

  # Internal types for construction
  XorSet = object
    xorMask: uint64
    count: int

  KeyIndex = object
    hash: uint64
    index: int

# =============================================================================
# Hash Functions
# =============================================================================

proc murmurHash64(key: uint64): uint64 {.inline.} =
  ## Fast 64-bit hash (MurmurHash-inspired)
  var h = key
  h = h xor (h shr 33)
  h = h * 0xff51afd7ed558ccd'u64
  h = h xor (h shr 33)
  h = h * 0xc4ceb9fe1a85ec53'u64
  h = h xor (h shr 33)
  result = h

proc hashToKey(data: openArray[byte], seed: uint64): uint64 =
  ## Hash arbitrary data to 64-bit key
  var h = seed
  for b in data:
    h = h xor b.uint64
    h = h * 0x100000001b3'u64  # FNV-1a style
  result = murmurHash64(h)

proc fingerprint8(hash: uint64): uint8 {.inline.} =
  ## Extract 8-bit fingerprint from hash
  result = (hash and 0xFF).uint8
  if result == 0:
    result = 1  # Avoid zero fingerprints

proc fingerprint16(hash: uint64): uint16 {.inline.} =
  ## Extract 16-bit fingerprint from hash
  result = (hash and 0xFFFF).uint16
  if result == 0:
    result = 1

proc fingerprint32(hash: uint64): uint32 {.inline.} =
  ## Extract 32-bit fingerprint from hash
  result = (hash and 0xFFFFFFFF'u64).uint32
  if result == 0:
    result = 1

# =============================================================================
# Hash Location Functions
# =============================================================================

proc getH0(hash: uint64, blockLength: int): int {.inline.} =
  ## First hash location (block 0)
  let r = (hash shr 32).uint32
  result = (r mod blockLength.uint32).int

proc getH1(hash: uint64, blockLength: int): int {.inline.} =
  ## Second hash location (block 1)
  let r = hash.uint32
  result = blockLength + (r mod blockLength.uint32).int

proc getH2(hash: uint64, blockLength: int): int {.inline.} =
  ## Third hash location (block 2)
  let r = ((hash xor (hash shr 32))).uint32
  result = 2 * blockLength + (r mod blockLength.uint32).int

# =============================================================================
# Construction Algorithm (Xor Filter 8-bit)
# =============================================================================

proc buildXorFilter8*(keys: openArray[string], maxAttempts: int = MaxIterations): XorFilter8 =
  ## Build Xor filter from set of string keys
  ##
  ## Uses "peeling" algorithm to construct filter:
  ## 1. Map each key to 3 locations (3-partite hypergraph)
  ## 2. Find keys that map to unique location (singleton)
  ## 3. "Peel" singleton keys and update remaining keys
  ## 4. Repeat until all keys processed
  ## 5. Assign fingerprints in reverse order
  ##
  ## If construction fails, retry with different seed (up to maxAttempts)
  ##
  ## Time: O(n) average case, O(n²) worst case
  ## Space: ~9 bits per key
  if keys.len == 0:
    raise newException(ValueError, "Cannot build filter from empty key set")

  let n = keys.len
  let capacity = int(n.float64 * SizeFactor) + SizeOffset
  let blockLength = (capacity + 2) div 3  # Divide into 3 equal blocks

  # Convert keys to 64-bit hashes
  var hashes = newSeq[uint64](n)

  for attempt in 0..<maxAttempts:
    let seed = attempt.uint64 * 0x9e3779b97f4a7c15'u64  # Golden ratio

    # Hash all keys with current seed
    for i in 0..<n:
      hashes[i] = hashToKey(keys[i].toOpenArrayByte(0, keys[i].len - 1), seed)

    # Initialize XOR sets for each array position
    var sets = newSeq[XorSet](3 * blockLength)

    for hash in hashes:
      let h0 = getH0(hash, blockLength)
      let h1 = getH1(hash, blockLength)
      let h2 = getH2(hash, blockLength)

      sets[h0].xorMask = sets[h0].xorMask xor hash
      sets[h0].count += 1
      sets[h1].xorMask = sets[h1].xorMask xor hash
      sets[h1].count += 1
      sets[h2].xorMask = sets[h2].xorMask xor hash
      sets[h2].count += 1

    # Peeling: find singleton keys (count == 1) and process them
    var stack = newSeq[KeyIndex]()
    var alone = newSeq[int]()

    # Find initial singleton positions
    for i in 0..<sets.len:
      if sets[i].count == 1:
        alone.add(i)

    # Peel singleton keys
    while alone.len > 0:
      let pos = alone.pop()
      if sets[pos].count != 1:
        continue  # Already processed

      let hash = sets[pos].xorMask
      stack.add(KeyIndex(hash: hash, index: pos))

      # Remove this key from the other two locations
      let h0 = getH0(hash, blockLength)
      let h1 = getH1(hash, blockLength)
      let h2 = getH2(hash, blockLength)

      sets[h0].xorMask = sets[h0].xorMask xor hash
      sets[h0].count -= 1
      if sets[h0].count == 1:
        alone.add(h0)

      sets[h1].xorMask = sets[h1].xorMask xor hash
      sets[h1].count -= 1
      if sets[h1].count == 1:
        alone.add(h1)

      sets[h2].xorMask = sets[h2].xorMask xor hash
      sets[h2].count -= 1
      if sets[h2].count == 1:
        alone.add(h2)

    # Check if peeling succeeded (all keys processed)
    if stack.len != n:
      continue  # Construction failed, retry with different seed

    # Construction succeeded! Assign fingerprints in reverse order
    result.seed = seed
    result.blockLength = blockLength
    result.fingerprints = newSeq[uint8](3 * blockLength)

    # Process stack in reverse to assign fingerprints
    for i in countdown(stack.len - 1, 0):
      let ki = stack[i]
      let hash = ki.hash

      let h0 = getH0(hash, blockLength)
      let h1 = getH1(hash, blockLength)
      let h2 = getH2(hash, blockLength)

      # fingerprint = B[h0] ⊕ B[h1] ⊕ B[h2] ⊕ fingerprint(hash)
      let fp = fingerprint8(hash)
      result.fingerprints[ki.index] = fp xor
        result.fingerprints[h0] xor
        result.fingerprints[h1] xor
        result.fingerprints[h2]

    return

  raise newException(ValueError, "Failed to construct Xor filter after " & $maxAttempts & " attempts")

proc buildXorFilter8*[T](keys: openArray[T], maxAttempts: int = MaxIterations): XorFilter8 =
  ## Build Xor filter from hashable keys
  var stringKeys = newSeq[string](keys.len)
  for i in 0..<keys.len:
    stringKeys[i] = $hash(keys[i])
  result = buildXorFilter8(stringKeys, maxAttempts)

# =============================================================================
# Query (Xor Filter 8-bit)
# =============================================================================

proc contains*(filter: XorFilter8, key: string): bool =
  ## Test if key is in set (may have false positives)
  ##
  ## Query algorithm:
  ## 1. Hash key to get 64-bit hash
  ## 2. Compute 3 locations: h0, h1, h2
  ## 3. XOR the 3 fingerprints: B[h0] ⊕ B[h1] ⊕ B[h2]
  ## 4. Compare with expected fingerprint
  ##
  ## Time: O(1) - exactly 3 memory accesses
  let hash = hashToKey(key.toOpenArrayByte(0, key.len - 1), filter.seed)

  let h0 = getH0(hash, filter.blockLength)
  let h1 = getH1(hash, filter.blockLength)
  let h2 = getH2(hash, filter.blockLength)

  let xorVal = filter.fingerprints[h0] xor
               filter.fingerprints[h1] xor
               filter.fingerprints[h2]

  result = xorVal == fingerprint8(hash)

proc contains*[T](filter: XorFilter8, key: T): bool =
  ## Test if hashable key is in set
  filter.contains($hash(key))

# =============================================================================
# Construction Algorithm (Xor Filter 16-bit)
# =============================================================================

proc buildXorFilter16*(keys: openArray[string], maxAttempts: int = MaxIterations): XorFilter16 =
  ## Build Xor filter with 16-bit fingerprints
  ## Lower false positive rate (~0.0015%) than 8-bit version
  if keys.len == 0:
    raise newException(ValueError, "Cannot build filter from empty key set")

  let n = keys.len
  let capacity = int(n.float64 * SizeFactor) + SizeOffset
  let blockLength = (capacity + 2) div 3

  var hashes = newSeq[uint64](n)

  for attempt in 0..<maxAttempts:
    let seed = attempt.uint64 * 0x9e3779b97f4a7c15'u64

    for i in 0..<n:
      hashes[i] = hashToKey(keys[i].toOpenArrayByte(0, keys[i].len - 1), seed)

    var sets = newSeq[XorSet](3 * blockLength)

    for hash in hashes:
      let h0 = getH0(hash, blockLength)
      let h1 = getH1(hash, blockLength)
      let h2 = getH2(hash, blockLength)
      sets[h0].xorMask = sets[h0].xorMask xor hash
      sets[h0].count += 1
      sets[h1].xorMask = sets[h1].xorMask xor hash
      sets[h1].count += 1
      sets[h2].xorMask = sets[h2].xorMask xor hash
      sets[h2].count += 1

    var stack = newSeq[KeyIndex]()
    var alone = newSeq[int]()

    for i in 0..<sets.len:
      if sets[i].count == 1:
        alone.add(i)

    while alone.len > 0:
      let pos = alone.pop()
      if sets[pos].count != 1:
        continue

      let hash = sets[pos].xorMask
      stack.add(KeyIndex(hash: hash, index: pos))

      let h0 = getH0(hash, blockLength)
      let h1 = getH1(hash, blockLength)
      let h2 = getH2(hash, blockLength)

      sets[h0].xorMask = sets[h0].xorMask xor hash
      sets[h0].count -= 1
      if sets[h0].count == 1:
        alone.add(h0)

      sets[h1].xorMask = sets[h1].xorMask xor hash
      sets[h1].count -= 1
      if sets[h1].count == 1:
        alone.add(h1)

      sets[h2].xorMask = sets[h2].xorMask xor hash
      sets[h2].count -= 1
      if sets[h2].count == 1:
        alone.add(h2)

    if stack.len != n:
      continue

    result.seed = seed
    result.blockLength = blockLength
    result.fingerprints = newSeq[uint16](3 * blockLength)

    for i in countdown(stack.len - 1, 0):
      let ki = stack[i]
      let hash = ki.hash
      let h0 = getH0(hash, blockLength)
      let h1 = getH1(hash, blockLength)
      let h2 = getH2(hash, blockLength)
      let fp = fingerprint16(hash)
      result.fingerprints[ki.index] = fp xor
        result.fingerprints[h0] xor
        result.fingerprints[h1] xor
        result.fingerprints[h2]

    return

  raise newException(ValueError, "Failed to construct Xor filter after " & $maxAttempts & " attempts")

proc contains*(filter: XorFilter16, key: string): bool =
  ## Test if key is in 16-bit filter
  let hash = hashToKey(key.toOpenArrayByte(0, key.len - 1), filter.seed)
  let h0 = getH0(hash, filter.blockLength)
  let h1 = getH1(hash, filter.blockLength)
  let h2 = getH2(hash, filter.blockLength)
  let xorVal = filter.fingerprints[h0] xor
               filter.fingerprints[h1] xor
               filter.fingerprints[h2]
  result = xorVal == fingerprint16(hash)

# =============================================================================
# Utilities
# =============================================================================

proc size*(filter: XorFilter8): int =
  ## Get number of keys in filter (estimated)
  int((filter.blockLength * 3 - SizeOffset).float64 / SizeFactor)

proc size*(filter: XorFilter16): int =
  int((filter.blockLength * 3 - SizeOffset).float64 / SizeFactor)

proc memoryUsage*(filter: XorFilter8): int =
  ## Get memory usage in bytes
  filter.fingerprints.len + 16  # Fingerprints + overhead

proc memoryUsage*(filter: XorFilter16): int =
  filter.fingerprints.len * 2 + 16

proc bitsPerKey*(filter: XorFilter8): float64 =
  ## Get bits per key (space efficiency metric)
  (filter.memoryUsage().float64 * 8.0) / filter.size().float64

proc bitsPerKey*(filter: XorFilter16): float64 =
  (filter.memoryUsage().float64 * 8.0) / filter.size().float64

proc falsePositiveRate*(filter: XorFilter8): float64 =
  ## Expected false positive rate for 8-bit filter
  1.0 / 256.0  # 2^(-8)

proc falsePositiveRate*(filter: XorFilter16): float64 =
  ## Expected false positive rate for 16-bit filter
  1.0 / 65536.0  # 2^(-16)

proc `$`*(filter: XorFilter8): string =
  result = "XorFilter8(size=" & $filter.size() &
           ", memory=" & $(filter.memoryUsage().float64 / 1024.0) & " KB" &
           ", bits/key=" & $filter.bitsPerKey().formatFloat(ffDecimal, 2) &
           ", FP~" & $(filter.falsePositiveRate() * 100.0) & "%)"

proc `$`*(filter: XorFilter16): string =
  result = "XorFilter16(size=" & $filter.size() &
           ", memory=" & $(filter.memoryUsage().float64 / 1024.0) & " KB" &
           ", bits/key=" & $filter.bitsPerKey().formatFloat(ffDecimal, 2) &
           ", FP~" & $(filter.falsePositiveRate() * 100.0) & "%)"

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/[random, times, strformat, sets]

  echo "Xor Filter - Approximate Membership Testing"
  echo "==========================================="
  echo ""

  # Test 1: Basic membership test
  echo "Test 1: Basic membership testing"
  echo "--------------------------------"

  let testKeys = ["alice", "bob", "charlie", "david", "eve", "frank", "grace", "henry"]
  let filter1 = buildXorFilter8(testKeys)

  echo "Built filter with ", testKeys.len, " keys"
  echo "Memory: ", filter1.memoryUsage(), " bytes (", filter1.bitsPerKey().formatFloat(ffDecimal, 2), " bits/key)"
  echo ""

  echo "Membership tests:"
  for key in testKeys:
    echo "  '", key, "': ", filter1.contains(key)

  echo ""
  echo "Non-members (should be false, may have rare false positives):"
  let nonMembers = ["zara", "quinn", "oscar", "nancy"]
  for key in nonMembers:
    echo "  '", key, "': ", filter1.contains(key)

  echo ""

  # Test 2: False positive rate
  echo "Test 2: False positive rate measurement"
  echo "---------------------------------------"

  # Build filter with 10K keys
  var keys2 = newSeq[string](10_000)
  for i in 0..<10_000:
    keys2[i] = "key_" & $i

  let filter2 = buildXorFilter8(keys2)

  # Test with 100K non-member queries
  var falsePositives = 0
  let numTests = 100_000

  for i in 0..<numTests:
    let testKey = "nonmember_" & $i
    if filter2.contains(testKey):
      inc falsePositives

  let measuredFPRate = falsePositives.float64 / numTests.float64

  echo "Filter built with 10,000 keys"
  echo "Tested ", numTests, " non-members"
  echo "False positives: ", falsePositives
  echo "Measured FP rate: ", (measuredFPRate * 100.0).formatFloat(ffDecimal, 3), "%"
  echo "Expected FP rate: ", (filter2.falsePositiveRate() * 100.0).formatFloat(ffDecimal, 3), "%"
  echo ""

  # Test 3: Performance benchmark
  echo "Test 3: Performance benchmark"
  echo "----------------------------"

  let numKeys = 1_000_000
  var keys3 = newSeq[string](numKeys)
  for i in 0..<numKeys:
    keys3[i] = "item_" & $i

  echo "Building filter with ", numKeys, " keys..."
  let buildStart = cpuTime()
  let filter3 = buildXorFilter8(keys3)
  let buildTime = cpuTime() - buildStart

  echo "Build time: ", (buildTime * 1000.0).formatFloat(ffDecimal, 2), " ms"
  echo "Build throughput: ", (numKeys.float64 / buildTime / 1_000_000.0).formatFloat(ffDecimal, 2), " M keys/sec"
  echo ""

  echo "Memory usage: ", (filter3.memoryUsage().float64 / 1024.0 / 1024.0).formatFloat(ffDecimal, 2), " MB"
  echo "Bits per key: ", filter3.bitsPerKey().formatFloat(ffDecimal, 2)
  echo ""

  # Query benchmark
  let numQueries = 1_000_000
  var hits = 0

  let queryStart = cpuTime()
  for i in 0..<numQueries:
    if filter3.contains("item_" & $i):
      inc hits
  let queryTime = cpuTime() - queryStart

  echo "Query time for ", numQueries, " lookups: ", (queryTime * 1000.0).formatFloat(ffDecimal, 2), " ms"
  echo "Query throughput: ", (numQueries.float64 / queryTime / 1_000_000.0).formatFloat(ffDecimal, 2), " M queries/sec"
  echo "Hits: ", hits, " (should be ~", numQueries, ")"
  echo ""

  # Test 4: Compare 8-bit vs 16-bit
  echo "Test 4: Compare 8-bit vs 16-bit filters"
  echo "---------------------------------------"

  let compareKeys = (0..<10_000).mapIt("key_" & $it)
  let filter8 = buildXorFilter8(compareKeys)
  let filter16 = buildXorFilter16(compareKeys)

  echo "XorFilter8:"
  echo "  Memory: ", filter8.memoryUsage(), " bytes (", filter8.bitsPerKey().formatFloat(ffDecimal, 2), " bits/key)"
  echo "  FP rate: ", (filter8.falsePositiveRate() * 100.0).formatFloat(ffDecimal, 4), "%"
  echo ""

  echo "XorFilter16:"
  echo "  Memory: ", filter16.memoryUsage(), " bytes (", filter16.bitsPerKey().formatFloat(ffDecimal, 2), " bits/key)"
  echo "  FP rate: ", (filter16.falsePositiveRate() * 100.0).formatFloat(ffDecimal, 4), "%"
  echo ""

  echo "All tests completed!"
