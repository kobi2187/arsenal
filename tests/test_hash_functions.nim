## Unit Tests for Hash Functions
## ==============================

import std/unittest
import ../src/arsenal/hashing/hashers/xxhash64
import ../src/arsenal/hashing/hashers/wyhash

suite "XXHash64 - One-shot Hashing":
  test "hash produces consistent output":
    let data = "hello world"
    let hash1 = XxHash64.hash(data, DefaultSeed)
    let hash2 = XxHash64.hash(data, DefaultSeed)

    check hash1 == hash2

  test "hash different data produces different output":
    let hash1 = XxHash64.hash("hello", DefaultSeed)
    let hash2 = XxHash64.hash("world", DefaultSeed)

    check hash1 != hash2

  test "hash with different seeds produces different output":
    let data = "test data"
    let hash1 = XxHash64.hash(data, HashSeed(0))
    let hash2 = XxHash64.hash(data, HashSeed(42))

    check hash1 != hash2

  test "hash empty string":
    let hash = XxHash64.hash("", DefaultSeed)
    check hash != 0  # Should produce non-zero hash

  test "hash large data":
    var largeData: string = ""
    for i in 0..<10000:
      largeData.add(char(i and 0xFF))

    let hash = XxHash64.hash(largeData, DefaultSeed)
    check hash != 0

suite "XXHash64 - Incremental Hashing":
  test "incremental hash matches one-shot":
    let data = "hello world"

    # One-shot
    let oneShot = XxHash64.hash(data, DefaultSeed)

    # Incremental
    var state = XxHash64.init(DefaultSeed)
    state.update(data)
    let incremental = state.finish()

    check oneShot == incremental

  test "incremental hash with multiple updates":
    let part1 = "hello "
    let part2 = "world"

    # One-shot
    let oneShot = XxHash64.hash("hello world", DefaultSeed)

    # Incremental
    var state = XxHash64.init(DefaultSeed)
    state.update(part1)
    state.update(part2)
    let incremental = state.finish()

    check oneShot == incremental

  test "incremental hash with many small updates":
    var state = XxHash64.init(DefaultSeed)

    # Update one character at a time
    for c in "testing incremental hashing":
      state.update($c)

    let incremental = state.finish()

    # Compare with one-shot
    let oneShot = XxHash64.hash("testing incremental hashing", DefaultSeed)

    check oneShot == incremental

  test "incremental hash with 32-byte chunks":
    var data: array[128, byte]
    for i in 0..<128:
      data[i] = i.byte

    # One-shot
    let oneShot = XxHash64.hash(data, DefaultSeed)

    # Incremental (32-byte chunks)
    var state = XxHash64.init(DefaultSeed)
    for i in countup(0, 96, 32):  # 0, 32, 64, 96
      state.update(data.toOpenArray(i, i + 31))
    let incremental = state.finish()

    check oneShot == incremental

  test "reset state works correctly":
    var state = XxHash64.init(DefaultSeed)
    state.update("some data")

    state.reset()

    state.update("hello")
    let hash = state.finish()

    # Should match fresh hash of "hello"
    let expected = XxHash64.hash("hello", DefaultSeed)
    check hash == expected

suite "WyHash - One-shot Hashing":
  test "hash produces consistent output":
    let data = "hello world"
    let hash1 = WyHash.hash(data, DefaultSeed)
    let hash2 = WyHash.hash(data, DefaultSeed)

    check hash1 == hash2

  test "hash different data produces different output":
    let hash1 = WyHash.hash("hello", DefaultSeed)
    let hash2 = WyHash.hash("world", DefaultSeed)

    check hash1 != hash2

  test "hash with different seeds":
    let data = "test"
    let hash1 = WyHash.hash(data, HashSeed(0))
    let hash2 = WyHash.hash(data, HashSeed(123))

    check hash1 != hash2

  test "hash empty data":
    let hash = WyHash.hash("", DefaultSeed)
    check hash != 0

  test "hash small data (< 16 bytes)":
    let hash1 = WyHash.hash("abc", DefaultSeed)
    let hash2 = WyHash.hash("abcd", DefaultSeed)
    let hash3 = WyHash.hash("abcdefghijklmno", DefaultSeed)  # 15 bytes

    check hash1 != hash2
    check hash2 != hash3

  test "hash medium data (16-48 bytes)":
    let data = "This is exactly 32 bytes long!!"  # 32 bytes
    let hash = WyHash.hash(data, DefaultSeed)

    check hash != 0

  test "hash large data (> 48 bytes)":
    var largeData: string = ""
    for i in 0..<100:
      largeData.add(char((i and 0xFF)))

    let hash = WyHash.hash(largeData, DefaultSeed)
    check hash != 0

