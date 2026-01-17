## t-Digest Quantile Estimation
## =============================
##
## Online algorithm for accurate quantile estimation using compact sketch.
## Particularly accurate at extreme quantiles (tail distributions).
##
## Paper: "Computing Extremely Accurate Quantiles Using t-Digests"
##        Dunning & Ertl (2019)
##        Software: Practice and Experience
##        arXiv:1902.04023
##        https://arxiv.org/abs/1902.04023
##
## Original: Ted Dunning (2013)
##        https://github.com/tdunning/t-digest
##
## Key Innovation:
## - **Adaptive clustering**: Uses k-means-like clustering with size constraints
## - **Scale functions**: Non-linear mapping for better tail accuracy
## - **Mergeable**: Can merge multiple t-digests for distributed computing
## - **Compact**: ~100-1000 centroids for billions of values
##
## Performance:
## - **Accuracy**: <0.1% error for extreme quantiles (p0.001, p0.999)
## - **Space**: O(1/δ) where δ is compression parameter (~100-1000 centroids)
## - **Time**: O(1) per insertion (amortized)
##
## Applications:
## - Percentile monitoring (P50, P95, P99, P999)
## - Service Level Objectives (SLO) tracking
## - Anomaly detection (tail behavior)
## - Distributed quantile estimation (Apache Spark, Redis)
##
## Usage:
## ```nim
## import arsenal/sketching/quantiles/tdigest
##
## # Create t-digest with compression factor 100
## var td = initTDigest(100)
##
## # Add values
## for value in data:
##   td.add(value)
##
## # Query quantiles
## echo "Median: ", td.quantile(0.5)
## echo "P95: ", td.quantile(0.95)
## echo "P99: ", td.quantile(0.99)
## ```

import std/[algorithm, math]

# =============================================================================
# Types
# =============================================================================

type
  Centroid* = object
    ## Cluster centroid: represents multiple values
    mean*: float64    ## Mean value of cluster
    weight*: float64  ## Number of values in cluster

  TDigest* = object
    ## t-Digest sketch for quantile estimation
    compression*: float64      ## Compression parameter (controls accuracy/size trade-off)
    centroids*: seq[Centroid]  ## Sorted centroids (by mean)
    totalWeight*: float64      ## Total number of values added
    min*: float64              ## Minimum value seen
    max*: float64              ## Maximum value seen
    unmerged*: seq[Centroid]   ## Buffer for new centroids (before compression)

  ScaleFunction* = enum
    ## Scale function for controlling centroid sizes
    K0  ## k₀(q) = δ/2 * q - Linear (uniform accuracy)
    K1  ## k₁(q) = δ/(2π) * asin(2q-1) - Asin (better tails)
    K2  ## k₂(q) = δ/(Z(δ)) * log(q/(1-q)) - Log (best tails)
    K3  ## k₃(q) = δ/4 * log(2q/(1-q)) if q < 0.5 else δ/4 * log(2(1-q)/q)

# =============================================================================
# Scale Functions
# =============================================================================

proc k0(q: float64, compression: float64): float64 {.inline.} =
  ## Linear scale function: k₀(q) = δ/2 * q
  ## Uniform accuracy across all quantiles
  compression / 2.0 * q

proc k1(q: float64, compression: float64): float64 {.inline.} =
  ## Asin scale function: k₁(q) = δ/(2π) * asin(2q-1)
  ## Better accuracy at tails than k₀
  compression / (2.0 * PI) * arcsin(2.0 * q - 1.0)

proc k2(q: float64, compression: float64): float64 =
  ## Log scale function: k₂(q) = δ/Z(δ) * log(q/(1-q))
  ## Best tail accuracy (default)
  ##
  ## Uses logistic sigmoid transformation
  if q < 0.0001:
    return 0.0
  if q > 0.9999:
    return compression

  # Normalization factor Z(δ) ≈ 2 for large δ
  let z = 2.0
  compression / z * ln(q / (1.0 - q))

proc k3(q: float64, compression: float64): float64 =
  ## Improved log scale: k₃(q)
  ## Symmetric version of k₂
  if q < 0.5:
    compression / 4.0 * ln(2.0 * q / (1.0 - q))
  else:
    compression - compression / 4.0 * ln(2.0 * (1.0 - q) / q)

