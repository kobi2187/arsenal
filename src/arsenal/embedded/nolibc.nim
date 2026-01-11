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
  ## IMPLEMENTATION:
  ## ```nim
  ## let p = cast[ptr UncheckedArray[byte]](dest)
  ## let val = c.byte
  ## for i in 0..<n:
  ##   p[i] = val
  ## result = dest
  ## ```
  ##
  ## Optimization: Use SIMD for large blocks
  ## - AVX2: 32 bytes per iteration
  ## - SSE2: 16 bytes per iteration
  ## - Scalar: 8 bytes per iteration (unrolled)

  let p = cast[ptr UncheckedArray[byte]](dest)
  let val = c.byte
  for i in 0..<n:
    p[i] = val
  result = dest

proc memcpy*(dest, src: pointer, n: csize_t): pointer {.exportc, cdecl.} =
  ## Copy memory (non-overlapping).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let d = cast[ptr UncheckedArray[byte]](dest)
  ## let s = cast[ptr UncheckedArray[byte]](src)
  ## for i in 0..<n:
  ##   d[i] = s[i]
  ## result = dest
  ## ```
  ##
  ## Optimization: Use SIMD, unroll loop, check alignment
  ## - If aligned to 16 bytes: Use SSE2 movdqa
  ## - If aligned to 8 bytes: Use 64-bit loads/stores
  ## - Otherwise: Byte-by-byte or align first

  let d = cast[ptr UncheckedArray[byte]](dest)
  let s = cast[ptr UncheckedArray[byte]](src)
  for i in 0..<n:
    d[i] = s[i]
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
  ## Returns number of characters written.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var n = value
  ## var i = 0
  ## let negative = n < 0
  ##
  ## if negative:
  ##   n = -n
  ##
  ## # Convert digits in reverse
  ## repeat:
  ##   let digit = n mod base
  ##   buf[i] = (if digit < 10: '0' + digit else: 'a' + (digit - 10)).char
  ##   inc i
  ##   n = n div base
  ## until n == 0
  ##
  ## if negative:
  ##   buf[i] = '-'
  ##   inc i
  ##
  ## # Reverse buffer
  ## for j in 0..<(i div 2):
  ##   swap(buf[j], buf[i - j - 1])
  ##
  ## buf[i] = '\0'
  ## return i
  ## ```

  # Stub
  buf[] = '0'
  cast[ptr char](cast[uint](buf) + 1)[] = '\0'
  return 1

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
  # This is a placeholder - real implementation depends on hardware
  var UART_BASE* {.importc, nodecl.}: ptr uint32

  proc putchar*(c: char) =
    ## Write to UART (hardware-specific).
    ##
    ## IMPLEMENTATION:
    ## Depends on hardware. Example for ARM PL011 UART:
    ## ```nim
    ## const UART_DATA_OFFSET = 0  # Data register offset
    ## const UART_FLAG_OFFSET = 0x18  # Flag register offset
    ## const UART_FLAG_TXFF = (1 shl 5)  # TX FIFO full flag
    ##
    ## # Wait for TX FIFO not full
    ## while (cast[ptr uint32](cast[uint](UART_BASE) + UART_FLAG_OFFSET)[] and UART_FLAG_TXFF) != 0:
    ##   discard
    ##
    ## # Write character
    ## cast[ptr uint32](cast[uint](UART_BASE) + UART_DATA_OFFSET)[] = c.uint32
    ## ```

    # Stub - requires hardware-specific implementation
    discard

# =============================================================================
# Stack Protection (Compiler Requirements)
# =============================================================================

var __stack_chk_guard* {.exportc, used.}: uint
  ## Stack canary for -fstack-protector

proc `__stack_chk_fail`*() {.exportc, noreturn.} =
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
  proc `__aeabi_uidiv`*(a, b: cuint): cuint {.exportc, cdecl.} =
    ## Unsigned integer division (ARM EABI).
    ## IMPLEMENTATION: Software division algorithm
    a div b  # Stub - should implement long division

  proc `__aeabi_idiv`*(a, b: cint): cint {.exportc, cdecl.} =
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
