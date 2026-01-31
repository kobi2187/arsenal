## Compression Abstraction
## =======================
##
## Unified interface for compression algorithms.
## Supports streaming and one-shot compression.
##
## Available Compressors:
## - LZ4: Fastest, moderate ratio (~2-2.5x)
## - Zstd: Best ratio, configurable speed/ratio tradeoff
##
## Usage:
## ```nim
## import arsenal/compression/compressor
##
## # One-shot compression
## let compressed = lz4.compress(data)
## let decompressed = lz4.decompress(compressed, originalSize)
##
## # Streaming compression
## var compressor = Lz4Compressor.init()
## for chunk in chunks:
##   let compressed = compressor.compress(chunk)
##   output.write(compressed)
## ```

import std/options

type
  CompressionLevel* = range[1..22]
    ## Compression level (1=fastest, 22=best ratio).
    ## Different compressors support different ranges.
    ## LZ4: Effectively binary (fast or high compression)
    ## Zstd: Full range 1-22

const
  DefaultLevel* = CompressionLevel(9)
    ## Balanced default compression level

type
  Compressor* = concept c
    ## Compression algorithm interface.
    ## Supports both stateless (one-shot) and stateful (streaming) compression.
    ##
    ## Implementations must provide:
    ## - compress(data) -> compressed bytes
    ## - decompress(data, maxSize) -> original bytes
    ## - (optional) streaming support via mutable state

    c.compress(openArray[byte]) is seq[byte]
    c.decompress(openArray[byte], int) is seq[byte]

  StreamingCompressor* = concept c
    ## Streaming compression interface.
    ## Maintains internal state across multiple compress() calls.
    ## Useful for compressing data in chunks without buffering everything.

    var mutableC = c
    mutableC.compress(openArray[byte]) is seq[byte]
    mutableC.finish() is seq[byte]  # Flush any remaining data
    mutableC.reset()                 # Reset to initial state

# =============================================================================
# Compression Result
# =============================================================================

type
  CompressionResult*[T] = object
    ## Result of a compression operation.
    ## Can represent success or failure with error details.
    case success*: bool
    of true:
      data*: T
      compressedSize*: int      ## Size after compression
      originalSize*: int        ## Original input size
      ratio*: float             ## Compression ratio (original / compressed)
    of false:
      error*: string

proc ok*[T](data: T, originalSize: int): CompressionResult[T] =
  ## Create successful compression result.
  let compSize = data.len
  let ratio = if compSize > 0: originalSize.float / compSize.float else: 0.0
  result = CompressionResult[T](
    success: true,
    data: data,
    compressedSize: compSize,
    originalSize: originalSize,
    ratio: ratio
  )

proc err*[T](error: string): CompressionResult[T] =
  ## Create failed compression result.
  result = CompressionResult[T](
    success: false,
    error: error
  )

proc isOk*[T](r: CompressionResult[T]): bool {.inline.} =
  ## Check if result is successful.
  r.success

proc isErr*[T](r: CompressionResult[T]): bool {.inline.} =
  ## Check if result is an error.
  not r.success

proc get*[T](r: CompressionResult[T]): T =
  ## Get data from result, raises if error.
  if not r.success:
    raise newException(ValueError, r.error)
  result = r.data

# =============================================================================
# Frame Format
# =============================================================================

type
  CompressionFrame* = object
    ## Standard frame format for compressed data.
    ## Allows decompression without knowing original size upfront.
    ##
    ## Frame layout (little-endian):
    ## - Magic: 4 bytes (0x41 0x52 0x53 0x4C = "ARSL")
    ## - Version: 1 byte
    ## - Flags: 1 byte (bit 0 = checksum present)
    ## - Original size: 8 bytes (uint64)
    ## - Compressed data: variable
    ## - Checksum: 4 bytes (xxHash32, optional)

    magic*: array[4, byte]
    version*: uint8
    flags*: uint8
    originalSize*: uint64
    data*: seq[byte]
    checksum*: Option[uint32]

const
  FrameMagic* = [byte 0x41, 0x52, 0x53, 0x4C]  # "ARSL"
  FrameVersion* = 1'u8
  FlagChecksum* = 0b00000001'u8

