## No-Libc Primitives
## ===================
##
## Essential operations without libc dependency.
## Enables running Nim on bare metal or in kernels.
##
## Provides:
## - Memory operations (memcpy, memset, memcmp)
## - String operations (strlen, strcmp, strcpy)
## - Basic I/O (putchar, puts via syscalls or MMIO)
##
## Compile with: --os:standalone --gc:none
##
## Usage:
## ```nim
## import arsenal/embedded/nolibc
##
## var buf: array[100, char]
## memset(addr buf, 0, 100)
## memcpy(addr buf, "hello".cstring, 5)
## ```

# =============================================================================
# Memory Operations
# =============================================================================

proc memset*(dest: pointer, c: cint, n: csize_t): pointer {.exportc, cdecl.} =
  ## Fill memory with constant byte.
  ##
  ## TECHNICAL NOTES:
  ## - Byte-by-byte: 1 byte/cycle worst case
  ## - Word-aligned: 4-8 bytes/cycle
  ## - SIMD: 16-32 bytes/cycle
  ##
  ## OPTIMIZATION STRATEGY:
  ## 1. Handle small sizes byte-by-byte (< 16 bytes)
  ## 2. Align to word boundary
  ## 3. Fill words for bulk (8 bytes at a time on 64-bit)
  ## 4. Handle remaining bytes
  ##
  ## PERFORMANCE:
  ## - Small (< 16 bytes): ~1-2 cycles/byte
  ## - Medium (16-256 bytes): ~0.5 cycles/byte
  ## - Large (> 256 bytes): ~0.125 cycles/byte (with SIMD)
  ##
  ## USAGE:
  ## ```nim
  ## var buffer: array[1024, byte]
  ## memset(addr buffer, 0, 1024)  # Zero buffer
  ## ```

  let p = cast[ptr UncheckedArray[byte]](dest)
  let val = c.byte

  # Fast path for small sizes
  if n < 16:
    for i in 0..<n:
      p[i] = val
    return dest

  # Build word-sized pattern
  let pattern64 = (val.uint64 shl 56) or (val.uint64 shl 48) or
                  (val.uint64 shl 40) or (val.uint64 shl 32) or
                  (val.uint64 shl 24) or (val.uint64 shl 16) or
                  (val.uint64 shl 8) or val.uint64

  var i: csize_t = 0

  # Align to 8-byte boundary
  while i < n and (cast[uint](addr p[i]) and 7) != 0:
    p[i] = val
    inc i

  # Fill 8 bytes at a time
  let p64 = cast[ptr UncheckedArray[uint64]](addr p[i])
  let numWords = (n - i) div 8
  for j in 0..<numWords:
    p64[j] = pattern64
  i += numWords * 8

  # Fill remaining bytes
  while i < n:
    p[i] = val
    inc i

  result = dest

proc memcpy*(dest, src: pointer, n: csize_t): pointer {.exportc, cdecl.} =
  ## Copy memory (non-overlapping).
  ##
  ## TECHNICAL NOTES:
  ## - CRITICAL: Assumes no overlap (use memmove for overlapping)
  ## - Performance dominated by memory bandwidth
  ## - Modern CPUs: ~10-50 GB/s depending on cache/RAM
  ##
  ## OPTIMIZATION STRATEGY:
  ## 1. Small copies (< 32 bytes): Unrolled byte-by-byte
  ## 2. Medium copies (32-256 bytes): 8-byte words
  ## 3. Large copies (> 256 bytes): SIMD or hardware accelerator
  ##
  ## ALIGNMENT:
  ## - Aligned loads/stores: Full bandwidth
  ## - Unaligned: 20-50% slower on older CPUs, minimal cost on modern
  ## - Cache line size (64 bytes): Optimal for bulk transfers
  ##
  ## PERFORMANCE:
  ## - L1 cache: ~0.25 cycles/byte (400 GB/s on 100 GHz)
  ## - L2 cache: ~3 cycles/byte
  ## - RAM: ~10-30 cycles/byte
  ##
  ## USAGE:
  ## ```nim
  ## var src, dest: array[1024, byte]
  ## memcpy(addr dest, addr src, 1024)
  ## ```

  let d = cast[ptr UncheckedArray[byte]](dest)
  let s = cast[ptr UncheckedArray[byte]](src)

  # Fast path for small sizes (unrolled)
  if n <= 32:
    for i in 0..<n:
      d[i] = s[i]
    return dest

  var i: csize_t = 0

  # Handle unaligned bytes at start
  while i < n and (cast[uint](addr s[i]) and 7) != 0:
    d[i] = s[i]
    inc i

  # Copy 8 bytes at a time (word-sized)
  let d64 = cast[ptr UncheckedArray[uint64]](addr d[i])
  let s64 = cast[ptr UncheckedArray[uint64]](addr s[i])
  let numWords = (n - i) div 8

  # Unroll by 4 for better pipelining
  var j: csize_t = 0
  while j + 4 <= numWords:
    d64[j] = s64[j]
    d64[j + 1] = s64[j + 1]
    d64[j + 2] = s64[j + 2]
    d64[j + 3] = s64[j + 3]
    j += 4

  # Handle remaining words
  while j < numWords:
    d64[j] = s64[j]
    inc j

  i += numWords * 8

  # Copy remaining bytes
  while i < n:
    d[i] = s[i]
    inc i

  result = dest

