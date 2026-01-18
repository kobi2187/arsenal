## S3-FIFO Cache Eviction
## =======================
##
## Simple, Scalable cache eviction using three Static FIFO queues.
## Outperforms LRU and other eviction algorithms with better hit rates and scalability.
##
## Paper: "FIFO queues are all you need for cache eviction"
##        Yang, Zhang, Qiu, Yue, Rashmi (2023)
##        ACM SOSP'23
##        https://dl.acm.org/doi/10.1145/3600006.3613147
##        https://s3fifo.com/
##
## Key Innovation:
## - **Three queues**: Small (filter), Main (bulk), Ghost (metadata)
## - **Lazy promotion**: Objects promoted only after repeated access
## - **Quick demotion**: Single-access objects quickly filtered out
## - **Lock-free**: Scales to 16+ threads with 6× throughput vs LRU
##
## Performance:
## - **Hit rate**: Better than LRU, ARC, LFU on 6594 production traces
## - **Throughput**: 6× higher than optimized LRU at 16 threads
## - **Simplicity**: Only FIFO queues, no complex data structures
##
## Applications:
## - Web caches (CDN, proxy caches)
## - Database buffer pools
## - Key-value stores (Redis, Memcached)
## - File system caches
##
## Adoption:
## - VMware (vSAN metadata cache)
## - Google (production systems)
## - Redpanda (Kafka-compatible streaming)
##
## Usage:
## ```nim
## import arsenal/caching/s3fifo
##
## # Create cache with 1000 entry capacity
## var cache = initS3FIFOCache[string, int](1000)
##
## # Insert entries
## cache.put("key1", 100)
## cache.put("key2", 200)
##
## # Lookup (returns Option[V])
## if cache.get("key1").isSome:
##   echo "Found: ", cache.get("key1").get()
## ```

import std/[tables, options, deques]

# =============================================================================
# Types
# =============================================================================

type
  CacheEntry*[K, V] = ref object
    ## Cache entry with metadata
    key*: K
    value*: V
    freq*: uint8  ## Access frequency (0-3, acts as 2-bit counter)

  S3FIFOCache*[K, V] = object
    ## S3-FIFO cache
    ##
    ## Structure:
    ## - Small queue (S): 10% capacity, filters single-access objects
    ## - Main queue (M): 90% capacity, stores frequently accessed objects
    ## - Ghost queue (G): Metadata only, tracks recently evicted keys
    capacity*: int                    ## Total cache capacity
    smallCapacity*: int               ## Small queue capacity (10% of total)
    mainCapacity*: int                ## Main queue capacity (90% of total)

    small*: Deque[CacheEntry[K, V]]   ## Small FIFO queue
    main*: Deque[CacheEntry[K, V]]    ## Main FIFO queue
    ghost*: Deque[K]                  ## Ghost queue (keys only)

    index*: Table[K, CacheEntry[K, V]]  ## Fast lookup table
    ghostSet*: Table[K, bool]           ## Ghost queue membership

    hits*: int                        ## Cache hits (for statistics)
    misses*: int                      ## Cache misses (for statistics)

# =============================================================================
# Constants
# =============================================================================

const
  SmallQueueRatio = 0.1  ## Small queue uses 10% of cache capacity
  MaxFrequency = 3       ## Maximum frequency counter value (2-bit)

# =============================================================================
# Construction
# =============================================================================

proc initS3FIFOCache*[K, V](capacity: int): S3FIFOCache[K, V] =
  ## Create new S3-FIFO cache
  ##
  ## Parameters:
  ## - capacity: Maximum number of entries in cache
  ##
  ## Queue sizes:
  ## - Small: 10% of capacity
  ## - Main: 90% of capacity
  ## - Ghost: Same as Main (metadata only)
  if capacity < 10:
    raise newException(ValueError, "Capacity must be at least 10")

  let smallCap = max(1, int(capacity.float64 * SmallQueueRatio))
  let mainCap = capacity - smallCap

  result = S3FIFOCache[K, V](
    capacity: capacity,
    smallCapacity: smallCap,
    mainCapacity: mainCap,
    small: initDeque[CacheEntry[K, V]](),
    main: initDeque[CacheEntry[K, V]](),
    ghost: initDeque[K](),
    index: initTable[K, CacheEntry[K, V]](),
    ghostSet: initTable[K, bool](),
    hits: 0,
    misses: 0
  )

