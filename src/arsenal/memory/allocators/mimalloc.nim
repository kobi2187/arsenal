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
  ## IMPLEMENTATION:
  ## ```nim
  ## result.heap = mi_heap_new()
  ## ```

  # Stub - use global heap
  result.heap = nil

proc `=destroy`*(a: var MimallocAllocator) =
  ## Destroy the allocator.
  ## IMPLEMENTATION:
  ## ```nim
  ## if a.heap != nil:
  ##   mi_heap_delete(a.heap)
  ##   a.heap = nil
  ## ```

  # TODO: Delete heap if owned

proc alloc*(a: MimallocAllocator, size: int): pointer =
  ## Allocate memory.
  ## IMPLEMENTATION:
  ## ```nim
  ## if a.heap != nil:
  ##   result = mi_heap_malloc(a.heap, size.csize_t)
  ## else:
  ##   result = mi_malloc(size.csize_t)
  ## ```

  # Stub - use system malloc
  result = alloc(size)

proc alloc*(a: MimallocAllocator, size: int, alignment: int): pointer =
  ## Allocate aligned memory.
  ## IMPLEMENTATION:
  ## Use mi_malloc_aligned for global heap, or calculate alignment manually for heap.
  ##
  ## ```nim
  ## if a.heap != nil:
  ##   # For heap allocation, we need to over-allocate and align manually
  ##   # This is complex - for now, fall back to regular allocation
  ##   result = mi_heap_malloc(a.heap, size.csize_t)
  ## else:
  ##   result = mi_malloc_aligned(size.csize_t, alignment.csize_t)
  ## ```

  # Stub - ignore alignment
  result = a.alloc(size)

proc dealloc*(a: MimallocAllocator, p: pointer) =
  ## Free memory.
  ## IMPLEMENTATION:
  ## ```nim
  ## if a.heap != nil:
  ##   mi_heap_free(a.heap, p)
  ## else:
  ##   mi_free(p)
  ## ```

  if p != nil:
    dealloc(p)

proc realloc*(a: MimallocAllocator, p: pointer, newSize: int): pointer =
  ## Reallocate memory.
  ## IMPLEMENTATION:
  ## mimalloc supports realloc, but only for global heap.
  ##
  ## ```nim
  ## if a.heap != nil:
  ##   # Heap realloc not directly supported
  ##   # Need to alloc new, copy, free old
  ##   result = mi_heap_malloc(a.heap, newSize.csize_t)
  ##   if result != nil and p != nil:
  ##     copyMem(result, p, min(currentSize, newSize))
  ##   mi_heap_free(a.heap, p)
  ## else:
  ##   result = mi_realloc(p, newSize.csize_t)
  ## ```

  # Stub - use Nim realloc
  result = realloc(p, newSize)

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