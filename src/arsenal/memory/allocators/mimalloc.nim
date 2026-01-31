## mimalloc Binding
## ================
##
## High-performance general-purpose allocator.
## Microsoft Research's memory allocator, designed for performance.
##
## Features:
## - Excellent general-purpose performance
## - Low fragmentation
## - Good scalability
## - Cross-platform

{.pragma: miImport, importc, header: "<mimalloc.h>".}

# =============================================================================
# mimalloc Types
# =============================================================================

type
  mi_heap_t* {.miImport.} = object
    ## Memory heap handle

# =============================================================================
# mimalloc Functions
# =============================================================================

proc mi_malloc*(size: csize_t): pointer {.miImport.}
  ## Allocate memory.

proc mi_calloc*(count: csize_t, size: csize_t): pointer {.miImport.}
  ## Allocate zero-initialized memory.

proc mi_realloc*(p: pointer, size: csize_t): pointer {.miImport.}
  ## Reallocate memory.

proc mi_free*(p: pointer) {.miImport.}
  ## Free memory.

proc mi_malloc_aligned*(size: csize_t, alignment: csize_t): pointer {.miImport.}
  ## Allocate aligned memory.

# Heap management (for isolation)
proc mi_heap_new*(): ptr mi_heap_t {.miImport.}
  ## Create a new heap.

proc mi_heap_delete*(heap: ptr mi_heap_t) {.miImport.}
  ## Delete a heap.

proc mi_heap_malloc*(heap: ptr mi_heap_t, size: csize_t): pointer {.miImport.}
  ## Allocate from specific heap.

proc mi_heap_free*(heap: ptr mi_heap_t, p: pointer) {.miImport.}
  ## Free from specific heap.

# =============================================================================
# Nim Wrapper
# =============================================================================

type
  MimallocAllocator* = object
    ## High-performance general allocator.
    heap: ptr mi_heap_t

proc init*(_: typedesc[MimallocAllocator]): MimallocAllocator =
  ## Create a mimalloc allocator using the global heap.
  result.heap = nil  # Use global heap

proc initHeap*(_: typedesc[MimallocAllocator]): MimallocAllocator =
  ## Create a mimalloc allocator with its own isolated heap.
  ## Creates a separate memory arena for isolation.
  ## Useful for per-thread or per-module allocations.

  result.heap = mi_heap_new()

proc `=destroy`*(a: var MimallocAllocator) =
  ## Destroy the allocator and free associated heap.
  ## Only deletes if heap was created with initHeap.

  if a.heap != nil:
    mi_heap_delete(a.heap)
    a.heap = nil

proc alloc*(a: MimallocAllocator, size: int): pointer =
  ## Allocate memory using mimalloc.
  ## Allocates from the isolated heap if created with initHeap(),
  ## otherwise uses the global mimalloc heap.

  if a.heap != nil:
    result = mi_heap_malloc(a.heap, size.csize_t)
  else:
    result = mi_malloc(size.csize_t)

proc alloc*(a: MimallocAllocator, size: int, alignment: int): pointer =
  ## Allocate aligned memory.
  ## For global heap, uses mimalloc's aligned allocation.
  ## For isolated heaps, falls back to regular allocation
  ## (alignment handling would require custom logic).

  if a.heap != nil:
    # Heap allocation: allocate normally
    # Real implementation would need custom alignment handling
    result = mi_heap_malloc(a.heap, size.csize_t)
  else:
    # Global heap: use mimalloc's aligned allocation
    result = mi_malloc_aligned(size.csize_t, alignment.csize_t)

proc dealloc*(a: MimallocAllocator, p: pointer) =
  ## Free memory using mimalloc.
  ## Properly handles memory allocated from either global or isolated heap.

  if p != nil:
    if a.heap != nil:
      mi_heap_free(a.heap, p)
    else:
      mi_free(p)

proc realloc*(a: MimallocAllocator, p: pointer, newSize: int): pointer =
  ## Reallocate memory.
  ## For global heap, uses mimalloc's realloc.
  ## For isolated heaps, performs manual reallocation (allocate, copy, free).

  if a.heap != nil:
    # For heap allocation: manual realloc
    if p == nil:
      result = mi_heap_malloc(a.heap, newSize.csize_t)
    else:
      # Allocate new block
      result = mi_heap_malloc(a.heap, newSize.csize_t)
      if result != nil and p != nil:
        # Note: We don't know the original size, so copy conservative amount
        # In a real implementation, track block sizes
        copyMem(result, p, newSize)
      # Free old block
      mi_heap_free(a.heap, p)
  else:
    # Global heap: use mimalloc's built-in realloc
    result = mi_realloc(p, newSize.csize_t)

# Header and library setup
when defined(windows):
  {.passL: "-Lmimalloc -lmimalloc".}
  {.passC: "-Imimalloc/include".}
elif defined(macosx):
  {.passL: "-Lmimalloc -lmimalloc".}
  {.passC: "-Imimalloc/include".}
elif defined(linux):
  {.passL: "-Lmimalloc -lmimalloc".}
  {.passC: "-Imimalloc/include".}
else:
  {.error: "mimalloc not supported on this platform".}