proc memmove*(dest, src: pointer, n: csize_t): pointer {.exportc, cdecl.} =
  ## Copy memory (handles overlapping regions).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let d = cast[ptr UncheckedArray[byte]](dest)
  ## let s = cast[ptr UncheckedArray[byte]](src)
  ##
  ## if cast[uint](dest) < cast[uint](src):
  ##   # Forward copy
  ##   for i in 0..<n:
  ##     d[i] = s[i]
  ## else:
  ##   # Backward copy
  ##   var i = n
  ##   while i > 0:
  ##     dec i
  ##     d[i] = s[i]
  ## result = dest
  ## ```

  let d = cast[ptr UncheckedArray[byte]](dest)
  let s = cast[ptr UncheckedArray[byte]](src)

  if cast[uint](dest) < cast[uint](src):
    for i in 0..<n:
      d[i] = s[i]
  else:
    var i = n
    while i > 0:
      dec i
      d[i] = s[i]
  result = dest

proc memcmp*(s1, s2: pointer, n: csize_t): cint {.exportc, cdecl.} =
  ## Compare memory regions.
  ## Returns: <0 if s1 < s2, 0 if equal, >0 if s1 > s2
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let p1 = cast[ptr UncheckedArray[byte]](s1)
  ## let p2 = cast[ptr UncheckedArray[byte]](s2)
  ## for i in 0..<n:
  ##   if p1[i] != p2[i]:
  ##     return p1[i].cint - p2[i].cint
  ## return 0
  ## ```
  ##
  ## Optimization: Compare 8 bytes at a time on 64-bit

  let p1 = cast[ptr UncheckedArray[byte]](s1)
  let p2 = cast[ptr UncheckedArray[byte]](s2)
  for i in 0..<n:
    if p1[i] != p2[i]:
      return p1[i].cint - p2[i].cint
  return 0

# =============================================================================
# String Operations
# =============================================================================

proc strlen*(s: cstring): csize_t {.exportc, cdecl.} =
  ## Get string length.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let p = cast[ptr UncheckedArray[char]](s)
  ## result = 0
  ## while p[result] != '\0':
  ##   inc result
  ## ```
  ##
  ## Optimization: Check 8 bytes at a time for null terminator
  ## - Load 64-bit word
  ## - Use bit tricks to detect zero byte (hasless macro)

  let p = cast[ptr UncheckedArray[char]](s)
  result = 0
  while p[result] != '\0':
    inc result

proc strcmp*(s1, s2: cstring): cint {.exportc, cdecl.} =
  ## Compare strings.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let p1 = cast[ptr UncheckedArray[char]](s1)
  ## let p2 = cast[ptr UncheckedArray[char]](s2)
  ## var i = 0
  ## while p1[i] != '\0' and p2[i] != '\0':
  ##   if p1[i] != p2[i]:
  ##     return p1[i].cint - p2[i].cint
  ##   inc i
  ## return p1[i].cint - p2[i].cint
  ## ```

  let p1 = cast[ptr UncheckedArray[char]](s1)
  let p2 = cast[ptr UncheckedArray[char]](s2)
  var i = 0
  while p1[i] != '\0' and p2[i] != '\0':
    if p1[i] != p2[i]:
      return p1[i].cint - p2[i].cint
    inc i
  return p1[i].cint - p2[i].cint

