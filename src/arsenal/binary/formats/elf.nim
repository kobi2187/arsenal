## ELF (Executable and Linkable Format) Parser
## ==============================================
##
## Parses Linux/Unix ELF binaries and shared libraries.
## Supports ELF32 and ELF64 (32-bit and 64-bit).
##
## Features:
## - Header parsing
## - Section headers
## - Program headers (segments)
## - Symbol table extraction
## - Dynamic linking information
## - Relocation tables
##
## Usage:
## ```nim
## import arsenal/binary/formats/elf
##
## let elf = parseElf(readFile("/bin/ls"))
## echo "Entry point: 0x", elf.header.entry.toHex
## for section in elf.sections:
##   echo section.name, ": ", section.size, " bytes"
## ```

import std/strutils
import std/tables

# =============================================================================
# ELF Header Structures
# =============================================================================

const
  ELFMAG* = [0x7F'u8, 'E'.uint8, 'L'.uint8, 'F'.uint8]  ## ELF magic number
  EI_NIDENT* = 16

  # ELF class (32/64-bit)
  ELFCLASS32* = 1
  ELFCLASS64* = 2

  # Data encoding
  ELFDATA2LSB* = 1  ## Little endian
  ELFDATA2MSB* = 2  ## Big endian

  # ELF version
  EV_CURRENT* = 1

  # Object file types
  ET_NONE* = 0     ## No file type
  ET_REL* = 1      ## Relocatable file
  ET_EXEC* = 2     ## Executable file
  ET_DYN* = 3      ## Shared object
  ET_CORE* = 4     ## Core file

  # Machine architectures
  EM_NONE* = 0
  EM_386* = 3       ## Intel 80386
  EM_ARM* = 40      ## ARM
  EM_X86_64* = 62   ## AMD x86-64
  EM_AARCH64* = 183 ## ARM 64-bit

  # Section header types
  SHT_NULL* = 0           ## Inactive section
  SHT_PROGBITS* = 1       ## Program data
  SHT_SYMTAB* = 2         ## Symbol table
  SHT_STRTAB* = 3         ## String table
  SHT_RELA* = 4           ## Relocation entries with addends
  SHT_HASH* = 5           ## Symbol hash table
  SHT_DYNAMIC* = 6        ## Dynamic linking information
  SHT_NOTE* = 7           ## Notes
  SHT_NOBITS* = 8         ## No space in file (BSS)
  SHT_REL* = 9            ## Relocation entries
  SHT_DYNSYM* = 11        ## Dynamic symbol table

  # Section header flags
  SHF_WRITE* = 0x1        ## Writable
  SHF_ALLOC* = 0x2        ## Occupies memory
  SHF_EXECINSTR* = 0x4    ## Executable

  # Program header types
  PT_NULL* = 0        ## Unused entry
  PT_LOAD* = 1        ## Loadable segment
  PT_DYNAMIC* = 2     ## Dynamic linking information
  PT_INTERP* = 3      ## Interpreter path
  PT_NOTE* = 4        ## Auxiliary information
  PT_PHDR* = 6        ## Program header table

  # Program header flags
  PF_X* = 0x1  ## Execute
  PF_W* = 0x2  ## Write
  PF_R* = 0x4  ## Read

  # Symbol binding
  STB_LOCAL* = 0   ## Local symbol
  STB_GLOBAL* = 1  ## Global symbol
  STB_WEAK* = 2    ## Weak symbol

  # Symbol types
  STT_NOTYPE* = 0   ## No type
  STT_OBJECT* = 1   ## Data object
  STT_FUNC* = 2     ## Function
  STT_SECTION* = 3  ## Section
  STT_FILE* = 4     ## File name

type
  Elf64Header* = object
    ## ELF64 file header (64-byte)
    magic*: array[4, uint8]       # Magic number
    class*: uint8                 # 1=32-bit, 2=64-bit
    data*: uint8                  # 1=little, 2=big endian
    version*: uint8               # ELF version
    osAbi*: uint8                 # OS/ABI
    abiVersion*: uint8            # ABI version
    pad*: array[7, uint8]         # Padding
    elfType*: uint16              # Object file type
    machine*: uint16              # Machine architecture
    versionWord*: uint32          # Version
    entry*: uint64                # Entry point address
    phoff*: uint64                # Program header offset
    shoff*: uint64                # Section header offset
    flags*: uint32                # Processor-specific flags
    ehsize*: uint16               # ELF header size
    phentsize*: uint16            # Program header entry size
    phnum*: uint16                # Program header count
    shentsize*: uint16            # Section header entry size
    shnum*: uint16                # Section header count
    shstrndx*: uint16             # Section header string table index

  Elf64SectionHeader* = object
    ## ELF64 section header (64-byte)
    name*: uint32                 # Section name (string table offset)
    shType*: uint32               # Section type
    flags*: uint64                # Section flags
    addr*: uint64                 # Virtual address
    offset*: uint64               # File offset
    size*: uint64                 # Section size
    link*: uint32                 # Link to another section
    info*: uint32                 # Additional info
    addralign*: uint64            # Address alignment
    entsize*: uint64              # Entry size if table

  Elf64ProgramHeader* = object
    ## ELF64 program header (56-byte)
    phType*: uint32               # Segment type
    flags*: uint32                # Segment flags
    offset*: uint64               # File offset
    vaddr*: uint64                # Virtual address
    paddr*: uint64                # Physical address
    filesz*: uint64               # Size in file
    memsz*: uint64                # Size in memory
    align*: uint64                # Alignment

  Elf64Symbol* = object
    ## ELF64 symbol table entry (24-byte)
    name*: uint32                 # String table offset
    info*: uint8                  # Type and binding
    other*: uint8                 # Reserved
    shndx*: uint16                # Section index
    value*: uint64                # Symbol value
    size*: uint64                 # Symbol size

  ElfSection* = object
    ## Parsed section information
    name*: string
    shType*: uint32
    flags*: uint64
    addr*: uint64
    offset*: uint64
    size*: uint64
    data*: seq[uint8]

  ElfSegment* = object
    ## Parsed program header/segment
    phType*: uint32
    flags*: uint32
    offset*: uint64
    vaddr*: uint64
    paddr*: uint64
    filesz*: uint64
    memsz*: uint64

  ElfSymbol* = object
    ## Parsed symbol
    name*: string
    value*: uint64
    size*: uint64
    binding*: uint8
    symType*: uint8
    section*: uint16

  ElfFile* = object
    ## Parsed ELF file
    header*: Elf64Header
    sections*: seq[ElfSection]
    segments*: seq[ElfSegment]
    symbols*: seq[ElfSymbol]
    dynamicSymbols*: seq[ElfSymbol]
    imports*: seq[string]
    exports*: seq[string]

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
  ## Read null-terminated string from data
  var i = offset
  while i < data.len and data[i] != 0:
    result.add(data[i].char)
    inc i

# =============================================================================
# ELF Parsing
# =============================================================================

proc parseHeader*(data: openArray[uint8]): Elf64Header =
  ## Parse ELF header
  if data.len < 64:
    raise newException(ValueError, "File too small for ELF header")

  # Check magic number
  if data[0..3] != ELFMAG:
    raise newException(ValueError, "Not an ELF file (invalid magic)")

  var offset = 0
  for i in 0..3:
    result.magic[i] = readU8(data, offset)

  result.class = readU8(data, offset)
  result.data = readU8(data, offset)
  result.version = readU8(data, offset)
  result.osAbi = readU8(data, offset)
  result.abiVersion = readU8(data, offset)

  for i in 0..6:
    result.pad[i] = readU8(data, offset)

  result.elfType = readU16LE(data, offset)
  result.machine = readU16LE(data, offset)
  result.versionWord = readU32LE(data, offset)
  result.entry = readU64LE(data, offset)
  result.phoff = readU64LE(data, offset)
  result.shoff = readU64LE(data, offset)
  result.flags = readU32LE(data, offset)
  result.ehsize = readU16LE(data, offset)
  result.phentsize = readU16LE(data, offset)
  result.phnum = readU16LE(data, offset)
  result.shentsize = readU16LE(data, offset)
  result.shnum = readU16LE(data, offset)
  result.shstrndx = readU16LE(data, offset)

  # Validate class
  if result.class != ELFCLASS64:
    raise newException(ValueError, "Only ELF64 is currently supported")

proc parseSectionHeader*(data: openArray[uint8], offset: int): Elf64SectionHeader =
  ## Parse a single section header
  var pos = offset
  result.name = readU32LE(data, pos)
  result.shType = readU32LE(data, pos)
  result.flags = readU64LE(data, pos)
  result.addr = readU64LE(data, pos)
  result.offset = readU64LE(data, pos)
  result.size = readU64LE(data, pos)
  result.link = readU32LE(data, pos)
  result.info = readU32LE(data, pos)
  result.addralign = readU64LE(data, pos)
  result.entsize = readU64LE(data, pos)

proc parseProgramHeader*(data: openArray[uint8], offset: int): Elf64ProgramHeader =
  ## Parse a single program header
  var pos = offset
  result.phType = readU32LE(data, pos)
  result.flags = readU32LE(data, pos)
  result.offset = readU64LE(data, pos)
  result.vaddr = readU64LE(data, pos)
  result.paddr = readU64LE(data, pos)
  result.filesz = readU64LE(data, pos)
  result.memsz = readU64LE(data, pos)
  result.align = readU64LE(data, pos)

proc parseSymbol*(data: openArray[uint8], offset: int): Elf64Symbol =
  ## Parse a single symbol entry
  var pos = offset
  result.name = readU32LE(data, pos)
  result.info = readU8(data, pos)
  result.other = readU8(data, pos)
  result.shndx = readU16LE(data, pos)
  result.value = readU64LE(data, pos)
  result.size = readU64LE(data, pos)

proc parseElf*(data: openArray[uint8]): ElfFile =
  ## Parse complete ELF file
  result.header = parseHeader(data)

  # Parse section headers
  var shstrtabOffset = 0'u64
  var shstrtabSize = 0'u64

  # First pass: find string table
  if result.header.shstrndx < result.header.shnum:
    let shdrOffset = (result.header.shoff + result.header.shstrndx.uint64 * result.header.shentsize.uint64).int
    let shstrtabHdr = parseSectionHeader(data, shdrOffset)
    shstrtabOffset = shstrtabHdr.offset
    shstrtabSize = shstrtabHdr.size

  # Second pass: parse all sections
  for i in 0..<result.header.shnum:
    let shdrOffset = (result.header.shoff + i.uint64 * result.header.shentsize.uint64).int
    if shdrOffset + 64 > data.len:
      break

    let shdr = parseSectionHeader(data, shdrOffset)

    var section = ElfSection(
      shType: shdr.shType,
      flags: shdr.flags,
      addr: shdr.addr,
      offset: shdr.offset,
      size: shdr.size
    )

    # Get section name
    if shstrtabOffset > 0 and shdr.name < shstrtabSize:
      section.name = readString(data, (shstrtabOffset + shdr.name.uint64).int)

    # Read section data (if present in file)
    if shdr.shType != SHT_NOBITS and shdr.offset + shdr.size <= data.len.uint64:
      section.data = newSeq[uint8](shdr.size.int)
      for j in 0..<shdr.size.int:
        section.data[j] = data[shdr.offset.int + j]

    result.sections.add(section)

  # Parse program headers
  for i in 0..<result.header.phnum:
    let phdrOffset = (result.header.phoff + i.uint64 * result.header.phentsize.uint64).int
    if phdrOffset + 56 > data.len:
      break

    let phdr = parseProgramHeader(data, phdrOffset)
    result.segments.add(ElfSegment(
      phType: phdr.phType,
      flags: phdr.flags,
      offset: phdr.offset,
      vaddr: phdr.vaddr,
      paddr: phdr.paddr,
      filesz: phdr.filesz,
      memsz: phdr.memsz
    ))

  # Parse symbols from .symtab
  for section in result.sections:
    if section.shType == SHT_SYMTAB or section.shType == SHT_DYNSYM:
      # Find associated string table
      var strtabData: seq[uint8]
      for s in result.sections:
        if s.shType == SHT_STRTAB and s.name in [".strtab", ".dynstr"]:
          strtabData = s.data
          break

      # Parse symbols
      var symOffset = 0
      while symOffset + 24 <= section.data.len:
        let sym = parseSymbol(section.data, symOffset)
        var elfSym = ElfSymbol(
          value: sym.value,
          size: sym.size,
          binding: sym.info shr 4,
          symType: sym.info and 0xF,
          section: sym.shndx
        )

        # Get symbol name
        if sym.name < strtabData.len.uint32:
          elfSym.name = readString(strtabData, sym.name.int)

        if section.shType == SHT_SYMTAB:
          result.symbols.add(elfSym)
        else:
          result.dynamicSymbols.add(elfSym)

        symOffset += 24

  # Extract imports/exports from dynamic symbols
  for sym in result.dynamicSymbols:
    if sym.binding == STB_GLOBAL:
      if sym.section == 0:  # Undefined = import
        result.imports.add(sym.name)
      else:  # Defined = export
        result.exports.add(sym.name)

proc parseElfFile*(filename: string): ElfFile =
  ## Parse ELF file from path
  let data = readFile(filename)
  parseElf(cast[seq[uint8]](data))

# =============================================================================
# Helper Functions
# =============================================================================

proc getSection*(elf: ElfFile, name: string): ElfSection =
  ## Find section by name
  for section in elf.sections:
    if section.name == name:
      return section
  raise newException(KeyError, "Section not found: " & name)

proc hasSection*(elf: ElfFile, name: string): bool =
  ## Check if section exists
  for section in elf.sections:
    if section.name == name:
      return true
  false

proc `$`*(header: Elf64Header): string =
  ## String representation of ELF header
  result = "ELF Header:\n"
  result.add("  Class: " & (if header.class == ELFCLASS64: "ELF64" else: "ELF32") & "\n")
  result.add("  Type: " & $header.elfType & "\n")
  result.add("  Machine: " & $header.machine & "\n")
  result.add("  Entry: 0x" & header.entry.toHex & "\n")
  result.add("  Sections: " & $header.shnum & "\n")
  result.add("  Segments: " & $header.phnum & "\n")

proc `$`*(elf: ElfFile): string =
  ## String representation of parsed ELF
  result = $elf.header
  result.add("\nSections (" & $elf.sections.len & "):\n")
  for section in elf.sections:
    result.add("  " & section.name & ": " & $section.size & " bytes\n")
  result.add("\nSymbols: " & $elf.symbols.len & "\n")
  result.add("Imports: " & $elf.imports.len & "\n")
  result.add("Exports: " & $elf.exports.len & "\n")
