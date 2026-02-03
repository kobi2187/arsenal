## Tests for memory allocators

import std/unittest
import std/[times, strutils]
import ../src/arsenal/memory/allocators/bump
import ../src/arsenal/memory/allocators/pool

suite "Bump Allocator":
  test "init creates allocator":
    var bump = BumpAllocator.init(1024)
    check bump.isEmpty()
    check bump.bytesFree() == 1024
    check bump.bytesUsed() == 0

  test "alloc returns aligned memory":
    var bump = BumpAllocator.init(1024)

    let p1 = bump.alloc(10)
    check p1 != nil
    check bump.bytesUsed() == 16  # 10 rounded up to 8-byte alignment

    let p2 = bump.alloc(5)
    check p2 != nil
    check bump.bytesUsed() == 24  # 16 + 8

  test "alloc with custom alignment":
    var bump = BumpAllocator.init(1024)

    let p1 = bump.alloc(10, alignment = 16)
    check p1 != nil
    check (cast[int](p1) and 15) == 0  # 16-byte aligned

  test "alloc returns nil when out of memory":
    var bump = BumpAllocator.init(100)

    let p1 = bump.alloc(50)
    check p1 != nil

    let p2 = bump.alloc(60)  # Would exceed capacity
    check p2 == nil

  test "reset frees all memory":
    var bump = BumpAllocator.init(1024)

    discard bump.alloc(100)
    discard bump.alloc(200)
    check bump.bytesUsed() > 0

    bump.reset()
    check bump.isEmpty()
    check bump.bytesUsed() == 0
    check bump.bytesFree() == 1024

  test "realloc returns nil (not supported)":
    var bump = BumpAllocator.init(1024)
    let p = bump.alloc(10)
    check bump.realloc(p, 20) == nil

  test "dealloc is no-op":
    var bump = BumpAllocator.init(1024)
    let p = bump.alloc(10)
    bump.dealloc(p)  # Should not crash
    check bump.bytesUsed() > 0  # Memory still used

  test "sequential allocations are contiguous":
    var bump = BumpAllocator.init(1024)

    let p1 = bump.alloc(8)
    let p2 = bump.alloc(8)

    # Should be adjacent (p2 = p1 + 8)
    check cast[int](p2) - cast[int](p1) == 8

  test "performance - many small allocations":
    var bump = BumpAllocator.init(1024 * 1024)  # 1 MB

    # Warmup
    for i in 0..<1000:
      discard bump.alloc(8)
    bump.reset()

    const iterations = 100_000
    let start = epochTime()
    for i in 0..<iterations:
      let p = bump.alloc(8)
      check p != nil
    let elapsed = epochTime() - start

    let msTotal = elapsed * 1000.0
    let nsPerAlloc = (elapsed * 1_000_000_000.0) / float(iterations)
    let allocsPerSec = float(iterations) / elapsed

    echo "  Bump Allocator Benchmark:"
    echo "    Total time: ", formatFloat(msTotal, ffDecimal, 3), " ms"
    echo "    Time per allocation: ", formatFloat(nsPerAlloc, ffDecimal, 2), " ns"
    echo "    Throughput: ", formatFloat(allocsPerSec / 1_000_000.0, ffDecimal, 2), " M allocs/sec"

    bump.reset()
    check bump.isEmpty()

