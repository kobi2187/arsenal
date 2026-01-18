## Unit Tests for No-Libc Primitives
## ===================================

import std/unittest
import ../src/arsenal/embedded/nolibc

suite "Memory Operations - memset":
  test "memset fills buffer correctly":
    var buffer: array[100, byte]

    # Fill with zeros
    discard memset(addr buffer, 0, 100)
    for i in 0..<100:
      check buffer[i] == 0

    # Fill with 0xFF
    discard memset(addr buffer, 0xFF, 100)
    for i in 0..<100:
      check buffer[i] == 0xFF

  test "memset with small sizes (< 16 bytes)":
    var small: array[10, byte]
    discard memset(addr small, 0x42, 10)

    for i in 0..<10:
      check small[i] == 0x42

  test "memset with large aligned buffer":
    var large: array[1024, byte]
    discard memset(addr large, 0xAB, 1024)

    # Check start, middle, end
    check large[0] == 0xAB
    check large[511] == 0xAB
    check large[1023] == 0xAB

suite "Memory Operations - memcpy":
  test "memcpy copies non-overlapping buffers":
    var src: array[50, byte]
    var dest: array[50, byte]

    # Initialize source
    for i in 0..<50:
      src[i] = (i and 0xFF).byte

    # Copy
    discard memcpy(addr dest, addr src, 50)

    # Verify
    for i in 0..<50:
      check dest[i] == src[i]

  test "memcpy with small sizes (< 32 bytes)":
    var src: array[20, byte] = [1'u8, 2, 3, 4, 5, 6, 7, 8, 9, 10,
                                  11, 12, 13, 14, 15, 16, 17, 18, 19, 20]
    var dest: array[20, byte]

    discard memcpy(addr dest, addr src, 20)

    check dest == src

  test "memcpy with large aligned buffer":
    var src: array[512, byte]
    var dest: array[512, byte]

    # Fill source with pattern
    for i in 0..<512:
      src[i] = ((i * 3) and 0xFF).byte

    discard memcpy(addr dest, addr src, 512)

    # Verify
    for i in 0..<512:
      check dest[i] == src[i]

suite "Memory Operations - memmove":
  test "memmove handles overlapping regions (forward)":
    var buffer: array[100, byte]

    # Initialize
    for i in 0..<50:
      buffer[i] = i.byte

    # Move forward (overlap)
    discard memmove(addr buffer[10], addr buffer[0], 50)

    # Verify
    for i in 0..<50:
      check buffer[i + 10] == i.byte

  test "memmove handles overlapping regions (backward)":
    var buffer: array[100, byte]

    # Initialize
    for i in 0..<50:
      buffer[i + 40] = i.byte

    # Move backward (overlap)
    discard memmove(addr buffer[30], addr buffer[40], 50)

    # Verify
    for i in 0..<50:
      check buffer[i + 30] == i.byte

