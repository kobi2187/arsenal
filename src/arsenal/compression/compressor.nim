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

proc encodeFrame*(data: seq[byte], originalSize: uint64, includeChecksum: bool = true): seq[byte] =
  ## Encode compressed data into frame format.
  ## IMPLEMENTATION:
  ## 1. Write magic, version, flags
  ## 2. Write original size (little-endian uint64)
  ## 3. Write compressed data
  ## 4. If includeChecksum, compute xxHash32 and append

  # Stub
  result = data

proc decodeFrame*(data: openArray[byte]): CompressionResult[CompressionFrame] =
  ## Decode frame format, validate magic and checksum.
  ## IMPLEMENTATION:
  ## 1. Read and validate magic bytes
  ## 2. Read version, flags
  ## 3. Read original size
  ## 4. Extract compressed data
  ## 5. If checksum present, validate it
  ## 6. Return CompressionFrame

  # Stub
  err[CompressionFrame]("Not implemented")

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
