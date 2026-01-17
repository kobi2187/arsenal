## Arsenal Sketching - Unified High-Level API
## ===========================================
##
## This module provides a consistent, ergonomic API for all sketching
## data structures. It wraps the underlying implementations without
## modifying them.
##
## You can use either:
## - This high-level API (consistent, discoverable)
## - Direct implementation modules (full control, all features)
##
## Usage:
## ```nim
## import arsenal/sketching
##
## # Cardinality estimation
## var unique = Cardinality.new(precision = 14)
## unique.add("user_123")
## echo unique.count()  # Estimated unique count
##
## # Quantile estimation
## var latency = Quantiles.new(compression = 100)
## latency.add(42.5)
## echo latency.p95()  # 95th percentile
## ```

import arsenal/sketching/cardinality/hyperloglog
import arsenal/sketching/quantiles/tdigest

export hyperloglog, tdigest  # Re-export for direct use if needed

# =============================================================================
# CARDINALITY ESTIMATION - Unified API for unique counting
# =============================================================================

type
  Cardinality* = object
    ## High-level API for cardinality estimation (unique counting)
    ##
    ## Wraps: HyperLogLog
    impl: HyperLogLog

  CardinalityBuilder* = object
    precision: int

# Constructors
proc new*(_: typedesc[Cardinality], precision: int = 14): CardinalityBuilder =
  ## Create cardinality estimator
  ##
  ## Parameters:
  ## - precision: Controls accuracy (4-18, default 14 = ~0.8% error)
  ##
  ## Example:
  ## ```nim
  ## var unique = Cardinality.new(precision = 14)
  ## ```
  CardinalityBuilder(precision: precision)

proc build*(builder: CardinalityBuilder): Cardinality =
  ## Build cardinality estimator from builder
  Cardinality(impl: initHyperLogLog(builder.precision))

proc init*(_: typedesc[Cardinality], precision: int = 14): Cardinality {.inline.} =
  ## Direct construction (no builder)
  Cardinality.new(precision).build()

# Presets
proc fast*(_: typedesc[Cardinality]): Cardinality {.inline.} =
  ## Fast preset: lower accuracy, less memory (precision = 10)
  Cardinality.new(10).build()

proc balanced*(_: typedesc[Cardinality]): Cardinality {.inline.} =
  ## Balanced preset: good accuracy/memory (precision = 14, ~0.8% error)
  Cardinality.new(14).build()

proc accurate*(_: typedesc[Cardinality]): Cardinality {.inline.} =
  ## Accurate preset: high accuracy, more memory (precision = 16, ~0.4% error)
  Cardinality.new(16).build()

# Operations
proc add*(c: var Cardinality, value: string) {.inline.} =
  ## Add element to sketch
  c.impl.add(value)

proc add*[T](c: var Cardinality, value: T) {.inline.} =
  ## Add any hashable element
  c.impl.add(value)

proc count*(c: Cardinality): int64 {.inline.} =
  ## Get estimated unique count (primary method)
  c.impl.cardinality()

proc estimate*(c: Cardinality): int64 {.inline.} =
  ## Alias for count()
  c.count()

proc len*(c: Cardinality): int64 {.inline.} =
  ## Nim-style length (alias for count)
  c.count()

proc merge*(c: var Cardinality, other: Cardinality) {.inline.} =
  ## Merge another cardinality estimator
  c.impl.merge(other.impl)

proc clear*(c: var Cardinality) {.inline.} =
  ## Reset to empty
  c.impl.clear()

# Metadata
proc memoryUsage*(c: Cardinality): int {.inline.} =
  ## Memory usage in bytes
  c.impl.memoryUsage()

proc expectedError*(c: Cardinality): float64 {.inline.} =
  ## Expected relative error (e.g., 0.008 = 0.8%)
  c.impl.expectedError()

# Serialization
proc toBytes*(c: Cardinality): seq[byte] {.inline.} =
  ## Serialize to bytes
  c.impl.toBytes()

