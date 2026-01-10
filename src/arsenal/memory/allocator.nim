## Allocator Interface & Implementations
## =====================================
##
## Arsenal provides a flexible allocator system where data structures
## can be parameterized by their memory strategy.
##
## Built-in allocators:
## - `SystemAllocator`: Wraps system malloc/free
## - `BumpAllocator`: Fast arena allocator (alloc only, bulk free)
## - `PoolAllocator`: Fixed-size object pools
## - `MimallocAllocator`: High-performance general allocator (binding)
##
## Usage:
## ```nim
## # Use system allocator (default)
## var table = newHashTable[int, string]()
##
## # Use arena allocator for batch processing
## var arena = BumpAllocator.init(64 * 1024)  # 64KB arena
## var nodes = arena.alloc[:Node](100)        # Allocate 100 nodes
## arena.reset()                              # Free all at once
## ```

import ../platform/config

type
  Allocator* = concept a
    ## Generic allocator interface.
    ## Any type satisfying this concept can be used as an allocator.
    a.alloc(int): pointer
    a.alloc(int, int): pointer  # size, alignment
    a.dealloc(pointer)
    a.realloc(pointer, int): pointer

  AllocatorStats* = object
    ## Statistics about allocator usage.
    totalAllocated*: int     ## Total bytes currently allocated
    totalFreed*: int         ## Total bytes freed
    peakUsage*: int          ## Maximum bytes allocated at once
    allocCount*: int         ## Number of allocations
    deallocCount*: int       ## Number of deallocations

# =============================================================================
# System Allocator (Wraps malloc/free)
# =============================================================================

type
  SystemAllocator* = object
    ## Allocator using the system's malloc/free.
    ## Thread-safe but may have contention under high load.
    discard

proc init*(_: typedesc[SystemAllocator]): SystemAllocator {.inline.} =
  ## Create a system allocator instance.
  ## Actually stateless - all instances share the system heap.
  discard

proc alloc*(a: SystemAllocator, size: int): pointer {.inline.} =
  ## Allocate `size` bytes from system heap.
  ##
  ## IMPLEMENTATION:
  ## Use Nim's `alloc` or C's `malloc`:
  ## ```nim
  ## result = alloc(size)
  ## ```
  ## Or with C:
  ## ```nim
  ## {.emit: "`result` = malloc(`size`);".}
  ## ```

  result = alloc(size)

proc alloc*(a: SystemAllocator, size: int, alignment: int): pointer {.inline.} =
  ## Allocate `size` bytes with given alignment.
  ##
  ## IMPLEMENTATION:
  ## Use `aligned_alloc` (C11) or `posix_memalign`:
  ## ```nim
  ## when defined(posix):
  ##   var p: pointer
  ##   discard posix_memalign(addr p, alignment, size)
  ##   result = p
  ## else:
  ##   result = aligned_alloc(alignment, size)
  ## ```

  result = alloc(size)  # TODO: aligned version

proc dealloc*(a: SystemAllocator, p: pointer) {.inline.} =
  ## Free memory.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## dealloc(p)
  ## ```

  if p != nil:
    dealloc(p)

proc realloc*(a: SystemAllocator, p: pointer, newSize: int): pointer {.inline.} =
  ## Resize allocation.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result = realloc(p, newSize)
  ## ```

  result = realloc(p, newSize)

# =============================================================================
# Bump Allocator (Arena / Linear Allocator)
# =============================================================================

type
  BumpAllocator* = object
    ## Fast arena allocator using bump pointer.
    ##
    ## - Allocation: O(1) - just bump the pointer
    ## - Deallocation: No-op (individual frees not supported)
    ## - Reset: O(1) - reset pointer to start
    ##
    ## Perfect for:
    ## - Per-request allocations in servers
    ## - Parse trees and temporary data structures
    ## - Any situation where you allocate many objects then free all at once
    buffer: ptr UncheckedArray[byte]
    capacity: int
    offset: int
    owned: bool  ## True if we allocated buffer, false if external

proc init*(_: typedesc[BumpAllocator], capacity: int): BumpAllocator =
  ## Create a bump allocator with given capacity.
  ##
  ## IMPLEMENTATION:
  ## Allocate a single large buffer:
  ## ```nim
  ## result.buffer = cast[ptr UncheckedArray[byte]](alloc(capacity))
  ## result.capacity = capacity
  ## result.offset = 0
  ## result.owned = true
  ## ```

  result = BumpAllocator(
    buffer: nil,  # TODO: Allocate
    capacity: capacity,
    offset: 0,
    owned: true
  )

proc init*(_: typedesc[BumpAllocator], buffer: pointer, size: int): BumpAllocator =
  ## Create a bump allocator using external buffer (e.g., stack memory).
  ##
  ## ```nim
  ## var stackBuffer: array[4096, byte]
  ## var arena = BumpAllocator.init(addr stackBuffer, sizeof(stackBuffer))
  ## ```

  result = BumpAllocator(
    buffer: cast[ptr UncheckedArray[byte]](buffer),
    capacity: size,
    offset: 0,
    owned: false
  )

proc alloc*(a: var BumpAllocator, size: int): pointer =
  ## Allocate `size` bytes. Returns nil if out of space.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if a.offset + size > a.capacity:
  ##   return nil
  ## result = addr a.buffer[a.offset]
  ## a.offset += size
  ## ```

  if a.offset + size > a.capacity:
    return nil
  result = cast[pointer](cast[int](a.buffer) + a.offset)
  a.offset += size

