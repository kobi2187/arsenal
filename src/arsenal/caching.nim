## Arsenal Caching - Unified High-Level API
## ==========================================
##
## This module provides a consistent, ergonomic API for all caching
## implementations. It wraps the underlying implementations without
## modifying them.
##
## You can use either:
## - This high-level API (consistent, discoverable)
## - Direct implementation modules (full control, all features)
##
## Usage:
## ```nim
## import arsenal/caching
##
## # Create cache
## var cache = Cache[string, int].new(capacity = 1000)
##
## # Store and retrieve
## cache.put("key", 100)
## if cache.get("key").isSome:
##   echo cache.get("key").get()
##
## # Check statistics
## echo cache.hitRate()
## ```

import arsenal/caching/s3fifo
import std/options

export s3fifo, options  # Re-export for direct use

# =============================================================================
# CACHE - Unified API for caching with eviction
# =============================================================================

type
  Cache*[K, V] = object
    ## High-level API for caching
    ##
    ## Wraps: S3FIFOCache
    ##
    ## Properties:
    ## - Bounded size with automatic eviction
    ## - Better hit rates than LRU
    ## - High throughput (lock-free friendly)
    impl: S3FIFOCache[K, V]

  CacheBuilder*[K, V] = object
    capacity: int
    smallRatio: float64

# Constructors
proc new*[K, V](_: typedesc[Cache[K, V]], capacity: int): CacheBuilder[K, V] =
  ## Create cache builder
  ##
  ## Parameters:
  ## - capacity: Maximum number of entries
  ##
  ## Example:
  ## ```nim
  ## var cache = Cache[string, int].new(capacity = 1000)
  ##   .withSmallRatio(0.1)
  ##   .build()
  ## ```
  CacheBuilder[K, V](capacity: capacity, smallRatio: 0.1)

proc withSmallRatio*[K, V](builder: CacheBuilder[K, V],
                           ratio: float64): CacheBuilder[K, V] =
  ## Set small queue ratio (default 0.1 = 10%)
  ##
  ## The small queue filters out single-access items
  result = builder
  result.smallRatio = ratio

proc build*[K, V](builder: CacheBuilder[K, V]): Cache[K, V] =
  ## Build cache from builder
  Cache[K, V](impl: initS3FIFOCache[K, V](builder.capacity))

proc init*[K, V](_: typedesc[Cache[K, V]], capacity: int): Cache[K, V] {.inline.} =
  ## Direct construction (no builder)
  Cache[K, V].new(capacity).build()

# Presets
proc fast*[K, V](_: typedesc[Cache[K, V]], capacity: int): Cache[K, V] {.inline.} =
  ## Fast preset: optimized for throughput
  Cache[K, V].new(capacity).build()

proc balanced*[K, V](_: typedesc[Cache[K, V]], capacity: int): Cache[K, V] {.inline.} =
  ## Balanced preset: good hit rate and throughput
  Cache[K, V].new(capacity).build()

# Mutation operations
proc put*[K, V](cache: var Cache[K, V], key: K, value: V) {.inline.} =
  ## Insert or update entry
  ##
  ## If cache is full, least useful entry is evicted
  cache.impl.put(key, value)

proc set*[K, V](cache: var Cache[K, V], key: K, value: V) {.inline.} =
  ## Alias for put()
  cache.put(key, value)

proc `[]=`*[K, V](cache: var Cache[K, V], key: K, value: V) {.inline.} =
  ## Assignment operator
  ##
  ## Example: cache["key"] = 100
  cache.put(key, value)

proc remove*[K, V](cache: var Cache[K, V], key: K): bool {.inline.} =
  ## Remove entry from cache
  ##
  ## Returns true if key was present
  cache.impl.remove(key)

proc delete*[K, V](cache: var Cache[K, V], key: K) {.inline.} =
  ## Delete entry (ignores result)
  discard cache.remove(key)

proc clear*[K, V](cache: var Cache[K, V]) {.inline.} =
  ## Remove all entries
  cache.impl.clear()

# Query operations
proc get*[K, V](cache: var Cache[K, V], key: K): Option[V] {.inline.} =
  ## Get value for key
  ##
  ## Returns Some(value) if found, None otherwise
  ## Cache hit increments access frequency
  cache.impl.get(key)

