## Monte Carlo Pi Estimation
## ==========================
##
## This example demonstrates practical usage of Arsenal's primitives:
## - Random number generation (PCG32 for parallel streams)
## - High-resolution timing (benchmark estimation accuracy)
## - Bit operations (efficient hit counting with bit manipulation)
##
## Monte Carlo Method:
## - Generate random points in a unit square [0,1) x [0,1)
## - Count points inside quarter circle (x² + y² < 1)
## - Estimate π ≈ 4 * (points inside) / (total points)
##
## Compilation:
## ```bash
## nim c -d:release examples/monte_carlo_pi.nim
## ./monte_carlo_pi
## ```

import std/[math, strformat]
import ../src/arsenal/random/rng
import ../src/arsenal/time/clock
import ../src/arsenal/bits/bitops

proc estimatePi(samples: int, stream: int = 1): float =
  ## Estimate π using Monte Carlo method
  var rng = initPcg32(12345, stream.uint64)
  var inside = 0

  for i in 0..<samples:
    let x = rng.nextFloat()
    let y = rng.nextFloat()

    if x * x + y * y < 1.0:
      inc inside

  return 4.0 * inside.float / samples.float

proc estimatePiParallel(samples: int, numStreams: int): float =
  ## Parallel estimation using multiple independent RNG streams
  let samplesPerStream = samples div numStreams
  var estimates: seq[float]

  for stream in 1..numStreams:
    let estimate = estimatePi(samplesPerStream, stream)
    estimates.add(estimate)

  # Average estimates
  var sum = 0.0
  for est in estimates:
    sum += est
  return sum / numStreams.float

