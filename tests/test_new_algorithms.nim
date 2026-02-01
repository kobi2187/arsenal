## Tests for newly implemented algorithms
##
## This file tests the 7 state-of-the-art algorithm modules:
## - Binary Fuse Filter (sketching/membership/binary_fuse.nim)
## - Gorilla Compression (timeseries/gorilla.nim)
## - H3 Hexagonal Grid (geo/h3.nim)
## - SIMD String Search (strings/simd_search.nim)
## - Delta-Stepping SSSP (graph/sssp.nim)
## - Harley-Seal Popcount (bits/popcount.nim)
## - Lock-Free Skip List (concurrent/skiplist.nim)

import std/[random, times, strformat, math, options]

# Import all new modules
import ../src/arsenal/sketching/membership/binary_fuse
import ../src/arsenal/timeseries/gorilla
import ../src/arsenal/geo/h3
import ../src/arsenal/strings/simd_search
import ../src/arsenal/graph/sssp
import ../src/arsenal/bits/popcount
import ../src/arsenal/concurrent/skiplist

proc testBinaryFuseFilter() =
  echo "\n=== Testing Binary Fuse Filter ==="
  
  # Create test keys
  var keys: seq[uint64] = @[]
  for i in 0 ..< 1000:
    keys.add(uint64(i * 17 + 42))
  
  # Build filter
  let filter = construct(keys)
  echo fmt"  Filter size: {filter.sizeInBytes()} bytes"
  echo fmt"  Bits per entry: {filter.bitsPerEntry(keys.len):.2f}"
  
  # Test membership
  var found = 0
  for key in keys:
    if filter.contains(key):
      inc found
  echo fmt"  Keys found: {found}/{keys.len}"
  
  # Test false positives
  var falsePositives = 0
  for i in 0 ..< 10000:
    let testKey = uint64(1_000_000 + i)
    if filter.contains(testKey):
      inc falsePositives
  echo fmt"  False positives: {falsePositives}/10000 ({float(falsePositives)/100:.2f}%)"
  
  assert found == keys.len, "All keys should be found"
  assert falsePositives < 100, "False positive rate should be < 1%"
  echo "  PASSED"

proc testBinaryFuse16() =
  echo "\n=== Testing Binary Fuse 16-bit Filter ==="
  
  var keys: seq[uint64] = @[]
  for i in 0 ..< 500:
    keys.add(uint64(i * 23 + 7))
  
  let filter = construct16(keys)
  echo fmt"  Filter size: {filter.sizeInBytes()} bytes"
  echo fmt"  Bits per entry: {filter.bitsPerEntry(keys.len):.2f}"
  
  var found = 0
  for key in keys:
    if filter.contains(key):
      inc found
  echo fmt"  Keys found: {found}/{keys.len}"
  
  assert found == keys.len, "All keys should be found"
  echo "  PASSED"

proc testGorillaCompression() =
  echo "\n=== Testing Gorilla Compression ==="
  
  # Create test time series (simulating regular sensor data)
  var encoder = newGorillaEncoder()
  
  let baseTime = int64(1704067200)  # 2024-01-01 00:00:00 UTC
  let numPoints = 100
  
  for i in 0 ..< numPoints:
    let timestamp = baseTime + int64(i * 60)  # Every 60 seconds
    let value = 20.0 + sin(float(i) * 0.1) * 5.0 + rand(0.1)  # Temperature-like data
    encoder.encode(timestamp, value)
  
  let compressed = encoder.finish()
  let originalSize = numPoints * 16  # 8 bytes timestamp + 8 bytes value
  let compressionRatio = compressionRatio(originalSize, compressed.len)
  
  echo fmt"  Original size: {originalSize} bytes"
  echo fmt"  Compressed size: {compressed.len} bytes"
  echo fmt"  Compression ratio: {compressionRatio:.2f}x"
  echo fmt"  Bits per point: {bitsPerPoint(compressed.len, numPoints):.2f}"
  
  # Decode and verify
  var decoder = newGorillaDecoder(compressed)
  for i in 0 ..< numPoints:
    let (ts, val) = decoder.decode()
    let expectedTs = baseTime + int64(i * 60)
    assert ts == expectedTs, fmt"Timestamp mismatch at {i}"
  
  assert compressionRatio > 2.0, "Should achieve at least 2x compression"
  echo "  PASSED"

proc testH3Grid() =
  echo "\n=== Testing H3 Hexagonal Grid ==="
  
  # Test San Francisco coordinates
  let sf = GeoCoord(latDeg: 37.7749, lngDeg: -122.4194)
  
  for res in [4, 9, 12]:
    let cell = latLngToCell(sf, res)
    let center = cellToLatLng(cell)
    let area = cellAreaKm2(res)
    
    echo fmt"  Resolution {res}: cell={cell}, area={area:.6f} km²"
    echo fmt"    Center: ({center.latDeg:.4f}, {center.lngDeg:.4f})"
  
  # Test hierarchy
  let cell9 = latLngToCell(sf, 9)
  let parent7 = cellToParent(cell9, 7)
  let children10 = cellToChildren(cell9, 10)
  
  echo fmt"  Resolution 9 cell: {cell9}"
  echo fmt"  Parent at res 7: {parent7}"
  echo fmt"  Children at res 10: {children10.len} cells"
  
  # Test grid disk
  let disk1 = gridDisk(cell9, 1)
  echo fmt"  Grid disk k=1: {disk1.len} cells"
  
  assert disk1.len == 7, "k=1 disk should have 7 cells"
  assert children10.len == 7, "Should have 7 children"
  echo "  PASSED"

