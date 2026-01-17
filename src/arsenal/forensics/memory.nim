## Memory Forensics
## =================
##
## Tools for memory acquisition and analysis.
## Supports process memory dumping, pattern scanning, and forensic analysis.
##
## Features:
## - Process memory dumping (Linux /proc, Windows ReadProcessMemory)
## - Memory region enumeration
## - Pattern scanning (byte patterns, strings, regex)
## - Memory diffing
## - Heap analysis
##
## Usage:
## ```nim
## import arsenal/forensics/memory
##
## # Dump process memory
## let pid = 1234
## let regions = enumMemoryRegions(pid)
## for region in regions:
##   echo "Region: 0x", region.start.toHex, " - 0x", region.`end`.toHex
##
## # Scan for pattern
## let matches = scanMemory(pid, "password".toOpenArrayByte(0, 7))
## ```

import std/strutils
import std/os

when defined(linux):
  import ../kernel/syscalls

# =============================================================================
# Types
# =============================================================================

type
  MemoryRegion* = object
    ## Memory region information
    start*: uint64                # Start address
    `end`*: uint64                # End address
    size*: uint64                 # Size in bytes
    permissions*: set[MemPerm]    # Permissions (r/w/x)
    path*: string                 # Mapped file path (if any)

  MemPerm* = enum
    ## Memory permissions
    Read
    Write
    Execute
    Shared
    Private

  MemoryMatch* = object
    ## Pattern match result
    address*: uint64              # Address of match
    data*: seq[uint8]             # Matched data
    context*: seq[uint8]          # Surrounding context

  ProcessMemoryDump* = object
    ## Complete process memory dump
    pid*: int
    regions*: seq[MemoryRegion]
    data*: Table[uint64, seq[uint8]]  # Region start -> data

# =============================================================================
# Linux: /proc/pid/maps and /proc/pid/mem
# =============================================================================

when defined(linux):
  import std/tables

  proc parseMapsLine(line: string): MemoryRegion =
    ## Parse a line from /proc/pid/maps
    ## Format: address perms offset dev inode pathname
    ## Example: 00400000-00452000 r-xp 00000000 08:02 173521 /usr/bin/dbus-daemon
    let parts = line.split(' ')
    if parts.len < 2:
      return

    # Parse address range
    let addrRange = parts[0].split('-')
    if addrRange.len != 2:
      return

    result.start = parseHexInt(addrRange[0]).uint64
    result.`end` = parseHexInt(addrRange[1]).uint64
    result.size = result.`end` - result.start

    # Parse permissions
    let perms = parts[1]
    if 'r' in perms: result.permissions.incl(Read)
    if 'w' in perms: result.permissions.incl(Write)
    if 'x' in perms: result.permissions.incl(Execute)
    if 's' in perms: result.permissions.incl(Shared)
    if 'p' in perms: result.permissions.incl(Private)

    # Parse pathname (if present)
    if parts.len >= 6:
      result.path = parts[5..^1].join(" ")

  proc enumMemoryRegions*(pid: int): seq[MemoryRegion] =
    ## Enumerate memory regions of a process (Linux)
    let mapsPath = "/proc/" & $pid & "/maps"
    if not fileExists(mapsPath):
      raise newException(IOError, "Process not found or no permission")

    for line in lines(mapsPath):
      let region = parseMapsLine(line)
      if region.size > 0:
        result.add(region)

  proc readProcessMemory*(pid: int, address: uint64, size: int): seq[uint8] =
    ## Read process memory at address (Linux)
    ## Uses /proc/pid/mem
    let memPath = "/proc/" & $pid & "/mem"
    var f: File
    if not open(f, memPath, fmRead):
      raise newException(IOError, "Cannot open " & memPath)

    try:
      f.setFilePos(address.int64)
      result = newSeq[uint8](size)
      let bytesRead = f.readBuffer(addr result[0], size)
      if bytesRead != size:
        raise newException(IOError, "Incomplete read")
    finally:
      f.close()

  proc readMemoryRegion*(pid: int, region: MemoryRegion): seq[uint8] =
    ## Read entire memory region
    readProcessMemory(pid, region.start, region.size.int)

  proc dumpProcessMemory*(pid: int): ProcessMemoryDump =
    ## Dump all readable memory regions of a process
    result.pid = pid
    result.regions = enumMemoryRegions(pid)

    for region in result.regions:
      # Only dump readable regions
      if Read in region.permissions:
        try:
          let data = readMemoryRegion(pid, region)
          result.data[region.start] = data
        except IOError:
          # Some regions may fail to read (permissions, mapped files, etc.)
          discard