proc scaleFunction(sf: ScaleFunction, q: float64, compression: float64): float64 =
  ## Apply scale function
  case sf
  of K0: k0(q, compression)
  of K1: k1(q, compression)
  of K2: k2(q, compression)
  of K3: k3(q, compression)

# =============================================================================
# Construction
# =============================================================================

proc initTDigest*(compression: float64 = 100.0, scaleFunc: ScaleFunction = K2): TDigest =
  ## Create new t-digest
  ##
  ## Parameters:
  ## - compression: Controls accuracy vs size trade-off
  ##   - Higher = more accurate, more memory
  ##   - Typical: 100-1000
  ##   - Default: 100 (good balance)
  ## - scaleFunc: Scale function for centroid size control
  ##   - K0: Linear (uniform accuracy)
  ##   - K1: Asin (better tails)
  ##   - K2: Log (best tails, default)
  ##   - K3: Improved log
  TDigest(
    compression: compression,
    centroids: newSeq[Centroid](),
    totalWeight: 0.0,
    min: Inf,
    max: -Inf,
    unmerged: newSeq[Centroid]()
  )

proc clear*(td: var TDigest) =
  ## Reset t-digest to empty state
  td.centroids.setLen(0)
  td.unmerged.setLen(0)
  td.totalWeight = 0.0
  td.min = Inf
  td.max = -Inf

# =============================================================================
# Merging/Compression
# =============================================================================

proc compress*(td: var TDigest, scaleFunc: ScaleFunction = K2) =
  ## Compress unmerged centroids into main centroid list
  ##
  ## Uses 1D k-means-like clustering with size constraints
  ## from scale function
  if td.unmerged.len == 0:
    return

  # Combine centroids and sort by mean
  var allCentroids = td.centroids & td.unmerged
  allCentroids.sort(proc(a, b: Centroid): int = cmp(a.mean, b.mean))

  td.centroids.setLen(0)
  td.unmerged.setLen(0)

  if allCentroids.len == 0:
    return

  # Merge centroids using scale function constraints
  var
    currentCentroid = allCentroids[0]
    weightSoFar = 0.0

  for i in 1..<allCentroids.len:
    let c = allCentroids[i]

    # Compute quantile for current position
    let q = (weightSoFar + currentCentroid.weight / 2.0) / td.totalWeight

    # Compute k-scale limits for this quantile
    let k = scaleFunction(scaleFunc, q, td.compression)
    let qNext = (weightSoFar + currentCentroid.weight + c.weight / 2.0) / td.totalWeight
    let kNext = scaleFunction(scaleFunc, qNext, td.compression)

    # Check if we can merge (size constraint from scale function)
    let maxWeight = td.totalWeight * (kNext - k) / td.compression

    if currentCentroid.weight + c.weight <= maxWeight:
      # Merge centroids (weighted average)
      let totalWeight = currentCentroid.weight + c.weight
      currentCentroid.mean = (currentCentroid.mean * currentCentroid.weight +
                              c.mean * c.weight) / totalWeight
      currentCentroid.weight = totalWeight
    else:
      # Can't merge, save current and start new
      td.centroids.add(currentCentroid)
      weightSoFar += currentCentroid.weight
      currentCentroid = c

  # Add final centroid
  td.centroids.add(currentCentroid)

# =============================================================================
# Adding Values
# =============================================================================

proc add*(td: var TDigest, value: float64, weight: float64 = 1.0) =
  ## Add value to t-digest
  ##
  ## Time: O(1) amortized
  if value.classify == fcNan or value.classify == fcInf or value.classify == fcNegInf:
    return  # Ignore invalid values

  # Update min/max
  td.min = min(td.min, value)
  td.max = max(td.max, value)

  # Add to unmerged buffer
  td.unmerged.add(Centroid(mean: value, weight: weight))
  td.totalWeight += weight

  # Compress if buffer is too large
  if td.unmerged.len >= td.compression.int:
    td.compress()

proc addMany*(td: var TDigest, values: openArray[float64]) =
  ## Add multiple values
  for value in values:
    td.add(value)

# =============================================================================
# Quantile Queries
# =============================================================================

