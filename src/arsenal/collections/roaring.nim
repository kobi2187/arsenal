## Roaring Bitmaps
## ================
##
## Compressed bitmap data structure for efficient storage of sets of unsigned integers.
## Outperforms traditional run-length encoded bitmaps (WAH, EWAH, Concise).
##
## Paper: "Better bitmap performance with Roaring bitmaps"
##        Chambi, Lemire, Kaser, Godin (2016)
##        Software: Practice and Experience 46(5)
##        arXiv:1402.6407
##        https://arxiv.org/abs/1402.6407
##
## Key Innovation:
## - Hybrid data structure: uses different encodings based on data density
## - Three container types: Array, Bitmap, Run (auto-selected)
## - Two-level structure: high 16 bits select container, low 16 bits stored in container
##
## Performance:
## - **Space**: Often 2× better compression than RLE-based bitmaps
## - **Speed**: Up to 900× faster for intersections vs traditional compressed bitmaps
## - **Operations**: Fast set operations (AND, OR, XOR, NOT)
##
## Applications:
## - Database indexes (Apache Lucene, Apache Spark, Apache Pinot)
## - Analytics (Netflix Atlas, Pilosa)
## - Search engines and inverted indexes
## - Set operations on large integer sets
##
## Usage:
## ```nim
## import arsenal/collections/roaring
##
## var rb = initRoaringBitmap()
##
## # Add integers
## rb.add(1)
## rb.add(100)
## rb.add(1000)
##
## # Test membership
## assert rb.contains(100)
## assert not rb.contains(50)
##
## # Set operations
## var rb2 = initRoaringBitmap()
## rb2.add(100)
## rb2.add(200)
##
## let union = rb or rb2
## let intersection = rb and rb2
## ```

import std/[algorithm, math, bitops]

# =============================================================================
# Constants
# =============================================================================

const
  # Container type thresholds
  ArrayContainerMaxSize = 4096  ## Array → Bitmap threshold

  # Container sizes
  BitmapContainerSize = 8192    ## 2^16 bits / 8 = 8192 bytes
  BitmapContainerWords = 1024   ## 8192 bytes / 8 = 1024 uint64s

# =============================================================================
# Container Types
# =============================================================================

type
  ContainerKind* = enum
    ## Type of container encoding
    ArrayContainer   ## Sorted array of uint16 (dense: ≤ 4096 elements)
    BitmapContainer  ## Bitmap of 2^16 bits (sparse: > 4096 elements)
    RunContainer     ## Run-length encoded (consecutive values)

  Container* = object
    ## Container holds values for one 2^16 range
    case kind*: ContainerKind
    of ArrayContainer:
      array*: seq[uint16]        ## Sorted array of 16-bit values
    of BitmapContainer:
      bitmap*: seq[uint64]       ## Bitmap (1024 × 64-bit words)
    of RunContainer:
      runs*: seq[tuple[start: uint16, length: uint16]]  ## Run-length encoding

  RoaringBitmap* = object
    ## Roaring bitmap: compressed set of uint32 integers
    ##
    ## Two-level structure:
    ## - High 16 bits: key (which container)
    ## - Low 16 bits: value (position in container)
    keys*: seq[uint16]           ## High 16 bits (sorted)
    containers*: seq[Container]  ## Containers for each key

# =============================================================================
# Container Operations - Array
# =============================================================================

proc initArrayContainer(): Container {.inline.} =
  Container(kind: ArrayContainer, array: newSeq[uint16]())

proc addToArray(c: var Container, value: uint16) =
  ## Add value to array container (maintains sorted order)
  # Binary search for insertion point
  var
    left = 0
    right = c.array.len

  while left < right:
    let mid = (left + right) div 2
    if c.array[mid] < value:
      left = mid + 1
    elif c.array[mid] > value:
      right = mid
    else:
      return  # Already present

  c.array.insert(value, left)

proc containsInArray(c: Container, value: uint16): bool =
  ## Check if value exists in array container (binary search)
  var
    left = 0
    right = c.array.len - 1

  while left <= right:
    let mid = (left + right) div 2
    if c.array[mid] == value:
      return true
    elif c.array[mid] < value:
      left = mid + 1
    else:
      right = mid - 1

  false

proc removeFromArray(c: var Container, value: uint16): bool =
  ## Remove value from array container
  var
    left = 0
    right = c.array.len - 1

  while left <= right:
    let mid = (left + right) div 2
    if c.array[mid] == value:
      c.array.delete(mid)
      return true
    elif c.array[mid] < value:
      left = mid + 1
    else:
      right = mid - 1

  false

