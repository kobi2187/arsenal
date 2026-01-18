## Arsenal Filters - Unified High-Level API
## ==========================================
##
## This module provides a consistent, ergonomic API for all membership
## testing filters. It wraps the underlying implementations without
## modifying them.
##
## You can use either:
## - This high-level API (consistent, discoverable)
## - Direct implementation modules (full control, all features)
##
## Usage:
## ```nim
## import arsenal/filters
##
## # Create filter from keys
## let keys = ["alice", "bob", "charlie"]
## let filter = MembershipFilter.from(keys)
##
## # Test membership
## echo filter.contains("alice")  # true
## echo filter.contains("dave")   # false (or rare false positive)
##
## # Check statistics
## echo filter.falsePositiveRate()  # ~0.39%
## echo filter.memoryUsage()        # bytes used
## ```

import arsenal/sketching/membership/xorfilter

export xorfilter  # Re-export for direct use if needed

# =============================================================================
# MEMBERSHIP FILTER - Unified API for approximate set membership
# =============================================================================

type
  MembershipFilter* = object
    ## High-level API for membership testing (approximate set)
    ##
    ## Wraps: XorFilter8 (8-bit fingerprints, ~0.39% false positive rate)
    ##
    ## Properties:
    ## - No false negatives: if contains() == false, element definitely not in set
    ## - May have false positives: if contains() == true, element *probably* in set
    ## - Static: cannot add/remove after construction
    impl: XorFilter8

  MembershipFilterBuilder* = object
    keys: seq[string]
    maxAttempts: int

  MembershipFilter16* = object
    ## High-precision filter with 16-bit fingerprints (~0.0015% FP rate)
    impl: XorFilter16

# =============================================================================
# 8-BIT FILTER (Standard)
# =============================================================================

# Constructors
proc new*(_: typedesc[MembershipFilter]): MembershipFilterBuilder =
  ## Create membership filter builder
  ##
  ## Example:
  ## ```nim
  ## let filter = MembershipFilter.new()
  ##   .withKeys(["alice", "bob"])
  ##   .build()
  ## ```
  MembershipFilterBuilder(keys: newSeq[string](), maxAttempts: 100)

proc withKeys*(builder: MembershipFilterBuilder, keys: openArray[string]): MembershipFilterBuilder =
  ## Set keys to include in filter
  result = builder
  result.keys = @keys

proc withMaxAttempts*(builder: MembershipFilterBuilder, attempts: int): MembershipFilterBuilder =
  ## Set maximum construction attempts (default 100)
  result = builder
  result.maxAttempts = attempts

proc build*(builder: MembershipFilterBuilder): MembershipFilter =
  ## Build filter from builder
  MembershipFilter(impl: buildXorFilter8(builder.keys, builder.maxAttempts))

proc from*(_: typedesc[MembershipFilter], keys: openArray[string],
           maxAttempts: int = 100): MembershipFilter =
  ## Direct construction from keys (most common usage)
  ##
  ## Example:
  ## ```nim
  ## let filter = MembershipFilter.from(["alice", "bob", "charlie"])
  ## ```
  MembershipFilter(impl: buildXorFilter8(keys, maxAttempts))

proc from*[T](_: typedesc[MembershipFilter], keys: openArray[T],
              maxAttempts: int = 100): MembershipFilter =
  ## Direct construction from hashable keys
  MembershipFilter(impl: buildXorFilter8(keys, maxAttempts))

# Query operations
proc contains*(filter: MembershipFilter, key: string): bool {.inline.} =
  ## Test if key is in set (may have false positives)
  filter.impl.contains(key)

proc contains*[T](filter: MembershipFilter, key: T): bool {.inline.} =
  ## Test if hashable key is in set
  filter.impl.contains(key)

proc mightContain*(filter: MembershipFilter, key: string): bool {.inline.} =
  ## Alias for contains() that emphasizes probabilistic nature
  filter.contains(key)

proc has*(filter: MembershipFilter, key: string): bool {.inline.} =
  ## Alias for contains()
  filter.contains(key)

# Metadata
proc len*(filter: MembershipFilter): int {.inline.} =
  ## Number of keys in filter (estimated)
  filter.impl.size()