proc fromBytes*(_: typedesc[Cardinality], data: openArray[byte]): Cardinality =
  ## Deserialize from bytes
  Cardinality(impl: hyperloglog.fromBytes(data))

proc `$`*(c: Cardinality): string =
  ## String representation
  "Cardinality(count~" & $c.count() & ", memory=" & $c.memoryUsage() & "B, error~" &
    $(c.expectedError() * 100.0) & "%)"

# =============================================================================
# QUANTILE ESTIMATION - Unified API for percentiles
# =============================================================================

type
  Quantiles* = object
    ## High-level API for quantile estimation (percentiles)
    ##
    ## Wraps: t-Digest
    impl: TDigest

  QuantilesBuilder* = object
    compression: float64

# Constructors
proc new*(_: typedesc[Quantiles], compression: float64 = 100.0): QuantilesBuilder =
  ## Create quantile estimator
  ##
  ## Parameters:
  ## - compression: Controls accuracy (default 100 = ~0.8% error)
  ##
  ## Example:
  ## ```nim
  ## var latency = Quantiles.new(compression = 100)
  ## ```
  QuantilesBuilder(compression: compression)

proc build*(builder: QuantilesBuilder): Quantiles =
  ## Build quantile estimator from builder
  Quantiles(impl: initTDigest(builder.compression))

proc init*(_: typedesc[Quantiles], compression: float64 = 100.0): Quantiles {.inline.} =
  ## Direct construction (no builder)
  Quantiles.new(compression).build()

# Presets
proc fast*(_: typedesc[Quantiles]): Quantiles {.inline.} =
  ## Fast preset: lower accuracy (compression = 50)
  Quantiles.new(50).build()

proc balanced*(_: typedesc[Quantiles]): Quantiles {.inline.} =
  ## Balanced preset: good accuracy (compression = 100)
  Quantiles.new(100).build()

proc accurate*(_: typedesc[Quantiles]): Quantiles {.inline.} =
  ## Accurate preset: high accuracy (compression = 200)
  Quantiles.new(200).build()

# Operations
proc add*(q: var Quantiles, value: float64, weight: float64 = 1.0) {.inline.} =
  ## Add value to sketch
  q.impl.add(value, weight)

proc addMany*(q: var Quantiles, values: openArray[float64]) {.inline.} =
  ## Add multiple values
  q.impl.addMany(values)

proc percentile*(q: var Quantiles, p: float64): float64 {.inline.} =
  ## Get percentile (0-100)
  ##
  ## Example: percentile(95) = 95th percentile
  q.impl.quantile(p / 100.0)

proc quantile*(q: var Quantiles, q_val: float64): float64 {.inline.} =
  ## Get quantile (0.0-1.0)
  ##
  ## Example: quantile(0.95) = 95th percentile
  q.impl.quantile(q_val)

# Common percentiles (convenience)
proc median*(q: var Quantiles): float64 {.inline.} =
  ## Median (50th percentile)
  q.percentile(50)

proc p50*(q: var Quantiles): float64 {.inline.} =
  ## 50th percentile (alias for median)
  q.percentile(50)

proc p90*(q: var Quantiles): float64 {.inline.} =
  ## 90th percentile
  q.percentile(90)

proc p95*(q: var Quantiles): float64 {.inline.} =
  ## 95th percentile
  q.percentile(95)

proc p99*(q: var Quantiles): float64 {.inline.} =
  ## 99th percentile
  q.percentile(99)

proc p999*(q: var Quantiles): float64 {.inline.} =
  ## 99.9th percentile
  q.percentile(99.9)

proc cdf*(q: var Quantiles, value: float64): float64 {.inline.} =
  ## Cumulative distribution function at value
  q.impl.cdf(value)

proc merge*(q: var Quantiles, other: Quantiles) {.inline.} =
  ## Merge another quantile estimator
  q.impl.merge(other.impl)

proc clear*(q: var Quantiles) {.inline.} =
  ## Reset to empty
  q.impl.clear()

# Metadata
proc count*(q: Quantiles): int {.inline.} =
  ## Number of values added
  q.impl.count()

