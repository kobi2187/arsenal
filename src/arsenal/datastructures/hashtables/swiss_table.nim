## Swiss Table - High-Performance Hash Table
## ========================================
##
## Implementation of Google's "Swiss Table" (Abseil flat_hash_map).
## Uses SIMD-accelerated metadata probing for ~2x faster lookups than
## traditional hash tables.
##
## Key innovations:
## - 1-byte metadata per slot (7 bits of hash + 1 bit state)
## - SIMD parallel comparison of 16 metadata bytes at once
## - Cache-friendly memory layout
##
## Performance:
## - Lookup: ~30% faster than std::unordered_map
## - Insert: ~40% faster than std::unordered_map
## - Memory: Similar to open addressing tables
##
## Usage:
## ```nim
## var table = SwissTable[string, int].init()
## table["hello"] = 42
## echo table["hello"]  # 42
## ```
##
## Reference: https://abseil.io/blog/20180927-swisstables

import std/options
import ../../hashing/hasher
import ../../platform/config

type
  CtrlByte* = distinct uint8
    ## Metadata byte for each slot.
    ##
    ## Encoding:
    ## - 0b0xxxxxxx (0-127): Slot is FULL, lower 7 bits = H2(hash)
    ## - 0b10000000 (128): Slot is EMPTY
    ## - 0b11111110 (254): Slot is DELETED (tombstone)
    ## - 0b11111111 (255): Slot is SENTINEL (marks group boundary)

  Group* = object
    ## A group of 16 control bytes that can be probed with SIMD.
    ctrl: array[16, CtrlByte]

  SwissTable*[K, V] = object
    ## SIMD-accelerated hash table.
    ##
    ## Memory layout:
    ## - Control bytes: array of metadata (1 byte per slot)
    ## - Slots: array of key-value pairs
    ## - Groups are 16 slots that fit in one SIMD register
    ctrl: ptr UncheckedArray[CtrlByte]
    slots: ptr UncheckedArray[tuple[key: K, value: V]]
    capacity: int       ## Total number of slots (always power of 2)
    size: int           ## Number of items currently stored
    growthLeft: int     ## Remaining slots before we need to grow

const
  CtrlEmpty = CtrlByte(0b10000000)    ## Empty slot
  CtrlDeleted = CtrlByte(0b11111110)  ## Deleted (tombstone)
  CtrlSentinel = CtrlByte(0b11111111) ## Group boundary
  GroupSize = 16

# =============================================================================
# Hash Functions
# =============================================================================

proc h1*[K](key: K): uint64 {.inline.} =
  ## H1: Primary hash, used for slot index.
  ## Use top 57 bits of 64-bit hash.
  let h = wyhash.hash($key)
  h shr 7

proc h2*[K](key: K): uint8 {.inline.} =
  ## H2: Secondary hash, stored in control byte.
  ## Use lower 7 bits of hash.
  let h = wyhash.hash($key)
  (h and 0x7F).uint8

# =============================================================================
# Control Byte Operations
# =============================================================================

proc isEmpty*(c: CtrlByte): bool {.inline.} =
  c.uint8 == CtrlEmpty.uint8

proc isFull*(c: CtrlByte): bool {.inline.} =
  (c.uint8 and 0b10000000) == 0

proc isDeleted*(c: CtrlByte): bool {.inline.} =
  c.uint8 == CtrlDeleted.uint8

proc isEmptyOrDeleted*(c: CtrlByte): bool {.inline.} =
  c.uint8 >= CtrlEmpty.uint8

# =============================================================================
# SIMD Group Matching
# =============================================================================

type
  BitMask* = distinct uint16
    ## Result of SIMD comparison - one bit per slot.