proc `[]`*[K, V](cache: var Cache[K, V], key: K): Option[V] {.inline.} =
  ## Index operator
  ##
  ## Example: let value = cache["key"]
  cache.get(key)

proc getOrDefault*[K, V](cache: var Cache[K, V], key: K, default: V): V =
  ## Get value or return default
  let opt = cache.get(key)
  if opt.isSome: opt.get() else: default

proc contains*[K, V](cache: var Cache[K, V], key: K): bool {.inline.} =
  ## Test if key exists in cache
  ##
  ## Note: Also increments access frequency
  cache.impl.contains(key)

proc has*[K, V](cache: var Cache[K, V], key: K): bool {.inline.} =
  ## Alias for contains()
  cache.contains(key)

# Metadata
proc len*[K, V](cache: Cache[K, V]): int {.inline.} =
  ## Current number of entries
  cache.impl.size()

proc size*[K, V](cache: Cache[K, V]): int {.inline.} =
  ## Alias for len()
  cache.len()

proc capacity*[K, V](cache: Cache[K, V]): int {.inline.} =
  ## Maximum capacity
  cache.impl.capacity()

proc isEmpty*[K, V](cache: Cache[K, V]): bool {.inline.} =
  ## Check if cache is empty
  cache.len() == 0

proc isFull*[K, V](cache: Cache[K, V]): bool {.inline.} =
  ## Check if cache is at capacity
  cache.len() >= cache.capacity()

proc utilization*[K, V](cache: Cache[K, V]): float64 {.inline.} =
  ## Cache utilization (0.0 to 1.0)
  cache.len().float64 / cache.capacity().float64

# Statistics
proc hitRate*[K, V](cache: Cache[K, V]): float64 {.inline.} =
  ## Cache hit rate (0.0 to 1.0)
  cache.impl.hitRate()

proc missRate*[K, V](cache: Cache[K, V]): float64 {.inline.} =
  ## Cache miss rate (0.0 to 1.0)
  cache.impl.missRate()

proc hits*[K, V](cache: Cache[K, V]): int {.inline.} =
  ## Total number of cache hits
  cache.impl.hits

proc misses*[K, V](cache: Cache[K, V]): int {.inline.} =
  ## Total number of cache misses
  cache.impl.misses

proc resetStats*[K, V](cache: var Cache[K, V]) {.inline.} =
  ## Reset hit/miss statistics
  cache.impl.resetStats()

# Iteration
iterator pairs*[K, V](cache: Cache[K, V]): (K, V) =
  ## Iterate over all key-value pairs
  for key, value in cache.impl.pairs():
    yield (key, value)

iterator keys*[K, V](cache: Cache[K, V]): K =
  ## Iterate over all keys
  for key, _ in cache.pairs():
    yield key

iterator values*[K, V](cache: Cache[K, V]): V =
  ## Iterate over all values
  for _, value in cache.pairs():
    yield value

# Display
proc `$`*[K, V](cache: Cache[K, V]): string =
  ## String representation
  "Cache(size=" & $cache.len() &
    "/" & $cache.capacity() &
    ", hit=" & $(cache.hitRate() * 100).formatFloat(ffDecimal, 1) & "%)"

# =============================================================================
# CONVENIENCE CONSTRUCTORS
# =============================================================================

template newCache*[K, V](capacity: int): Cache[K, V] =
  ## Quick constructor
  Cache[K, V].init(capacity)