elif defined(windows):
  # Windows implementation using ReadProcessMemory
  type
    HANDLE = pointer
    DWORD = uint32
    SIZE_T = uint
    LPCVOID = pointer
    LPVOID = pointer
    BOOL = cint

  proc OpenProcess(dwDesiredAccess: DWORD, bInheritHandle: BOOL, dwProcessId: DWORD): HANDLE
    {.stdcall, dynlib: "kernel32", importc: "OpenProcess".}

  proc ReadProcessMemory(hProcess: HANDLE, lpBaseAddress: LPCVOID,
                         lpBuffer: LPVOID, nSize: SIZE_T,
                         lpNumberOfBytesRead: ptr SIZE_T): BOOL
    {.stdcall, dynlib: "kernel32", importc: "ReadProcessMemory".}

  proc CloseHandle(hObject: HANDLE): BOOL
    {.stdcall, dynlib: "kernel32", importc: "CloseHandle".}

  const
    PROCESS_VM_READ = 0x0010
    PROCESS_QUERY_INFORMATION = 0x0400

  proc readProcessMemory*(pid: int, address: uint64, size: int): seq[uint8] =
    ## Read process memory (Windows)
    let hProcess = OpenProcess(PROCESS_VM_READ or PROCESS_QUERY_INFORMATION,
                                0, pid.DWORD)
    if hProcess == nil:
      raise newException(IOError, "Cannot open process")

    result = newSeq[uint8](size)
    var bytesRead: SIZE_T
    let success = ReadProcessMemory(hProcess,
                                    cast[LPCVOID](address),
                                    addr result[0],
                                    size.SIZE_T,
                                    addr bytesRead)

    discard CloseHandle(hProcess)

    if success == 0 or bytesRead.int != size:
      raise newException(IOError, "ReadProcessMemory failed")

# =============================================================================
# Memory Scanning
# =============================================================================

proc scanBytes*(data: openArray[uint8], pattern: openArray[uint8]): seq[int] =
  ## Search for byte pattern in data
  ## Returns list of offsets where pattern was found
  if pattern.len == 0 or data.len < pattern.len:
    return

  for i in 0..(data.len - pattern.len):
    var match = true
    for j in 0..<pattern.len:
      if data[i + j] != pattern[j]:
        match = false
        break
    if match:
      result.add(i)

proc scanMemory*(pid: int, pattern: openArray[uint8]): seq[MemoryMatch] =
  ## Scan process memory for byte pattern
  when defined(linux):
    let regions = enumMemoryRegions(pid)

    for region in regions:
      if Read notin region.permissions:
        continue

      try:
        let data = readMemoryRegion(pid, region)
        let offsets = scanBytes(data, pattern)

        for offset in offsets:
          var match = MemoryMatch(
            address: region.start + offset.uint64
          )

          # Extract matched data
          match.data = newSeq[uint8](pattern.len)
          for i in 0..<pattern.len:
            match.data[i] = data[offset + i]

          # Extract context (32 bytes before and after)
          let contextSize = 32
          let contextStart = max(0, offset - contextSize)
          let contextEnd = min(data.len, offset + pattern.len + contextSize)
          match.context = newSeq[uint8](contextEnd - contextStart)
          for i in contextStart..<contextEnd:
            match.context[i - contextStart] = data[i]

          result.add(match)
      except IOError:
        continue

proc scanString*(pid: int, str: string): seq[MemoryMatch] =
  ## Scan process memory for string
  scanMemory(pid, cast[seq[uint8]](str))

