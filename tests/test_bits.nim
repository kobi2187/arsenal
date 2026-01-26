## Tests for Bit Manipulation Operations
## =======================================

import std/unittest
import ../src/arsenal/bits/bitops

suite "Count Leading Zeros (CLZ)":
  test "clz of zero":
    check countLeadingZeros(0'u32) == 32
    check countLeadingZeros(0'u64) == 64

  test "clz of powers of 2":
    check countLeadingZeros(1'u32) == 31
    check countLeadingZeros(2'u32) == 30
    check countLeadingZeros(4'u32) == 29
    check countLeadingZeros(8'u32) == 28
    check countLeadingZeros(0x80000000'u32) == 0

  test "clz of arbitrary values":
    check countLeadingZeros(0x00001000'u32) == 19
    check countLeadingZeros(0x0000FFFF'u32) == 16
    check countLeadingZeros(0xFFFFFFFF'u32) == 0

  test "clz 64-bit":
    check countLeadingZeros(1'u64) == 63
    check countLeadingZeros(0x8000000000000000'u64) == 0
    check countLeadingZeros(0x0000000100000000'u64) == 31

  test "clz alias":
    check clz(0x1000'u32) == countLeadingZeros(0x1000'u32)
    check clz(0x1000'u64) == countLeadingZeros(0x1000'u64)

suite "Count Trailing Zeros (CTZ)":
  test "ctz of zero":
    check countTrailingZeros(0'u32) == 32
    check countTrailingZeros(0'u64) == 64

  test "ctz of powers of 2":
    check countTrailingZeros(1'u32) == 0
    check countTrailingZeros(2'u32) == 1
    check countTrailingZeros(4'u32) == 2
    check countTrailingZeros(8'u32) == 3
    check countTrailingZeros(0x80000000'u32) == 31

  test "ctz of arbitrary values":
    check countTrailingZeros(0x00001000'u32) == 12
    check countTrailingZeros(0xFFFF0000'u32) == 16
    check countTrailingZeros(0xFFFFFFFF'u32) == 0

  test "ctz 64-bit":
    check countTrailingZeros(1'u64) == 0
    check countTrailingZeros(0x8000000000000000'u64) == 63
    check countTrailingZeros(0x0000000100000000'u64) == 32

  test "ctz alias":
    check ctz(0x1000'u32) == countTrailingZeros(0x1000'u32)
    check ctz(0x1000'u64) == countTrailingZeros(0x1000'u64)

suite "Population Count (POPCNT)":
  test "popcount of zero":
    check popcount(0'u32) == 0
    check popcount(0'u64) == 0

  test "popcount of all ones":
    check popcount(0xFFFFFFFF'u32) == 32
    check popcount(0xFFFFFFFFFFFFFFFF'u64) == 64

  test "popcount of powers of 2":
    check popcount(1'u32) == 1
    check popcount(2'u32) == 1
    check popcount(4'u32) == 1
    check popcount(0x80000000'u32) == 1

  test "popcount of arbitrary values":
    check popcount(0b10101010'u32) == 4
    check popcount(0b11111111'u32) == 8
    check popcount(0b00001111'u32) == 4
    check popcount(0xAAAAAAAA'u32) == 16  # 1010...1010

  test "popcount 64-bit":
    check popcount(0xAAAAAAAAAAAAAAAA'u64) == 32
    check popcount(0x5555555555555555'u64) == 32

suite "Byte Swap":
  test "byteSwap 16-bit":
    check byteSwap(0x1234'u16) == 0x3412'u16
    check byteSwap(0xABCD'u16) == 0xCDAB'u16

  test "byteSwap 32-bit":
    check byteSwap(0x12345678'u32) == 0x78563412'u32
    check byteSwap(0xABCDEF00'u32) == 0x00EFCDAB'u32

  test "byteSwap 64-bit":
    check byteSwap(0x123456789ABCDEF0'u64) == 0xF0DEBC9A78563412'u64

  test "byteSwap is self-inverse":
    let val32 = 0xDEADBEEF'u32
    check byteSwap(byteSwap(val32)) == val32

    let val64 = 0xDEADBEEFCAFEBABE'u64
    check byteSwap(byteSwap(val64)) == val64

suite "Rotate":
  test "rotateLeft 32-bit":
    check rotateLeft(0x12345678'u32, 0) == 0x12345678'u32
    check rotateLeft(0x12345678'u32, 8) == 0x34567812'u32
    check rotateLeft(0x12345678'u32, 16) == 0x56781234'u32
    check rotateLeft(0x12345678'u32, 24) == 0x78123456'u32
    check rotateLeft(0x12345678'u32, 32) == 0x12345678'u32

  test "rotateLeft 64-bit":
    check rotateLeft(0x123456789ABCDEF0'u64, 0) == 0x123456789ABCDEF0'u64
    check rotateLeft(0x123456789ABCDEF0'u64, 32) == 0x9ABCDEF012345678'u64

  test "rotateRight 32-bit":
    check rotateRight(0x12345678'u32, 0) == 0x12345678'u32
    check rotateRight(0x12345678'u32, 8) == 0x78123456'u32
    check rotateRight(0x12345678'u32, 16) == 0x56781234'u32

  test "rotateRight is inverse of rotateLeft":
    let val = 0xDEADBEEF'u32
    check rotateRight(rotateLeft(val, 13), 13) == val

suite "Power of Two Operations":
  test "isPowerOfTwo":
    check isPowerOfTwo(1'u32)
    check isPowerOfTwo(2'u32)
    check isPowerOfTwo(4'u32)
    check isPowerOfTwo(1024'u32)
    check not isPowerOfTwo(0'u32)
    check not isPowerOfTwo(3'u32)
    check not isPowerOfTwo(1023'u32)

  test "isPowerOfTwo 64-bit":
    check isPowerOfTwo(1'u64)
    check isPowerOfTwo(0x8000000000000000'u64)
    check not isPowerOfTwo(0'u64)
    check not isPowerOfTwo(3'u64)

  test "nextPowerOfTwo":
    check nextPowerOfTwo(0'u32) == 1
    check nextPowerOfTwo(1'u32) == 1
    check nextPowerOfTwo(2'u32) == 2
    check nextPowerOfTwo(3'u32) == 4
    check nextPowerOfTwo(5'u32) == 8
    check nextPowerOfTwo(1023'u32) == 1024
    check nextPowerOfTwo(1024'u32) == 1024
    check nextPowerOfTwo(1025'u32) == 2048

  test "nextPowerOfTwo 64-bit":
    check nextPowerOfTwo(0'u64) == 1
    check nextPowerOfTwo(1'u64) == 1
    check nextPowerOfTwo(1000'u64) == 1024

  test "log2Floor":
    check log2Floor(1'u32) == 0
    check log2Floor(2'u32) == 1
    check log2Floor(3'u32) == 1
    check log2Floor(4'u32) == 2
    check log2Floor(7'u32) == 2
    check log2Floor(8'u32) == 3
    check log2Floor(1024'u32) == 10

  test "log2Floor 64-bit":
    check log2Floor(1'u64) == 0
    check log2Floor(0x8000000000000000'u64) == 63

suite "Bit Extraction":
  test "extractBits basic":
    check extractBits(0b11111111'u64, 0, 4) == 0b1111
    check extractBits(0b11111111'u64, 4, 4) == 0b1111
    check extractBits(0b10101010'u64, 0, 8) == 0b10101010

  test "extractBits from middle":
    check extractBits(0x12345678'u64, 8, 8) == 0x56
    check extractBits(0x12345678'u64, 16, 8) == 0x34

  test "extractBits edge cases":
    check extractBits(0xFFFFFFFFFFFFFFFF'u64, 0, 0) == 0
    check extractBits(0xFFFFFFFFFFFFFFFF'u64, 0, 1) == 1
    check extractBits(0xFFFFFFFFFFFFFFFF'u64, 0, 64) == 0xFFFFFFFFFFFFFFFF'u64

suite "Parallel Bit Operations":
  test "depositBits basic":
    # Deposit bits from contiguous source to positions in mask
    check depositBits(0b11111111'u64, 0b10101010'u64) == 0b10101010'u64
    check depositBits(0b1111'u64, 0b10001000'u64) == 0b10001000'u64

  test "extractBitsParallel basic":
    # Extract bits from positions in mask to contiguous result
    check extractBitsParallel(0b10101010'u64, 0b11111111'u64) == 0b10101010'u64
    check extractBitsParallel(0b10001000'u64, 0b10001000'u64) == 0b11'u64

  test "deposit and extract are inverse":
    let mask = 0b10110110'u64
    let data = 0b1111'u64

    let deposited = depositBits(data, mask)
    let extracted = extractBitsParallel(deposited, mask)

    check extracted == data

suite "Bit Operations Properties":
  test "clz and ctz are complementary":
    let val = 0x00008000'u32  # One bit set
    let clzVal = countLeadingZeros(val)
    let ctzVal = countTrailingZeros(val)

    check clzVal + ctzVal + 1 == 32

  test "popcount after rotation unchanged":
    let val = 0xAAAAAAAA'u32
    let count1 = popcount(val)
    let rotated = rotateLeft(val, 7)
    let count2 = popcount(rotated)

    check count1 == count2

  test "log2Floor and nextPowerOfTwo relationship":
    for i in 1'u32..100:
      let next = nextPowerOfTwo(i)
      if isPowerOfTwo(i):
        check log2Floor(next) == log2Floor(i)
      else:
        check log2Floor(next) == log2Floor(i) + 1

suite "Edge Cases and Corner Values":
  test "operations on maximum values":
    check popcount(uint32.high) == 32
    check popcount(uint64.high) == 64
    check countLeadingZeros(uint32.high) == 0
    check countTrailingZeros(uint32.high) == 0

  test "operations on minimum values":
    check popcount(0'u32) == 0
    check popcount(0'u64) == 0
    check countLeadingZeros(0'u32) == 32
    check countTrailingZeros(0'u64) == 64

  test "rotate by full width":
    let val = 0x12345678'u32
    check rotateLeft(val, 32) == val
    check rotateRight(val, 32) == val

suite "Practical Use Cases":
  test "isolate lowest set bit":
    proc lowestSetBit(x: uint32): uint32 =
      x and (0'u32 - x)

    check lowestSetBit(0b10101000'u32) == 0b1000'u32
    check lowestSetBit(0b10100000'u32) == 0b100000'u32

  test "clear lowest set bit":
    proc clearLowestBit(x: uint32): uint32 =
      x and (x - 1)

    check clearLowestBit(0b10101000'u32) == 0b10100000'u32
    check clearLowestBit(0b10100000'u32) == 0b10000000'u32

  test "round up to power of 2 for allocation":
    proc roundUpAllocation(size: uint32): uint32 =
      if isPowerOfTwo(size):
        size
      else:
        nextPowerOfTwo(size)

    check roundUpAllocation(100) == 128
    check roundUpAllocation(128) == 128
    check roundUpAllocation(129) == 256

  test "count set bits in range":
    proc countBitsInRange(x: uint64, start, length: int): int =
      let extracted = extractBits(x, start, length)
      popcount(extracted)

    check countBitsInRange(0b11111111'u64, 0, 4) == 4
    check countBitsInRange(0b10101010'u64, 0, 8) == 4

  test "check if bit is set at position":
    proc isBitSet(x: uint64, pos: int): bool =
      (x and (1'u64 shl pos)) != 0

    check isBitSet(0b1000'u64, 3)
    check not isBitSet(0b1000'u64, 2)

  test "find first set bit (ffs)":
    proc findFirstSet(x: uint32): int =
      if x == 0:
        return -1
      return countTrailingZeros(x)

    check findFirstSet(0b1000'u32) == 3
    check findFirstSet(0b10000000'u32) == 7
    check findFirstSet(0'u32) == -1

  test "find last set bit":
    proc findLastSet(x: uint32): int =
      if x == 0:
        return -1
      return 31 - countLeadingZeros(x)

    check findLastSet(0b1000'u32) == 3
    check findLastSet(0b10000000'u32) == 7
    check findLastSet(0'u32) == -1
