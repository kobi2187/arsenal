## Benchmarks for Swiss Table Hash Map
## =====================================

import std/[times, strformat, random, hashes]
import ../src/arsenal/datastructures/hashtables/swiss_table

proc benchmark(name: string, iterations: int, fn: proc()) =
  ## Run a benchmark and print results
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let opsPerSec = float(iterations) / elapsed
  let nsPerOp = (elapsed * 1_000_000_000.0) / float(iterations)

  echo &"{name:55} {opsPerSec:15.0f} ops/sec  {nsPerOp:8.2f} ns/op"

echo "Swiss Table Hash Map Benchmarks"
echo "================================"
echo ""

# Insertion Benchmarks
echo "Insertion Performance:"
echo "----------------------"

benchmark "Insert 1,000 items (sequential keys)", 1000:
  var table = SwissTable[int, int].init()
  for i in 0..<1000:
    table[i] = i * 2

benchmark "Insert 10,000 items (sequential keys)", 100:
  var table = SwissTable[int, int].init()
  for i in 0..<10000:
    table[i] = i * 2

benchmark "Insert 100,000 items (sequential keys)", 10:
  var table = SwissTable[int, int].init()
  for i in 0..<100000:
    table[i] = i * 2

echo ""

benchmark "Insert 1,000 items (random keys)", 1000:
  var table = SwissTable[int, int].init()
  randomize(42)
  for i in 0..<1000:
    table[rand(1000000)] = i

benchmark "Insert 10,000 items (random keys)", 100:
  var table = SwissTable[int, int].init()
  randomize(42)
  for i in 0..<10000:
    table[rand(1000000)] = i

echo ""

benchmark "Insert 1,000 string items", 1000:
  var table = SwissTable[string, int].init()
  for i in 0..<1000:
    table["key_" & $i] = i

benchmark "Insert 10,000 string items", 100:
  var table = SwissTable[string, int].init()
  for i in 0..<10000:
    table["key_" & $i] = i

echo ""

# Lookup Benchmarks
echo "Lookup Performance:"
echo "-------------------"

# Setup tables for lookup tests
var intTable1k = SwissTable[int, int].init()
var intTable10k = SwissTable[int, int].init()
var intTable100k = SwissTable[int, int].init()
var stringTable1k = SwissTable[string, int].init()

for i in 0..<1000:
  intTable1k[i] = i * 2
for i in 0..<10000:
  intTable10k[i] = i * 2
for i in 0..<100000:
  intTable100k[i] = i * 2
for i in 0..<1000:
  stringTable1k["key_" & $i] = i

benchmark "Lookup (1,000 items, 100% hit rate)", 100000:
  randomize(42)
  discard intTable1k[rand(1000)]

benchmark "Lookup (10,000 items, 100% hit rate)", 100000:
  randomize(42)
  discard intTable10k[rand(10000)]

benchmark "Lookup (100,000 items, 100% hit rate)", 100000:
  randomize(42)
  discard intTable100k[rand(100000)]

echo ""

benchmark "contains() check (1,000 items, 100% hit)", 1000000:
  randomize(42)
  discard intTable1k.contains(rand(1000))

benchmark "contains() check (10,000 items, 100% hit)", 1000000:
  randomize(42)
  discard intTable10k.contains(rand(10000))

benchmark "contains() check (1,000 items, 0% hit)", 1000000:
  randomize(42)
  discard intTable1k.contains(rand(1000000) + 100000)

echo ""

benchmark "find() Some (1,000 items, 100% hit)", 1000000:
  randomize(42)
  discard intTable1k.find(rand(1000))

benchmark "find() None (1,000 items, 0% hit)", 1000000:
  randomize(42)
  discard intTable1k.find(rand(1000000) + 100000)

echo ""

benchmark "String lookup (1,000 items)", 100000:
  randomize(42)
  let key = "key_" & $rand(1000)
  discard stringTable1k[key]

echo ""

# Update Benchmarks
echo "Update Performance:"
echo "-------------------"

benchmark "Update existing keys (1,000 items)", 10000:
  var table = SwissTable[int, int].init()
  for i in 0..<1000:
    table[i] = i * 2
  for i in 0..<1000:
    table[i] = i * 3  # Update

benchmark "Update existing keys (10,000 items)", 1000:
  var table = SwissTable[int, int].init()
  for i in 0..<10000:
    table[i] = i * 2
  for i in 0..<10000:
    table[i] = i * 3  # Update

echo ""

# Deletion Benchmarks
echo "Deletion Performance:"
echo "---------------------"

benchmark "Delete 500 items from 1,000", 1000:
  var table = SwissTable[int, int].init()
  for i in 0..<1000:
    table[i] = i * 2
  for i in 0..<500:
    discard table.delete(i)

benchmark "Delete 5,000 items from 10,000", 100:
  var table = SwissTable[int, int].init()
  for i in 0..<10000:
    table[i] = i * 2
  for i in 0..<5000:
    discard table.delete(i)

echo ""

# Iteration Benchmarks
echo "Iteration Performance:"
echo "----------------------"

benchmark "Iterate pairs (1,000 items)", 10000:
  var sum = 0
  for k, v in intTable1k.pairs:
    sum += v

benchmark "Iterate pairs (10,000 items)", 1000:
  var sum = 0
  for k, v in intTable10k.pairs:
    sum += v