# =============================================================================
# Container Operations - Bitmap
# =============================================================================

proc initBitmapContainer(): Container {.inline.} =
  Container(kind: BitmapContainer, bitmap: newSeq[uint64](BitmapContainerWords))

proc addToBitmap(c: var Container, value: uint16) =
  ## Add value to bitmap container
  let
    wordIdx = value shr 6           # value / 64
    bitIdx = value and 0x3F         # value mod 64
  c.bitmap[wordIdx] = c.bitmap[wordIdx] or (1'u64 shl bitIdx)

proc containsInBitmap(c: Container, value: uint16): bool =
  ## Check if value exists in bitmap container
  let
    wordIdx = value shr 6
    bitIdx = value and 0x3F
  result = (c.bitmap[wordIdx] and (1'u64 shl bitIdx)) != 0

proc removeFromBitmap(c: var Container, value: uint16): bool =
  ## Remove value from bitmap container
  let
    wordIdx = value shr 6
    bitIdx = value and 0x3F
    mask = 1'u64 shl bitIdx

  if (c.bitmap[wordIdx] and mask) != 0:
    c.bitmap[wordIdx] = c.bitmap[wordIdx] and (not mask)
    return true
  false

# =============================================================================
# Container Cardinality
# =============================================================================

proc cardinality*(c: Container): int =
  ## Count number of elements in container
  case c.kind
  of ArrayContainer:
    c.array.len
  of BitmapContainer:
    var count = 0
    for word in c.bitmap:
      count += popcount(word)
    count
  of RunContainer:
    var count = 0
    for run in c.runs:
      count += run.length.int + 1
    count

# =============================================================================
# Container Conversion (Array ↔ Bitmap)
# =============================================================================

proc arrayToBitmap(c: Container): Container =
  ## Convert array container to bitmap container
  result = initBitmapContainer()
  for value in c.array:
    result.addToBitmap(value)

proc bitmapToArray(c: Container): Container =
  ## Convert bitmap container to array container
  result = initArrayContainer()
  for wordIdx in 0..<BitmapContainerWords:
    if c.bitmap[wordIdx] != 0:
      for bitIdx in 0..<64:
        if (c.bitmap[wordIdx] and (1'u64 shl bitIdx)) != 0:
          result.array.add((wordIdx.uint16 shl 6) or bitIdx.uint16)

proc optimizeContainer(c: Container): Container =
  ## Optimize container encoding based on cardinality
  let card = c.cardinality()

  case c.kind
  of ArrayContainer:
    if card > ArrayContainerMaxSize:
      # Convert to bitmap (too many elements for array)
      result = c.arrayToBitmap()
    else:
      result = c
  of BitmapContainer:
    if card <= ArrayContainerMaxSize:
      # Convert to array (too few elements for bitmap)
      result = c.bitmapToArray()
    else:
      result = c
  of RunContainer:
    # Keep run container as-is for now
    result = c

# =============================================================================
# RoaringBitmap Construction
# =============================================================================

proc initRoaringBitmap*(): RoaringBitmap =
  ## Create empty Roaring bitmap
  RoaringBitmap(
    keys: newSeq[uint16](),
    containers: newSeq[Container]()
  )

proc getContainerIndex(rb: RoaringBitmap, key: uint16): int =
  ## Find container index for key (binary search)
  ## Returns -1 if not found, -(insertPos+1) if should insert
  var
    left = 0
    right = rb.keys.len - 1

  while left <= right:
    let mid = (left + right) div 2
    if rb.keys[mid] == key:
      return mid
    elif rb.keys[mid] < key:
      left = mid + 1
    else:
      right = mid - 1

  -(left + 1)  # Not found, return insert position

# =============================================================================
# RoaringBitmap Operations
# =============================================================================

proc add*(rb: var RoaringBitmap, value: uint32) =
  ## Add integer to bitmap
  ##
  ## Time: O(log n + log k) where n = number of containers, k = container size
  let
    key = (value shr 16).uint16     # High 16 bits
    lowBits = (value and 0xFFFF).uint16  # Low 16 bits

  let idx = rb.getContainerIndex(key)

  if idx >= 0:
    # Container exists, add to it
    case rb.containers[idx].kind
    of ArrayContainer:
      rb.containers[idx].addToArray(lowBits)
      # Check if we need to convert to bitmap
      if rb.containers[idx].array.len > ArrayContainerMaxSize:
        rb.containers[idx] = rb.containers[idx].arrayToBitmap()
    of BitmapContainer:
      rb.containers[idx].addToBitmap(lowBits)
    of RunContainer:
      # For now, treat run containers like arrays
      discard
  else:
    # Create new container
    let insertPos = -(idx + 1)
    var newContainer = initArrayContainer()
    newContainer.array.add(lowBits)

    rb.keys.insert(key, insertPos)
    rb.containers.insert(newContainer, insertPos)

proc contains*(rb: RoaringBitmap, value: uint32): bool =
  ## Test if value is in bitmap
  ##
  ## Time: O(log n + log k)
  let
    key = (value shr 16).uint16
    lowBits = (value and 0xFFFF).uint16

  let idx = rb.getContainerIndex(key)
  if idx < 0:
    return false

  case rb.containers[idx].kind
  of ArrayContainer:
    rb.containers[idx].containsInArray(lowBits)
  of BitmapContainer:
    rb.containers[idx].containsInBitmap(lowBits)
  of RunContainer:
    false  # TODO: implement run container search

proc remove*(rb: var RoaringBitmap, value: uint32): bool =
  ## Remove value from bitmap
  ##
  ## Returns true if value was present
  let
    key = (value shr 16).uint16
    lowBits = (value and 0xFFFF).uint16

  let idx = rb.getContainerIndex(key)
  if idx < 0:
    return false

  var removed = false
  case rb.containers[idx].kind
  of ArrayContainer:
    removed = rb.containers[idx].removeFromArray(lowBits)
  of BitmapContainer:
    removed = rb.containers[idx].removeFromBitmap(lowBits)
    # Convert to array if too sparse
    if rb.containers[idx].cardinality() <= ArrayContainerMaxSize:
      rb.containers[idx] = rb.containers[idx].bitmapToArray()
  of RunContainer:
    discard

  # Remove container if empty
  if removed and rb.containers[idx].cardinality() == 0:
    rb.keys.delete(idx)
    rb.containers.delete(idx)

  removed

proc cardinality*(rb: RoaringBitmap): int =
  ## Count total number of elements in bitmap
  ##
  ## Time: O(n) where n = number of containers
  for container in rb.containers:
    result += container.cardinality()

proc isEmpty*(rb: RoaringBitmap): bool =
  ## Check if bitmap is empty
  rb.keys.len == 0

proc clear*(rb: var RoaringBitmap) =
  ## Remove all elements
  rb.keys.setLen(0)
  rb.containers.setLen(0)

# =============================================================================
# Set Operations
# =============================================================================

proc `or`*(rb1, rb2: RoaringBitmap): RoaringBitmap =
  ## Union of two bitmaps (rb1 ∪ rb2)
  ##
  ## Time: O(n + m) where n, m = number of containers
  result = initRoaringBitmap()

  var
    i = 0
    j = 0

  while i < rb1.keys.len and j < rb2.keys.len:
    if rb1.keys[i] < rb2.keys[j]:
      result.keys.add(rb1.keys[i])
      result.containers.add(rb1.containers[i])
      inc i
    elif rb1.keys[i] > rb2.keys[j]:
      result.keys.add(rb2.keys[j])
      result.containers.add(rb2.containers[j])
      inc j
    else:
      # Same key: merge containers
      result.keys.add(rb1.keys[i])

      # For simplicity, convert both to bitmap and OR
      let c1 = if rb1.containers[i].kind == BitmapContainer:
        rb1.containers[i]
      else:
        rb1.containers[i].arrayToBitmap()

      let c2 = if rb2.containers[j].kind == BitmapContainer:
        rb2.containers[j]
      else:
        rb2.containers[j].arrayToBitmap()

      var merged = initBitmapContainer()
      for k in 0..<BitmapContainerWords:
        merged.bitmap[k] = c1.bitmap[k] or c2.bitmap[k]

      result.containers.add(merged.optimizeContainer())
      inc i
      inc j

  # Add remaining containers
  while i < rb1.keys.len:
    result.keys.add(rb1.keys[i])
    result.containers.add(rb1.containers[i])
    inc i

  while j < rb2.keys.len:
    result.keys.add(rb2.keys[j])
    result.containers.add(rb2.containers[j])
    inc j

proc `and`*(rb1, rb2: RoaringBitmap): RoaringBitmap =
  ## Intersection of two bitmaps (rb1 ∩ rb2)
  ##
  ## Time: O(min(n, m))
  result = initRoaringBitmap()

  var
    i = 0
    j = 0

  while i < rb1.keys.len and j < rb2.keys.len:
    if rb1.keys[i] < rb2.keys[j]:
      inc i
    elif rb1.keys[i] > rb2.keys[j]:
      inc j
    else:
      # Same key: intersect containers
      let c1 = if rb1.containers[i].kind == BitmapContainer:
        rb1.containers[i]
      else:
        rb1.containers[i].arrayToBitmap()

      let c2 = if rb2.containers[j].kind == BitmapContainer:
        rb2.containers[j]
      else:
        rb2.containers[j].arrayToBitmap()

      var intersected = initBitmapContainer()
      for k in 0..<BitmapContainerWords:
        intersected.bitmap[k] = c1.bitmap[k] and c2.bitmap[k]

      if intersected.cardinality() > 0:
        result.keys.add(rb1.keys[i])
        result.containers.add(intersected.optimizeContainer())

      inc i
      inc j

proc `xor`*(rb1, rb2: RoaringBitmap): RoaringBitmap =
  ## Symmetric difference of two bitmaps (rb1 ⊕ rb2)
  ##
  ## Time: O(n + m)
  result = initRoaringBitmap()

  var
    i = 0
    j = 0

  while i < rb1.keys.len and j < rb2.keys.len:
    if rb1.keys[i] < rb2.keys[j]:
      result.keys.add(rb1.keys[i])
      result.containers.add(rb1.containers[i])
      inc i
    elif rb1.keys[i] > rb2.keys[j]:
      result.keys.add(rb2.keys[j])
      result.containers.add(rb2.containers[j])
      inc j
    else:
      # Same key: XOR containers
      let c1 = if rb1.containers[i].kind == BitmapContainer:
        rb1.containers[i]
      else:
        rb1.containers[i].arrayToBitmap()

      let c2 = if rb2.containers[j].kind == BitmapContainer:
        rb2.containers[j]
      else:
        rb2.containers[j].arrayToBitmap()

      var xored = initBitmapContainer()
      for k in 0..<BitmapContainerWords:
        xored.bitmap[k] = c1.bitmap[k] xor c2.bitmap[k]

      if xored.cardinality() > 0:
        result.keys.add(rb1.keys[i])
        result.containers.add(xored.optimizeContainer())

      inc i
      inc j

  # Add remaining
  while i < rb1.keys.len:
    result.keys.add(rb1.keys[i])
    result.containers.add(rb1.containers[i])
    inc i

  while j < rb2.keys.len:
    result.keys.add(rb2.keys[j])
    result.containers.add(rb2.containers[j])
    inc j

proc `-`*(rb1, rb2: RoaringBitmap): RoaringBitmap =
  ## Difference of two bitmaps (rb1 \ rb2)
  ##
  ## Elements in rb1 but not in rb2
  result = initRoaringBitmap()

  var
    i = 0
    j = 0

  while i < rb1.keys.len:
    if j >= rb2.keys.len or rb1.keys[i] < rb2.keys[j]:
      result.keys.add(rb1.keys[i])
      result.containers.add(rb1.containers[i])
      inc i
    elif rb1.keys[i] > rb2.keys[j]:
      inc j
    else:
      # Same key: difference containers
      let c1 = if rb1.containers[i].kind == BitmapContainer:
        rb1.containers[i]
      else:
        rb1.containers[i].arrayToBitmap()

      let c2 = if rb2.containers[j].kind == BitmapContainer:
        rb2.containers[j]
      else:
        rb2.containers[j].arrayToBitmap()

      var diff = initBitmapContainer()
      for k in 0..<BitmapContainerWords:
        diff.bitmap[k] = c1.bitmap[k] and (not c2.bitmap[k])

      if diff.cardinality() > 0:
        result.keys.add(rb1.keys[i])
        result.containers.add(diff.optimizeContainer())

      inc i
      inc j

# =============================================================================
# Iteration
# =============================================================================

iterator items*(rb: RoaringBitmap): uint32 =
  ## Iterate over all values in bitmap (ascending order)
  for i in 0..<rb.keys.len:
    let keyBase = rb.keys[i].uint32 shl 16

    case rb.containers[i].kind
    of ArrayContainer:
      for value in rb.containers[i].array:
        yield keyBase or value.uint32
    of BitmapContainer:
      for wordIdx in 0..<BitmapContainerWords:
        if rb.containers[i].bitmap[wordIdx] != 0:
          for bitIdx in 0..<64:
            if (rb.containers[i].bitmap[wordIdx] and (1'u64 shl bitIdx)) != 0:
              let value = (wordIdx.uint32 shl 6) or bitIdx.uint32
              yield keyBase or value
    of RunContainer:
      discard  # TODO: implement run container iteration

# =============================================================================
# Utilities
# =============================================================================

proc `$`*(rb: RoaringBitmap): string =
  result = "RoaringBitmap(cardinality=" & $rb.cardinality() &
           ", containers=" & $rb.keys.len & ")"

proc memoryUsage*(rb: RoaringBitmap): int =
  ## Estimate memory usage in bytes
  result = rb.keys.len * 2  # Keys

  for container in rb.containers:
    case container.kind
    of ArrayContainer:
      result += container.array.len * 2
    of BitmapContainer:
      result += BitmapContainerSize
    of RunContainer:
      result += container.runs.len * 4

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "Roaring Bitmaps - Compressed Integer Sets"
  echo "========================================="
  echo ""

  # Test 1: Basic operations
  echo "Test 1: Basic operations"
  echo "-----------------------"

  var rb1 = initRoaringBitmap()

  # Add some integers
  for i in [1'u32, 100, 1000, 10000, 100000]:
    rb1.add(i)

  echo "Added: 1, 100, 1000, 10000, 100000"
  echo "Cardinality: ", rb1.cardinality()
  echo ""

  echo "Membership tests:"
  echo "  contains(100): ", rb1.contains(100)
  echo "  contains(500): ", rb1.contains(500)
  echo ""

  # Test 2: Set operations
  echo "Test 2: Set operations"
  echo "---------------------"

  var rb2 = initRoaringBitmap()
  var rb3 = initRoaringBitmap()

  for i in 0'u32..<100:
    rb2.add(i)

  for i in 50'u32..<150:
    rb3.add(i)

  echo "rb2: [0..99], cardinality = ", rb2.cardinality()
  echo "rb3: [50..149], cardinality = ", rb3.cardinality()
  echo ""

  let union = rb2 or rb3
  let intersection = rb2 and rb3
  let difference = rb2 - rb3
  let symDiff = rb2 xor rb3

  echo "Union (rb2 ∪ rb3): ", union.cardinality()
  echo "Intersection (rb2 ∩ rb3): ", intersection.cardinality()
  echo "Difference (rb2 \ rb3): ", difference.cardinality()
  echo "Symmetric difference (rb2 ⊕ rb3): ", symDiff.cardinality()
  echo ""

  # Test 3: Large bitmap
  echo "Test 3: Large bitmap with 1M integers"
  echo "-------------------------------------"

  var rb4 = initRoaringBitmap()
  let numInts = 1_000_000

  let addStart = cpuTime()
  for i in 0'u32..<numInts.uint32:
    rb4.add(i)
  let addTime = cpuTime() - addStart

  echo "Added ", numInts, " integers"
  echo "Time: ", (addTime * 1000.0).formatFloat(ffDecimal, 2), " ms"
  echo "Throughput: ", (numInts.float64 / addTime / 1_000_000.0).formatFloat(ffDecimal, 2), " M ops/sec"
  echo "Cardinality: ", rb4.cardinality()
  echo "Memory usage: ", (rb4.memoryUsage().float64 / 1024.0 / 1024.0).formatFloat(ffDecimal, 2), " MB"
  echo "Bits per integer: ", (rb4.memoryUsage().float64 * 8.0 / numInts.float64).formatFloat(ffDecimal, 2)
  echo ""

  # Lookup benchmark
  let lookupStart = cpuTime()
  var found = 0
  for i in 0'u32..<numInts.uint32:
    if rb4.contains(i):
      inc found
  let lookupTime = cpuTime() - lookupStart

  echo "Lookup time for ", numInts, " queries: ", (lookupTime * 1000.0).formatFloat(ffDecimal, 2), " ms"
  echo "Lookup throughput: ", (numInts.float64 / lookupTime / 1_000_000.0).formatFloat(ffDecimal, 2), " M queries/sec"
  echo ""

  # Test 4: Sparse bitmap
  echo "Test 4: Sparse bitmap"
  echo "--------------------"

  var rb5 = initRoaringBitmap()

  # Add sparse values (every 1000th value)
  for i in 0'u32..<1_000_000'u32:
    if i mod 1000 == 0:
      rb5.add(i)

  echo "Added 1000 sparse integers (every 1000th from 0..1M)"
  echo "Cardinality: ", rb5.cardinality()
  echo "Memory usage: ", rb5.memoryUsage(), " bytes"
  echo "Bytes per integer: ", (rb5.memoryUsage().float64 / rb5.cardinality().float64).formatFloat(ffDecimal, 2)
  echo ""

  echo "All tests completed!"
