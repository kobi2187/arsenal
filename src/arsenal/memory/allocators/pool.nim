## Pool Allocator
## ==============
##
## Fixed-size object pool allocator. Maintains a free list of
## pre-allocated objects for O(1) allocation/deallocation.
##
## Performance: ~100M operations/second
## Use cases: Many small objects of the same size

type
  PoolAllocator*[T] = object
    ## Pool allocator for objects of type T.
    ## All allocations are the same size (sizeof(T)).
    freeList: seq[ptr T]
    blocks: seq[ptr UncheckedArray[T]]
    blockSize: int
    allocated: int

proc init*[T](_: typedesc[PoolAllocator[T]], blockSize: int = 1024): PoolAllocator[T] =
  ## Create a pool allocator.
  ## blockSize: Number of objects to allocate per block.
  result.blockSize = blockSize
  result.freeList = @[]
  result.blocks = @[]
  result.allocated = 0

proc `=destroy`*[T](p: var PoolAllocator[T]) =
  ## Free all allocated blocks.
  for blk in p.blocks:
    dealloc(blk)
  p.blocks.setLen(0)
  p.freeList.setLen(0)

proc alloc*[T](p: var PoolAllocator[T]): ptr T =
  ## Allocate one object. O(1) operation.
  if p.freeList.len > 0:
    result = p.freeList.pop()
  else:
    # Allocate new block
    let blk = cast[ptr UncheckedArray[T]](
      alloc0(p.blockSize * sizeof(T))
    )
    p.blocks.add(blk)

    # Add all objects except first to free list
    for i in 1..<p.blockSize:
      p.freeList.add(addr blk[i])

    result = addr blk[0]

  inc p.allocated

proc dealloc*[T](p: var PoolAllocator[T], obj: ptr T) =
  ## Return object to the pool. O(1) operation.
  ##
  ## IMPLEMENTATION:
  ## 1. Add to free list for reuse
  ## 2. Decrement allocated count
  ##
  ## ```nim
  ## p.freeList.add(obj)
  ## dec p.allocated
  ## ```

  if obj != nil:
    p.freeList.add(obj)
    dec p.allocated

proc alloc*[T](p: var PoolAllocator[T], size: int): pointer =
  ## Pool allocators only support allocating sizeof(T).
  ## If size != sizeof(T), return nil.
  if size == sizeof(T):
    result = p.alloc()
  else:
    result = nil

proc alloc*[T](p: var PoolAllocator[T], size: int, alignment: int): pointer =
  ## Same as alloc(size), but check alignment too.
  if size == sizeof(T) and alignment <= alignof(T):
    result = p.alloc()
  else:
    result = nil

proc realloc*[T](p: var PoolAllocator[T], obj: pointer, newSize: int): pointer =
  ## Pool allocators don't support realloc.
  return nil

proc len*[T](p: PoolAllocator[T]): int =
  ## Return number of currently allocated objects.
  p.allocated

proc capacity*[T](p: PoolAllocator[T]): int =
  ## Return total capacity (allocated + free).
  p.allocated + p.freeList.len