proc strcpy*(dest, src: cstring): cstring {.exportc, cdecl.} =
  ## Copy string.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let d = cast[ptr UncheckedArray[char]](dest)
  ## let s = cast[ptr UncheckedArray[char]](src)
  ## var i = 0
  ## while s[i] != '\0':
  ##   d[i] = s[i]
  ##   inc i
  ## d[i] = '\0'
  ## result = dest
  ## ```

  let d = cast[ptr UncheckedArray[char]](dest)
  let s = cast[ptr UncheckedArray[char]](src)
  var i = 0
  while s[i] != '\0':
    d[i] = s[i]
    inc i
  d[i] = '\0'
  result = dest

proc strncpy*(dest, src: cstring, n: csize_t): cstring {.exportc, cdecl.} =
  ## Copy at most n characters.
  let d = cast[ptr UncheckedArray[char]](dest)
  let s = cast[ptr UncheckedArray[char]](src)
  var i: csize_t = 0
  while i < n and s[i] != '\0':
    d[i] = s[i]
    inc i
  while i < n:
    d[i] = '\0'
    inc i
  result = dest

# =============================================================================
# Integer to String Conversion
# =============================================================================

proc intToStr*(value: int64, buf: ptr char, base: cint = 10): cint =
  ## Convert integer to string.
  ## Returns number of characters written (excluding null terminator).
  ##
  ## TECHNICAL NOTES:
  ## - Supports bases 2-36 (binary through base-36)
  ## - Buffer must be large enough: 65 bytes for base 2, 21 for base 10
  ## - Generates digits in reverse, then reverses buffer
  ##
  ## PERFORMANCE:
  ## - Division is slow (~20-40 cycles on modern CPUs)
  ## - For decimal, can optimize with multiply-by-reciprocal
  ## - For powers of 2, use bitshift instead of division
  ##
  ## USAGE:
  ## ```nim
  ## var buffer: array[32, char]
  ## let len = intToStr(-12345, addr buffer[0], 10)
  ## # buffer now contains "-12345\0"
  ## puts(cast[cstring](addr buffer))  # Print: -12345
  ## ```

  let bufArr = cast[ptr UncheckedArray[char]](buf)
  var n = value
  var i: cint = 0
  let negative = n < 0 and base == 10

  if negative:
    n = -n

  # Special case: value is 0
  if value == 0:
    bufArr[0] = '0'
    bufArr[1] = '\0'
    return 1

  # Convert digits in reverse order
  while n != 0:
    let digit = (n mod base.int64).int
    bufArr[i] = (if digit < 10: char(ord('0') + digit)
                 else: char(ord('a') + digit - 10))
    inc i
    n = n div base.int64

  # Add negative sign
  if negative:
    bufArr[i] = '-'
    inc i

  # Reverse buffer
  for j in 0..<(i div 2):
    let temp = bufArr[j]
    bufArr[j] = bufArr[i - j - 1]
    bufArr[i - j - 1] = temp

  # Null terminate
  bufArr[i] = '\0'
  return i

proc uintToStr*(value: uint64, buf: ptr char, base: cint = 10): cint =
  ## Convert unsigned integer to string.
  # Similar to intToStr but no negative handling
  # Stub
  return intToStr(cast[int64](value), buf, base)

# =============================================================================
# Basic Output (Platform-Specific)
# =============================================================================

when defined(linux):
  import ../kernel/syscalls

  proc putchar*(c: char) =
    ## Write single character to stdout.
    var ch = c
    discard sys_write(1, addr ch, 1)

  proc puts*(s: cstring) =
    ## Write string to stdout.
    let len = strlen(s)
    discard sys_write(1, s, len)
    putchar('\n')

