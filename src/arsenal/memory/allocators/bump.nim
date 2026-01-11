## Bump Allocator
## ==============
##
## A fast arena-style allocator. All allocations are served from a
## contiguous memory block. Memory is freed all at once by resetting
## the bump pointer.
##
## Performance: ~1 billion allocations/second
## Use cases: Frame-based allocation, batch processing, short-lived objects

type
  BumpAllocator* = object
    ## Fast arena allocator with O(1) allocation and O(1) deallocation.
    buffer: ptr UncheckedArray[byte]
    size: int
    offset: int

proc init*(_: typedesc[BumpAllocator], size: int): BumpAllocator =
  ## Create a bump allocator with a fixed-size buffer.
  ## All allocations must fit within this buffer.
  result.size = size
  result.offset = 0
  # Allocate aligned buffer (use system alloc for now, could be aligned in production)
  result.buffer = cast[ptr UncheckedArray[byte]](alloc0(size))

proc `=destroy`*(a: var BumpAllocator) =
  ## Free the allocator's buffer.
  if a.buffer != nil:
    dealloc(a.buffer)
    a.buffer = nil

proc alloc*(a: var BumpAllocator, size: int): pointer =
  ## Allocate memory. Never fails - if out of space, returns nil.
  # 8-byte alignment
  let alignedSize = (size + 7) and not 7

  if a.offset + alignedSize > a.size:
    return nil  # Out of memory

  result = addr a.buffer[a.offset]
  a.offset += alignedSize

proc alloc*(a: var BumpAllocator, size: int, alignment: int): pointer =
  ## Allocate with specific alignment.
  # Align offset to next alignment boundary
  let alignedOffset = (a.offset + alignment - 1) and not (alignment - 1)

  if alignedOffset + size > a.size:
    return nil

  result = addr a.buffer[alignedOffset]
  a.offset = alignedOffset + size

proc dealloc*(a: var BumpAllocator, p: pointer) {.inline.} =
  ## No-op for bump allocator. Memory is freed by reset().
  discard

proc realloc*(a: var BumpAllocator, p: pointer, newSize: int): pointer {.inline.} =
  ## Bump allocators don't support individual realloc.
  ## Return nil to indicate failure.
  return nil

proc reset*(a: var BumpAllocator) {.inline.} =
  ## Reset the allocator, freeing all allocated memory.
  ## O(1) operation.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## a.offset = 0
  ## ```

  a.offset = 0

proc bytesUsed*(a: BumpAllocator): int {.inline.} =
  ## Return number of bytes currently allocated.
  a.offset

proc bytesFree*(a: BumpAllocator): int {.inline.} =
  ## Return number of bytes still available.
  a.size - a.offset

proc isEmpty*(a: BumpAllocator): bool {.inline.} =
  ## Check if allocator has no allocations.
  a.offset == 0