proc len*(q: Quantiles): int {.inline.} =
  ## Nim-style length (alias for count)
  q.count()

proc memoryUsage*(q: Quantiles): int {.inline.} =
  ## Memory usage in bytes
  q.impl.memoryUsage()

proc min*(q: Quantiles): float64 {.inline.} =
  ## Minimum value seen
  q.impl.min

proc max*(q: Quantiles): float64 {.inline.} =
  ## Maximum value seen
  q.impl.max

# Serialization
proc toBytes*(q: Quantiles): seq[byte] {.inline.} =
  ## Serialize to bytes
  q.impl.toBytes()

proc fromBytes*(_: typedesc[Quantiles], data: openArray[byte]): Quantiles =
  ## Deserialize from bytes
  Quantiles(impl: tdigest.fromBytes(data))

proc `$`*(q: Quantiles): string =
  ## String representation
  "Quantiles(count=" & $q.count() & ", memory=" & $q.memoryUsage() & "B)"

# =============================================================================
# CONVENIENCE CONSTRUCTORS (optional syntactic sugar)
# =============================================================================

template newCardinality*(precision: int = 14): Cardinality =
  ## Convenience constructor
  Cardinality.new(precision).build()

template newQuantiles*(compression: float64 = 100.0): Quantiles =
  ## Convenience constructor
  Quantiles.new(compression).build()

# =============================================================================
# EXAMPLE USAGE
# =============================================================================

when isMainModule:
  import std/[random, strformat]

  echo "Arsenal Sketching - Unified API Demo"
  echo "===================================="
  echo ""

  # Cardinality estimation
  echo "1. Cardinality Estimation"
  echo "-------------------------"

  var unique = Cardinality.balanced()

  for i in 0..<10_000:
    unique.add("user_" & $i)

  echo "Added 10,000 unique users"
  echo "Estimated count: ", unique.count()
  echo "Memory usage: ", unique.memoryUsage(), " bytes"
  echo "Expected error: ", (unique.expectedError() * 100).formatFloat(ffDecimal, 2), "%"
  echo ""

  # Quantile estimation
  echo "2. Quantile Estimation"
  echo "----------------------"

  var latency = Quantiles.balanced()

  randomize(42)
  for i in 0..<10_000:
    latency.add(gauss(100.0, 20.0))

  echo "Added 10,000 latency measurements"
  echo "Count: ", latency.count()
  echo "Min: ", latency.min().formatFloat(ffDecimal, 2)
  echo "Median: ", latency.median().formatFloat(ffDecimal, 2)
  echo "P95: ", latency.p95().formatFloat(ffDecimal, 2)
  echo "P99: ", latency.p99().formatFloat(ffDecimal, 2)
  echo "Max: ", latency.max().formatFloat(ffDecimal, 2)
  echo ""

  # Presets comparison
  echo "3. Presets Comparison"
  echo "--------------------"

  var fast = Cardinality.fast()
  var balanced = Cardinality.balanced()
  var accurate = Cardinality.accurate()

  for i in 0..<10_000:
    fast.add(i)
    balanced.add(i)
    accurate.add(i)

  echo "True count: 10,000"
  echo "Fast:     ", fast.count(), " (", fast.memoryUsage(), " bytes, ",
       (fast.expectedError() * 100).formatFloat(ffDecimal, 2), "% error)"
  echo "Balanced: ", balanced.count(), " (", balanced.memoryUsage(), " bytes, ",
       (balanced.expectedError() * 100).formatFloat(ffDecimal, 2), "% error)"
  echo "Accurate: ", accurate.count(), " (", accurate.memoryUsage(), " bytes, ",
       (accurate.expectedError() * 100).formatFloat(ffDecimal, 2), "% error)"
  echo ""

  # Serialization
  echo "4. Serialization"
  echo "---------------"

  let bytes = unique.toBytes()
  let restored = Cardinality.fromBytes(bytes)

  echo "Serialized size: ", bytes.len, " bytes"
  echo "Restored count: ", restored.count()
  echo ""

  echo "All demos completed!"