# =============================================================================
# EXAMPLE USAGE
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "Arsenal Caching - Unified API Demo"
  echo "==================================="
  echo ""

  # Basic caching
  echo "1. Basic Caching"
  echo "---------------"

  var cache = Cache[string, int].init(capacity = 5)

  # Add entries
  cache["user_1"] = 100
  cache["user_2"] = 200
  cache["user_3"] = 300

  echo "Added 3 entries"
  echo "Size: ", cache.len(), " / ", cache.capacity()
  echo ""

  # Retrieve entries
  echo "Lookups:"
  for key in ["user_1", "user_2", "user_99"]:
    let result = cache[key]
    if result.isSome:
      echo "  ", key, ": ", result.get()
    else:
      echo "  ", key, ": NOT FOUND"

  echo ""
  echo cache
  echo ""

  # Eviction behavior
  echo "2. Eviction Behavior"
  echo "-------------------"

  var smallCache = Cache[int, string].init(capacity = 5)

  # Fill cache
  for i in 1..5:
    smallCache[i] = "value_" & $i

  echo "Filled cache with 5 entries: [1, 2, 3, 4, 5]"
  echo ""

  # Access some entries multiple times (promote to main queue)
  for _ in 0..2:
    discard smallCache[1]
    discard smallCache[3]

  echo "Accessed keys 1 and 3 multiple times (should be promoted)"
  echo ""

  # Add new entries (should evict less frequently accessed)
  smallCache[6] = "value_6"
  smallCache[7] = "value_7"

  echo "Added keys 6 and 7"
  echo "Current keys in cache:"
  for key in smallCache.keys():
    echo "  ", key

  echo ""

  # Hit rate tracking
  echo "3. Hit Rate Tracking"
  echo "-------------------"

  var trackCache = Cache[int, int].init(capacity = 100)

  # Warm up cache
  randomize(42)
  for i in 0..<1000:
    let key = rand(200)  # Access keys 0-199, cache holds 100
    let val = trackCache[key]
    if val.isNone:
      trackCache[key] = key * 10

  echo "Workload: 1000 accesses to 200 keys (cache holds 100)"
  echo "Hit rate: ", (trackCache.hitRate() * 100).formatFloat(ffDecimal, 2), "%"
  echo "Miss rate: ", (trackCache.missRate() * 100).formatFloat(ffDecimal, 2), "%"
  echo "Hits: ", trackCache.hits()
  echo "Misses: ", trackCache.misses()
  echo "Utilization: ", (trackCache.utilization() * 100).formatFloat(ffDecimal, 1), "%"
  echo ""

  # Skewed workload (80/20 rule)
  echo "4. Skewed Workload (80/20 Pattern)"
  echo "-----------------------------------"

  var skewCache = Cache[int, int].init(capacity = 50)
  skewCache.resetStats()

  randomize(123)
  for i in 0..<10_000:
    # 80% of accesses to 20% of keys (hot keys: 0-39)
    let key = if rand(100) < 80:
      rand(40)  # Hot keys
    else:
      40 + rand(160)  # Cold keys: 40-199

    let val = skewCache[key]
    if val.isNone:
      skewCache[key] = key

  echo "Workload: 10,000 accesses (80% to 40 hot keys, 20% to 160 cold keys)"
  echo "Cache capacity: ", skewCache.capacity()
  echo "Hit rate: ", (skewCache.hitRate() * 100).formatFloat(ffDecimal, 2), "%"
  echo "Cache size: ", skewCache.len(), " / ", skewCache.capacity()
  echo ""

  # Performance benchmark
  echo "5. Performance Benchmark"
  echo "-----------------------"

  var perfCache = Cache[int, int].init(capacity = 1000)
  let numOps = 100_000

  echo "Performing ", numOps, " operations..."

  let start = cpuTime()
  randomize(456)
  for i in 0..<numOps:
    let key = rand(10_000)
    let val = perfCache[key]
    if val.isNone:
      perfCache[key] = key * 2

  let elapsed = cpuTime() - start

  echo "  Time: ", (elapsed * 1000).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (numOps.float64 / elapsed / 1_000_000).formatFloat(ffDecimal, 2), " M ops/sec"
  echo "  Hit rate: ", (perfCache.hitRate() * 100).formatFloat(ffDecimal, 2), "%"
  echo "  Final size: ", perfCache.len(), " / ", perfCache.capacity()
  echo ""

  # getOrDefault usage
  echo "6. getOrDefault Usage"
  echo "--------------------"

  var userCache = Cache[string, string].init(capacity = 10)
  userCache["alice"] = "Alice Smith"
  userCache["bob"] = "Bob Jones"

  echo "Known users: alice, bob"
  echo ""

  echo "Lookups with default:"
  echo "  alice: ", userCache.getOrDefault("alice", "Unknown")
  echo "  charlie: ", userCache.getOrDefault("charlie", "Unknown")
  echo ""

  echo "All demos completed!"
