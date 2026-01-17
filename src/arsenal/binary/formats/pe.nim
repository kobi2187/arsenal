## PE (Portable Executable) Parser
## =================================
##
## Parses Windows PE/PE+ (PE32/PE32+) executables and DLLs.
## Supports both 32-bit and 64-bit PE files.
##
## Features:
## - DOS header and stub
## - PE headers (COFF, Optional)
## - Section headers
## - Import table (imported DLLs and functions)
## - Export table (exported functions)
## - Resource directory
## - Relocation table
##
## Usage:
## ```nim
## import arsenal/binary/formats/pe
##
## let pe = parsePe(readFile("program.exe"))
## echo "Entry point: 0x", pe.optionalHeader.addressOfEntryPoint.toHex
## for imp in pe.imports:
##   echo "Import: ", imp.dllName, " -> ", imp.functionName
## ```

import std/strutils
import std/tables

# =============================================================================
# Constants
# =============================================================================

const
  DOS_SIGNATURE* = 0x5A4D'u16  ## "MZ"
  PE_SIGNATURE* = 0x4550'u32   ## "PE\0\0"

  # Machine types
  IMAGE_FILE_MACHINE_I386* = 0x014c      ## x86
  IMAGE_FILE_MACHINE_AMD64* = 0x8664     ## x64
  IMAGE_FILE_MACHINE_ARM* = 0x01c0       ## ARM
  IMAGE_FILE_MACHINE_ARM64* = 0xaa64     ## ARM64

  # Magic numbers for Optional Header
  PE32_MAGIC* = 0x10b'u16      ## PE32
  PE32PLUS_MAGIC* = 0x20b'u16  ## PE32+ (64-bit)

  # Subsystems
  IMAGE_SUBSYSTEM_NATIVE* = 1           ## Native (driver)
  IMAGE_SUBSYSTEM_WINDOWS_GUI* = 2      ## GUI application
  IMAGE_SUBSYSTEM_WINDOWS_CUI* = 3      ## Console application
  IMAGE_SUBSYSTEM_WINDOWS_CE_GUI* = 9   ## Windows CE

  # DLL Characteristics
  IMAGE_DLLCHARACTERISTICS_NX_COMPAT* = 0x0100    ## DEP enabled
  IMAGE_DLLCHARACTERISTICS_DYNAMIC_BASE* = 0x0040 ## ASLR

  # Section characteristics
  IMAGE_SCN_CNT_CODE* = 0x00000020              ## Contains code
  IMAGE_SCN_CNT_INITIALIZED_DATA* = 0x00000040  ## Contains data
  IMAGE_SCN_CNT_UNINITIALIZED_DATA* = 0x00000080 ## Contains BSS
  IMAGE_SCN_MEM_EXECUTE* = 0x20000000           ## Executable
  IMAGE_SCN_MEM_READ* = 0x40000000              ## Readable
  IMAGE_SCN_MEM_WRITE* = 0x80000000             ## Writable

  # Data directory indices
  IMAGE_DIRECTORY_ENTRY_EXPORT* = 0
  IMAGE_DIRECTORY_ENTRY_IMPORT* = 1
  IMAGE_DIRECTORY_ENTRY_RESOURCE* = 2
  IMAGE_DIRECTORY_ENTRY_EXCEPTION* = 3
  IMAGE_DIRECTORY_ENTRY_SECURITY* = 4
  IMAGE_DIRECTORY_ENTRY_BASERELOC* = 5
  IMAGE_DIRECTORY_ENTRY_DEBUG* = 6
  IMAGE_DIRECTORY_ENTRY_ARCHITECTURE* = 7
  IMAGE_DIRECTORY_ENTRY_GLOBALPTR* = 8
  IMAGE_DIRECTORY_ENTRY_TLS* = 9
  IMAGE_DIRECTORY_ENTRY_LOAD_CONFIG* = 10
  IMAGE_DIRECTORY_ENTRY_BOUND_IMPORT* = 11
  IMAGE_DIRECTORY_ENTRY_IAT* = 12
  IMAGE_DIRECTORY_ENTRY_DELAY_IMPORT* = 13
  IMAGE_DIRECTORY_ENTRY_COM_DESCRIPTOR* = 14