# =============================================================================
# String Extraction
# =============================================================================

proc extractStrings*(data: openArray[uint8], minLen: int = 4): seq[string] =
  ## Extract printable ASCII strings from data
  ## Minimum length defaults to 4 characters
  var currentString = ""

  for i in 0..<data.len:
    let c = data[i].char

    # Printable ASCII (space to ~)
    if c >= ' ' and c <= '~':
      currentString.add(c)
    else:
      if currentString.len >= minLen:
        result.add(currentString)
      currentString = ""

  # Add last string if meets criteria
  if currentString.len >= minLen:
    result.add(currentString)

proc extractUnicodeStrings*(data: openArray[uint8], minLen: int = 4): seq[string] =
  ## Extract Unicode (UTF-16LE) strings from data
  var currentString = ""
  var i = 0

  while i + 1 < data.len:
    let c1 = data[i]
    let c2 = data[i + 1]

    # UTF-16LE: low byte first, high byte should be 0 for ASCII
    if c2 == 0 and c1 >= 32 and c1 <= 126:
      currentString.add(c1.char)
    else:
      if currentString.len >= minLen:
        result.add(currentString)
      currentString = ""

    i += 2

  if currentString.len >= minLen:
    result.add(currentString)

# =============================================================================
# Memory Diffing
# =============================================================================

type
  MemoryDiff* = object
    ## Memory diff result
    offset*: int
    oldValue*: uint8
    newValue*: uint8

proc diffMemory*(old, new: openArray[uint8]): seq[MemoryDiff] =
  ## Find differences between two memory snapshots
  let minLen = min(old.len, new.len)

  for i in 0..<minLen:
    if old[i] != new[i]:
      result.add(MemoryDiff(
        offset: i,
        oldValue: old[i],
        newValue: new[i]
      ))

  # Handle size differences
  if old.len != new.len:
    let maxLen = max(old.len, new.len)
    for i in minLen..<maxLen:
      if i < old.len:
        result.add(MemoryDiff(offset: i, oldValue: old[i], newValue: 0))
      else:
        result.add(MemoryDiff(offset: i, oldValue: 0, newValue: new[i]))

# =============================================================================
# Hex Dump
# =============================================================================

proc hexDump*(data: openArray[uint8], baseAddress: uint64 = 0): string =
  ## Create hex dump of data (like xxd or hexdump)
  ## Format: ADDRESS  HEX                              ASCII
  const bytesPerLine = 16

  for lineStart in countup(0, data.len - 1, bytesPerLine):
    # Address
    result.add((baseAddress + lineStart.uint64).toHex(8))
    result.add("  ")

    # Hex bytes
    for i in 0..<bytesPerLine:
      let offset = lineStart + i
      if offset < data.len:
        result.add(data[offset].toHex(2))
        result.add(" ")
      else:
        result.add("   ")

      # Space after 8 bytes
      if i == 7:
        result.add(" ")

    result.add(" ")

    # ASCII representation
    for i in 0..<bytesPerLine:
      let offset = lineStart + i
      if offset < data.len:
        let c = data[offset].char
        if c >= ' ' and c <= '~':
          result.add(c)
        else:
          result.add('.')
      else:
        result.add(' ')

    result.add("\n")

# =============================================================================
# Helper Functions
# =============================================================================

proc `$`*(region: MemoryRegion): string =
  ## String representation of memory region
  result = "0x" & region.start.toHex & "-0x" & region.`end`.toHex & " "
  result.add(if Read in region.permissions: "r" else: "-")
  result.add(if Write in region.permissions: "w" else: "-")
  result.add(if Execute in region.permissions: "x" else: "-")
  result.add(if Shared in region.permissions: "s" else:
             if Private in region.permissions: "p" else: "-")
  result.add(" " & $region.size & " bytes")
  if region.path.len > 0:
    result.add(" " & region.path)

proc `$`*(match: MemoryMatch): string =
  result = "Match at 0x" & match.address.toHex & ":\n"
  result.add(hexDump(match.data, match.address))