proc alloc*(a: var BumpAllocator, size: int, alignment: int): pointer =
  ## Allocate with alignment.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## # Calculate padding needed for alignment
  ## let currentAddr = cast[int](a.buffer) + a.offset
  ## let padding = (alignment - (currentAddr mod alignment)) mod alignment
  ## let totalSize = size + padding
  ##
  ## if a.offset + totalSize > a.capacity:
  ##   return nil
  ##
  ## a.offset += padding
  ## result = addr a.buffer[a.offset]
  ## a.offset += size
  ## ```

  let currentAddr = cast[int](a.buffer) + a.offset
  let padding = (alignment - (currentAddr mod alignment)) mod alignment

  if a.offset + size + padding > a.capacity:
    return nil

  a.offset += padding
  result = cast[pointer](cast[int](a.buffer) + a.offset)
  a.offset += size

proc dealloc*(a: var BumpAllocator, p: pointer) {.inline.} =
  ## No-op. Bump allocators don't support individual deallocation.
  ## Use `reset()` to free all memory at once.
  discard

proc realloc*(a: var BumpAllocator, p: pointer, newSize: int): pointer =
  ## Not efficiently supported. Allocates new block, doesn't free old.
  ## For real realloc support, use a different allocator.
  result = a.alloc(newSize)
  # Note: This doesn't copy old data or free old block

proc reset*(a: var BumpAllocator) {.inline.} =
  ## Reset allocator, freeing all allocations at once.
  ## This is O(1) - just reset the offset.
  a.offset = 0

proc remaining*(a: BumpAllocator): int {.inline.} =
  ## Bytes remaining in arena.
  a.capacity - a.offset

proc used*(a: BumpAllocator): int {.inline.} =
  ## Bytes used so far.
  a.offset

proc `=destroy`*(a: BumpAllocator) =
  ## Free the buffer if we own it.
  if a.owned and a.buffer != nil:
    dealloc(a.buffer)

# =============================================================================
# Pool Allocator (Fixed-Size Object Pool)
# =============================================================================

type
  PoolAllocator*[T] = object
    ## Fixed-size object pool allocator.
    ##
    ## - Allocation: O(1) - pop from free list
    ## - Deallocation: O(1) - push to free list
    ##
    ## All allocations are same size (sizeof(T)).
    ## Excellent for allocating many objects of the same type.
    buffer: ptr UncheckedArray[T]
    freeList: ptr T  ## Head of intrusive free list
    capacity: int
    allocated: int

  FreeNode = object
    ## Intrusive free list node.
    ## Stored in the free slot itself (no extra memory).
    next: ptr FreeNode

proc init*[T](_: typedesc[PoolAllocator[T]], capacity: int): PoolAllocator[T] =
  ## Create a pool allocator for `capacity` objects of type T.
  ##
  ## IMPLEMENTATION:
  ## 1. Allocate buffer for `capacity` objects
  ## 2. Initialize free list linking all slots
  ##
  ## ```nim
  ## let buffer = cast[ptr UncheckedArray[T]](alloc(capacity * sizeof(T)))
  ##
  ## # Link all slots into free list
  ## for i in 0..<capacity-1:
  ##   let node = cast[ptr FreeNode](addr buffer[i])
  ##   node.next = cast[ptr FreeNode](addr buffer[i + 1])
  ##
  ## cast[ptr FreeNode](addr buffer[capacity - 1]).next = nil
  ##
  ## result.buffer = buffer
  ## result.freeList = cast[ptr T](addr buffer[0])
  ## result.capacity = capacity
  ## result.allocated = 0
  ## ```

  result = PoolAllocator[T](
    buffer: nil,  # TODO: Allocate
    freeList: nil,
    capacity: capacity,
    allocated: 0
  )

proc alloc*[T](p: var PoolAllocator[T]): ptr T =
  ## Allocate one object from the pool.
  ## Returns nil if pool is exhausted.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if p.freeList == nil:
  ##   return nil
  ##
  ## result = p.freeList
  ## p.freeList = cast[ptr T](cast[ptr FreeNode](p.freeList).next)
  ## p.allocated += 1
  ## ```

  if p.freeList == nil:
    return nil

  result = p.freeList
  p.freeList = cast[ptr T](cast[ptr FreeNode](p.freeList).next)
  p.allocated += 1

proc dealloc*[T](p: var PoolAllocator[T], obj: ptr T) =
  ## Return object to pool.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let node = cast[ptr FreeNode](obj)
  ## node.next = cast[ptr FreeNode](p.freeList)
  ## p.freeList = obj
  ## p.allocated -= 1
  ## ```

  let node = cast[ptr FreeNode](obj)
  node.next = cast[ptr FreeNode](p.freeList)
  p.freeList = obj
  p.allocated -= 1

proc available*[T](p: PoolAllocator[T]): int {.inline.} =
  ## Number of free slots.
  p.capacity - p.allocated

proc `=destroy`*[T](p: PoolAllocator[T]) =
  if p.buffer != nil:
    dealloc(p.buffer)

# =============================================================================
# Typed Allocation Helpers
# =============================================================================

proc alloc*[T; A: Allocator](a: var A, _: typedesc[T]): ptr T {.inline.} =
  ## Allocate a single object of type T.
  cast[ptr T](a.alloc(sizeof(T), alignof(T)))

proc alloc*[T; A: Allocator](a: var A, _: typedesc[T], count: int): ptr UncheckedArray[T] {.inline.} =
  ## Allocate an array of `count` objects of type T.
  cast[ptr UncheckedArray[T]](a.alloc(sizeof(T) * count, alignof(T)))

proc create*[T; A: Allocator](a: var A, value: T): ptr T =
  ## Allocate and initialize with value.
  result = a.alloc(T)
  if result != nil:
    result[] = value

# =============================================================================
# Global Allocator
# =============================================================================

var globalAllocator*: SystemAllocator = SystemAllocator.init()
  ## Default global allocator. Can be replaced.