suite "WyHash - Incremental Hashing":
  test "incremental hash matches one-shot":
    let data = "hello world"

    # One-shot
    let oneShot = WyHash.hash(data, DefaultSeed)

    # Incremental
    var state = WyHash.init(DefaultSeed)
    state.update(data)
    let incremental = state.finish()

    check oneShot == incremental

  test "incremental with multiple updates":
    let part1 = "hello "
    let part2 = "world"

    # One-shot
    let oneShot = WyHash.hash("hello world", DefaultSeed)

    # Incremental
    var state = WyHash.init(DefaultSeed)
    state.update(part1)
    state.update(part2)
    let incremental = state.finish()

    check oneShot == incremental

  test "incremental with 48-byte chunks":
    var data: array[192, byte]
    for i in 0..<192:
      data[i] = i.byte

    # One-shot
    let oneShot = WyHash.hash(data, DefaultSeed)

    # Incremental (48-byte chunks)
    var state = WyHash.init(DefaultSeed)
    for i in countup(0, 144, 48):  # 0, 48, 96, 144
      state.update(data.toOpenArray(i, i + 47))
    let incremental = state.finish()

    check oneShot == incremental

  test "incremental with small data (< 16 bytes)":
    let data = "small"

    let oneShot = WyHash.hash(data, DefaultSeed)

    var state = WyHash.init(DefaultSeed)
    state.update(data)
    let incremental = state.finish()

    check oneShot == incremental

  test "reset state works":
    var state = WyHash.init(DefaultSeed)
    state.update("some data")

    state.reset()

    state.update("hello")
    let hash = state.finish()

    let expected = WyHash.hash("hello", DefaultSeed)
    check hash == expected

suite "Hash Function Properties":
  test "XXHash64 avalanche effect":
    # Changing one bit should affect roughly half the output bits
    let hash1 = XxHash64.hash("test", DefaultSeed)
    let hash2 = XxHash64.hash("tast", DefaultSeed)  # Changed one character

    # Hashes should be very different
    check hash1 != hash2

    # Count different bits (avalanche)
    var diff = hash1 xor hash2
    var bitCount = 0
    while diff != 0:
      if (diff and 1) != 0:
        inc bitCount
      diff = diff shr 1

    # Expect roughly 32 bits different (out of 64)
    check bitCount > 20  # At least 20 bits changed

  test "WyHash avalanche effect":
    let hash1 = WyHash.hash("test", DefaultSeed)
    let hash2 = WyHash.hash("tast", DefaultSeed)

    check hash1 != hash2

    var diff = hash1 xor hash2
    var bitCount = 0
    while diff != 0:
      if (diff and 1) != 0:
        inc bitCount
      diff = diff shr 1

    check bitCount > 20

  test "XXHash64 distribution test":
    # Hash many values and check distribution
    var hashes: seq[uint64]
    for i in 0..<1000:
      hashes.add(XxHash64.hash($i, DefaultSeed))

    # All hashes should be unique for sequential inputs
    var uniqueCount = 0
    for i in 0..<hashes.len:
      var isUnique = true
      for j in 0..<i:
        if hashes[i] == hashes[j]:
          isUnique = false
          break
      if isUnique:
        inc uniqueCount

    # Expect all unique (no collisions in small sample)
    check uniqueCount == 1000

  test "WyHash distribution test":
    var hashes: seq[uint64]
    for i in 0..<1000:
      hashes.add(WyHash.hash($i, DefaultSeed))

    var uniqueCount = 0
    for i in 0..<hashes.len:
      var isUnique = true
      for j in 0..<i:
        if hashes[i] == hashes[j]:
          isUnique = false
          break
      if isUnique:
        inc uniqueCount

    check uniqueCount == 1000

echo "Hash function tests completed successfully!"
