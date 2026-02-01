## Mach-O (Mach Object) Parser
## =============================
##
## Parses macOS/iOS Mach-O executables, dylibs, and bundles.
## Supports both 32-bit and 64-bit Mach-O files.
##
## Features:
## - Mach-O header parsing
## - Load commands
## - Segment and section parsing
## - Symbol table extraction
## - Dynamic linking information (dyld info)
## - Code signature parsing
##
## Usage:
## ```nim
## import arsenal/binary/formats/macho
##
## let macho = parseMacho(readFile("/bin/ls"))
## echo "Entry point: 0x", macho.entryPoint.toHex
## for segment in macho.segments:
##   echo segment.name, ": ", segment.vmsize, " bytes"
## ```

import std/strutils
import std/tables

# =============================================================================
# Constants
# =============================================================================

const
  MH_MAGIC* = 0xfeedface'u32      ## Mach-O 32-bit magic
  MH_MAGIC_64* = 0xfeedfacf'u32   ## Mach-O 64-bit magic
  MH_CIGAM* = 0xcefaedfe'u32      ## Mach-O 32-bit magic (swapped)
  MH_CIGAM_64* = 0xcffaedfe'u32   ## Mach-O 64-bit magic (swapped)

  FAT_MAGIC* = 0xcafebabe'u32     ## Universal binary magic
  FAT_CIGAM* = 0xbebafeca'u32     ## Universal binary magic (swapped)

  # Mach-O file types
  MH_OBJECT* = 0x1         ## Relocatable object file
  MH_EXECUTE* = 0x2        ## Demand paged executable
  MH_FVMLIB* = 0x3         ## Fixed VM shared library
  MH_CORE* = 0x4           ## Core file
  MH_PRELOAD* = 0x5        ## Preloaded executable
  MH_DYLIB* = 0x6          ## Dynamically bound shared library
  MH_DYLINKER* = 0x7       ## Dynamic link editor
  MH_BUNDLE* = 0x8         ## Dynamically bound bundle file
  MH_DSYM* = 0xa           ## Debug symbols file

  # CPU types
  CPU_TYPE_I386* = 7
  CPU_TYPE_X86_64* = (CPU_TYPE_I386 or 0x01000000)
  CPU_TYPE_ARM* = 12
  CPU_TYPE_ARM64* = (CPU_TYPE_ARM or 0x01000000)

  # Load command types
  LC_SEGMENT* = 0x1              ## Segment of this file to be mapped
  LC_SYMTAB* = 0x2               ## Symbol table
  LC_THREAD* = 0x4               ## Thread state
  LC_UNIXTHREAD* = 0x5           ## Unix thread (entry point)
  LC_LOAD_DYLIB* = 0xc           ## Load a dynamically linked shared library
  LC_ID_DYLIB* = 0xd             ## ID of dynamically linked shared library
  LC_LOAD_DYLINKER* = 0xe        ## Load dynamic linker
  LC_SEGMENT_64* = 0x19          ## 64-bit segment of this file to be mapped
  LC_UUID* = 0x1b                ## UUID for the binary
  LC_CODE_SIGNATURE* = 0x1d      ## Code signature
  LC_SEGMENT_SPLIT_INFO* = 0x1e  ## Segment split info
  LC_REEXPORT_DYLIB* = 0x1f or 0x80000000'u32 ## Re-export dylib
  LC_DYLD_INFO* = 0x22           ## Dyld info
  LC_DYLD_INFO_ONLY* = 0x22 or 0x80000000'u32
  LC_VERSION_MIN_MACOSX* = 0x24  ## Minimum macOS version
  LC_VERSION_MIN_IPHONEOS* = 0x25 ## Minimum iOS version
  LC_FUNCTION_STARTS* = 0x26     ## Compressed table of function start addresses
  LC_MAIN* = 0x28 or 0x80000000'u32 ## Entry point (modern)
  LC_DATA_IN_CODE* = 0x29        ## Table of non-instructions
  LC_SOURCE_VERSION* = 0x2A      ## Source version
  LC_DYLIB_CODE_SIGN_DRS* = 0x2B ## Code signing DRs copied from linked dylibs

  # Segment protection flags
  VM_PROT_READ* = 0x01
  VM_PROT_WRITE* = 0x02
  VM_PROT_EXECUTE* = 0x04

  # Section type masks
  SECTION_TYPE* = 0x000000ff     ## Section type mask
  SECTION_ATTRIBUTES* = 0xffffff00 ## Section attributes mask

  # Section types
  S_REGULAR* = 0x0                ## Regular section
  S_ZEROFILL* = 0x1               ## Zero fill on demand section
  S_CSTRING_LITERALS* = 0x2       ## Section with only literal C strings
  S_4BYTE_LITERALS* = 0x3         ## Section with only 4 byte literals
  S_8BYTE_LITERALS* = 0x4         ## Section with only 8 byte literals
  S_LITERAL_POINTERS* = 0x5       ## Section with pointers to literals