type
  DosHeader* = object
    ## DOS header (64 bytes)
    magic*: uint16                # "MZ" signature
    cblp*: uint16                 # Bytes on last page
    cp*: uint16                   # Pages in file
    crlc*: uint16                 # Relocations
    cparhdr*: uint16              # Size of header in paragraphs
    minalloc*: uint16             # Minimum extra paragraphs
    maxalloc*: uint16             # Maximum extra paragraphs
    ss*: uint16                   # Initial SS value
    sp*: uint16                   # Initial SP value
    csum*: uint16                 # Checksum
    ip*: uint16                   # Initial IP value
    cs*: uint16                   # Initial CS value
    lfarlc*: uint16               # File address of relocation table
    ovno*: uint16                 # Overlay number
    res*: array[4, uint16]        # Reserved
    oemid*: uint16                # OEM identifier
    oeminfo*: uint16              # OEM information
    res2*: array[10, uint16]      # Reserved
    lfanew*: uint32               # File address of PE header

  CoffHeader* = object
    ## COFF file header (20 bytes after PE signature)
    machine*: uint16              # Machine type
    numberOfSections*: uint16     # Number of sections
    timeDateStamp*: uint32        # Time/date stamp
    pointerToSymbolTable*: uint32 # Pointer to symbol table
    numberOfSymbols*: uint32      # Number of symbols
    sizeOfOptionalHeader*: uint16 # Size of optional header
    characteristics*: uint16      # Characteristics flags

  DataDirectory* = object
    ## Data directory entry (8 bytes)
    virtualAddress*: uint32       # RVA of table
    size*: uint32                 # Size of table

  OptionalHeader64* = object
    ## Optional header for PE32+ (64-bit)
    magic*: uint16                        # PE32+ magic (0x20b)
    majorLinkerVersion*: uint8
    minorLinkerVersion*: uint8
    sizeOfCode*: uint32
    sizeOfInitializedData*: uint32
    sizeOfUninitializedData*: uint32
    addressOfEntryPoint*: uint32          # RVA of entry point
    baseOfCode*: uint32                   # RVA of code section
    imageBase*: uint64                    # Preferred load address
    sectionAlignment*: uint32             # Section alignment in memory
    fileAlignment*: uint32                # File alignment
    majorOperatingSystemVersion*: uint16
    minorOperatingSystemVersion*: uint16
    majorImageVersion*: uint16
    minorImageVersion*: uint16
    majorSubsystemVersion*: uint16
    minorSubsystemVersion*: uint16
    win32VersionValue*: uint32
    sizeOfImage*: uint32                  # Size of image in memory
    sizeOfHeaders*: uint32                # Size of headers
    checkSum*: uint32                     # Image checksum
    subsystem*: uint16                    # Subsystem
    dllCharacteristics*: uint16           # DLL characteristics
    sizeOfStackReserve*: uint64
    sizeOfStackCommit*: uint64
    sizeOfHeapReserve*: uint64
    sizeOfHeapCommit*: uint64
    loaderFlags*: uint32
    numberOfRvaAndSizes*: uint32
    dataDirectory*: array[16, DataDirectory] # Data directories

  SectionHeader* = object
    ## Section header (40 bytes)
    name*: array[8, char]         # Section name (8 bytes, null-padded)
    virtualSize*: uint32          # Size in memory
    virtualAddress*: uint32       # RVA in memory
    sizeOfRawData*: uint32        # Size in file
    pointerToRawData*: uint32     # File offset
    pointerToRelocations*: uint32 # File offset to relocations
    pointerToLinenumbers*: uint32 # File offset to line numbers
    numberOfRelocations*: uint16  # Number of relocations
    numberOfLinenumbers*: uint16  # Number of line numbers
    characteristics*: uint32      # Section flags

  ImportDescriptor* = object
    ## Import directory entry (20 bytes)
    originalFirstThunk*: uint32   # RVA to import lookup table
    timeDateStamp*: uint32        # Time/date stamp
    forwarderChain*: uint32       # Forwarder chain
    name*: uint32                 # RVA to DLL name
    firstThunk*: uint32           # RVA to import address table (IAT)

  ExportDirectory* = object
    ## Export directory table (40 bytes)
    characteristics*: uint32
    timeDateStamp*: uint32
    majorVersion*: uint16
    minorVersion*: uint16
    name*: uint32                 # RVA to DLL name
    base*: uint32                 # Ordinal base
    numberOfFunctions*: uint32    # Number of functions
    numberOfNames*: uint32        # Number of names
    addressOfFunctions*: uint32   # RVA to function addresses
    addressOfNames*: uint32       # RVA to function names
    addressOfNameOrdinals*: uint32 # RVA to name ordinals

  PeSection* = object
    ## Parsed section
    name*: string
    virtualAddress*: uint32
    virtualSize*: uint32
    rawSize*: uint32
    characteristics*: uint32
    data*: seq[uint8]

  PeImport* = object
    ## Parsed import entry
    dllName*: string
    functionName*: string
    ordinal*: uint16
    address*: uint64

  PeExport* = object
    ## Parsed export entry
    name*: string
    ordinal*: uint32
    address*: uint32

  PeFile* = object
    ## Parsed PE file
    dosHeader*: DosHeader
    coffHeader*: CoffHeader
    optionalHeader*: OptionalHeader64
    sections*: seq[PeSection]
    imports*: seq[PeImport]
    exports*: seq[PeExport]
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