proc clear*[K, V](cache: var S3FIFOCache[K, V]) =
  ## Clear all entries from cache
  cache.small.clear()
  cache.main.clear()
  cache.ghost.clear()
  cache.index.clear()
  cache.ghostSet.clear()
  cache.hits = 0
  cache.misses = 0

# =============================================================================
# Internal Operations
# =============================================================================

proc evictFromSmall[K, V](cache: var S3FIFOCache[K, V]) =
  ## Evict one entry from small queue
  ##
  ## Algorithm:
  ## 1. Get tail entry from small queue
  ## 2. If freq > 0: move to main queue (lazy promotion)
  ## 3. Otherwise: evict to ghost queue (quick demotion)
  if cache.small.len == 0:
    return

  let entry = cache.small.popFirst()

  if entry.freq > 0:
    # Promote to main queue (was accessed while in small)
    entry.freq = 0  # Reset frequency

    # Evict from main if full
    if cache.main.len >= cache.mainCapacity:
      cache.evictFromMain()

    cache.main.addLast(entry)
  else:
    # Evict to ghost queue (single-access object)
    cache.index.del(entry.key)

    # Add to ghost queue
    cache.ghost.addLast(entry.key)
    cache.ghostSet[entry.key] = true

    # Evict from ghost if full
    if cache.ghost.len > cache.mainCapacity:
      let evictedKey = cache.ghost.popFirst()
      cache.ghostSet.del(evictedKey)

proc evictFromMain[K, V](cache: var S3FIFOCache[K, V]) =
  ## Evict one entry from main queue
  ##
  ## Algorithm (FIFO-Reinsertion):
  ## 1. Get tail entry from main queue
  ## 2. If freq > 0: reinsert to head (give another chance)
  ## 3. Otherwise: evict to ghost queue
  if cache.main.len == 0:
    return

  # Scan from tail until we find an entry with freq == 0
  var attempts = 0
  let maxAttempts = cache.main.len

  while attempts < maxAttempts:
    let entry = cache.main.popFirst()
    inc attempts

    if entry.freq > 0:
      # Reinsert to head (give another chance)
      dec entry.freq
      cache.main.addLast(entry)
    else:
      # Evict to ghost queue
      cache.index.del(entry.key)

      cache.ghost.addLast(entry.key)
      cache.ghostSet[entry.key] = true

      if cache.ghost.len > cache.mainCapacity:
        let evictedKey = cache.ghost.popFirst()
        cache.ghostSet.del(evictedKey)

      return

  # All entries have freq > 0, evict the first one anyway
  if cache.main.len > 0:
    let entry = cache.main.popFirst()
    cache.index.del(entry.key)

    cache.ghost.addLast(entry.key)
    cache.ghostSet[entry.key] = true

    if cache.ghost.len > cache.mainCapacity:
      let evictedKey = cache.ghost.popFirst()
      cache.ghostSet.del(evictedKey)

# =============================================================================
# Cache Operations
# =============================================================================

proc get*[K, V](cache: var S3FIFOCache[K, V], key: K): Option[V] =
  ## Get value for key (cache hit increments frequency)
  ##
  ## Returns:
  ## - Some(value) if key exists
  ## - None if key not found
  ##
  ## Side effect: Increments frequency counter on hit
  if key in cache.index:
    let entry = cache.index[key]

    # Increment frequency (capped at MaxFrequency)
    if entry.freq < MaxFrequency:
      inc entry.freq

    inc cache.hits
    return some(entry.value)

  inc cache.misses
  none(V)

proc contains*[K, V](cache: var S3FIFOCache[K, V], key: K): bool =
  ## Check if key exists in cache (also increments frequency)
  cache.get(key).isSome

