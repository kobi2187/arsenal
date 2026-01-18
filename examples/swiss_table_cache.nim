## Swiss Table LRU Cache Example
## ===============================
##
## This example demonstrates practical use of Arsenal's Swiss Table
## as a high-performance cache with LRU (Least Recently Used) eviction.
##
## Features:
## - Fast lookups (O(1) average)
## - LRU eviction policy
## - Cache hit/miss statistics
## - Practical web API caching example
##
## Usage:
## ```bash
## nim c -r swiss_table_cache.nim
## ```

import std/[times, strformat, lists]
import ../src/arsenal/datastructures/hashtables/swiss_table

type
  CacheEntry*[V] = object
    value: V
    accessTime: float
    accessCount: int

  LRUCache*[K, V] = object
    table: SwissTable[K, CacheEntry[V]]
    maxSize: int
    hits: int
    misses: int
    evictions: int

proc init*[K, V](_: typedesc[LRUCache[K, V]], maxSize: int): LRUCache[K, V] =
  ## Create a new LRU cache with maximum size
  result.table = SwissTable[K, CacheEntry[V]].init(maxSize)
  result.maxSize = maxSize
  result.hits = 0
  result.misses = 0
  result.evictions = 0

proc get*[K, V](cache: var LRUCache[K, V], key: K): Option[V] =
  ## Get value from cache, updating access time
  let entryOpt = cache.table.find(key)

  if entryOpt.isSome:
    # Cache hit
    inc cache.hits
    var entry = entryOpt.get[]
    entry.accessTime = cpuTime()
    inc entry.accessCount
    cache.table[key] = entry  # Update entry
    return some(entry.value)
  else:
    # Cache miss
    inc cache.misses
    return none(V)

proc put*[K, V](cache: var LRUCache[K, V], key: K, value: V) =
  ## Put value in cache, evicting LRU entry if necessary

  # Check if we need to evict
  if cache.table.len >= cache.maxSize and not cache.table.contains(key):
    # Find LRU entry (oldest access time)
    var oldestKey: K
    var oldestTime = Inf

    for k, entry in cache.table.pairs:
      if entry.accessTime < oldestTime:
        oldestTime = entry.accessTime
        oldestKey = k

    # Evict oldest entry
    discard cache.table.delete(oldestKey)
    inc cache.evictions

  # Insert or update entry
  cache.table[key] = CacheEntry[V](
    value: value,
    accessTime: cpuTime(),
    accessCount: 1
  )

proc clear*[K, V](cache: var LRUCache[K, V]) =
  ## Clear all entries from cache
  cache.table.clear()
  cache.hits = 0
  cache.misses = 0
  cache.evictions = 0

proc len*[K, V](cache: LRUCache[K, V]): int =
  ## Get number of entries in cache
  cache.table.len

proc hitRate*[K, V](cache: LRUCache[K, V]): float =
  ## Calculate cache hit rate (0.0 - 1.0)
  let total = cache.hits + cache.misses
  if total == 0:
    return 0.0
  return float(cache.hits) / float(total)

proc stats*[K, V](cache: LRUCache[K, V]): string =
  ## Get cache statistics as string
  let total = cache.hits + cache.misses
  let hitPct = if total > 0: cache.hitRate() * 100.0 else: 0.0

  result = "Cache Statistics:\n"
  result &= &"  Entries:   {cache.len} / {cache.maxSize}\n"
  result &= &"  Hits:      {cache.hits}\n"
  result &= &"  Misses:    {cache.misses}\n"
  result &= &"  Hit Rate:  {hitPct:.1f}%\n"
  result &= &"  Evictions: {cache.evictions}"

# Example 1: Simple String Cache
proc exampleSimpleCache() =
  echo "Example 1: Simple String Cache"
  echo "==============================="
  echo ""

  var cache = LRUCache[string, string].init(maxSize = 3)

  # Add entries
  cache.put("user:1", "Alice")
  cache.put("user:2", "Bob")
  cache.put("user:3", "Charlie")
  echo "Added 3 users to cache (max size: 3)"
  echo ""

  # Cache hits
  echo "Looking up user:1..."
  let alice = cache.get("user:1")
  if alice.isSome:
    echo &"  Found: {alice.get()}"

  echo "Looking up user:2..."
  let bob = cache.get("user:2")
  if bob.isSome:
    echo &"  Found: {bob.get()}"
  echo ""

  # Cache miss
  echo "Looking up user:99 (not in cache)..."
  let missing = cache.get("user:99")
  if missing.isNone:
    echo "  Not found (cache miss)"
  echo ""

  # Trigger eviction
  echo "Adding user:4 (will evict LRU entry)..."
  cache.put("user:4", "David")
  echo ""

  # Check if user:3 was evicted (it was the LRU)
  echo "Looking up user:3 (should be evicted)..."
  let charlie = cache.get("user:3")
  if charlie.isNone:
    echo "  Not found (was evicted)"
  echo ""

  echo cache.stats()
  echo ""
  echo ""