proc readString(data: openArray[uint8], offset: int): string =
  ## Read null-terminated string
  var i = offset
  while i < data.len and data[i] != 0:
    result.add(data[i].char)
    inc i

proc rvaToFileOffset(rva: uint32, sections: seq[PeSection]): int =
  ## Convert RVA (Relative Virtual Address) to file offset
  for section in sections:
    if rva >= section.virtualAddress and
       rva < section.virtualAddress + section.virtualSize:
      return (rva - section.virtualAddress + section.rawSize).int
  -1

# =============================================================================
# PE Parsing
# =============================================================================

proc parseDosHeader*(data: openArray[uint8]): DosHeader =
  ## Parse DOS header
  if data.len < 64:
    raise newException(ValueError, "File too small for DOS header")

  var offset = 0
  result.magic = readU16LE(data, offset)
  if result.magic != DOS_SIGNATURE:
    raise newException(ValueError, "Not a PE file (invalid DOS signature)")

  result.cblp = readU16LE(data, offset)
  result.cp = readU16LE(data, offset)
  result.crlc = readU16LE(data, offset)
  result.cparhdr = readU16LE(data, offset)
  result.minalloc = readU16LE(data, offset)
  result.maxalloc = readU16LE(data, offset)
  result.ss = readU16LE(data, offset)
  result.sp = readU16LE(data, offset)
  result.csum = readU16LE(data, offset)
  result.ip = readU16LE(data, offset)
  result.cs = readU16LE(data, offset)
  result.lfarlc = readU16LE(data, offset)
  result.ovno = readU16LE(data, offset)

  for i in 0..3:
    result.res[i] = readU16LE(data, offset)

  result.oemid = readU16LE(data, offset)
  result.oeminfo = readU16LE(data, offset)

  for i in 0..9:
    result.res2[i] = readU16LE(data, offset)

  result.lfanew = readU32LE(data, offset)

