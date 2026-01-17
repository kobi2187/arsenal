## File Carving
## =============
##
## Extract files from disk images, memory dumps, or raw data using file signatures.
## Implements header/footer based carving for common file formats.
##
## Features:
## - Signature-based file detection (magic bytes)
## - Header/footer matching
## - File extraction
## - Support for common formats (JPEG, PNG, PDF, ZIP, etc.)
## - Custom signature definitions
##
## Usage:
## ```nim
## import arsenal/forensics/carving
##
## # Carve files from disk image
## let diskImage = readFile("disk.img")
## let carved = carveFiles(diskImage.toOpenArrayByte(0, diskImage.len-1))
## for file in carved:
##   echo "Found ", file.fileType, " at offset ", file.offset
##   writeFile("carved_" & $file.offset, file.data)
## ```

import std/strutils
import std/tables

# =============================================================================
# File Signatures
# =============================================================================

type
  FileSignature* = object
    ## File signature (magic bytes)
    name*: string                 # File type name
    extension*: string            # File extension
    header*: seq[uint8]           # Header magic bytes
    footer*: seq[uint8]           # Footer magic bytes (optional)
    maxSize*: int                 # Maximum file size (0 = unlimited)

  CarvedFile* = object
    ## Carved file result
    fileType*: string             # Detected file type
    offset*: int                  # Offset in source data
    size*: int                    # File size
    data*: seq[uint8]             # File content