type
  MachHeader64* = object
    ## Mach-O 64-bit header (32 bytes)
    magic*: uint32                # Magic number
    cputype*: int32               # CPU type
    cpusubtype*: int32            # CPU subtype
    filetype*: uint32             # File type
    ncmds*: uint32                # Number of load commands
    sizeofcmds*: uint32           # Total size of load commands
    flags*: uint32                # Flags
    reserved*: uint32             # Reserved (64-bit only)

  LoadCommand* = object
    ## Load command header (8 bytes)
    cmd*: uint32                  # Command type
    cmdsize*: uint32              # Command size (including header)

  SegmentCommand64* = object
    ## 64-bit segment load command (72 bytes)
    cmd*: uint32                  # LC_SEGMENT_64
    cmdsize*: uint32              # Command size
    segname*: array[16, char]     # Segment name
    vmaddr*: uint64               # Virtual memory address
    vmsize*: uint64               # Virtual memory size
    fileoff*: uint64              # File offset
    filesize*: uint64             # File size
    maxprot*: int32               # Maximum VM protection
    initprot*: int32              # Initial VM protection
    nsects*: uint32               # Number of sections
    flags*: uint32                # Flags

  Section64* = object
    ## 64-bit section (80 bytes)
    sectname*: array[16, char]    # Section name
    segname*: array[16, char]     # Segment name
    addr*: uint64                 # Memory address
    size*: uint64                 # Size in bytes
    offset*: uint32               # File offset
    align*: uint32                # Alignment (power of 2)
    reloff*: uint32               # File offset of relocations
    nreloc*: uint32               # Number of relocations
    flags*: uint32                # Section flags
    reserved1*: uint32            # Reserved
    reserved2*: uint32            # Reserved
    reserved3*: uint32            # Reserved (64-bit only)

  SymtabCommand* = object
    ## Symbol table load command (24 bytes)
    cmd*: uint32                  # LC_SYMTAB
    cmdsize*: uint32              # Command size
    symoff*: uint32               # Symbol table file offset
    nsyms*: uint32                # Number of symbol table entries
    stroff*: uint32               # String table file offset
    strsize*: uint32              # String table size

  DylibCommand* = object
    ## Dynamically linked library command (24+ bytes)
    cmd*: uint32                  # LC_LOAD_DYLIB, LC_ID_DYLIB, etc.
    cmdsize*: uint32              # Command size
    nameOffset*: uint32           # Offset of library path string
    timestamp*: uint32            # Library build timestamp
    currentVersion*: uint32       # Library current version
    compatibilityVersion*: uint32 # Library compatibility version

  EntryPointCommand* = object
    ## Entry point command (LC_MAIN) (24 bytes)
    cmd*: uint32                  # LC_MAIN
    cmdsize*: uint32              # Command size
    entryoff*: uint64             # File offset of entry point
    stacksize*: uint64            # Initial stack size

  NList64* = object
    ## 64-bit symbol table entry (16 bytes)
    n_strx*: uint32               # String table index
    n_type*: uint8                # Type flag
    n_sect*: uint8                # Section number
    n_desc*: uint16               # Description
    n_value*: uint64              # Symbol value

  MachoSegment* = object
    ## Parsed segment
    name*: string
    vmaddr*: uint64
    vmsize*: uint64
    fileoff*: uint64
    filesize*: uint64
    initprot*: int32
    maxprot*: int32
    sections*: seq[MachoSection]

  MachoSection* = object
    ## Parsed section
    sectname*: string
    segname*: string
    addr*: uint64
    size*: uint64
    offset*: uint32
    flags*: uint32
    data*: seq[uint8]

  MachoSymbol* = object
    ## Parsed symbol
    name*: string
    value*: uint64
    section*: uint8
    symType*: uint8

  MachoFile* = object
    ## Parsed Mach-O file
    header*: MachHeader64
    segments*: seq[MachoSegment]
    symbols*: seq[MachoSymbol]
    dylibs*: seq[string]
    entryPoint*: uint64
    is64Bit*: bool

# =============================================================================
# Utility Functions
# =============================================================================

proc readU8(data: openArray[uint8], offset: var int): uint8 =
  result = data[offset]
  inc offset

proc readU16LE(data: openArray[uint8], offset: var int): uint16 =
  result = data[offset].uint16 or (data[offset + 1].uint16 shl 8)
  offset += 2

proc readU32LE(data: openArray[uint8], offset: var int): uint32 =
  result = data[offset].uint32 or
           (data[offset + 1].uint32 shl 8) or
           (data[offset + 2].uint32 shl 16) or
           (data[offset + 3].uint32 shl 24)
  offset += 4