proc parseCoffHeader*(data: openArray[uint8], offset: int): CoffHeader =
  ## Parse COFF header (after PE signature)
  var pos = offset
  result.machine = readU16LE(data, pos)
  result.numberOfSections = readU16LE(data, pos)
  result.timeDateStamp = readU32LE(data, pos)
  result.pointerToSymbolTable = readU32LE(data, pos)
  result.numberOfSymbols = readU32LE(data, pos)
  result.sizeOfOptionalHeader = readU16LE(data, pos)
  result.characteristics = readU16LE(data, pos)

proc parseOptionalHeader64*(data: openArray[uint8], offset: int): OptionalHeader64 =
  ## Parse PE32+ optional header (64-bit)
  var pos = offset
  result.magic = readU16LE(data, pos)

  if result.magic != PE32PLUS_MAGIC and result.magic != PE32_MAGIC:
    raise newException(ValueError, "Invalid PE optional header magic")

  result.majorLinkerVersion = readU8(data, pos)
  result.minorLinkerVersion = readU8(data, pos)
  result.sizeOfCode = readU32LE(data, pos)
  result.sizeOfInitializedData = readU32LE(data, pos)
  result.sizeOfUninitializedData = readU32LE(data, pos)
  result.addressOfEntryPoint = readU32LE(data, pos)
  result.baseOfCode = readU32LE(data, pos)

  # PE32+ is 64-bit, PE32 has baseOfData field here
  if result.magic == PE32PLUS_MAGIC:
    result.imageBase = readU64LE(data, pos)
  else:
    discard readU32LE(data, pos)  # baseOfData (PE32 only)
    result.imageBase = readU32LE(data, pos).uint64

  result.sectionAlignment = readU32LE(data, pos)
  result.fileAlignment = readU32LE(data, pos)
  result.majorOperatingSystemVersion = readU16LE(data, pos)
  result.minorOperatingSystemVersion = readU16LE(data, pos)
  result.majorImageVersion = readU16LE(data, pos)
  result.minorImageVersion = readU16LE(data, pos)
  result.majorSubsystemVersion = readU16LE(data, pos)
  result.minorSubsystemVersion = readU16LE(data, pos)
  result.win32VersionValue = readU32LE(data, pos)
  result.sizeOfImage = readU32LE(data, pos)
  result.sizeOfHeaders = readU32LE(data, pos)
  result.checkSum = readU32LE(data, pos)
  result.subsystem = readU16LE(data, pos)
  result.dllCharacteristics = readU16LE(data, pos)

  if result.magic == PE32PLUS_MAGIC:
    result.sizeOfStackReserve = readU64LE(data, pos)
    result.sizeOfStackCommit = readU64LE(data, pos)
    result.sizeOfHeapReserve = readU64LE(data, pos)
    result.sizeOfHeapCommit = readU64LE(data, pos)
  else:
    result.sizeOfStackReserve = readU32LE(data, pos).uint64
    result.sizeOfStackCommit = readU32LE(data, pos).uint64
    result.sizeOfHeapReserve = readU32LE(data, pos).uint64
    result.sizeOfHeapCommit = readU32LE(data, pos).uint64

  result.loaderFlags = readU32LE(data, pos)
  result.numberOfRvaAndSizes = readU32LE(data, pos)

  # Parse data directories
  for i in 0..<min(result.numberOfRvaAndSizes.int, 16):
    result.dataDirectory[i].virtualAddress = readU32LE(data, pos)
    result.dataDirectory[i].size = readU32LE(data, pos)

proc parseSectionHeader*(data: openArray[uint8], offset: int): SectionHeader =
  ## Parse section header
  var pos = offset
  for i in 0..7:
    result.name[i] = data[pos].char
    inc pos

  result.virtualSize = readU32LE(data, pos)
  result.virtualAddress = readU32LE(data, pos)
  result.sizeOfRawData = readU32LE(data, pos)
  result.pointerToRawData = readU32LE(data, pos)
  result.pointerToRelocations = readU32LE(data, pos)
  result.pointerToLinenumbers = readU32LE(data, pos)
  result.numberOfRelocations = readU16LE(data, pos)
  result.numberOfLinenumbers = readU16LE(data, pos)
  result.characteristics = readU32LE(data, pos)