proc testSimdStringSearch() =
  echo "\n=== Testing SIMD String Search ==="
  
  let haystack = "The quick brown fox jumps over the lazy dog. " & 
                 "Pack my box with five dozen liquor jugs."
  
  # Test basic search
  let pos1 = simdFind(haystack, "fox")
  let pos2 = simdFind(haystack, "xyz")
  let pos3 = simdFind(haystack, "box")
  
  echo fmt"  'fox' found at: {pos1}"
  echo fmt"  'xyz' found at: {pos2}"
  echo fmt"  'box' found at: {pos3}"
  
  assert pos1 == 16, "Should find 'fox' at position 16"
  assert pos2 == -1, "Should not find 'xyz'"
  
  # Test find all
  let allThe = simdFindAll(haystack, "the")
  echo fmt"  'the' occurrences: {allThe.len}"
  
  # Test count
  let count = simdCount(haystack, "o")
  echo fmt"  Letter 'o' count: {count}"
  
  # Test startsWith/endsWith
  assert startsWith(haystack, "The"), "Should start with 'The'"
  assert endsWith(haystack, "jugs."), "Should end with 'jugs.'"
  
  echo "  PASSED"

proc testDeltaSteppingSSSP() =
  echo "\n=== Testing Delta-Stepping SSSP ==="
  
  # Create a simple test graph
  var adj = newAdjacencyList(6)
  adj.addEdge(0, 1, 7)
  adj.addEdge(0, 2, 9)
  adj.addEdge(0, 5, 14)
  adj.addEdge(1, 2, 10)
  adj.addEdge(1, 3, 15)
  adj.addEdge(2, 3, 11)
  adj.addEdge(2, 5, 2)
  adj.addEdge(3, 4, 6)
  adj.addEdge(4, 5, 9)
  
  let graph = adj.toCSR()
  echo fmt"  Graph: {graph.numNodes} nodes, {graph.numEdges} edges"
  
  # Run Dijkstra
  let dijkstraDist = dijkstra(graph, 0)
  echo fmt"  Dijkstra distances from 0: {dijkstraDist}"
  
  # Run Delta-Stepping
  let delta = suggestDelta(graph)
  let deltaDist = deltaSteppingSSSP(graph, 0, delta)
  echo fmt"  Delta-Stepping (δ={delta:.1f}): {deltaDist}"
  
  # Verify results match
  for i in 0 ..< graph.numNodes:
    assert abs(dijkstraDist[i] - deltaDist[i]) < 1e-6, 
           fmt"Distance mismatch at node {i}"
  
  echo "  PASSED"

proc testHarleySealPopcount() =
  echo "\n=== Testing Harley-Seal Popcount ==="
  
  # Create test data
  var data: seq[uint64] = @[]
  for i in 0 ..< 100:
    data.add(uint64(i) * 0xABCDEF123456789'u64)
  
  # Compare implementations
  let scalarCount = popcountScalar(data)
  let harleySealCount = harleySealScalar(data)
  let autoCount = popcount(data)
  
  echo fmt"  Data: {data.len} 64-bit words"
  echo fmt"  Scalar popcount: {scalarCount}"
  echo fmt"  Harley-Seal popcount: {harleySealCount}"
  echo fmt"  Auto-selected popcount: {autoCount}"
  
  assert scalarCount == harleySealCount, "Counts should match"
  assert scalarCount == autoCount, "Counts should match"
  
  # Test positional popcount
  let positional = positionalPopcount(data)
  echo fmt"  Positional popcount[0..3]: {positional[0]}, {positional[1]}, {positional[2]}, {positional[3]}"
  
  echo "  PASSED"

proc testLockFreeSkipList() =
  echo "\n=== Testing Lock-Free Skip List ==="
  
  var sl = newSkipList[int, string]()
  
  # Insert items
  for i in [5, 3, 8, 1, 9, 2, 7, 4, 6]:
    discard sl.insert(i, fmt"value_{i}")
  
  echo "  Inserted 9 items"
  
  # Test contains
  assert sl.contains(5), "Should contain 5"
  assert sl.contains(1), "Should contain 1"
  assert not sl.contains(10), "Should not contain 10"
  
  # Test get
  let val5 = sl.get(5)
  echo fmt"  get(5) = {val5}"
  assert val5.isSome and val5.get == "value_5", "Should get value_5"
  
  # Test remove
  discard sl.remove(5)
  assert not sl.contains(5), "Should not contain 5 after removal"
  echo "  Removed 5"
  
  # Iterate
  echo "  Items in order:"
  for (k, v) in sl.items:
    echo fmt"    {k} -> {v}"
  
  echo "  PASSED"

when isMainModule:
  randomize()
  echo "Testing newly implemented algorithms..."
  
  testBinaryFuseFilter()
  testBinaryFuse16()
  testGorillaCompression()
  testH3Grid()
  testSimdStringSearch()
  testDeltaSteppingSSSP()
  testHarleySealPopcount()
  testLockFreeSkipList()
  
  echo "\n" & "=" .repeat(50)
  echo "All tests PASSED!"
  echo "=" .repeat(50)