# Example 2: Web API Response Cache
type
  ApiResponse = object
    statusCode: int
    body: string
    timestamp: float

proc exampleApiCache() =
  echo "Example 2: Web API Response Cache"
  echo "=================================="
  echo ""

  var cache = LRUCache[string, ApiResponse].init(maxSize = 100)

  proc fetchFromApi(endpoint: string): ApiResponse =
    ## Simulate API call (expensive)
    let delay = 0.1  # Simulate 100ms network latency
    let start = cpuTime()
    while cpuTime() - start < delay:
      discard  # Busy wait

    return ApiResponse(
      statusCode: 200,
      body: &"Response from {endpoint}",
      timestamp: cpuTime()
    )

  proc cachedFetch(cache: var LRUCache[string, ApiResponse], endpoint: string): ApiResponse =
    ## Fetch with caching
    let cached = cache.get(endpoint)
    if cached.isSome:
      return cached.get()

    # Cache miss - fetch from API
    let response = fetchFromApi(endpoint)
    cache.put(endpoint, response)
    return response

  # Simulate API requests
  echo "Making API requests with caching..."
  let endpoints = @["/users", "/posts", "/comments", "/users", "/posts", "/users"]

  let startTime = cpuTime()

  for endpoint in endpoints:
    let response = cache.cachedFetch(endpoint)
    echo &"  GET {endpoint} -> {response.statusCode} (cached: {cache.get(endpoint).isSome})"

  let elapsed = cpuTime() - startTime

  echo ""
  echo &"Total time: {elapsed * 1000:.1f} ms"
  echo &"Without cache: ~{endpoints.len.float * 100.0:.0f} ms"
  echo &"Speedup: {(endpoints.len.float * 0.1) / elapsed:.1f}x"
  echo ""
  echo cache.stats()
  echo ""
  echo ""

# Example 3: Computation Cache (Memoization)
proc fibonacci(n: int): int64 =
  ## Naive Fibonacci (exponential time)
  if n <= 1:
    return n.int64
  return fibonacci(n - 1) + fibonacci(n - 2)

proc fibonacciCached(n: int, cache: var LRUCache[int, int64]): int64 =
  ## Fibonacci with caching (linear time)
  if n <= 1:
    return n.int64

  let cached = cache.get(n)
  if cached.isSome:
    return cached.get()

  let result = fibonacciCached(n - 1, cache) + fibonacciCached(n - 2, cache)
  cache.put(n, result)
  return result

proc exampleMemoization() =
  echo "Example 3: Computation Memoization"
  echo "==================================="
  echo ""

  const N = 40

  # Without cache (slow)
  echo &"Computing fibonacci({N}) without cache..."
  let start1 = cpuTime()
  let result1 = fibonacci(N)
  let elapsed1 = cpuTime() - start1
  echo &"  Result: {result1}"
  echo &"  Time: {elapsed1 * 1000:.1f} ms"
  echo ""

  # With cache (fast)
  echo &"Computing fibonacci({N}) with cache..."
  var cache = LRUCache[int, int64].init(maxSize = 100)
  let start2 = cpuTime()
  let result2 = fibonacciCached(N, cache)
  let elapsed2 = cpuTime() - start2
  echo &"  Result: {result2}"
  echo &"  Time: {elapsed2 * 1000:.3f} ms"
  echo &"  Speedup: {elapsed1 / elapsed2:.0f}x"
  echo ""
  echo cache.stats()
  echo ""
  echo ""

# Example 4: Database Query Cache
type
  User = object
    id: int
    name: string
    email: string

proc exampleDatabaseCache() =
  echo "Example 4: Database Query Cache"
  echo "================================"
  echo ""

  var cache = LRUCache[int, User].init(maxSize = 1000)

  proc queryDatabase(userId: int): User =
    ## Simulate slow database query
    let delay = 0.05  # 50ms query time
    let start = cpuTime()
    while cpuTime() - start < delay:
      discard

    return User(
      id: userId,
      name: &"User{userId}",
      email: &"user{userId}@example.com"
    )

  proc getUser(cache: var LRUCache[int, User], userId: int): User =
    ## Get user with caching
    let cached = cache.get(userId)
    if cached.isSome:
      return cached.get()

    let user = queryDatabase(userId)
    cache.put(userId, user)
    return user

  # Simulate user queries (with repetition)
  echo "Simulating user lookups..."
  let userIds = @[1, 2, 3, 1, 2, 4, 1, 5, 2, 1]

  let startTime = cpuTime()

  for userId in userIds:
    let user = cache.getUser(userId)
    let wasCached = cache.hits > 0
    echo &"  Query user {userId}: {user.name} (cached: {wasCached})"

  let elapsed = cpuTime() - startTime

  echo ""
  echo &"Total time: {elapsed * 1000:.1f} ms"
  echo &"Without cache: ~{userIds.len.float * 50.0:.0f} ms"
  echo &"Speedup: {(userIds.len.float * 0.05) / elapsed:.1f}x"
  echo ""
  echo cache.stats()
  echo ""