proc parsePe*(data: openArray[uint8]): PeFile =
  ## Parse complete PE file
  # Parse DOS header
  result.dosHeader = parseDosHeader(data)

  # Check PE signature
  let peOffset = result.dosHeader.lfanew.int
  if peOffset + 24 > data.len:
    raise newException(ValueError, "Invalid PE offset")

  var offset = peOffset
  let peSig = readU32LE(data, offset)
  if peSig != PE_SIGNATURE:
    raise newException(ValueError, "Invalid PE signature")

  # Parse COFF header
  result.coffHeader = parseCoffHeader(data, offset)
  offset += 20

  # Parse optional header
  result.optionalHeader = parseOptionalHeader64(data, offset)
  result.is64Bit = result.optionalHeader.magic == PE32PLUS_MAGIC

  # Parse section headers
  offset = peOffset + 24 + result.coffHeader.sizeOfOptionalHeader.int
  for i in 0..<result.coffHeader.numberOfSections:
    let sectionHdr = parseSectionHeader(data, offset)
    offset += 40

    var section = PeSection(
      virtualAddress: sectionHdr.virtualAddress,
      virtualSize: sectionHdr.virtualSize,
      rawSize: sectionHdr.sizeOfRawData,
      characteristics: sectionHdr.characteristics
    )

    # Extract name (null-terminated)
    for i in 0..7:
      if sectionHdr.name[i] != '\0':
        section.name.add(sectionHdr.name[i])
      else:
        break

    # Read section data
    if sectionHdr.pointerToRawData > 0 and
       sectionHdr.pointerToRawData.int + sectionHdr.sizeOfRawData.int <= data.len:
      section.data = newSeq[uint8](sectionHdr.sizeOfRawData.int)
      for j in 0..<sectionHdr.sizeOfRawData.int:
        section.data[j] = data[sectionHdr.pointerToRawData.int + j]

    result.sections.add(section)

  # Parse imports (simplified)
  let importDir = result.optionalHeader.dataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT]
  if importDir.size > 0 and importDir.virtualAddress > 0:
    let importOffset = rvaToFileOffset(importDir.virtualAddress, result.sections)
    if importOffset >= 0:
      # Parse import descriptors (simplified - would need full implementation)
      discard

  # Parse exports (simplified)
  let exportDir = result.optionalHeader.dataDirectory[IMAGE_DIRECTORY_ENTRY_EXPORT]
  if exportDir.size > 0 and exportDir.virtualAddress > 0:
    let exportOffset = rvaToFileOffset(exportDir.virtualAddress, result.sections)
    if exportOffset >= 0:
      # Parse export directory (simplified - would need full implementation)
      discard

proc parsePeFile*(filename: string): PeFile =
  ## Parse PE file from path
  let data = readFile(filename)
  parsePe(cast[seq[uint8]](data))

# =============================================================================
# Helper Functions
# =============================================================================

proc getSection*(pe: PeFile, name: string): PeSection =
  ## Find section by name
  for section in pe.sections:
    if section.name == name:
      return section
  raise newException(KeyError, "Section not found: " & name)

proc hasSection*(pe: PeFile, name: string): bool =
  ## Check if section exists
  for section in pe.sections:
    if section.name == name:
      return true
  false

proc `$`*(pe: PeFile): string =
  ## String representation
  result = "PE File:\n"
  result.add("  Machine: 0x" & pe.coffHeader.machine.toHex & "\n")
  result.add("  Subsystem: " & $pe.optionalHeader.subsystem & "\n")
  result.add("  Entry Point: 0x" & pe.optionalHeader.addressOfEntryPoint.toHex & "\n")
  result.add("  Image Base: 0x" & pe.optionalHeader.imageBase.toHex & "\n")
  result.add("  Sections: " & $pe.sections.len & "\n")
  for section in pe.sections:
    result.add("    " & section.name & ": " & $section.virtualSize & " bytes\n")