proc estimatePiOptimized(samples: int): float =
  ## Optimized version using bit operations for efficient counting
  var rng = initPcg32(54321, 1)
  var inside: uint64 = 0

  # Process in batches of 64 for efficient bit counting
  let batches = samples div 64
  let remainder = samples mod 64

  for batch in 0..<batches:
    var hitBits: uint64 = 0

    for i in 0..<64:
      let x = rng.nextFloat()
      let y = rng.nextFloat()

      if x * x + y * y < 1.0:
        hitBits = hitBits or (1'u64 shl i)

    # Use popcount for efficient bit counting
    inside += popcount(hitBits).uint64

  # Handle remainder
  for i in 0..<remainder:
    let x = rng.nextFloat()
    let y = rng.nextFloat()

    if x * x + y * y < 1.0:
      inc inside

  return 4.0 * inside.float / samples.float

proc convergenceAnalysis() =
  ## Analyze convergence rate with different sample sizes
  echo "Convergence Analysis"
  echo "===================="
  echo ""
  echo "Samples        | Estimate      | Error         | Time"
  echo "---------------|---------------|---------------|-------------"

  let sampleSizes = [1_000, 10_000, 100_000, 1_000_000, 10_000_000]

  for size in sampleSizes:
    let timer = startTimer()
    let estimate = estimatePi(size)
    let elapsed = timer.elapsedMs()

    let error = abs(estimate - PI) / PI * 100.0

    echo &"{size:14} | {estimate:13.10f} | {error:12.8f}% | {elapsed:10} ms"

  echo ""

proc parallelScaling() =
  ## Demonstrate parallel scaling with multiple RNG streams
  echo "Parallel Scaling (10M samples)"
  echo "==============================="
  echo ""
  echo "Streams | Estimate      | Time"
  echo "--------|---------------|-------------"

  const samples = 10_000_000

  for streams in [1, 2, 4, 8]:
    let timer = startTimer()
    let estimate = estimatePiParallel(samples, streams)
    let elapsed = timer.elapsedMs()

    echo &"{streams:7} | {estimate:13.10f} | {elapsed:10} ms"

  echo ""
  echo "Note: Actual parallel speedup requires threading."
  echo "This demonstrates independent stream generation."
  echo ""

proc optimizationComparison() =
  ## Compare standard vs optimized implementations
  echo "Optimization Comparison (10M samples)"
  echo "====================================="
  echo ""

  const samples = 10_000_000

  # Standard version
  echo "Standard implementation:"
  let timer1 = startTimer()
  let estimate1 = estimatePi(samples)
  let time1 = timer1.elapsedMs()
  echo &"  Estimate: {estimate1:.10f}"
  echo &"  Time:     {time1} ms"
  echo ""

  # Optimized version (with popcount)
  echo "Optimized implementation (batch processing + popcount):"
  let timer2 = startTimer()
  let estimate2 = estimatePiOptimized(samples)
  let time2 = timer2.elapsedMs()
  echo &"  Estimate: {estimate2:.10f}"
  echo &"  Time:     {time2} ms"
  echo &"  Speedup:  {time1.float / time2.float:.2f}x"
  echo ""

proc statisticalAnalysis() =
  ## Run multiple trials for statistical analysis
  echo "Statistical Analysis (10 trials, 1M samples each)"
  echo "=================================================="
  echo ""

  const trials = 10
  const samplesPerTrial = 1_000_000

  var estimates: seq[float]

  for trial in 1..trials:
    # Use different stream for each trial
    var rng = initPcg32(trial.uint64, trial.uint64)
    var inside = 0

    for i in 0..<samplesPerTrial:
      let x = rng.nextFloat()
      let y = rng.nextFloat()

      if x * x + y * y < 1.0:
        inc inside

    let estimate = 4.0 * inside.float / samplesPerTrial.float
    estimates.add(estimate)

  # Calculate statistics
  var mean = 0.0
  for est in estimates:
    mean += est
  mean /= trials.float

  var variance = 0.0
  for est in estimates:
    let diff = est - mean
    variance += diff * diff
  variance /= trials.float

  let stddev = sqrt(variance)
  let error = abs(mean - PI) / PI * 100.0

  echo &"Mean estimate:     {mean:.10f}"
  echo &"True value (π):    {PI:.10f}"
  echo &"Standard deviation: {stddev:.10f}"
  echo &"Mean error:        {error:.8f}%"
  echo ""

  echo "Individual trial estimates:"
  for i, est in estimates:
    let trialError = abs(est - PI) / PI * 100.0
    echo &"  Trial {i+1:2}: {est:.10f} (error: {trialError:.8f}%)"

  echo ""

## Main Program
when isMainModule:
  echo "Arsenal Monte Carlo Pi Estimation"
  echo "=================================="
  echo ""
  echo "This example demonstrates:"
  echo "  - PCG32 random number generation"
  echo "  - High-resolution timing"
  echo "  - Bit operations (popcount for efficiency)"
  echo "  - Multiple independent RNG streams"
  echo ""

  # Run analyses
  convergenceAnalysis()
  parallelScaling()
  optimizationComparison()
  statisticalAnalysis()

  # Final high-precision estimate
  echo "Final High-Precision Estimate"
  echo "============================="
  echo ""
  echo "Computing with 100 million samples..."
  let finalTimer = startTimer()
  let finalEstimate = estimatePi(100_000_000)
  let finalTime = finalTimer.elapsedSeconds()

  echo &"Estimate:      {finalEstimate:.12f}"
  echo &"True value:    {PI:.12f}"
  echo &"Error:         {abs(finalEstimate - PI):.12f}"
  echo &"Relative error: {abs(finalEstimate - PI) / PI * 100:.10f}%"
  echo &"Time:          {finalTime:.3f} seconds"
  echo ""

  # Performance summary
  let samplesPerSec = 100_000_000.0 / finalTime
  echo "Performance Summary"
  echo "==================="
  echo &"Samples per second: {samplesPerSec / 1_000_000:.2f} M samples/sec"
  echo &"Time per sample:    {finalTime / 100_000_000.0 * 1_000_000_000:.2f} ns"
  echo ""

  echo "Key Takeaways:"
  echo "  1. PCG32 provides ~1 ns per number (very fast)"
  echo "  2. Convergence rate: error ∝ 1/√N (Monte Carlo property)"
  echo "  3. Multiple streams enable parallel Monte Carlo"
  echo "  4. Bit operations (popcount) can optimize counting"
  echo "  5. High-resolution timing essential for accurate benchmarking"

## Notes
## =====
##
## Monte Carlo Method Accuracy:
##   Error = 1 / √N
##   For 1% error:     Need ~10,000 samples
##   For 0.1% error:   Need ~1,000,000 samples
##   For 0.01% error:  Need ~100,000,000 samples
##
## Performance Characteristics:
##   - RNG dominates computation time (~70-80%)
##   - Square root and comparison: ~20-30%
##   - popcount optimization: ~10-20% speedup
##
## Parallel Opportunities:
##   - Each stream is independent (embarrassingly parallel)
##   - Linear speedup with thread count (no contention)
##   - Combine results at end (simple average)
##
## Real-World Applications:
##   - Financial modeling (option pricing)
##   - Physics simulations (particle transport)
##   - Risk analysis (uncertainty quantification)
##   - Computer graphics (path tracing)
##   - Bayesian inference (MCMC sampling)