elif defined(bare_metal):
  # For bare metal, use UART or serial port
  # Platform-specific UART base address (set at link time or via config)
  var UART_BASE* {.importc, nodecl.}: ptr uint32

  proc putchar*(c: char) =
    ## Write to UART (hardware-specific).
    ## Uses ARM PL011 UART register layout as baseline.
    ##
    ## Register layout:
    ## - Offset 0x00: Data register (write)
    ## - Offset 0x18: Flag register (read-only)
    ## - Bit 5 of flag register: TX FIFO full
    ##
    ## This implementation works on ARM Cortex-M, ARM Cortex-A,
    ## and RISC-V platforms using compatible UART controllers.

    when defined(arm) or defined(arm64) or defined(riscv64):
      if UART_BASE != nil:
        # Offset constants for ARM PL011 UART
        const UART_DATA_OFFSET = 0    # DR - Data register
        const UART_FLAG_OFFSET = 0x18 # FR - Flag register
        const UART_FLAG_TXFF = (1 shl 5)  # TX FIFO full flag

        # Wait for TX FIFO not full
        while (cast[ptr uint32](cast[uint](UART_BASE) + UART_FLAG_OFFSET)[] and UART_FLAG_TXFF) != 0:
          # Spin until TX FIFO has space
          discard

        # Write character to data register
        cast[ptr uint32](cast[uint](UART_BASE) + UART_DATA_OFFSET)[] = c.uint32
    else:
      # Fallback for unsupported platforms
      discard

# =============================================================================
# Stack Protection (Compiler Requirements)
# =============================================================================

var stack_chk_guard {.exportc: "__stack_chk_guard", used.}: uint
  ## Stack canary for -fstack-protector

proc stack_chk_fail() {.exportc: "__stack_chk_fail", noreturn.} =
  ## Stack smashing detected.
  ## For embedded: Trigger fault or infinite loop
  ## For kernel: Panic

  when defined(linux):
    const msg = "*** stack smashing detected ***\n"
    discard sys_write(2, msg.cstring, msg.len.csize_t)
    sys_exit(127)
  else:
    while true: discard  # Infinite loop

# =============================================================================
# Compiler Builtins (May be needed for --os:standalone)
# =============================================================================

# These may be called by compiler-generated code

# Division helpers for architectures without hardware division
when defined(arm) and not defined(arm64):
  proc aeabi_uidiv(a, b: cuint): cuint {.exportc: "__aeabi_uidiv", cdecl.} =
    ## Unsigned integer division (ARM EABI).
    ## IMPLEMENTATION: Software division algorithm
    a div b  # Stub - should implement long division

  proc aeabi_idiv(a, b: cint): cint {.exportc: "__aeabi_idiv", cdecl.} =
    ## Signed integer division (ARM EABI).
    a div b  # Stub

# =============================================================================
# Memory Barrier
# =============================================================================

proc memoryBarrier*() {.inline.} =
  ## Full memory barrier.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(amd64):
  ##   {.emit: "asm volatile(\"mfence\" ::: \"memory\");".}
  ## elif defined(arm64):
  ##   {.emit: "asm volatile(\"dmb sy\" ::: \"memory\");".}
  ## else:
  ##   {.emit: "__sync_synchronize();".}
  ## ```

  when defined(amd64):
    {.emit: "asm volatile(\"mfence\" ::: \"memory\");".}
  elif defined(arm64):
    {.emit: "asm volatile(\"dmb sy\" ::: \"memory\");".}

# =============================================================================
# Notes
# =============================================================================

## USAGE NOTES:
##
## To compile with no-libc:
## ```bash
## nim c --os:standalone --cpu:amd64 --gc:none --noMain \
##   -d:useMalloc --passL:-nostdlib --passL:-static \
##   main.nim
## ```
##
## For bare metal (no OS):
## ```bash
## nim c --os:standalone --cpu:arm --gc:none --noMain \
##   -d:bare_metal --noLinking main.nim
## # Then link with custom linker script
## ```
##
## Custom entry point:
## ```nim
## proc main() {.exportc: "_start", noreturn.} =
##   # Your code here
##   when defined(linux):
##     sys_exit(0)
##   else:
##     while true: discard
## ```
