## HyperLogLog Cardinality Estimation
## ====================================
##
## Probabilistic data structure for estimating cardinality (distinct count)
## of very large datasets with minimal memory usage.
##
## Paper: "HyperLogLog: the analysis of a near-optimal cardinality estimation algorithm"
##        Flajolet, Fusy, Gandouet, Meunier (2007)
##        https://algo.inria.fr/flajolet/Publications/FlFuGaMe07.pdf
##
## Key Properties:
## - **Accuracy**: Standard error ≈ 1.04/√m where m = number of registers
## - **Memory**: With m = 2^14 (16384 registers), uses ~16 KB for billions of elements
## - **Performance**: O(1) insertion, O(m) cardinality estimation
## - **Mergeable**: Two HyperLogLog sketches can be merged by taking register-wise maximum
##
## Typical configurations:
## - m = 2^12 (4096):   ~1.6% error, 4 KB memory
## - m = 2^14 (16384):  ~0.8% error, 16 KB memory
## - m = 2^16 (65536):  ~0.4% error, 64 KB memory
##
## Applications:
## - Database query optimization (distinct count estimation)
## - Network monitoring (unique IP addresses)
## - Analytics (unique visitors, unique events)
## - Big data processing (Spark, Presto, BigQuery)
##
## Usage:
## ```nim
## import arsenal/sketching/cardinality/hyperloglog
##
## # Create HyperLogLog with 16384 registers (standard error ~0.8%)
## var hll = initHyperLogLog(14)  # 2^14 = 16384 registers
##
## # Add elements
## hll.add("user_12345")
## hll.add("user_67890")
## hll.add("user_12345")  # Duplicate (counted once)
##
## # Estimate cardinality
## let estimate = hll.cardinality()
## echo "Estimated unique count: ", estimate
##
## # Merge two sketches
## var hll2 = initHyperLogLog(14)
## hll2.add("user_99999")
## hll.merge(hll2)
## ```

import std/[math, hashes]

# =============================================================================
# Constants and Types
# =============================================================================