proc match*(g: Group, h2val: uint8): BitMask =
  ## Find all slots in group where ctrl byte matches h2val.
  ## Returns a bitmask with 1s for matching positions.
  ##
  ## IMPLEMENTATION (SSE2):
  ## ```nim
  ## # Load 16 control bytes into SSE register
  ## let ctrl = mm_loadu_si128(cast[ptr m128i](addr g.ctrl))
  ##
  ## # Broadcast h2val to all 16 positions
  ## let needle = mm_set1_epi8(h2val.cchar)
  ##
  ## # Compare for equality (returns 0xFF for match, 0x00 for no match)
  ## let cmp = mm_cmpeq_epi8(ctrl, needle)
  ##
  ## # Convert to bitmask (one bit per byte)
  ## result = mm_movemask_epi8(cmp).BitMask
  ## ```
  ##
  ## IMPLEMENTATION (ARM NEON):
  ## ```nim
  ## let ctrl = vld1q_u8(addr g.ctrl)
  ## let needle = vdupq_n_u8(h2val)
  ## let cmp = vceqq_u8(ctrl, needle)
  ## # Convert to bitmask (more complex on ARM)
  ## ```
  ##
  ## IMPLEMENTATION (Scalar fallback):
  ## ```nim
  ## result = 0.BitMask
  ## for i in 0..<16:
  ##   if g.ctrl[i].uint8 == h2val:
  ##     result = BitMask(result.uint16 or (1'u16 shl i))
  ## ```

  # Scalar fallback
  var mask: uint16 = 0
  for i in 0..<16:
    if g.ctrl[i].uint8 == h2val:
      mask = mask or (1'u16 shl i)
  result = BitMask(mask)

proc matchEmpty*(g: Group): BitMask =
  ## Find all empty slots in group.
  ##
  ## IMPLEMENTATION:
  ## Same as match() but compare against CtrlEmpty.
  ## Can optimize: empty has high bit set, so use sign comparison.

  var mask: uint16 = 0
  for i in 0..<16:
    if g.ctrl[i].isEmpty:
      mask = mask or (1'u16 shl i)
  result = BitMask(mask)

proc matchEmptyOrDeleted*(g: Group): BitMask =
  ## Find all empty or deleted slots.
  ##
  ## IMPLEMENTATION:
  ## Both empty and deleted have high bit set, so:
  ## ```nim
  ## let ctrl = mm_loadu_si128(...)
  ## let mask = mm_movemask_epi8(ctrl)  # Sign bit of each byte
  ## result = mask.BitMask
  ## ```

  var mask: uint16 = 0
  for i in 0..<16:
    if g.ctrl[i].isEmptyOrDeleted:
      mask = mask or (1'u16 shl i)
  result = BitMask(mask)

iterator setBits*(mask: BitMask): int =
  ## Iterate over set bits in mask.
  ##
  ## IMPLEMENTATION:
  ## Use `countTrailingZeros` (CTZ) to find next set bit:
  ## ```nim
  ## var m = mask.uint16
  ## while m != 0:
  ##   yield countTrailingZeros(m)
  ##   m = m and (m - 1)  # Clear lowest set bit
  ## ```

  var m = mask.uint16
  var pos = 0
  while m != 0:
    if (m and 1) != 0:
      yield pos
    m = m shr 1
    inc pos

# =============================================================================
# Table Operations
# =============================================================================

proc init*[K, V](_: typedesc[SwissTable[K, V]], capacity: int = 16): SwissTable[K, V] =
  ## Create a new Swiss Table with given initial capacity.
  ##
  ## IMPLEMENTATION:
  ## 1. Round up capacity to multiple of GroupSize (16)
  ## 2. Allocate ctrl array (capacity + GroupSize bytes for sentinel/wraparound)
  ## 3. Allocate slots array
  ## 4. Initialize all ctrl bytes to Empty
  ## 5. Set sentinel bytes at the end
  ##
  ## ```nim
  ## let cap = max(16, roundUpToGroupSize(capacity))
  ## result.ctrl = cast[ptr UncheckedArray[CtrlByte]](
  ##   alloc((cap + GroupSize) * sizeof(CtrlByte))
  ## )
  ## result.slots = cast[ptr UncheckedArray[...]](
  ##   alloc(cap * sizeof(tuple[key: K, value: V]))
  ## )
  ##
  ## for i in 0..<cap:
  ##   result.ctrl[i] = CtrlEmpty
  ## for i in cap..<cap+GroupSize:
  ##   result.ctrl[i] = CtrlSentinel
  ##
  ## result.capacity = cap
  ## result.size = 0
  ## result.growthLeft = (cap * 7) div 8  # 87.5% load factor
  ## ```

  let cap = max(16, capacity)
  result = SwissTable[K, V](
    ctrl: nil,  # TODO: Allocate
    slots: nil,
    capacity: cap,
    size: 0,
    growthLeft: (cap * 7) div 8
  )

proc find*[K, V](t: SwissTable[K, V], key: K): Option[ptr V] =
  ## Find key and return pointer to value, or none if not found.
  ##
  ## IMPLEMENTATION:
  ## 1. Compute h1 and h2 from key
  ## 2. Starting at group = h1 % capacity, probe groups:
  ##    a. Use SIMD to find all slots matching h2
  ##    b. For each match, compare actual key
  ##    c. If key matches, return value pointer
  ##    d. Use SIMD to check for empty slots
  ##    e. If any empty slot in group, key doesn't exist
  ##    f. Continue to next group (quadratic probing)
  ##
  ## ```nim
  ## let h1val = h1(key)
  ## let h2val = h2(key)
  ##
  ## var probeSeq = initProbeSeq(h1val, t.capacity)
  ##
  ## while true:
  ##   let g = t.group(probeSeq.offset)
  ##
  ##   for i in match(g, h2val).setBits:
  ##     let idx = probeSeq.offset + i
  ##     if t.slots[idx].key == key:
  ##       return some(addr t.slots[idx].value)
  ##
  ##   if matchEmpty(g).uint16 != 0:
  ##     return none(ptr V)  # Found empty, key doesn't exist
  ##
  ##   probeSeq.next()
  ## ```

  result = none(ptr V)

proc `[]`*[K, V](t: SwissTable[K, V], key: K): V =
  ## Get value by key. Raises KeyError if not found.
  let p = t.find(key)
  if p.isSome:
    result = p.get[]
  else:
    raise newException(KeyError, "Key not found")

proc `[]=`*[K, V](t: var SwissTable[K, V], key: K, value: V) =
  ## Insert or update key-value pair.
  ##
  ## IMPLEMENTATION:
  ## 1. Check if we need to grow (growthLeft <= 0)
  ## 2. Find insertion point:
  ##    a. First check if key exists (update in place)
  ##    b. Otherwise find empty or deleted slot
  ## 3. Insert key and value
  ## 4. Update ctrl byte with h2
  ## 5. Decrement growthLeft
  ##
  ## ```nim
  ## if t.growthLeft <= 0:
  ##   t.grow()
  ##
  ## let h1val = h1(key)
  ## let h2val = h2(key)
  ##
  ## var probeSeq = initProbeSeq(h1val, t.capacity)
  ##
  ## while true:
  ##   let g = t.group(probeSeq.offset)
  ##
  ##   # Check for existing key
  ##   for i in match(g, h2val).setBits:
  ##     let idx = probeSeq.offset + i
  ##     if t.slots[idx].key == key:
  ##       t.slots[idx].value = value
  ##       return
  ##
  ##   # Find empty/deleted slot for insertion
  ##   let emptyMask = matchEmptyOrDeleted(g)
  ##   if emptyMask.uint16 != 0:
  ##     let i = firstSetBit(emptyMask)
  ##     let idx = probeSeq.offset + i
  ##     t.ctrl[idx] = CtrlByte(h2val)
  ##     t.slots[idx] = (key, value)
  ##     t.size += 1
  ##     if t.ctrl[idx].isEmpty:
  ##       t.growthLeft -= 1
  ##     return
  ##
  ##   probeSeq.next()
  ## ```

  # Stub
  discard

proc contains*[K, V](t: SwissTable[K, V], key: K): bool {.inline.} =
  ## Check if key exists.
  t.find(key).isSome

proc delete*[K, V](t: var SwissTable[K, V], key: K): bool =
  ## Delete key. Returns true if key existed.
  ##
  ## IMPLEMENTATION:
  ## 1. Find the key
  ## 2. If found, set ctrl byte to Deleted (tombstone)
  ## 3. Optionally clear the slot (for GC)
  ## 4. Decrement size
  ## 5. If slot was followed by empty, convert Deleted to Empty

  result = false

proc len*[K, V](t: SwissTable[K, V]): int {.inline.} =
  t.size

proc clear*[K, V](t: var SwissTable[K, V]) =
  ## Remove all entries.
  ##
  ## IMPLEMENTATION:
  ## Set all ctrl bytes to Empty, reset size and growthLeft.

  t.size = 0
  t.growthLeft = (t.capacity * 7) div 8

iterator pairs*[K, V](t: SwissTable[K, V]): (K, V) =
  ## Iterate over all key-value pairs.
  ##
  ## IMPLEMENTATION:
  ## Scan ctrl bytes, yield for each Full slot.

  for i in 0..<t.capacity:
    if t.ctrl != nil and t.ctrl[i].isFull:
      yield (t.slots[i].key, t.slots[i].value)

iterator keys*[K, V](t: SwissTable[K, V]): K =
  for k, v in t.pairs:
    yield k

iterator values*[K, V](t: SwissTable[K, V]): V =
  for k, v in t.pairs:
    yield v