benchmark "Iterate pairs (100,000 items)", 100:
  var sum = 0
  for k, v in intTable100k.pairs:
    sum += v

echo ""

benchmark "Iterate keys (1,000 items)", 10000:
  var sum = 0
  for k in intTable1k.keys:
    sum += k

benchmark "Iterate values (1,000 items)", 10000:
  var sum = 0
  for v in intTable1k.values:
    sum += v

echo ""

# Mixed Operations Benchmark
echo "Mixed Workload (realistic usage):"
echo "----------------------------------"

benchmark "Mixed: 70% lookup, 20% insert, 10% delete", 10000:
  var table = SwissTable[int, int].init()
  randomize(42)

  # Initial population
  for i in 0..<1000:
    table[i] = i

  # Mixed operations
  for i in 0..<1000:
    let r = rand(100)
    if r < 70:
      # Lookup
      discard table.contains(rand(1000))
    elif r < 90:
      # Insert
      table[rand(2000)] = i
    else:
      # Delete
      discard table.delete(rand(1000))

echo ""

# Clear Benchmark
echo "Clear Performance:"
echo "------------------"

benchmark "Clear table (1,000 items)", 10000:
  var table = SwissTable[int, int].init()
  for i in 0..<1000:
    table[i] = i * 2
  table.clear()

benchmark "Clear table (10,000 items)", 1000:
  var table = SwissTable[int, int].init()
  for i in 0..<10000:
    table[i] = i * 2
  table.clear()

echo ""

# Load Factor Test
echo "Load Factor Impact:"
echo "-------------------"

benchmark "Insert to 50% load (capacity 1024)", 1000:
  var table = SwissTable[int, int].init(1024)
  for i in 0..<512:  # 50% load
    table[i] = i

benchmark "Insert to 75% load (capacity 1024)", 1000:
  var table = SwissTable[int, int].init(1024)
  for i in 0..<768:  # 75% load
    table[i] = i

benchmark "Insert to 87.5% load (capacity 1024)", 1000:
  var table = SwissTable[int, int].init(1024)
  for i in 0..<896:  # 87.5% load (max before resize)
    table[i] = i

echo ""

# Memory Overhead
echo "Memory Characteristics:"
echo "-----------------------"

var table1k = SwissTable[int, int].init()
for i in 0..<1000:
  table1k[i] = i

echo &"  Table with 1,000 items:"
echo &"    Length: {table1k.len}"
echo &"    Capacity: {table1k.capacity}"
echo &"    Load factor: {float(table1k.len) / float(table1k.capacity) * 100.0:.1f}%"
echo &"    Control bytes: {table1k.capacity} bytes"
echo &"    Slots: {table1k.capacity} * (8 + 8) = {table1k.capacity * 16} bytes"
echo &"    Total overhead: ~{table1k.capacity * 17} bytes"
echo &"    Bytes per entry: ~{table1k.capacity * 17 div table1k.len} bytes"

echo ""

var table10k = SwissTable[int, int].init()
for i in 0..<10000:
  table10k[i] = i

echo &"  Table with 10,000 items:"
echo &"    Length: {table10k.len}"
echo &"    Capacity: {table10k.capacity}"
echo &"    Load factor: {float(table10k.len) / float(table10k.capacity) * 100.0:.1f}%"
echo &"    Bytes per entry: ~{table10k.capacity * 17 div table10k.len} bytes"

echo ""

echo "Performance Summary"
echo "==================="
echo ""
echo "Swiss Table Design:"
echo "  - 1-byte metadata per slot (7-bit hash + 1-bit state)"
echo "  - 16-slot groups for SIMD readiness"
echo "  - Linear probing by group (cache-friendly)"
echo "  - 87.5% max load factor (7/8 slots before resize)"
echo ""
echo "Expected Performance (modern CPU, single core):"
echo ""
echo "Insertions:"
echo "  - Sequential keys: ~5-10 million ops/sec"
echo "  - Random keys: ~3-8 million ops/sec"
echo "  - Includes hash computation and collision handling"
echo ""
echo "Lookups:"
echo "  - Hit (key exists): ~10-30 million ops/sec"
echo "  - Miss (key absent): ~15-40 million ops/sec"
echo "  - O(1) average case, cache-friendly"
echo ""
echo "Deletions:"
echo "  - Tombstone marking: ~8-15 million ops/sec"
echo "  - Maintains probe chain integrity"
echo ""
echo "Iteration:"
echo "  - Full scan: ~100-500 million entries/sec"
echo "  - Cache-friendly sequential access"
echo ""
echo "Memory:"
echo "  - Per-entry overhead: ~17 bytes (1 ctrl + 16 key+value)"
echo "  - For int->int: 17 bytes vs 16 bytes payload = 106% overhead"
echo "  - Better for larger values (less relative overhead)"
echo ""
echo "SIMD Potential:"
echo "  - Control byte groups enable SSE2/AVX2 matching"
echo "  - Can check 16 slots in parallel"
echo "  - Current implementation: scalar (portable)"
echo "  - SIMD version: 2-3x faster lookups possible"
echo ""
echo "Comparison to std/tables:"
echo "  - Swiss Table: Better cache locality, SIMD-ready"
echo "  - std/tables: Good general-purpose, mature"
echo "  - Swiss Table: Better for high-performance needs"