proc quantile*(td: var TDigest, q: float64): float64 =
  ## Estimate quantile q ∈ [0, 1]
  ##
  ## Examples:
  ## - q=0.5: median
  ## - q=0.95: 95th percentile
  ## - q=0.99: 99th percentile
  ##
  ## Time: O(log k) where k = number of centroids
  if q < 0.0 or q > 1.0:
    raise newException(ValueError, "Quantile must be in [0, 1]")

  # Compress pending values
  if td.unmerged.len > 0:
    td.compress()

  if td.centroids.len == 0:
    return NaN

  # Handle edge cases
  if q == 0.0 or td.centroids.len == 1:
    return td.min
  if q == 1.0:
    return td.max

  # Find quantile by interpolating between centroids
  let targetWeight = q * td.totalWeight

  var weightSoFar = 0.0

  for i in 0..<td.centroids.len:
    let c = td.centroids[i]
    let weightAtCentroid = weightSoFar + c.weight / 2.0

    if weightAtCentroid >= targetWeight:
      # Interpolate between previous and current centroid
      if i == 0:
        return td.min

      let prevCentroid = td.centroids[i - 1]
      let prevWeight = weightSoFar - prevCentroid.weight / 2.0
      let currWeight = weightSoFar + c.weight / 2.0

      # Linear interpolation
      let t = (targetWeight - prevWeight) / (currWeight - prevWeight)
      return prevCentroid.mean + t * (c.mean - prevCentroid.mean)

    weightSoFar += c.weight

  # Beyond last centroid
  return td.max

proc cdf*(td: var TDigest, value: float64): float64 =
  ## Estimate cumulative distribution function at value
  ##
  ## Returns P(X ≤ value) where X ~ distribution of added values
  if td.unmerged.len > 0:
    td.compress()

  if td.centroids.len == 0:
    return NaN

  if value < td.min:
    return 0.0
  if value > td.max:
    return 1.0

  # Interpolate between centroids to find cumulative weight
  var weightSoFar = 0.0

  for i in 0..<td.centroids.len:
    let c = td.centroids[i]

    if value < c.mean:
      # Interpolate between previous and current
      if i == 0:
        return 0.0

      let prevCentroid = td.centroids[i - 1]
      let t = (value - prevCentroid.mean) / (c.mean - prevCentroid.mean)
      let w = weightSoFar - prevCentroid.weight / 2.0 + t * (c.weight / 2.0 + prevCentroid.weight / 2.0)
      return w / td.totalWeight

    weightSoFar += c.weight

  return 1.0

# =============================================================================
# Merging t-Digests
# =============================================================================

proc merge*(td1: var TDigest, td2: TDigest) =
  ## Merge another t-digest into this one
  ##
  ## Useful for distributed quantile estimation:
  ## 1. Each worker builds local t-digest
  ## 2. Master merges all worker t-digests
  ## 3. Query merged t-digest for global quantiles
  for c in td2.centroids:
    td1.unmerged.add(c)

  for c in td2.unmerged:
    td1.unmerged.add(c)

  td1.totalWeight += td2.totalWeight
  td1.min = min(td1.min, td2.min)
  td1.max = max(td1.max, td2.max)

  td1.compress()

# =============================================================================
# Statistics
# =============================================================================

proc count*(td: TDigest): int =
  ## Total number of values added (approximate, if weights != 1)
  td.totalWeight.int

proc size*(td: TDigest): int =
  ## Number of centroids (memory usage indicator)
  td.centroids.len + td.unmerged.len

proc memoryUsage*(td: TDigest): int =
  ## Estimate memory usage in bytes
  td.size() * 16  # Each centroid: 2 × float64 = 16 bytes