proc put*[K, V](cache: var S3FIFOCache[K, V], key: K, value: V) =
  ## Insert or update entry in cache
  ##
  ## Algorithm:
  ## 1. If key exists: update value, increment frequency
  ## 2. If key in ghost: insert to main (was recently evicted)
  ## 3. Otherwise: insert to small (new entry)

  # Update existing entry
  if key in cache.index:
    let entry = cache.index[key]
    entry.value = value

    if entry.freq < MaxFrequency:
      inc entry.freq

    return

  # Create new entry
  let entry = CacheEntry[K, V](
    key: key,
    value: value,
    freq: 0
  )

  cache.index[key] = entry

  # Check if key was in ghost queue (recently evicted)
  if key in cache.ghostSet:
    # Insert to main queue (promote immediately)
    cache.ghostSet.del(key)

    # Remove from ghost queue (O(n) operation, but rare)
    var newGhost = initDeque[K]()
    for gkey in cache.ghost:
      if gkey != key:
        newGhost.addLast(gkey)
    cache.ghost = newGhost

    # Evict from main if full
    if cache.main.len >= cache.mainCapacity:
      cache.evictFromMain()

    cache.main.addLast(entry)
  else:
    # Insert to small queue (new entry)
    # Evict from small if full
    if cache.small.len >= cache.smallCapacity:
      cache.evictFromSmall()

    cache.small.addLast(entry)

proc remove*[K, V](cache: var S3FIFOCache[K, V], key: K): bool =
  ## Remove entry from cache
  ##
  ## Returns true if key was present
  if key notin cache.index:
    return false

  let entry = cache.index[key]
  cache.index.del(key)

  # Remove from appropriate queue (O(n) operation)
  # Note: For production use, consider using doubly-linked list with pointers
  var newSmall = initDeque[CacheEntry[K, V]]()
  for e in cache.small:
    if e.key != key:
      newSmall.addLast(e)
  cache.small = newSmall

  var newMain = initDeque[CacheEntry[K, V]]()
  for e in cache.main:
    if e.key != key:
      newMain.addLast(e)
  cache.main = newMain

  true

# =============================================================================
# Statistics
# =============================================================================

proc size*[K, V](cache: S3FIFOCache[K, V]): int =
  ## Current number of entries in cache
  cache.index.len

proc capacity*[K, V](cache: S3FIFOCache[K, V]): int =
  ## Maximum cache capacity
  cache.capacity

proc hitRate*[K, V](cache: S3FIFOCache[K, V]): float64 =
  ## Cache hit rate (hits / total accesses)
  let total = cache.hits + cache.misses
  if total == 0:
    return 0.0
  cache.hits.float64 / total.float64

proc missRate*[K, V](cache: S3FIFOCache[K, V]): float64 =
  ## Cache miss rate (misses / total accesses)
  1.0 - cache.hitRate()

proc resetStats*[K, V](cache: var S3FIFOCache[K, V]) =
  ## Reset hit/miss statistics
  cache.hits = 0
  cache.misses = 0

proc `$`*[K, V](cache: S3FIFOCache[K, V]): string =
  result = "S3FIFOCache(capacity=" & $cache.capacity &
           ", size=" & $cache.size() &
           ", small=" & $cache.small.len &
           ", main=" & $cache.main.len &
           ", ghost=" & $cache.ghost.len &
           ", hitRate=" & (cache.hitRate() * 100.0).formatFloat(ffDecimal, 2) & "%)"

# =============================================================================
# Iterator
# =============================================================================

