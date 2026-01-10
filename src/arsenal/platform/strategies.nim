## Optimization Strategy Selection
## ===============================
##
## Arsenal modules can adapt their behavior based on the current
## optimization strategy. This allows the same code to be optimized
## for different use cases (high throughput vs low latency).
##
## Usage:
## ```nim
## setStrategy(Latency)  # Optimize for low latency
##
## withStrategy(Throughput):
##   # This block uses throughput optimizations
##   processLargeBatch(data)
## ```

type
  OptimizationStrategy* = enum
    ## Controls how Arsenal primitives optimize their operations.

    Balanced
      ## Default. Good general-purpose performance.
      ## Use when you don't know what to optimize for.

    Throughput
      ## Maximize operations per second.
      ## - Prefer batch operations
      ## - Larger buffers
      ## - May have higher latency per operation
      ## Good for: servers, batch processing, data pipelines

    Latency
      ## Minimize time per operation.
      ## - Smaller buffers, less batching
      ## - Busy-wait instead of sleep
      ## - Avoid syscalls where possible
      ## Good for: HFT, real-time audio, games

    MinimalMemory
      ## Minimize memory footprint.
      ## - Smaller buffers
      ## - Simpler data structures
      ## - May sacrifice speed
      ## Good for: embedded systems, memory-constrained environments

# =============================================================================
# Thread-Local Strategy
# =============================================================================

var currentStrategy {.threadvar.}: OptimizationStrategy

proc setStrategy*(s: OptimizationStrategy) =
  ## Set the optimization strategy for the current thread.
  ## This affects all Arsenal operations in this thread.
  currentStrategy = s

proc getStrategy*(): OptimizationStrategy =
  ## Get the current thread's optimization strategy.
  result = currentStrategy

template withStrategy*(s: OptimizationStrategy, body: untyped) =
  ## Execute body with a temporary strategy, then restore the original.
  ##
  ## ```nim
  ## withStrategy(Latency):
  ##   criticalOperation()
  ## # Strategy is restored here
  ## ```
  let oldStrategy = currentStrategy
  currentStrategy = s
  try:
    body
  finally:
    currentStrategy = oldStrategy

# =============================================================================
# Strategy-Based Configuration
# =============================================================================

type
  StrategyConfig* = object
    ## Configuration values that vary based on strategy.
    ## Use `getConfig()` to get values appropriate for current strategy.

    defaultBufferSize*: int
      ## Default buffer size for queues, channels, etc.

    spinIterations*: int
      ## How many times to spin before yielding/sleeping.

    batchSize*: int
      ## Preferred batch size for bulk operations.

    useHugePages*: bool
      ## Whether to prefer huge pages for large allocations.

    busyWait*: bool
      ## Whether to busy-wait instead of sleeping.

const
  BalancedConfig* = StrategyConfig(
    defaultBufferSize: 4096,
    spinIterations: 1000,
    batchSize: 64,
    useHugePages: false,
    busyWait: false
  )

  ThroughputConfig* = StrategyConfig(
    defaultBufferSize: 65536,
    spinIterations: 100,
    batchSize: 256,
    useHugePages: true,
    busyWait: false
  )

  LatencyConfig* = StrategyConfig(
    defaultBufferSize: 1024,
    spinIterations: 10000,
    batchSize: 16,
    useHugePages: true,
    busyWait: true
  )

  MinimalMemoryConfig* = StrategyConfig(
    defaultBufferSize: 256,
    spinIterations: 100,
    batchSize: 8,
    useHugePages: false,
    busyWait: false
  )

proc getConfig*(): StrategyConfig =
  ## Returns configuration appropriate for the current strategy.
  case getStrategy()
  of Balanced: BalancedConfig
  of Throughput: ThroughputConfig
  of Latency: LatencyConfig
  of MinimalMemory: MinimalMemoryConfig

proc getConfig*(s: OptimizationStrategy): StrategyConfig =
  ## Returns configuration for a specific strategy.
  case s
  of Balanced: BalancedConfig
  of Throughput: ThroughputConfig
  of Latency: LatencyConfig
  of MinimalMemory: MinimalMemoryConfig