# Common file signatures database
const CommonSignatures* = [
  # Images
  FileSignature(
    name: "JPEG",
    extension: "jpg",
    header: @[0xFF'u8, 0xD8, 0xFF],
    footer: @[0xFF'u8, 0xD9],
    maxSize: 50_000_000  # 50 MB
  ),
  FileSignature(
    name: "PNG",
    extension: "png",
    header: @[0x89'u8, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    footer: @[0x49'u8, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82],
    maxSize: 50_000_000
  ),
  FileSignature(
    name: "GIF",
    extension: "gif",
    header: @[0x47'u8, 0x49, 0x46, 0x38],  # "GIF8"
    footer: @[0x00'u8, 0x3B],  # 0x00;
    maxSize: 50_000_000
  ),
  FileSignature(
    name: "BMP",
    extension: "bmp",
    header: @[0x42'u8, 0x4D],  # "BM"
    footer: @[],
    maxSize: 50_000_000
  ),

  # Documents
  FileSignature(
    name: "PDF",
    extension: "pdf",
    header: @[0x25'u8, 0x50, 0x44, 0x46],  # "%PDF"
    footer: @[0x25'u8, 0x25, 0x45, 0x4F, 0x46],  # "%%EOF"
    maxSize: 100_000_000
  ),
  FileSignature(
    name: "RTF",
    extension: "rtf",
    header: @[0x7B'u8, 0x5C, 0x72, 0x74, 0x66],  # "{\rtf"
    footer: @[0x7D'u8],  # "}"
    maxSize: 10_000_000
  ),

  # Archives
  FileSignature(
    name: "ZIP",
    extension: "zip",
    header: @[0x50'u8, 0x4B, 0x03, 0x04],  # "PK.."
    footer: @[0x50'u8, 0x4B, 0x05, 0x06],  # ZIP End of central directory
    maxSize: 1_000_000_000  # 1 GB
  ),
  FileSignature(
    name: "RAR",
    extension: "rar",
    header: @[0x52'u8, 0x61, 0x72, 0x21, 0x1A, 0x07],  # "Rar!.."
    footer: @[],
    maxSize: 1_000_000_000
  ),
  FileSignature(
    name: "7Z",
    extension: "7z",
    header: @[0x37'u8, 0x7A, 0xBC, 0xAF, 0x27, 0x1C],
    footer: @[],
    maxSize: 1_000_000_000
  ),
  FileSignature(
    name: "GZIP",
    extension: "gz",
    header: @[0x1F'u8, 0x8B],
    footer: @[],
    maxSize: 1_000_000_000
  ),

  # Executables
  FileSignature(
    name: "ELF",
    extension: "elf",
    header: @[0x7F'u8, 0x45, 0x4C, 0x46],  # ".ELF"
    footer: @[],
    maxSize: 100_000_000
  ),
  FileSignature(
    name: "PE",
    extension: "exe",
    header: @[0x4D'u8, 0x5A],  # "MZ"
    footer: @[],
    maxSize: 100_000_000
  ),
  FileSignature(
    name: "Mach-O",
    extension: "macho",
    header: @[0xFE'u8, 0xED, 0xFA, 0xCF],  # 64-bit Mach-O
    footer: @[],
    maxSize: 100_000_000
  ),

  # Media
  FileSignature(
    name: "MP3",
    extension: "mp3",
    header: @[0xFF'u8, 0xFB],  # MPEG-1 Layer 3
    footer: @[],
    maxSize: 100_000_000
  ),
  FileSignature(
    name: "MP4",
    extension: "mp4",
    header: @[0x00'u8, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70],  # "....ftyp"
    footer: @[],
    maxSize: 2_000_000_000  # 2 GB
  ),
  FileSignature(
    name: "AVI",
    extension: "avi",
    header: @[0x52'u8, 0x49, 0x46, 0x46],  # "RIFF"
    footer: @[],
    maxSize: 2_000_000_000
  ),

  # Office Documents
  FileSignature(
    name: "DOCX",
    extension: "docx",
    header: @[0x50'u8, 0x4B, 0x03, 0x04],  # ZIP-based (same as ZIP)
    footer: @[],
    maxSize: 100_000_000
  ),
]

# =============================================================================
# Pattern Matching
# =============================================================================

proc matchesPattern(data: openArray[uint8], offset: int, pattern: seq[uint8]): bool =
  ## Check if pattern matches at offset
  if pattern.len == 0:
    return true

  if offset + pattern.len > data.len:
    return false

  for i in 0..<pattern.len:
    if data[offset + i] != pattern[i]:
      return false

  true

proc findPattern(data: openArray[uint8], pattern: seq[uint8], startOffset: int = 0): int =
  ## Find first occurrence of pattern starting from startOffset
  ## Returns offset or -1 if not found
  if pattern.len == 0:
    return -1

  for i in startOffset..(data.len - pattern.len):
    if matchesPattern(data, i, pattern):
      return i

  -1

proc findAllPatterns(data: openArray[uint8], pattern: seq[uint8]): seq[int] =
  ## Find all occurrences of pattern
  var offset = 0
  while true:
    let pos = findPattern(data, pattern, offset)
    if pos < 0:
      break
    result.add(pos)
    offset = pos + 1

# =============================================================================
# File Carving
# =============================================================================

proc carveFile*(data: openArray[uint8], offset: int, sig: FileSignature): CarvedFile =
  ## Carve a single file starting at offset using signature
  result.fileType = sig.name
  result.offset = offset

  # Find footer (if signature has one)
  var endOffset = data.len

  if sig.footer.len > 0:
    # Search for footer after header
    let footerPos = findPattern(data, sig.footer, offset + sig.header.len)
    if footerPos >= 0:
      endOffset = footerPos + sig.footer.len
    else:
      # Footer not found, use max size or end of data
      if sig.maxSize > 0:
        endOffset = min(offset + sig.maxSize, data.len)
  else:
    # No footer defined, use max size or heuristics
    if sig.maxSize > 0:
      endOffset = min(offset + sig.maxSize, data.len)

  result.size = endOffset - offset

  # Extract file data
  result.data = newSeq[uint8](result.size)
  for i in 0..<result.size:
    result.data[i] = data[offset + i]

proc carveFilesBySig*(data: openArray[uint8], sig: FileSignature): seq[CarvedFile] =
  ## Carve all files matching a signature
  let headerPositions = findAllPatterns(data, sig.header)

  for pos in headerPositions:
    try:
      let carved = carveFile(data, pos, sig)
      # Basic validation: file should have reasonable size
      if carved.size > sig.header.len and
         (sig.maxSize == 0 or carved.size <= sig.maxSize):
        result.add(carved)
    except:
      # Skip invalid carves
      continue

proc carveFiles*(data: openArray[uint8], signatures: openArray[FileSignature] = CommonSignatures): seq[CarvedFile] =
  ## Carve files from data using multiple signatures
  ## Default uses common file signatures
  for sig in signatures:
    let carved = carveFilesBySig(data, sig)
    result.add(carved)

  # Sort by offset
  result.sort(proc(a, b: CarvedFile): int = cmp(a.offset, b.offset))

# =============================================================================
# Advanced Carving
# =============================================================================

proc carveByExtension*(data: openArray[uint8], extension: string): seq[CarvedFile] =
  ## Carve files by extension
  ## Searches all signatures matching the extension
  var matchingSigs: seq[FileSignature]

  for sig in CommonSignatures:
    if sig.extension == extension:
      matchingSigs.add(sig)

  carveFiles(data, matchingSigs)

proc estimateFileType*(data: openArray[uint8]): string =
  ## Estimate file type from header bytes
  for sig in CommonSignatures:
    if matchesPattern(data, 0, sig.header):
      return sig.name

  "Unknown"

# =============================================================================
# File Validation
# =============================================================================

proc validateCarvedFile*(carved: CarvedFile): bool =
  ## Basic validation of carved file
  ## Checks header and footer match expectations
  if carved.data.len == 0:
    return false

  # Check if file type is known
  for sig in CommonSignatures:
    if sig.name == carved.fileType:
      # Verify header
      if not matchesPattern(carved.data, 0, sig.header):
        return false

      # Verify footer (if defined)
      if sig.footer.len > 0:
        let footerOffset = carved.data.len - sig.footer.len
        if footerOffset >= 0:
          if not matchesPattern(carved.data, footerOffset, sig.footer):
            return false

      return true

  # Unknown file type, assume valid
  true

# =============================================================================
# Statistics
# =============================================================================

type
  CarvingStats* = object
    ## Carving statistics
    totalFiles*: int
    byType*: Table[string, int]
    totalSize*: int64

proc getStats*(carved: seq[CarvedFile]): CarvingStats =
  ## Calculate carving statistics
  result.totalFiles = carved.len
  result.byType = initTable[string, int]()

  for file in carved:
    result.totalSize += file.size.int64
    if file.fileType in result.byType:
      result.byType[file.fileType] += 1
    else:
      result.byType[file.fileType] = 1

proc `$`*(stats: CarvingStats): string =
  result = "Carving Statistics:\n"
  result.add("  Total files: " & $stats.totalFiles & "\n")
  result.add("  Total size: " & $stats.totalSize & " bytes\n")
  result.add("  By type:\n")
  for fileType, count in stats.byType:
    result.add("    " & fileType & ": " & $count & "\n")

# =============================================================================
# Utilities
# =============================================================================

proc saveCarvedFiles*(carved: seq[CarvedFile], outputDir: string) =
  ## Save carved files to directory
  ## Files are named: <offset>_<type>.<ext>
  import std/os
  createDir(outputDir)

  for i, file in carved:
    let filename = outputDir / $file.offset & "_" & file.fileType & "." &
                   (if file.fileType == "JPEG": "jpg"
                    elif file.fileType == "PNG": "png"
                    else: "bin")

    var f: File
    if open(f, filename, fmWrite):
      discard f.writeBuffer(unsafeAddr file.data[0], file.data.len)
      f.close()

proc `$`*(carved: CarvedFile): string =
  result = carved.fileType & " at offset 0x" & carved.offset.toHex &
           ", size: " & $carved.size & " bytes"