proc size*(filter: MembershipFilter): int {.inline.} =
  ## Alias for len()
  filter.len()

proc memoryUsage*(filter: MembershipFilter): int {.inline.} =
  ## Memory usage in bytes
  filter.impl.memoryUsage()

proc bitsPerKey*(filter: MembershipFilter): float64 {.inline.} =
  ## Space efficiency (bits per key)
  filter.impl.bitsPerKey()

proc falsePositiveRate*(filter: MembershipFilter): float64 {.inline.} =
  ## Expected false positive rate (e.g., 0.0039 = 0.39%)
  filter.impl.falsePositiveRate()

proc accuracy*(filter: MembershipFilter): float64 {.inline.} =
  ## Accuracy (1 - false positive rate)
  1.0 - filter.falsePositiveRate()

# Serialization
proc toBytes*(filter: MembershipFilter): seq[byte] {.inline.} =
  ## Serialize to bytes
  # Note: XorFilter8 doesn't have toBytes, would need to add wrapper
  raise newException(CatchableError, "Serialization not yet implemented for XorFilter8")

proc `$`*(filter: MembershipFilter): string =
  ## String representation
  "MembershipFilter(size=" & $filter.size() &
    ", memory=" & $filter.memoryUsage() & "B" &
    ", bits/key=" & $filter.bitsPerKey().formatFloat(ffDecimal, 2) &
    ", FP=" & $(filter.falsePositiveRate() * 100) & "%)"

# =============================================================================
# 16-BIT FILTER (High Precision)
# =============================================================================

# Constructors
proc new*(_: typedesc[MembershipFilter16]): MembershipFilterBuilder =
  ## Create high-precision membership filter builder
  MembershipFilterBuilder(keys: newSeq[string](), maxAttempts: 100)

proc from*(_: typedesc[MembershipFilter16], keys: openArray[string],
           maxAttempts: int = 100): MembershipFilter16 =
  ## Direct construction from keys (high precision, ~0.0015% FP rate)
  ##
  ## Example:
  ## ```nim
  ## let filter = MembershipFilter16.from(["alice", "bob"])
  ## ```
  MembershipFilter16(impl: buildXorFilter16(keys, maxAttempts))

# Query operations
proc contains*(filter: MembershipFilter16, key: string): bool {.inline.} =
  ## Test if key is in set
  filter.impl.contains(key)

proc mightContain*(filter: MembershipFilter16, key: string): bool {.inline.} =
  ## Alias for contains()
  filter.contains(key)

# Metadata
proc len*(filter: MembershipFilter16): int {.inline.} =
  ## Number of keys in filter
  filter.impl.size()

proc memoryUsage*(filter: MembershipFilter16): int {.inline.} =
  ## Memory usage in bytes
  filter.impl.memoryUsage()

proc bitsPerKey*(filter: MembershipFilter16): float64 {.inline.} =
  ## Space efficiency
  filter.impl.bitsPerKey()

proc falsePositiveRate*(filter: MembershipFilter16): float64 {.inline.} =
  ## Expected false positive rate
  filter.impl.falsePositiveRate()

proc `$`*(filter: MembershipFilter16): string =
  "MembershipFilter16(size=" & $filter.size() &
    ", memory=" & $filter.memoryUsage() & "B" &
    ", FP=" & $(filter.falsePositiveRate() * 100) & "%)"

# =============================================================================
# CONVENIENCE CONSTRUCTORS
# =============================================================================

template newFilter*(keys: openArray[string]): MembershipFilter =
  ## Quick constructor
  MembershipFilter.from(keys)

template newFilter*[T](keys: openArray[T]): MembershipFilter =
  ## Quick constructor for hashable keys
  MembershipFilter.from(keys)

# =============================================================================
# EXAMPLE USAGE
# =============================================================================