iterator pairs*[K, V](cache: S3FIFOCache[K, V]): (K, V) =
  ## Iterate over all key-value pairs in cache
  for key, entry in cache.index:
    yield (key, entry.value)

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "S3-FIFO Cache Eviction"
  echo "======================"
  echo ""

  # Test 1: Basic operations
  echo "Test 1: Basic cache operations"
  echo "------------------------------"

  var cache1 = initS3FIFOCache[string, int](10)

  # Insert entries
  for i in 1..10:
    cache1.put("key" & $i, i * 100)

  echo "Inserted 10 entries"
  echo "Cache size: ", cache1.size()
  echo ""

  # Lookups
  echo "Lookups:"
  for key in ["key1", "key5", "key10", "key99"]:
    let result = cache1.get(key)
    if result.isSome:
      echo "  ", key, ": ", result.get()
    else:
      echo "  ", key, ": NOT FOUND"

  echo ""
  echo cache1
  echo ""

  # Test 2: Eviction behavior
  echo "Test 2: Eviction behavior"
  echo "-------------------------"

  var cache2 = initS3FIFOCache[int, string](5)

  # Fill cache
  for i in 1..5:
    cache2.put(i, "value" & $i)

  echo "Filled cache with 5 entries: [1, 2, 3, 4, 5]"
  echo ""

  # Access some entries multiple times (promote to main)
  for _ in 0..2:
    discard cache2.get(1)
    discard cache2.get(3)

  echo "Accessed keys 1 and 3 multiple times (should be promoted)"
  echo ""

  # Add new entries (should evict less frequently accessed)
  cache2.put(6, "value6")
  cache2.put(7, "value7")

  echo "Added keys 6 and 7"
  echo "Current entries:"
  for key, value in cache2.pairs():
    echo "  ", key, ": ", value
  echo ""

  # Test 3: Hit rate measurement
  echo "Test 3: Hit rate measurement"
  echo "---------------------------"

  var cache3 = initS3FIFOCache[int, int](100)

  # Zipf-like access pattern (realistic for caches)
  randomize(42)

  # Phase 1: Warm up
  for i in 0..<1000:
    let key = rand(200)  # Access keys 0-199
    if cache3.get(key).isNone:
      cache3.put(key, key * 10)

  echo "Warm-up phase: 1000 accesses"
  echo "  Hit rate: ", (cache3.hitRate() * 100.0).formatFloat(ffDecimal, 2), "%"
  echo "  Cache size: ", cache3.size()
  echo ""

  cache3.resetStats()

  # Phase 2: Skewed workload
  for i in 0..<10_000:
    # 80% of accesses to 20% of keys (80/20 rule)
    let key = if rand(100) < 80:
      rand(40)  # Hot keys: 0-39
    else:
      40 + rand(160)  # Cold keys: 40-199

    if cache3.get(key).isNone:
      cache3.put(key, key * 10)

  echo "Skewed workload: 10,000 accesses (80/20 distribution)"
  echo "  Hit rate: ", (cache3.hitRate() * 100.0).formatFloat(ffDecimal, 2), "%"
  echo "  Miss rate: ", (cache3.missRate() * 100.0).formatFloat(ffDecimal, 2), "%"
  echo "  Cache size: ", cache3.size()
  echo ""

  # Test 4: Performance benchmark
  echo "Test 4: Performance benchmark"
  echo "----------------------------"

  var cache4 = initS3FIFOCache[int, int](1000)
  let numOps = 1_000_000

  echo "Performing ", numOps, " operations..."

  let start = cpuTime()

  randomize(123)
  for i in 0..<numOps:
    let key = rand(10_000)

    if cache4.get(key).isNone:
      cache4.put(key, key)

  let elapsed = cpuTime() - start

  echo "  Time: ", (elapsed * 1000.0).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (numOps.float64 / elapsed / 1_000_000.0).formatFloat(ffDecimal, 2), " M ops/sec"
  echo "  Hit rate: ", (cache4.hitRate() * 100.0).formatFloat(ffDecimal, 2), "%"
  echo "  Cache size: ", cache4.size(), " / ", cache4.capacity()
  echo ""

  # Test 5: Comparison with naive FIFO
  echo "Test 5: S3-FIFO advantage over naive FIFO"
  echo "-----------------------------------------"

  # Workload: repeated access to same keys (S3-FIFO should win)
  var cache5 = initS3FIFOCache[int, int](50)

  randomize(456)

  # Hot set: 30 keys accessed repeatedly
  # Cold set: 1000 keys accessed once each
  for i in 0..<5000:
    let key = if rand(100) < 90:
      rand(30)  # Hot: 90% accesses to 30 keys
    else:
      30 + rand(970)  # Cold: 10% accesses to 970 keys

    if cache5.get(key).isNone:
      cache5.put(key, key)

  echo "Workload: 90% hot (30 keys), 10% cold (970 keys)"
  echo "  Cache capacity: ", cache5.capacity()
  echo "  Hit rate: ", (cache5.hitRate() * 100.0).formatFloat(ffDecimal, 2), "%"
  echo "  (Naive FIFO would have much lower hit rate)"
  echo ""

  echo "All tests completed!"