proc okFrame*(frame: CompressionFrame): CompressionResult[CompressionFrame] =
  ## Create successful compression result for frame.
  result = CompressionResult[CompressionFrame](
    success: true,
    data: frame,
    compressedSize: frame.data.len,
    originalSize: frame.originalSize.int,
    ratio: if frame.data.len > 0: frame.originalSize.float / frame.data.len.float else: 0.0
  )

proc encodeFrame*(data: seq[byte], originalSize: uint64, includeChecksum: bool = true): seq[byte] =
  ## Encode compressed data into frame format.

  result = newSeq[byte](4 + 1 + 1 + 8 + data.len + (if includeChecksum: 4 else: 0))

  var offset = 0

  # Write magic
  result[offset..offset+3] = FrameMagic
  offset += 4

  # Write version
  result[offset] = FrameVersion
  offset += 1

  # Write flags
  let flags = if includeChecksum: FlagChecksum else: 0'u8
  result[offset] = flags
  offset += 1

  # Write original size (little-endian uint64)
  for i in 0..<8:
    result[offset + i] = byte((originalSize shr (i * 8)) and 0xFF)
  offset += 8

  # Write compressed data
  result[offset..offset+data.len-1] = data
  offset += data.len

  # Write checksum if requested (simplified: just XOR all bytes)
  if includeChecksum:
    var checksum = 0u32
    for b in data:
      checksum = checksum xor b.uint32
    for i in 0..<4:
      result[offset + i] = byte((checksum shr (i * 8)) and 0xFF)

proc decodeFrame*(data: openArray[byte]): CompressionResult[CompressionFrame] =
  ## Decode frame format, validate magic and checksum.

  if data.len < 14:
    return err[CompressionFrame]("Frame too small (minimum 14 bytes)")

  var offset = 0
  var frame = CompressionFrame()

  # Read and validate magic
  for i in 0..<4:
    frame.magic[i] = data[offset + i]
  if frame.magic != FrameMagic:
    return err[CompressionFrame]("Invalid frame magic")
  offset += 4

  # Read version
  frame.version = data[offset]
  if frame.version != FrameVersion:
    return err[CompressionFrame]("Unsupported frame version")
  offset += 1

  # Read flags
  frame.flags = data[offset]
  offset += 1

  # Read original size (little-endian uint64)
  frame.originalSize = 0
  for i in 0..<8:
    frame.originalSize = frame.originalSize or (data[offset + i].uint64 shl (i * 8))
  offset += 8

  # Extract compressed data
  let hasChecksum = (frame.flags and FlagChecksum) != 0
  let checksumSize = if hasChecksum: 4 else: 0
  let compressedDataSize = data.len - offset - checksumSize

  if compressedDataSize < 0:
    return err[CompressionFrame]("Invalid frame size")

  frame.data = @data[offset..offset+compressedDataSize-1]
  offset += compressedDataSize

  # Validate checksum if present
  if hasChecksum:
    var storedChecksum = 0u32
    for i in 0..<4:
      storedChecksum = storedChecksum or (data[offset + i].uint32 shl (i * 8))

    var computedChecksum = 0u32
    for b in frame.data:
      computedChecksum = computedChecksum xor b.uint32

    if storedChecksum != computedChecksum:
      return err[CompressionFrame]("Checksum mismatch")

    frame.checksum = some(storedChecksum)

  okFrame(frame)

# =============================================================================
# Utility Functions
# =============================================================================

proc estimateMaxCompressedSize*(originalSize: int, algorithm: string = "lz4"): int =
  ## Estimate maximum compressed size for given input.
  ## Always >= originalSize (worst case: incompressible data).
  ##
  ## IMPLEMENTATION:
  ## LZ4: originalSize + (originalSize div 255) + 16
  ## Zstd: Use ZSTD_compressBound()

  # Conservative estimate
  result = originalSize + (originalSize div 8) + 1024

proc compressionRatio*(originalSize, compressedSize: int): float =
  ## Calculate compression ratio.
  ## > 1.0 = compression achieved
  ## < 1.0 = expansion (rare, incompressible data)
  ## = 1.0 = no change

  if compressedSize == 0:
    return 0.0
  originalSize.float / compressedSize.float

# =============================================================================
# Export Compressor Implementations
# =============================================================================

import ./compressors/lz4
export lz4

when not defined(arsenal_no_zstd):
  import ./compressors/zstd
  export zstd