proc `$`*(td: TDigest): string =
  result = "TDigest(compression=" & $td.compression &
           ", centroids=" & $td.centroids.len &
           ", count=" & $td.totalWeight.int &
           ", range=[" & $td.min & ", " & $td.max & "])"

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "t-Digest Quantile Estimation"
  echo "============================"
  echo ""

  # Test 1: Basic quantile estimation
  echo "Test 1: Basic quantile estimation"
  echo "---------------------------------"

  var td1 = initTDigest(100)

  # Add uniform random values [0, 1000)
  randomize(42)
  for i in 0..<10_000:
    td1.add(rand(1000).float64)

  echo "Added 10,000 values uniformly distributed in [0, 1000)"
  echo ""

  echo "Quantiles:"
  for q in [0.01, 0.05, 0.25, 0.5, 0.75, 0.95, 0.99]:
    let quantile = td1.quantile(q)
    let expected = q * 1000.0
    let error = abs(quantile - expected)
    echo &"  P{q*100:>5.1f}: {quantile:>7.2f} (expected ~{expected:>7.2f}, error: {error:>5.2f})"

  echo ""
  echo "Statistics:"
  echo "  Count: ", td1.count()
  echo "  Centroids: ", td1.centroids.len
  echo "  Memory: ", td1.memoryUsage(), " bytes"
  echo ""

  # Test 2: Extreme quantiles (tails)
  echo "Test 2: Extreme quantile accuracy"
  echo "---------------------------------"

  var td2 = initTDigest(200)  # Higher compression for better tail accuracy

  # Normal distribution (mean=500, stddev=100)
  randomize(123)
  for i in 0..<100_000:
    let value = gauss(500.0, 100.0)
    td2.add(value)

  echo "Added 100,000 values from N(500, 100²)"
  echo ""

  echo "Extreme quantiles:"
  for q in [0.001, 0.01, 0.1, 0.9, 0.99, 0.999]:
    echo &"  P{q*100:>6.2f}: {td2.quantile(q):>7.2f}"

  echo ""

  # Test 3: CDF estimation
  echo "Test 3: CDF estimation"
  echo "---------------------"

  var td3 = initTDigest(100)
  for i in 0..<1000:
    td3.add(i.float64)

  echo "Added values [0, 999]"
  echo ""

  echo "CDF values:"
  for value in [100.0, 250.0, 500.0, 750.0, 900.0]:
    let cdf = td3.cdf(value)
    let expected = value / 1000.0
    echo &"  P(X ≤ {value:>4.0f}): {cdf:>5.3f} (expected ~{expected:>5.3f})"

  echo ""

  # Test 4: Performance benchmark
  echo "Test 4: Performance benchmark"
  echo "----------------------------"

  var td4 = initTDigest(100)
  let numValues = 1_000_000

  echo "Inserting ", numValues, " values..."
  let insertStart = cpuTime()
  for i in 0..<numValues:
    td4.add(rand(1000000).float64)
  let insertTime = cpuTime() - insertStart

  echo "  Time: ", (insertTime * 1000.0).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (numValues.float64 / insertTime / 1_000_000.0).formatFloat(ffDecimal, 2), " M values/sec"
  echo "  Centroids: ", td4.centroids.len
  echo "  Compression ratio: ", (numValues.float64 / td4.centroids.len.float64).formatFloat(ffDecimal, 0), "×"
  echo ""

  echo "Querying quantiles..."
  let queryStart = cpuTime()
  for q in 0..100:
    discard td4.quantile(q.float64 / 100.0)
  let queryTime = cpuTime() - queryStart

  echo "  Time for 101 quantiles: ", (queryTime * 1000.0).formatFloat(ffDecimal, 2), " ms"
  echo "  Per-quantile: ", (queryTime * 1000.0 / 101.0).formatFloat(ffDecimal, 3), " ms"
  echo ""

  # Test 5: Merging t-digests (distributed)
  echo "Test 5: Merging t-digests"
  echo "------------------------"

  # Simulate 3 workers
  var workers = newSeq[TDigest](3)
  for i in 0..2:
    workers[i] = initTDigest(100)

  # Each worker processes 10K values
  randomize(456)
  for workerIdx in 0..2:
    for i in 0..<10_000:
      workers[workerIdx].add(rand(1000).float64 + workerIdx.float64 * 100.0)

  echo "3 workers, each processed 10,000 values"
  echo ""

  # Merge all workers
  var master = initTDigest(100)
  for worker in workers:
    master.merge(worker)

  echo "Merged t-digest:"
  echo "  Total count: ", master.count()
  echo "  Centroids: ", master.centroids.len
  echo "  Median: ", master.quantile(0.5).formatFloat(ffDecimal, 2)
  echo "  P95: ", master.quantile(0.95).formatFloat(ffDecimal, 2)
  echo ""

  echo "All tests completed!"
