## Lock-Free Skip List
## ====================
##
## Concurrent ordered map using lock-free skip list.
## Used by Redis, MemSQL, Discord, Java ConcurrentSkipListMap.
##
## Papers:
## - "A Pragmatic Implementation of Non-Blocking Linked-Lists"
##   (Harris, 2001)
## - "Lock-Free Linked Lists and Skip Lists"
##   (Fomitchev & Ruppert, 2004)
##
## Key properties:
## - O(log n) search, insert, delete (expected)
## - Lock-free using CAS (compare-and-swap)
## - Maintains sorted order
## - Range queries efficient
##
## Implementation uses:
## - Logical deletion (mark node, then unlink)
## - Back-links for recovery from deleted nodes
## - Memory reclamation via hazard pointers or epoch-based

import std/[atomics, random, hashes]

# =============================================================================
# Constants
# =============================================================================

const
  MaxLevel* = 32
    ## Maximum height of skip list (log2 of max elements)

  Probability* = 0.5
    ## Probability of adding another level (geometric distribution)

# =============================================================================
# Types
# =============================================================================

type
  MarkablePtr*[T] = distinct uint
    ## Pointer with mark bit for logical deletion.
    ##
    ## Uses lowest bit as mark flag (assumes aligned pointers).
    ## mark=1 means node is logically deleted.

  SkipNode*[K, V] = object
    ## Skip list node with variable-height tower.
    ##
    ## Layout:
    ##   [key][value][height][next[0]][next[1]]...[next[height-1]]
    ##
    ## Logical deletion:
    ## 1. Mark next[0] pointer (set low bit)
    ## 2. CAS to unlink from list
    key*: K
    value*: V
    height*: int
    next*: seq[Atomic[MarkablePtr[SkipNode[K, V]]]]

  SkipList*[K, V] = object
    ## Lock-free concurrent skip list.
    ##
    ## Invariants:
    ## - Nodes sorted by key at all levels
    ## - Higher levels are subsets of lower levels
    ## - Head/tail sentinel nodes never deleted
    head*: ptr SkipNode[K, V]
    tail*: ptr SkipNode[K, V]
    maxHeight*: Atomic[int]

# =============================================================================
# MarkablePtr Operations
# =============================================================================
##
## Markable Pointer:
## =================
##
## Combines pointer and mark bit in single word for atomic operations.
## Critical for lock-free deletion:
##
## 1. To delete node N:
##    - Mark N.next[i] for all levels (logical delete)
##    - CAS predecessor.next[i] from N to N.next[i] (physical delete)
##
## 2. Marking prevents concurrent inserts between N and N.next
##
## 3. Readers check mark bit; if marked, help complete deletion

proc pack*[T](p: ptr T, mark: bool): MarkablePtr[T] {.inline.} =
  ## Pack pointer and mark bit.
  let ptrVal = cast[uint](p)
  MarkablePtr[T](ptrVal or (if mark: 1'u else: 0'u))