const
  # Bias correction constants for different precision values (p = log2(m))
  # From the paper's empirical analysis
  AlphaTable = [
    0.0,       # p=0 (invalid)
    0.0,       # p=1 (invalid)
    0.0,       # p=2 (invalid)
    0.0,       # p=3 (invalid)
    0.673,     # p=4  (m=16)
    0.697,     # p=5  (m=32)
    0.709,     # p=6  (m=64)
    0.7152,    # p=7  (m=128)
    0.7182,    # p=8  (m=256)
    0.7197,    # p=9  (m=512)
    0.7206,    # p=10 (m=1024)
  ]

  # For p >= 11, use α = 0.7213/(1 + 1.079/m)
  AlphaInf = 0.7213

  # Thresholds for bias correction
  SmallRangeCorrectionFactor = 2.5
  LargeRangeCorrectionThreshold = (1'u64 shl 32) div 30  # 2^32/30

type
  HyperLogLog* = object
    ## HyperLogLog sketch for cardinality estimation
    p: int              ## Precision parameter (log2(m))
    m: int              ## Number of registers (2^p)
    registers: seq[uint8]  ## Register array (stores max leading zeros + 1)
    alphaMm2: float64   ## Precomputed α_m * m^2 for estimation formula

# =============================================================================
# Utility Functions
# =============================================================================

proc leadingZeros(x: uint64, startBit: int): int {.inline.} =
  ## Count leading zeros starting from bit position startBit
  ## Returns position of first 1-bit (1-indexed), or startBit+1 if all zeros
  ##
  ## This implements the ρ(x) function from the paper:
  ## ρ(x) = position of first 1-bit in binary representation
  if x == 0:
    return startBit + 1

  var mask = 1'u64 shl startBit
  var pos = 1

  while (x and mask) == 0 and pos <= startBit:
    mask = mask shr 1
    inc pos

  result = pos

proc getAlpha(p: int): float64 {.inline.} =
  ## Get bias correction constant α_m for given precision
  if p < AlphaTable.len:
    result = AlphaTable[p]
  else:
    let m = 1 shl p
    result = AlphaInf / (1.0 + 1.079 / m.float64)

# =============================================================================
# HyperLogLog Construction
# =============================================================================

proc initHyperLogLog*(precision: int = 14): HyperLogLog =
  ## Create new HyperLogLog sketch
  ##
  ## Parameters:
  ## - precision: log2(m), number of registers = 2^precision
  ##   - Typical range: 4-16
  ##   - precision=12: ~1.6% error, 4 KB
  ##   - precision=14: ~0.8% error, 16 KB (recommended)
  ##   - precision=16: ~0.4% error, 64 KB
  ##
  ## Returns initialized HyperLogLog sketch
  if precision < 4 or precision > 18:
    raise newException(ValueError, "Precision must be between 4 and 18")

  let m = 1 shl precision
  let alpha = getAlpha(precision)

  result = HyperLogLog(
    p: precision,
    m: m,
    registers: newSeq[uint8](m),
    alphaMm2: alpha * m.float64 * m.float64
  )

proc clear*(hll: var HyperLogLog) =
  ## Reset all registers to zero
  for i in 0..<hll.registers.len:
    hll.registers[i] = 0

# =============================================================================
# HyperLogLog Operations
# =============================================================================

proc add*(hll: var HyperLogLog, data: openArray[byte]) =
  ## Add element to HyperLogLog sketch (raw bytes)
  ##
  ## This is the core operation. It:
  ## 1. Hashes the input to get uniform distribution
  ## 2. Uses first p bits to select register
  ## 3. Counts leading zeros in remaining bits
  ## 4. Updates register with maximum value seen

  # Hash input to 64-bit value
  let hashVal = hash(data).uint64

  # First p bits determine register index
  let registerIdx = (hashVal shr (64 - hll.p)).int

  # Remaining (64-p) bits: count leading zeros + 1
  let w = hashVal shl hll.p  # Remove first p bits
  let leadingZerosCount = leadingZeros(w, 64 - hll.p)

  # Update register with maximum
  if leadingZerosCount > hll.registers[registerIdx].int:
    hll.registers[registerIdx] = leadingZerosCount.uint8

proc add*(hll: var HyperLogLog, item: string) =
  ## Add string element to HyperLogLog sketch
  hll.add(item.toOpenArrayByte(0, item.len - 1))

proc add*[T](hll: var HyperLogLog, item: T) =
  ## Add any hashable element to HyperLogLog sketch
  ##
  ## Works with integers, floats, custom types (if they implement hash)
  let h = hash(item).uint64
  var bytes: array[8, byte]

  # Convert hash to bytes
  bytes[0] = ((h shr 0) and 0xFF).byte
  bytes[1] = ((h shr 8) and 0xFF).byte
  bytes[2] = ((h shr 16) and 0xFF).byte
  bytes[3] = ((h shr 24) and 0xFF).byte
  bytes[4] = ((h shr 32) and 0xFF).byte
  bytes[5] = ((h shr 40) and 0xFF).byte
  bytes[6] = ((h shr 48) and 0xFF).byte
  bytes[7] = ((h shr 56) and 0xFF).byte

  hll.add(bytes)

# =============================================================================
# Cardinality Estimation
# =============================================================================

proc cardinality*(hll: HyperLogLog): int64 =
  ## Estimate cardinality (distinct count) of elements added
  ##
  ## Uses the HyperLogLog formula from the paper:
  ## E = α_m * m^2 / sum(2^(-M[j]))
  ##
  ## With bias corrections:
  ## - Small range: if E < 2.5m and empty registers exist
  ## - Large range: if E > 2^32/30
  ##
  ## Returns estimated distinct count

  # Compute raw estimate: α_m * m^2 / sum(2^(-M[j]))
  var sum = 0.0
  var emptyRegisters = 0

  for reg in hll.registers:
    if reg == 0:
      inc emptyRegisters
      sum += 1.0  # 2^0 = 1
    else:
      sum += 1.0 / (1'u64 shl reg).float64  # 2^(-reg)

  let rawEstimate = hll.alphaMm2 / sum

  # Apply bias corrections
  if rawEstimate <= SmallRangeCorrectionFactor * hll.m.float64:
    # Small range correction: use linear counting for better accuracy
    if emptyRegisters > 0:
      let linearCount = hll.m.float64 * ln(hll.m.float64 / emptyRegisters.float64)
      return linearCount.int64

  if rawEstimate <= LargeRangeCorrectionThreshold.float64:
    # No correction needed in normal range
    return rawEstimate.int64

  # Large range correction: compensate for hash collisions
  let largeCorrection = -(1'i64 shl 32).float64 * ln(1.0 - rawEstimate / (1'i64 shl 32).float64)
  result = largeCorrection.int64

# =============================================================================
# Merging
# =============================================================================

proc merge*(hll: var HyperLogLog, other: HyperLogLog) =
  ## Merge another HyperLogLog sketch into this one
  ##
  ## Both sketches must have the same precision (same m)
  ## Merging is done by taking register-wise maximum
  ##
  ## This allows distributed cardinality estimation:
  ## 1. Process data in parallel, each creating local HLL
  ## 2. Merge all local HLLs into global HLL
  ## 3. Estimate cardinality from merged HLL
  if hll.p != other.p:
    raise newException(ValueError, "Cannot merge HyperLogLog sketches with different precision")

  for i in 0..<hll.m:
    if other.registers[i] > hll.registers[i]:
      hll.registers[i] = other.registers[i]

proc merged*(hll1, hll2: HyperLogLog): HyperLogLog =
  ## Create new HyperLogLog that is the merge of two sketches
  result = hll1
  result.merge(hll2)

# =============================================================================
# Serialization / Utilities
# =============================================================================

proc toBytes*(hll: HyperLogLog): seq[byte] =
  ## Serialize HyperLogLog to bytes
  ##
  ## Format: [precision:1 byte][registers:m bytes]
  result = newSeq[byte](1 + hll.m)
  result[0] = hll.p.byte

  for i in 0..<hll.m:
    result[1 + i] = hll.registers[i]

proc fromBytes*(data: openArray[byte]): HyperLogLog =
  ## Deserialize HyperLogLog from bytes
  if data.len < 2:
    raise newException(ValueError, "Invalid HyperLogLog data: too short")

  let precision = data[0].int
  let m = 1 shl precision

  if data.len != 1 + m:
    raise newException(ValueError, "Invalid HyperLogLog data: wrong size")

  result = initHyperLogLog(precision)
  for i in 0..<m:
    result.registers[i] = data[1 + i]

proc `$`*(hll: HyperLogLog): string =
  ## String representation of HyperLogLog
  let est = hll.cardinality()
  let memKb = hll.m.float64 / 1024.0
  let errorPct = (1.04 / sqrt(hll.m.float64)) * 100.0

  result = "HyperLogLog(m=" & $hll.m &
           ", memory=" & memKb.formatFloat(ffDecimal, 1) & " KB" &
           ", error~" & errorPct.formatFloat(ffDecimal, 2) & "%" &
           ", cardinality~" & $est & ")"

proc precision*(hll: HyperLogLog): int =
  ## Get precision parameter (log2(m))
  hll.p

proc numRegisters*(hll: HyperLogLog): int =
  ## Get number of registers (m = 2^p)
  hll.m

proc memoryUsage*(hll: HyperLogLog): int =
  ## Get memory usage in bytes
  hll.m

proc expectedError*(hll: HyperLogLog): float64 =
  ## Get expected relative standard error
  ##
  ## Returns value between 0.0 and 1.0
  ## e.g., 0.008 means 0.8% error
  1.04 / sqrt(hll.m.float64)

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "HyperLogLog Cardinality Estimation"
  echo "==================================="
  echo ""

  # Test 1: Basic accuracy test
  echo "Test 1: Accuracy test with known cardinality"
  echo "--------------------------------------------"

  for precision in [10, 12, 14]:
    var hll = initHyperLogLog(precision)
    let trueCount = 10_000

    # Add elements
    for i in 0..<trueCount:
      hll.add(i)

    let estimate = hll.cardinality()
    let error = abs(estimate - trueCount).float64 / trueCount.float64 * 100.0

    echo &"  p={precision} (m={hll.m}, {hll.memoryUsage()} bytes):"
    echo &"    True count:     {trueCount}"
    echo &"    Estimated:      {estimate}"
    echo &"    Error:          {error:.2f}%"
    echo &"    Expected error: {hll.expectedError() * 100:.2f}%"
    echo ""

  # Test 2: Duplicates handling
  echo "Test 2: Duplicate handling"
  echo "-------------------------"

  var hll2 = initHyperLogLog(14)

  # Add 1000 unique values, each 10 times
  for i in 0..<1000:
    for _ in 0..<10:
      hll2.add(i)

  let estimate2 = hll2.cardinality()
  echo &"  Added 1000 unique values (10 times each)"
  echo &"  Estimated cardinality: {estimate2}"
  echo &"  Error: {abs(estimate2 - 1000).float64 / 1000.0 * 100:.2f}%"
  echo ""

  # Test 3: Large cardinality
  echo "Test 3: Large cardinality (1 million unique)"
  echo "-------------------------------------------"

  var hll3 = initHyperLogLog(14)
  let largeCount = 1_000_000

  let startTime = cpuTime()
  for i in 0..<largeCount:
    hll3.add(i)
  let elapsed = cpuTime() - startTime

  let estimate3 = hll3.cardinality()
  let error3 = abs(estimate3 - largeCount).float64 / largeCount.float64 * 100.0

  echo &"  True count:     {largeCount}"
  echo &"  Estimated:      {estimate3}"
  echo &"  Error:          {error3:.2f}%"
  echo &"  Time:           {elapsed * 1000:.2f} ms"
  echo &"  Throughput:     {(largeCount.float64 / elapsed / 1_000_000):.2f} M ops/sec"
  echo &"  Memory usage:   {hll3.memoryUsage().float64 / 1024:.1f} KB"
  echo ""

  # Test 4: Merging
  echo "Test 4: Merging HyperLogLog sketches"
  echo "------------------------------------"

  var hllA = initHyperLogLog(12)
  var hllB = initHyperLogLog(12)

  # Add disjoint sets
  for i in 0..<5000:
    hllA.add(i)

  for i in 5000..<10000:
    hllB.add(i)

  echo &"  HLL A cardinality: {hllA.cardinality()}"
  echo &"  HLL B cardinality: {hllB.cardinality()}"

  hllA.merge(hllB)
  let mergedEstimate = hllA.cardinality()

  echo &"  Merged cardinality: {mergedEstimate}"
  echo &"  True count: 10000"
  echo &"  Error: {abs(mergedEstimate - 10000).float64 / 10000.0 * 100:.2f}%"
  echo ""

  # Test 5: String values
  echo "Test 5: String values"
  echo "--------------------"

  var hll5 = initHyperLogLog(14)

  for i in 0..<10000:
    hll5.add("user_" & $i)

  let estimate5 = hll5.cardinality()
  echo &"  Added 10000 unique strings"
  echo &"  Estimated: {estimate5}"
  echo &"  Error: {abs(estimate5 - 10000).float64 / 10000.0 * 100:.2f}%"
  echo ""

  echo "All tests completed!"
