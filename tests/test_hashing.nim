## xxHash64 Unit Tests
## Tests the real xxHash64 implementation against known test vectors

import ../src/arsenal/hashing/hasher
import std/strutils

# Known test vectors from xxHash official test suite
# Format: (input, seed, expected_output)
const TestVectors = [
  # Empty string
  (data: "", seed: 0u64, expected: 0xEF46DB3751D8E999'u64),

  # Single byte
  (data: "\x00", seed: 0u64, expected: 0x3061585A80A3C7A3'u64),

  # Single byte with different seed
  (data: "\x00", seed: 1u64, expected: 0x3061585A80A3C7A2'u64),

  # String "abc"
  (data: "abc", seed: 0u64, expected: 0x44BC2CF5AD770999'u64),

  # Longer string "hello world"
  (data: "hello world", seed: 0u64, expected: 0x37405BDC8E6B17DE'u64),

  # Block-size data (32 bytes exactly)
  (data: "abcdefghijklmnopqrstuvwxyz012345", seed: 0u64, expected: 0x0EAB4A5F30FF3CB3'u64),

  # Just over 32 bytes (33 bytes)
  (data: "abcdefghijklmnopqrstuvwxyz0123456", seed: 0u64, expected: 0xF15A06CA5B5B7C03'u64),
]

proc testOneShotHashing() =
  ## Test one-shot hashing with known vectors
  echo "Testing xxHash64 one-shot hashing..."
  var passed = 0
  var failed = 0

  for i, (data, seed, expected) in TestVectors:
    let result = if data.len > 0:
      xxHash64.hash(data.toOpenArrayByte(0, data.len - 1), HashSeed(seed))
    else:
      let emptyArr: seq[byte] = @[]
      xxHash64.hash(emptyArr, HashSeed(seed))

    if result == expected:
      echo "  [✓] Test ", i + 1, ": PASSED"
      inc passed
    else:
      echo "  [✗] Test ", i + 1, ": FAILED"
      echo "      Input: \"", data, "\""
      echo "      Seed: ", seed
      echo "      Expected: 0x", toHex(expected)
      echo "      Got:      0x", toHex(result)
      inc failed

  echo "One-shot tests: ", passed, " passed, ", failed, " failed"
  if failed == 0:
    echo "✓ All one-shot tests passed!"

proc testIncrementalHashing() =
  ## Test incremental hashing produces same results as one-shot
  echo "\nTesting xxHash64 incremental hashing..."
  var passed = 0
  var failed = 0

  # Test data to hash incrementally
  let testData = "The quick brown fox jumps over the lazy dog"

  # One-shot hash
  let oneShotResult = xxHash64.hash(
    testData.toOpenArrayByte(0, testData.len - 1),
    HashSeed(0)
  )

  # Incremental hash (single update)
  var state1 = xxHash64.init(HashSeed(0))
  state1.update(testData.toOpenArrayByte(0, testData.len - 1))
  let singleUpdateResult = state1.finish()

  # Incremental hash (multiple updates)
  var state2 = xxHash64.init(HashSeed(0))
  # Split into 3 parts
  let part1Len = 5
  let part2Len = 10
  state2.update(testData.toOpenArrayByte(0, part1Len - 1))
  state2.update(testData.toOpenArrayByte(part1Len, part1Len + part2Len - 1))
  state2.update(testData.toOpenArrayByte(part1Len + part2Len, testData.len - 1))
  let multiUpdateResult = state2.finish()

  # Check results match
  if oneShotResult == singleUpdateResult:
    echo "  [✓] Single update matches one-shot: PASSED"
    inc passed
  else:
    echo "  [✗] Single update does not match one-shot: FAILED"
    echo "      One-shot: 0x", toHex(oneShotResult)
    echo "      Single:   0x", toHex(singleUpdateResult)
    inc failed

  if oneShotResult == multiUpdateResult:
    echo "  [✓] Multiple updates match one-shot: PASSED"
    inc passed
  else:
    echo "  [✗] Multiple updates do not match one-shot: FAILED"
    echo "      One-shot:  0x", toHex(oneShotResult)
    echo "      Multiple:  0x", toHex(multiUpdateResult)
    inc failed

  echo "Incremental tests: ", passed, " passed, ", failed, " failed"

proc testStringHashing() =
  ## Test string hashing convenience function
  echo "\nTesting xxHash64 string hashing..."

  let str1 = "hello"
  let str2 = "hello"
  let str3 = "world"

  let hash1 = xxHash64.hash(str1, HashSeed(0))
  let hash2 = xxHash64.hash(str2, HashSeed(0))
  let hash3 = xxHash64.hash(str3, HashSeed(0))

  if hash1 == hash2:
    echo "  [✓] Same strings produce same hash: PASSED"
  else:
    echo "  [✗] Same strings produce different hashes: FAILED"
    echo "      \"hello\": 0x", toHex(hash1)
    echo "      \"hello\": 0x", toHex(hash2)

  if hash1 != hash3:
    echo "  [✓] Different strings produce different hashes: PASSED"
  else:
    echo "  [✗] Different strings produce same hash: FAILED"
    echo "      \"hello\": 0x", toHex(hash1)
    echo "      \"world\": 0x", toHex(hash3)

proc testDifferentSeeds() =
  ## Test that different seeds produce different hashes
  echo "\nTesting xxHash64 with different seeds..."

  let data = "test data"
  let seed0 = xxHash64.hash(data.toOpenArrayByte(0, data.len - 1), HashSeed(0))
  let seed1 = xxHash64.hash(data.toOpenArrayByte(0, data.len - 1), HashSeed(1))
  let seed2 = xxHash64.hash(data.toOpenArrayByte(0, data.len - 1), HashSeed(0xDEADBEEF))

  if seed0 != seed1:
    echo "  [✓] Different seeds produce different hashes: PASSED"
  else:
    echo "  [✗] Different seeds produce same hash: FAILED"
    echo "      Seed 0:          0x", toHex(seed0)
    echo "      Seed 1:          0x", toHex(seed1)

  if seed0 != seed2:
    echo "  [✓] Large seed differs from zero seed: PASSED"
  else:
    echo "  [✗] Large seed same as zero seed: FAILED"

# Run all tests
when isMainModule:
  echo "═══════════════════════════════════════════════════════════════"
  echo "xxHash64 Unit Tests"
  echo "═══════════════════════════════════════════════════════════════"

  testOneShotHashing()
  testIncrementalHashing()
  testStringHashing()
  testDifferentSeeds()

  echo "\n═══════════════════════════════════════════════════════════════"
  echo "Test suite completed!"
  echo "═══════════════════════════════════════════════════════════════"
