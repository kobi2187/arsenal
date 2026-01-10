## Tests for Optimization Strategies
## ================================

import std/unittest
import ../src/arsenal/platform/strategies

suite "Optimization Strategies":

  test "default strategy is Balanced":
    check getStrategy() == Balanced

  test "setStrategy changes thread-local strategy":
    let original = getStrategy()
    setStrategy(Throughput)
    check getStrategy() == Throughput
    setStrategy(original)  # Restore

  test "withStrategy temporarily changes strategy":
    let original = getStrategy()
    var innerStrategy: OptimizationStrategy

    withStrategy(Latency):
      innerStrategy = getStrategy()
      check innerStrategy == Latency

    check getStrategy() == original

  test "getConfig returns correct configs":
    check getConfig(Balanced).defaultBufferSize == 4096
    check getConfig(Throughput).defaultBufferSize == 65536
    check getConfig(Latency).defaultBufferSize == 1024
    check getConfig(MinimalMemory).defaultBufferSize == 256

  test "getConfig uses current strategy":
    let original = getStrategy()
    setStrategy(Latency)
    check getConfig().defaultBufferSize == 1024
    setStrategy(original)  # Restore

  test "strategy configs have reasonable values":
    for s in [Balanced, Throughput, Latency, MinimalMemory]:
      let config = getConfig(s)
      check config.defaultBufferSize > 0
      check config.spinIterations > 0
      check config.batchSize > 0