proc unpack*[T](mp: MarkablePtr[T]): tuple[p: ptr T, mark: bool] {.inline.} =
  ## Unpack pointer and mark bit.
  let val = uint(mp)
  result.p = cast[ptr T](val and not 1'u)
  result.mark = (val and 1'u) != 0

proc getPtr*[T](mp: MarkablePtr[T]): ptr T {.inline.} =
  cast[ptr T](uint(mp) and not 1'u)

proc isMarked*[T](mp: MarkablePtr[T]): bool {.inline.} =
  (uint(mp) and 1'u) != 0

proc mark*[T](mp: MarkablePtr[T]): MarkablePtr[T] {.inline.} =
  MarkablePtr[T](uint(mp) or 1'u)

# =============================================================================
# Node Operations
# =============================================================================

proc randomLevel(): int =
  ## Generate random height using geometric distribution.
  ## P(height = k) = (1-p)^(k-1) * p
  result = 1
  while rand(1.0) < Probability and result < MaxLevel:
    inc result

proc newNode*[K, V](key: K, value: V, height: int): ptr SkipNode[K, V] =
  ## Allocate new skip list node.
  result = cast[ptr SkipNode[K, V]](alloc0(sizeof(SkipNode[K, V])))
  result.key = key
  result.value = value
  result.height = height
  result.next = newSeq[Atomic[MarkablePtr[SkipNode[K, V]]]](height)

proc freeNode*[K, V](node: ptr SkipNode[K, V]) =
  ## Free skip list node.
  ## CAUTION: Must ensure no concurrent access (use hazard pointers)
  if node != nil:
    dealloc(node)

# =============================================================================
# Skip List Operations
# =============================================================================

proc newSkipList*[K, V](): SkipList[K, V] =
  ## Create new empty skip list.
  ##
  ## Initializes head and tail sentinels with maximum height.

  # Create sentinel nodes
  # Head has minimum key, tail has maximum key
  result.head = newNode[K, V](default(K), default(V), MaxLevel)
  result.tail = newNode[K, V](default(K), default(V), MaxLevel)

  # Initialize head to point to tail at all levels
  for i in 0 ..< MaxLevel:
    result.head.next[i].store(pack(result.tail, false))

  result.maxHeight.store(1)

proc find*[K, V](sl: SkipList[K, V], key: K,
                 preds: var array[MaxLevel, ptr SkipNode[K, V]],
                 succs: var array[MaxLevel, ptr SkipNode[K, V]]): bool =
  ## Find key and record predecessor/successor at each level.
  ##
  ## Algorithm (Harris):
  ## 1. Start from head at top level
  ## 2. Move right while next.key < search key
  ## 3. If next is marked, help delete and retry
  ## 4. Move down one level
  ## 5. Repeat until bottom level
  ##
  ## Returns true if key found (at bottom level)

  var level = sl.maxHeight.load() - 1
  var pred = sl.head

  while level >= 0:
    var curr = pred.next[level].load().getPtr()

    while true:
      # Get next node and its mark
      let (succ, marked) = curr.next[level].load().unpack()

      # Help delete marked nodes
      while marked:
        # CAS to unlink curr
        let expected = pack(curr, false)
        let desired = pack(succ, false)
        discard pred.next[level].compareExchange(expected, desired)

        curr = pred.next[level].load().getPtr()
        if curr == sl.tail:
          break
        let (nextSucc, nextMarked) = curr.next[level].load().unpack()
        # Continue with new curr

      if curr == sl.tail or curr.key >= key:
        break

      pred = curr
      curr = succ

    preds[level] = pred
    succs[level] = curr
    dec level

  # Check if found at bottom level
  result = succs[0] != sl.tail and succs[0].key == key

proc insert*[K, V](sl: var SkipList[K, V], key: K, value: V): bool =
  ## Insert key-value pair.
  ##
  ## Algorithm:
  ## 1. Find predecessors and successors at all levels
  ## 2. Check if key already exists
  ## 3. Create new node with random height
  ## 4. CAS to link at bottom level first
  ## 5. Link at higher levels bottom-up
  ##
  ## Returns true if inserted, false if key existed

  let height = randomLevel()

  # Update max height if needed
  var currMax = sl.maxHeight.load()
  while height > currMax:
    if sl.maxHeight.compareExchange(currMax, height):
      break
    currMax = sl.maxHeight.load()

  var preds: array[MaxLevel, ptr SkipNode[K, V]]
  var succs: array[MaxLevel, ptr SkipNode[K, V]]

  while true:
    if sl.find(key, preds, succs):
      # Key exists, optionally update value
      return false

    # Create new node
    let newNode = newNode(key, value, height)

    # Initialize next pointers
    for i in 0 ..< height:
      newNode.next[i].store(pack(succs[i], false))

    # Try to link at bottom level
    let expected = pack(succs[0], false)
    let desired = pack(newNode, false)

    if not preds[0].next[0].compareExchange(expected, desired):
      # Failed, retry
      freeNode(newNode)
      continue

    # Link at higher levels
    for i in 1 ..< height:
      while true:
        let pred = preds[i]
        let succ = succs[i]
        let expected = pack(succ, false)
        let desired = pack(newNode, false)

        if pred.next[i].compareExchange(expected, desired):
          break

        # Re-find at this level
        discard sl.find(key, preds, succs)

    return true

proc remove*[K, V](sl: var SkipList[K, V], key: K): bool =
  ## Remove key from skip list.
  ##
  ## Algorithm:
  ## 1. Find node and predecessors
  ## 2. Mark next pointers top-down (logical delete)
  ## 3. CAS to unlink at each level (physical delete)
  ##
  ## Returns true if removed, false if not found

  var preds: array[MaxLevel, ptr SkipNode[K, V]]
  var succs: array[MaxLevel, ptr SkipNode[K, V]]

  while true:
    if not sl.find(key, preds, succs):
      return false

    let nodeToRemove = succs[0]

    # Mark all levels top-down
    for i in countdown(nodeToRemove.height - 1, 1):
      var (succ, marked) = nodeToRemove.next[i].load().unpack()
      while not marked:
        let expected = pack(succ, false)
        let desired = pack(succ, true)
        if nodeToRemove.next[i].compareExchange(expected, desired):
          break
        (succ, marked) = nodeToRemove.next[i].load().unpack()

    # Mark bottom level
    var (succ, marked) = nodeToRemove.next[0].load().unpack()
    while true:
      let expected = pack(succ, false)
      let desired = pack(succ, true)
      let success = nodeToRemove.next[0].compareExchange(expected, desired)
      (succ, marked) = nodeToRemove.next[0].load().unpack()

      if success:
        # We marked it, now physically remove
        discard sl.find(key, preds, succs)
        return true
      elif marked:
        # Another thread marked it
        return false
      # Else retry

proc get*[K, V](sl: SkipList[K, V], key: K): Option[V] =
  ## Get value for key.
  ##
  ## Returns Some(value) if found, None if not.
  var preds: array[MaxLevel, ptr SkipNode[K, V]]
  var succs: array[MaxLevel, ptr SkipNode[K, V]]

  if sl.find(key, preds, succs):
    result = some(succs[0].value)
  else:
    result = none(V)

proc contains*[K, V](sl: SkipList[K, V], key: K): bool =
  ## Check if key exists.
  var preds: array[MaxLevel, ptr SkipNode[K, V]]
  var succs: array[MaxLevel, ptr SkipNode[K, V]]
  sl.find(key, preds, succs)

# =============================================================================
# Range Operations
# =============================================================================

iterator items*[K, V](sl: SkipList[K, V]): (K, V) =
  ## Iterate over all key-value pairs in sorted order.
  ##
  ## Note: Concurrent modifications may cause skipped or repeated items.
  var curr = sl.head.next[0].load().getPtr()

  while curr != sl.tail:
    let (succ, marked) = curr.next[0].load().unpack()
    if not marked:
      yield (curr.key, curr.value)
    curr = succ

iterator range*[K, V](sl: SkipList[K, V], lo, hi: K): (K, V) =
  ## Iterate over keys in range [lo, hi).
  var preds: array[MaxLevel, ptr SkipNode[K, V]]
  var succs: array[MaxLevel, ptr SkipNode[K, V]]

  # Find starting position
  discard sl.find(lo, preds, succs)
  var curr = succs[0]

  while curr != sl.tail and curr.key < hi:
    let (succ, marked) = curr.next[0].load().unpack()
    if not marked:
      yield (curr.key, curr.value)
    curr = succ