suite "Pool Allocator":
  test "init creates empty pool":
    var pool = PoolAllocator[int].init(blockSize = 100)
    check pool.len() == 0
    check pool.capacity() == 0

  test "alloc returns object":
    var pool = PoolAllocator[int].init()

    let p = pool.alloc()
    check p != nil
    check pool.len() == 1

  test "dealloc returns object to pool":
    var pool = PoolAllocator[int].init()

    let p = pool.alloc()
    check pool.len() == 1

    pool.dealloc(p)
    check pool.len() == 0

  test "reuse from free list":
    var pool = PoolAllocator[int].init()

    let p1 = pool.alloc()
    pool.dealloc(p1)

    let p2 = pool.alloc()
    check p2 == p1  # Should reuse same memory

  test "allocates new block when needed":
    var pool = PoolAllocator[int].init(blockSize = 4)

    var ptrs: array[10, ptr int]
    for i in 0..<10:
      ptrs[i] = pool.alloc()
      check ptrs[i] != nil

    check pool.len() == 10

  test "capacity grows with blocks":
    var pool = PoolAllocator[int].init(blockSize = 4)

    discard pool.alloc()  # First block: 4 objects
    check pool.capacity() == 4

    # Use up free list
    discard pool.alloc()
    discard pool.alloc()
    discard pool.alloc()

    discard pool.alloc()  # Triggers second block
    check pool.capacity() >= 8

  test "alloc(size) only works for sizeof(T)":
    var pool = PoolAllocator[int].init()

    let p1 = pool.alloc(sizeof(int))
    check p1 != nil

    let p2 = pool.alloc(sizeof(int) * 2)
    check p2 == nil  # Wrong size

  test "realloc returns nil (not supported)":
    var pool = PoolAllocator[int].init()
    let p = pool.alloc()
    check pool.realloc(p, sizeof(int) * 2) == nil

  test "performance - many allocations and deallocations":
    var pool = PoolAllocator[int].init()

    # Warmup
    var warmupPtrs: seq[ptr int]
    for i in 0..<100:
      warmupPtrs.add(pool.alloc())
    for p in warmupPtrs:
      pool.dealloc(p)

    const iterations = 10_000
    var ptrs: seq[ptr int]

    # Benchmark allocations
    let startAlloc = epochTime()
    for i in 0..<iterations:
      ptrs.add(pool.alloc())
    let allocElapsed = epochTime() - startAlloc

    check pool.len() == iterations

    # Benchmark deallocations
    let startDealloc = epochTime()
    for p in ptrs:
      pool.dealloc(p)
    let deallocElapsed = epochTime() - startDealloc

    check pool.len() == 0
    check pool.capacity() >= iterations

    let allocNs = (allocElapsed * 1_000_000_000.0) / float(iterations)
    let deallocNs = (deallocElapsed * 1_000_000_000.0) / float(iterations)
    let allocPerSec = float(iterations) / allocElapsed
    let deallocPerSec = float(iterations) / deallocElapsed

    echo "  Pool Allocator Benchmark:"
    echo "    Alloc time per op: ", formatFloat(allocNs, ffDecimal, 2), " ns"
    echo "    Dealloc time per op: ", formatFloat(deallocNs, ffDecimal, 2), " ns"
    echo "    Alloc throughput: ", formatFloat(allocPerSec / 1_000_000.0, ffDecimal, 2), " M ops/sec"
    echo "    Dealloc throughput: ", formatFloat(deallocPerSec / 1_000_000.0, ffDecimal, 2), " M ops/sec"

  test "works with custom types":
    type
      Point = object
        x, y: float

    var pool = PoolAllocator[Point].init()

    let p = pool.alloc()
    check p != nil

    p.x = 1.0
    p.y = 2.0

    check p.x == 1.0
    check p.y == 2.0

    pool.dealloc(p)

suite "Allocator Comparison":
  test "bump vs pool for same-size allocations":
    var bump = BumpAllocator.init(10000)
    var pool = PoolAllocator[int].init()

    # Both can allocate
    let b = bump.alloc(sizeof(int))
    let p = pool.alloc()

    check b != nil
    check p != nil

    # Bump doesn't support dealloc, pool does
    bump.dealloc(b)  # No-op
    pool.dealloc(p)  # Returns to free list

    check bump.bytesUsed() > 0
    check pool.len() == 0

  test "bump is better for batch allocations":
    var bump = BumpAllocator.init(100000)

    for i in 0..<10000:
      discard bump.alloc(8)

    # All allocated, can reset in O(1)
    bump.reset()
    check bump.isEmpty()

  test "pool is better for reuse patterns":
    var pool = PoolAllocator[int].init()

    # Allocate and free in a loop
    for i in 0..<100:
      let p = pool.alloc()
      p[] = i
      pool.dealloc(p)

    # No memory growth after first iteration
    check pool.capacity() > 0
    check pool.len() == 0