# Main program
when isMainModule:
  echo "Arsenal Swiss Table Cache Examples"
  echo "===================================="
  echo ""
  echo ""

  exampleSimpleCache()
  exampleApiCache()
  exampleMemoization()
  exampleDatabaseCache()

  echo ""
  echo "Key Takeaways:"
  echo "=============="
  echo ""
  echo "1. Swiss Table provides O(1) average-case lookups"
  echo "2. LRU eviction keeps cache bounded"
  echo "3. Cache dramatically improves performance for repeated operations"
  echo "4. Hit rates > 50% typically justify caching overhead"
  echo "5. Choose cache size based on working set size"
  echo ""
  echo "Performance Tips:"
  echo "================="
  echo ""
  echo "- Cache expensive operations (I/O, computation, network)"
  echo "- Monitor hit rate (aim for > 70%)"
  echo "- Size cache appropriately (too small = low hit rate, too large = wasted memory)"
  echo "- Consider TTL (time-to-live) for stale data"
  echo "- Use Swiss Table for speed, consider memory overhead"
  echo ""
  echo "Real-World Use Cases:"
  echo "===================="
  echo ""
  echo "- Web API response caching"
  echo "- Database query results"
  echo "- Computed values (memoization)"
  echo "- File metadata lookups"
  echo "- DNS resolution results"
  echo "- Configuration lookups"
  echo "- Session data"
  echo "- User preferences"
  echo ""

## Advanced: TTL Cache
## ===================
##
## Add time-to-live to cache entries:
##
## ```nim
## type
##   TTLCacheEntry[V] = object
##     value: V
##     insertTime: float
##     ttl: float
##
##   TTLCache[K, V] = object
##     table: SwissTable[K, TTLCacheEntry[V]]
##     defaultTTL: float
##
## proc get*[K, V](cache: var TTLCache[K, V], key: K): Option[V] =
##   let entryOpt = cache.table.find(key)
##   if entryOpt.isNone:
##     return none(V)
##
##   let entry = entryOpt.get[]
##   let age = cpuTime() - entry.insertTime
##
##   if age > entry.ttl:
##     # Expired - delete and return None
##     discard cache.table.delete(key)
##     return none(V)
##
##   return some(entry.value)
## ```
##
## Advanced: Write-Through Cache
## ==============================
##
## Cache that updates both cache and backing store:
##
## ```nim
## proc set*[K, V](cache: var LRUCache[K, V], key: K, value: V) =
##   # Write to backing store
##   database.update(key, value)
##
##   # Update cache
##   cache.put(key, value)
## ```
##
## Advanced: Multi-Level Cache
## ============================
##
## L1 (small, fast) -> L2 (large, slower) hierarchy:
##
## ```nim
## proc get*[K, V](l1: var LRUCache[K, V], l2: var LRUCache[K, V], key: K): Option[V] =
##   # Try L1 first
##   let l1Result = l1.get(key)
##   if l1Result.isSome:
##     return l1Result
##
##   # Try L2
##   let l2Result = l2.get(key)
##   if l2Result.isSome:
##     # Promote to L1
##     l1.put(key, l2Result.get())
##     return l2Result
##
##   return none(V)
## ```
##
## Performance Characteristics
## ===========================
##
## Swiss Table Lookups:
## - Average: O(1), ~10-30 ns
## - Worst: O(n), rare with good hash
##
## LRU Eviction:
## - Current: O(n) full scan
## - Optimized: O(1) with doubly-linked list
##
## Memory Overhead:
## - Swiss Table: ~17 bytes per entry (ctrl + key + value)
## - LRU metadata: +16 bytes per entry (time + count)
## - Total: ~33 bytes + sizeof(K) + sizeof(V)
##
## Cache Hit Savings:
## - Database query: 10-100 ms saved
## - API call: 50-500 ms saved
## - Computation: varies (can be huge)
##
## When NOT to Cache:
## - Data changes frequently
## - Low hit rate (< 30%)
## - Memory constrained
## - Cold data (accessed once)