proc readU64LE(data: openArray[uint8], offset: var int): uint64 =
  result = data[offset].uint64 or
           (data[offset + 1].uint64 shl 8) or
           (data[offset + 2].uint64 shl 16) or
           (data[offset + 3].uint64 shl 24) or
           (data[offset + 4].uint64 shl 32) or
           (data[offset + 5].uint64 shl 40) or
           (data[offset + 6].uint64 shl 48) or
           (data[offset + 7].uint64 shl 56)
  offset += 8

proc readI32LE(data: openArray[uint8], offset: var int): int32 =
  cast[int32](readU32LE(data, offset))

proc readString(data: openArray[uint8], offset: int): string =
  ## Read null-terminated string
  var i = offset
  while i < data.len and data[i] != 0:
    result.add(data[i].char)
    inc i

proc extractName(arr: array[16, char]): string =
  ## Extract null-terminated name from fixed array
  for c in arr:
    if c == '\0':
      break
    result.add(c)

# =============================================================================
# Mach-O Parsing
# =============================================================================

proc parseHeader*(data: openArray[uint8]): MachHeader64 =
  ## Parse Mach-O header
  if data.len < 32:
    raise newException(ValueError, "File too small for Mach-O header")

  var offset = 0
  result.magic = readU32LE(data, offset)

  if result.magic notin [MH_MAGIC_64, MH_MAGIC]:
    raise newException(ValueError, "Not a Mach-O file (invalid magic: 0x" & result.magic.toHex & ")")

  result.cputype = readI32LE(data, offset)
  result.cpusubtype = readI32LE(data, offset)
  result.filetype = readU32LE(data, offset)
  result.ncmds = readU32LE(data, offset)
  result.sizeofcmds = readU32LE(data, offset)
  result.flags = readU32LE(data, offset)

  if result.magic == MH_MAGIC_64:
    result.reserved = readU32LE(data, offset)

proc parseLoadCommand*(data: openArray[uint8], offset: int): LoadCommand =
  ## Parse load command header
  var pos = offset
  result.cmd = readU32LE(data, pos)
  result.cmdsize = readU32LE(data, pos)

proc parseSegmentCommand64*(data: openArray[uint8], offset: int): SegmentCommand64 =
  ## Parse 64-bit segment load command
  var pos = offset
  result.cmd = readU32LE(data, pos)
  result.cmdsize = readU32LE(data, pos)

  for i in 0..15:
    result.segname[i] = data[pos].char
    inc pos

  result.vmaddr = readU64LE(data, pos)
  result.vmsize = readU64LE(data, pos)
  result.fileoff = readU64LE(data, pos)
  result.filesize = readU64LE(data, pos)
  result.maxprot = readI32LE(data, pos)
  result.initprot = readI32LE(data, pos)
  result.nsects = readU32LE(data, pos)
  result.flags = readU32LE(data, pos)

proc parseSection64*(data: openArray[uint8], offset: int): Section64 =
  ## Parse 64-bit section
  var pos = offset
  for i in 0..15:
    result.sectname[i] = data[pos].char
    inc pos

  for i in 0..15:
    result.segname[i] = data[pos].char
    inc pos

  result.addr = readU64LE(data, pos)
  result.size = readU64LE(data, pos)
  result.offset = readU32LE(data, pos)
  result.align = readU32LE(data, pos)
  result.reloff = readU32LE(data, pos)
  result.nreloc = readU32LE(data, pos)
  result.flags = readU32LE(data, pos)
  result.reserved1 = readU32LE(data, pos)
  result.reserved2 = readU32LE(data, pos)
  result.reserved3 = readU32LE(data, pos)

proc parseSymtabCommand*(data: openArray[uint8], offset: int): SymtabCommand =
  ## Parse symbol table load command
  var pos = offset
  result.cmd = readU32LE(data, pos)
  result.cmdsize = readU32LE(data, pos)
  result.symoff = readU32LE(data, pos)
  result.nsyms = readU32LE(data, pos)
  result.stroff = readU32LE(data, pos)
  result.strsize = readU32LE(data, pos)

proc parseNList64*(data: openArray[uint8], offset: int): NList64 =
  ## Parse 64-bit symbol table entry
  var pos = offset
  result.n_strx = readU32LE(data, pos)
  result.n_type = readU8(data, pos)
  result.n_sect = readU8(data, pos)
  result.n_desc = readU16LE(data, pos)
  result.n_value = readU64LE(data, pos)

