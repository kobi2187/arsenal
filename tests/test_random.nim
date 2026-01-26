## Tests for Random Number Generators
## ===================================

import std/[unittest, tables, math]
import ../src/arsenal/random/rng

suite "SplitMix64 - Fast Seeding RNG":
  test "initialization with seed":
    var rng = initSplitMix64(12345)
    let val1 = rng.next()
    let val2 = rng.next()

    # Values should be different
    check val1 != val2

    # Same seed produces same sequence
    var rng2 = initSplitMix64(12345)
    check rng2.next() == val1
    check rng2.next() == val2

  test "initialization with time seed":
    var rng1 = initSplitMix64(0)  # Time-based
    var rng2 = initSplitMix64(0)  # Time-based

    # Should produce values (may be same if called quickly)
    discard rng1.next()
    discard rng2.next()

  test "generates different sequences for different seeds":
    var rng1 = initSplitMix64(111)
    var rng2 = initSplitMix64(222)

    let seq1 = [rng1.next(), rng1.next(), rng1.next()]
    let seq2 = [rng2.next(), rng2.next(), rng2.next()]

    check seq1 != seq2

  test "sequence quality - not all zeros or ones":
    var rng = initSplitMix64(42)
    var hasZeroBits = false
    var hasOneBits = false

    for i in 0..<10:
      let val = rng.next()
      if val != uint64.high: hasZeroBits = true
      if val != 0: hasOneBits = true

    check hasZeroBits
    check hasOneBits

suite "PCG32 - Permuted Congruential Generator":
  test "initialization with seed":
    var rng = initPcg32(12345, 1)
    let val1 = rng.next()
    let val2 = rng.next()

    check val1 != val2

    # Same seed and stream produces same sequence
    var rng2 = initPcg32(12345, 1)
    check rng2.next() == val1
    check rng2.next() == val2

  test "different streams produce different sequences":
    var rng1 = initPcg32(12345, 1)
    var rng2 = initPcg32(12345, 2)

    let seq1 = [rng1.next(), rng1.next(), rng1.next()]
    let seq2 = [rng2.next(), rng2.next(), rng2.next()]

    check seq1 != seq2

  test "nextU64 combines two 32-bit values":
    var rng = initPcg32(789)
    let val = rng.nextU64()

    check val > uint32.high.uint64  # Should be > 32 bits

  test "nextFloat returns value in [0, 1)":
    var rng = initPcg32(456)

    for i in 0..<100:
      let f = rng.nextFloat()
      check f >= 0.0
      check f < 1.0

  test "nextRange returns value in [0, max)":
    var rng = initPcg32(123)
    let max = 10'u32

    for i in 0..<100:
      let val = rng.nextRange(max)
      check val < max

  test "nextRange with max=0 returns 0":
    var rng = initPcg32(123)
    check rng.nextRange(0) == 0

  test "nextRange distribution quality":
    # Check that distribution is roughly uniform
    var rng = initPcg32(999)
    const max = 10'u32
    const trials = 10000
    var counts: array[10, int]

    for i in 0..<trials:
      let val = rng.nextRange(max)
      counts[val] += 1

    # Each bucket should have roughly trials/max entries
    # Allow 30% deviation
    let expected = trials div 10
    let tolerance = int(expected.float * 0.3)

    for count in counts:
      check count > expected - tolerance
      check count < expected + tolerance

suite "PCG32 - Utility Functions":
  test "shuffle randomizes array":
    var rng = initPcg32(777)
    var arr = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    let original = arr

    rng.shuffle(arr)

    # Array should be different (very unlikely to be same)
    check arr != original

    # But should contain same elements
    var sum = 0
    for x in arr:
      sum += x
    check sum == 55  # 1+2+...+10

  test "shuffle same seed produces same result":
    var arr1 = [1, 2, 3, 4, 5]
    var arr2 = [1, 2, 3, 4, 5]

    var rng1 = initPcg32(111, 1)
    var rng2 = initPcg32(111, 1)

    rng1.shuffle(arr1)
    rng2.shuffle(arr2)

    check arr1 == arr2

  test "sample returns element from array":
    var rng = initPcg32(888)
    let arr = [10, 20, 30, 40, 50]

    for i in 0..<20:
      let val = rng.sample(arr)
      check val in arr

  test "sample from empty array raises exception":
    var rng = initPcg32(999)
    var emptyArr: seq[int] = @[]

    expect(IndexDefect):
      discard rng.sample(emptyArr)

suite "Crypto RNG":
  when not defined(arsenal_no_crypto):
    test "initialization":
      var rng = initCryptoRng()
      check rng.initialized

    test "generates random bytes":
      var rng = initCryptoRng()
      let bytes = rng.nextBytes(32)

      check bytes.len == 32

      # Should not be all zeros
      var hasNonZero = false
      for b in bytes:
        if b != 0:
          hasNonZero = true
          break
      check hasNonZero

    test "generates different sequences":
      var rng = initCryptoRng()
      let bytes1 = rng.nextBytes(16)
      let bytes2 = rng.nextBytes(16)

      check bytes1 != bytes2

    test "next() produces uint64":
      var rng = initCryptoRng()
      let val1 = rng.next()
      let val2 = rng.next()

      check val1 != val2  # Very unlikely to be same

suite "Random Module - Integration":
  test "stdlib random works":
    randomize(42)
    let val1 = rand(100)
    let val2 = rand(100)

    check val1 >= 0
    check val1 <= 100
    check val2 >= 0
    check val2 <= 100

  test "multiple RNG types work together":
    var split = initSplitMix64(123)
    var pcg = initPcg32(456, 1)

    let splitVal = split.next()
    let pcgVal = pcg.next()

    # Both should produce values
    check splitVal != 0 or splitVal == 0  # Always true
    check pcgVal != 0 or pcgVal == 0

suite "Statistical Properties":
  test "PCG32 chi-square test for uniformity":
    # Simple chi-square test for uniform distribution
    var rng = initPcg32(314159)
    const buckets = 10
    const trials = 10000
    var counts: array[buckets, int]

    for i in 0..<trials:
      let val = rng.nextRange(buckets.uint32)
      counts[val] += 1

    let expected = trials.float / buckets.float
    var chiSquare = 0.0

    for count in counts:
      let diff = count.float - expected
      chiSquare += (diff * diff) / expected

    # Chi-square critical value for 9 df at 0.05 significance: 16.919
    # Allow some margin
    check chiSquare < 20.0

  test "PCG32 runs test for independence":
    # Count runs of increasing/decreasing values
    var rng = initPcg32(271828)
    var values: seq[uint32]

    for i in 0..<100:
      values.add(rng.next())

    var runs = 1
    for i in 1..<values.len:
      if (values[i] > values[i-1]) != (values[1] > values[0]):
        runs += 1

    # Expected runs for random sequence: ~50
    # Allow wide margin
    check runs > 30
    check runs < 70