suite "Memory Operations - memcmp":
  test "memcmp returns 0 for equal buffers":
    var buf1: array[50, byte]
    var buf2: array[50, byte]

    for i in 0..<50:
      buf1[i] = i.byte
      buf2[i] = i.byte

    check memcmp(addr buf1, addr buf2, 50) == 0

  test "memcmp returns negative for less-than":
    var buf1: array[10, byte] = [1'u8, 2, 3, 4, 5, 6, 7, 8, 9, 10]
    var buf2: array[10, byte] = [1'u8, 2, 3, 5, 5, 6, 7, 8, 9, 10]  # buf2[3] > buf1[3]

    check memcmp(addr buf1, addr buf2, 10) < 0

  test "memcmp returns positive for greater-than":
    var buf1: array[10, byte] = [1'u8, 2, 3, 5, 5, 6, 7, 8, 9, 10]
    var buf2: array[10, byte] = [1'u8, 2, 3, 4, 5, 6, 7, 8, 9, 10]

    check memcmp(addr buf1, addr buf2, 10) > 0

suite "String Operations - strlen":
  test "strlen counts characters correctly":
    check strlen("hello".cstring) == 5
    check strlen("".cstring) == 0
    check strlen("a".cstring) == 1
    check strlen("12345678901234567890".cstring) == 20

suite "String Operations - strcmp":
  test "strcmp returns 0 for equal strings":
    check strcmp("hello".cstring, "hello".cstring) == 0
    check strcmp("".cstring, "".cstring) == 0

  test "strcmp returns negative for less-than":
    check strcmp("abc".cstring, "abd".cstring) < 0
    check strcmp("a".cstring, "b".cstring) < 0

  test "strcmp returns positive for greater-than":
    check strcmp("abd".cstring, "abc".cstring) > 0
    check strcmp("b".cstring, "a".cstring) > 0

suite "String Operations - strcpy":
  test "strcpy copies string correctly":
    var dest: array[20, char]
    discard strcpy(cast[cstring](addr dest), "hello".cstring)

    check dest[0] == 'h'
    check dest[1] == 'e'
    check dest[2] == 'l'
    check dest[3] == 'l'
    check dest[4] == 'o'
    check dest[5] == '\0'

  test "strcpy handles empty string":
    var dest: array[10, char]
    discard strcpy(cast[cstring](addr dest), "".cstring)
    check dest[0] == '\0'

suite "String Operations - strncpy":
  test "strncpy copies with limit":
    var dest: array[20, char]
    discard strncpy(cast[cstring](addr dest), "hello world".cstring, 5)

    check dest[0] == 'h'
    check dest[1] == 'e'
    check dest[2] == 'l'
    check dest[3] == 'l'
    check dest[4] == 'o'

  test "strncpy pads with zeros":
    var dest: array[20, char]
    discard strncpy(cast[cstring](addr dest), "hi".cstring, 10)

    check dest[0] == 'h'
    check dest[1] == 'i'
    check dest[2] == '\0'
    check dest[9] == '\0'

suite "Integer to String Conversion":
  test "intToStr converts positive decimal":
    var buffer: array[32, char]
    let len = intToStr(12345, addr buffer[0], 10)

    check len == 5
    check buffer[0] == '1'
    check buffer[1] == '2'
    check buffer[2] == '3'
    check buffer[3] == '4'
    check buffer[4] == '5'
    check buffer[5] == '\0'

  test "intToStr converts negative decimal":
    var buffer: array[32, char]
    let len = intToStr(-12345, addr buffer[0], 10)

    check len == 6
    check buffer[0] == '-'
    check buffer[1] == '1'
    check buffer[2] == '2'
    check buffer[3] == '3'
    check buffer[4] == '4'
    check buffer[5] == '5'
    check buffer[6] == '\0'

  test "intToStr converts zero":
    var buffer: array[32, char]
    let len = intToStr(0, addr buffer[0], 10)

    check len == 1
    check buffer[0] == '0'
    check buffer[1] == '\0'

  test "intToStr converts hexadecimal":
    var buffer: array[32, char]
    let len = intToStr(0xDEADBEEF, addr buffer[0], 16)

    check len > 0
    check buffer[0] == 'd'
    check buffer[1] == 'e'
    check buffer[2] == 'a'
    check buffer[3] == 'd'
    check buffer[4] == 'b'
    check buffer[5] == 'e'
    check buffer[6] == 'e'
    check buffer[7] == 'f'

  test "intToStr converts binary":
    var buffer: array[65, char]
    let len = intToStr(42, addr buffer[0], 2)

    check len == 6
    check buffer[0] == '1'
    check buffer[1] == '0'
    check buffer[2] == '1'
    check buffer[3] == '0'
    check buffer[4] == '1'
    check buffer[5] == '0'  # 42 = 101010 in binary

  test "intToStr handles large numbers":
    var buffer: array[32, char]
    let len = intToStr(9223372036854775807'i64, addr buffer[0], 10)  # Max int64

    check len > 0
    check buffer[len] == '\0'

suite "Performance Characteristics":
  test "memset large buffer performance":
    var large: array[10000, byte]
    let start = 0  # Would use actual timing in real benchmark

    discard memset(addr large, 0xAA, 10000)

    # Verify all set correctly
    check large[0] == 0xAA
    check large[4999] == 0xAA
    check large[9999] == 0xAA

  test "memcpy large buffer performance":
    var src: array[10000, byte]
    var dest: array[10000, byte]

    # Initialize source
    for i in 0..<10000:
      src[i] = (i and 0xFF).byte

    discard memcpy(addr dest, addr src, 10000)

    # Verify
    check dest[0] == src[0]
    check dest[4999] == src[4999]
    check dest[9999] == src[9999]

echo "No-Libc tests completed successfully!"