when isMainModule:
  import std/[random, strformat, sets]

  echo "Arsenal Filters - Unified API Demo"
  echo "==================================="
  echo ""

  # Basic membership testing
  echo "1. Basic Membership Testing"
  echo "---------------------------"

  let usernames = ["alice", "bob", "charlie", "david", "eve"]
  let filter = MembershipFilter.from(usernames)

  echo "Created filter with ", usernames.len, " users"
  echo ""

  echo "Membership tests:"
  for name in ["alice", "frank", "charlie", "zara"]:
    let result = filter.contains(name)
    echo "  ", name, ": ", result

  echo ""
  echo "Filter stats:"
  echo "  Size: ", filter.size(), " keys"
  echo "  Memory: ", filter.memoryUsage(), " bytes"
  echo "  Bits/key: ", filter.bitsPerKey().formatFloat(ffDecimal, 2)
  echo "  False positive rate: ", (filter.falsePositiveRate() * 100).formatFloat(ffDecimal, 3), "%"
  echo ""

  # False positive rate measurement
  echo "2. False Positive Rate Measurement"
  echo "----------------------------------"

  # Create filter with 1000 keys
  var keys1000 = newSeq[string](1000)
  for i in 0..<1000:
    keys1000[i] = "key_" & $i

  let filter1000 = MembershipFilter.from(keys1000)

  # Test with 10000 non-members
  var falsePositives = 0
  for i in 1000..<11000:
    let testKey = "key_" & $i
    if filter1000.contains(testKey):
      inc falsePositives

  let measuredFP = falsePositives.float64 / 10000.0

  echo "Created filter with 1000 keys"
  echo "Tested 10,000 non-members"
  echo "False positives: ", falsePositives
  echo "Measured FP rate: ", (measuredFP * 100).formatFloat(ffDecimal, 3), "%"
  echo "Expected FP rate: ", (filter1000.falsePositiveRate() * 100).formatFloat(ffDecimal, 3), "%"
  echo ""

  # Compare 8-bit vs 16-bit
  echo "3. Compare 8-bit vs 16-bit Filters"
  echo "----------------------------------"

  let keys100 = (0..<100).mapIt("item_" & $it)

  let filter8 = MembershipFilter.from(keys100)
  let filter16 = MembershipFilter16.from(keys100)

  echo "Filter8 (standard):"
  echo "  Memory: ", filter8.memoryUsage(), " bytes"
  echo "  Bits/key: ", filter8.bitsPerKey().formatFloat(ffDecimal, 2)
  echo "  FP rate: ", (filter8.falsePositiveRate() * 100).formatFloat(ffDecimal, 4), "%"
  echo ""

  echo "Filter16 (high precision):"
  echo "  Memory: ", filter16.memoryUsage(), " bytes"
  echo "  Bits/key: ", filter16.bitsPerKey().formatFloat(ffDecimal, 2)
  echo "  FP rate: ", (filter16.falsePositiveRate() * 100).formatFloat(ffDecimal, 4), "%"
  echo ""

  # Performance vs HashSet
  echo "4. Performance vs HashSet"
  echo "------------------------"

  let numKeys = 10_000
  var largeKeys = newSeq[string](numKeys)
  for i in 0..<numKeys:
    largeKeys[i] = "user_" & $i

  # Create both filter and hashset
  let largeFilter = MembershipFilter.from(largeKeys)
  let largeSet = largeKeys.toHashSet()

  echo "Both structures contain ", numKeys, " keys"
  echo ""

  echo "MembershipFilter:"
  echo "  Memory: ", (largeFilter.memoryUsage().float64 / 1024.0).formatFloat(ffDecimal, 2), " KB"
  echo "  Accuracy: ", (largeFilter.accuracy() * 100).formatFloat(ffDecimal, 2), "%"
  echo ""

  echo "HashSet:"
  # Rough estimate: HashSet uses ~32 bytes per entry (key + hash + overhead)
  let hashsetMem = numKeys * 32
  echo "  Memory: ~", (hashsetMem.float64 / 1024.0).formatFloat(ffDecimal, 2), " KB"
  echo "  Accuracy: 100%"
  echo ""

  let memSavings = (1.0 - largeFilter.memoryUsage().float64 / hashsetMem.float64) * 100.0
  echo "Memory savings: ~", memSavings.formatFloat(ffDecimal, 1), "%"
  echo "(Trade-off: ", (largeFilter.falsePositiveRate() * 100).formatFloat(ffDecimal, 2),
       "% false positives)"
  echo ""

  echo "All demos completed!"