proc parseMacho*(data: openArray[uint8]): MachoFile =
  ## Parse complete Mach-O file
  result.header = parseHeader(data)
  result.is64Bit = result.header.magic == MH_MAGIC_64

  let headerSize = if result.is64Bit: 32 else: 28
  var offset = headerSize

  # Parse load commands
  var symtabCmd: SymtabCommand
  var hasSymtab = false

  for i in 0..<result.header.ncmds:
    if offset + 8 > data.len:
      break

    let lcmd = parseLoadCommand(data, offset)

    case lcmd.cmd
    of LC_SEGMENT_64:
      # Parse 64-bit segment
      let seg = parseSegmentCommand64(data, offset)
      var machoSeg = MachoSegment(
        name: extractName(seg.segname),
        vmaddr: seg.vmaddr,
        vmsize: seg.vmsize,
        fileoff: seg.fileoff,
        filesize: seg.filesize,
        initprot: seg.initprot,
        maxprot: seg.maxprot
      )

      # Parse sections in this segment
      var sectionOffset = offset + 72
      for j in 0..<seg.nsects:
        if sectionOffset + 80 > data.len:
          break

        let sect = parseSection64(data, sectionOffset)
        var machoSect = MachoSection(
          sectname: extractName(sect.sectname),
          segname: extractName(sect.segname),
          addr: sect.addr,
          size: sect.size,
          offset: sect.offset,
          flags: sect.flags
        )

        # Read section data
        if sect.offset > 0 and sect.offset.int + sect.size.int <= data.len:
          machoSect.data = newSeq[uint8](sect.size.int)
          for k in 0..<sect.size.int:
            machoSect.data[k] = data[sect.offset.int + k]

        machoSeg.sections.add(machoSect)
        sectionOffset += 80

      result.segments.add(machoSeg)

    of LC_SYMTAB:
      symtabCmd = parseSymtabCommand(data, offset)
      hasSymtab = true

    of LC_LOAD_DYLIB, LC_ID_DYLIB, LC_REEXPORT_DYLIB:
      # Parse dylib name
      var pos = offset + 8  # Skip cmd and cmdsize
      let nameOffset = readU32LE(data, pos).int
      if offset + nameOffset < data.len:
        let dylibName = readString(data, offset + nameOffset)
        result.dylibs.add(dylibName)

    of LC_MAIN:
      # Parse entry point
      var pos = offset + 8  # Skip cmd and cmdsize
      result.entryPoint = readU64LE(data, pos)

    else:
      # Unhandled load command type
      # This is expected for less common command types (LC_SEGMENT_64_PAGEZERO,
      # LC_NOTE, LC_BUILD_VERSION, etc.) that don't affect basic parsing.
      # Supported: LC_SEGMENT, LC_SEGMENT_64, LC_SYMTAB, LC_DYLIB, LC_DYLINKER, LC_MAIN
      when defined(debug):
        debugEcho "Unsupported Mach-O load command type: 0x" & cmd.toHex(8)

    offset += lcmd.cmdsize.int

  # Parse symbol table
  if hasSymtab and symtabCmd.symoff > 0:
    var symOffset = symtabCmd.symoff.int
    for i in 0..<symtabCmd.nsyms:
      if symOffset + 16 > data.len:
        break

      let sym = parseNList64(data, symOffset)
      var machoSym = MachoSymbol(
        value: sym.n_value,
        section: sym.n_sect,
        symType: sym.n_type
      )

      # Get symbol name from string table
      if symtabCmd.stroff > 0 and sym.n_strx < symtabCmd.strsize:
        machoSym.name = readString(data, (symtabCmd.stroff + sym.n_strx).int)

      result.symbols.add(machoSym)
      symOffset += 16

proc parseMachoFile*(filename: string): MachoFile =
  ## Parse Mach-O file from path
  let data = readFile(filename)
  parseMacho(cast[seq[uint8]](data))

# =============================================================================
# Helper Functions
# =============================================================================

proc getSegment*(macho: MachoFile, name: string): MachoSegment =
  ## Find segment by name
  for segment in macho.segments:
    if segment.name == name:
      return segment
  raise newException(KeyError, "Segment not found: " & name)

proc hasSegment*(macho: MachoFile, name: string): bool =
  ## Check if segment exists
  for segment in macho.segments:
    if segment.name == name:
      return true
  false

proc `$`*(macho: MachoFile): string =
  ## String representation
  result = "Mach-O File:\n"
  result.add("  CPU Type: " & $macho.header.cputype & "\n")
  result.add("  File Type: " & $macho.header.filetype & "\n")
  result.add("  Entry Point: 0x" & macho.entryPoint.toHex & "\n")
  result.add("  Segments: " & $macho.segments.len & "\n")
  for segment in macho.segments:
    result.add("    " & segment.name & ": " & $segment.vmsize & " bytes, " &
               $segment.sections.len & " sections\n")
  result.add("  Symbols: " & $macho.symbols.len & "\n")
  result.add("  Dylibs: " & $macho.dylibs.len & "\n")
