## LZ4 Compression
## ===============
##
## Binding to LZ4, a very fast compression library.
## LZ4 offers the best speed/compression ratio for most use cases.
##
## Performance:
## - Compression: ~500 MB/s
## - Decompression: ~2000 MB/s (fastest)
## - Ratio: 2.0-2.5x (moderate compression)

{.pragma: lz4Import, importc, header: "<lz4.h>".}

# =============================================================================
# LZ4 Types
# =============================================================================

type
  LZ4_stream_t* {.lz4Import.} = object
    ## LZ4 streaming compression context

  LZ4_streamDecode_t* {.lz4Import.} = object
    ## LZ4 streaming decompression context

# =============================================================================
# LZ4 Functions
# =============================================================================

proc LZ4_versionNumber*(): cint {.lz4Import.}
  ## Get LZ4 version number

proc LZ4_compress_default*(
  src: cstring, dst: cstring,
  srcSize: cint, dstCapacity: cint
): cint {.lz4Import.}
  ## Compress data.
  ## Returns compressed size, or 0 on error.

proc LZ4_decompress_safe*(
  src: cstring, dst: cstring,
  compressedSize: cint, dstCapacity: cint
): cint {.lz4Import.}
  ## Decompress data.
  ## Returns decompressed size, or negative on error.

proc LZ4_compressBound*(inputSize: cint): cint {.lz4Import.}
  ## Maximum compressed size for given input size.

# Streaming compression
proc LZ4_createStream*(): ptr LZ4_stream_t {.lz4Import.}
  ## Create compression stream

proc LZ4_freeStream*(streamPtr: ptr LZ4_stream_t): cint {.lz4Import.}
  ## Free compression stream

proc LZ4_compress_fast_continue*(
  streamPtr: ptr LZ4_stream_t,
  src: cstring, dst: cstring,
  srcSize: cint, dstCapacity: cint, acceleration: cint
): cint {.lz4Import.}
  ## Streaming compression

# Streaming decompression
proc LZ4_createStreamDecode*(): ptr LZ4_streamDecode_t {.lz4Import.}
  ## Create decompression stream

proc LZ4_freeStreamDecode*(streamPtr: ptr LZ4_streamDecode_t): cint {.lz4Import.}
  ## Free decompression stream

proc LZ4_decompress_safe_continue*(
  streamPtr: ptr LZ4_streamDecode_t,
  src: cstring, dst: cstring,
  srcSize: cint, dstCapacity: cint
): cint {.lz4Import.}
  ## Streaming decompression

# =============================================================================
# Nim Wrapper
# =============================================================================

type
  Lz4Compressor* = object
    ## LZ4 compression wrapper.
    stream: ptr LZ4_stream_t

proc init*(_: typedesc[Lz4Compressor]): Lz4Compressor =
  ## Create LZ4 compressor.
  ##
  ## TECHNICAL NOTES:
  ## - LZ4_createStream() allocates ~16KB for dictionary
  ## - Use for streaming compression or multiple blocks
  ## - For one-shot, can use LZ4_compress_default directly (no stream needed)
  ## - Stream enables dictionary compression for better ratio

  result.stream = LZ4_createStream()
  if result.stream == nil:
    raise newException(IOError, "Failed to create LZ4 stream")

proc `=destroy`*(c: var Lz4Compressor) =
  ## Destroy compressor.
  ##
  ## TECHNICAL NOTES:
  ## - LZ4_freeStream returns 0 on success
  ## - Safe to call with nil pointer
  ## - Must free to avoid 16KB memory leak per compressor

  if c.stream != nil:
    discard LZ4_freeStream(c.stream)
    c.stream = nil

proc compress*(c: var Lz4Compressor, data: openArray[byte]): seq[byte] =
  ## Compress data using LZ4.
  ##
  ## TECHNICAL NOTES:
  ## - LZ4_compressBound: Returns max size = inputSize + (inputSize/255) + 16
  ## - Worst case: incompressible data slightly expands
  ## - LZ4_compress_default uses compression level 1 (fast mode)
  ## - For higher compression, use LZ4_compress_HC (not bound here)
  ## - Returns 0 on failure (buffer too small or invalid input)
  ##
  ## PERFORMANCE:
  ## - ~500 MB/s compression on modern CPUs
  ## - Single-threaded, but can parallelize blocks
  ## - Zero-copy possible with proper buffer management

  if data.len == 0:
    return @[]

  # Calculate maximum compressed size
  let maxCompressedSize = LZ4_compressBound(data.len.cint)
  result = newSeq[byte](maxCompressedSize)

  # Compress using C pointers for zero-copy
  let compressedSize = LZ4_compress_default(
    cast[cstring](unsafeAddr data[0]),
    cast[cstring](addr result[0]),
    data.len.cint,
    maxCompressedSize
  )

  if compressedSize <= 0:
    raise newException(IOError, "LZ4 compression failed")

  # Resize to actual compressed size
  result.setLen(compressedSize)

proc compress*(data: openArray[byte]): seq[byte] =
  ## One-shot compression.
  var compressor = Lz4Compressor.init()
  result = compressor.compress(data)

# =============================================================================
# Decompressor
# =============================================================================

type
  Lz4Decompressor* = object
    ## LZ4 decompression wrapper.
    stream: ptr LZ4_streamDecode_t

proc init*(_: typedesc[Lz4Decompressor]): Lz4Decompressor =
  ## Create LZ4 decompressor.
  ##
  ## TECHNICAL NOTES:
  ## - Decompression stream needed for streaming/chunked data
  ## - For one-shot, can use LZ4_decompress_safe directly
  ## - Stream maintains dictionary for inter-block dependencies

  result.stream = LZ4_createStreamDecode()
  if result.stream == nil:
    raise newException(IOError, "Failed to create LZ4 decode stream")

proc `=destroy`*(d: var Lz4Decompressor) =
  ## Destroy decompressor.
  ##
  ## TECHNICAL NOTES:
  ## - Must free to avoid memory leak
  ## - LZ4 decode stream is smaller than compression stream

  if d.stream != nil:
    discard LZ4_freeStreamDecode(d.stream)
    d.stream = nil

proc decompress*(d: var Lz4Decompressor, data: openArray[byte], maxOutputSize: int): seq[byte] =
  ## Decompress LZ4 data.
  ## maxOutputSize: Maximum expected output size for safety.
  ##
  ## TECHNICAL NOTES:
  ## - LZ4_decompress_safe: Protected against buffer overruns
  ## - Returns negative on error (corrupted data, buffer overflow)
  ## - Returns actual decompressed size on success
  ## - maxOutputSize prevents memory exhaustion attacks
  ##
  ## PERFORMANCE:
  ## - ~2000 MB/s decompression (fastest in class)
  ## - ~4x faster than compression
  ## - Memory bandwidth bound on modern CPUs
  ##
  ## SECURITY:
  ## - Always use LZ4_decompress_safe (not _fast variant)
  ## - Validates input to prevent buffer overflows
  ## - Protects against malformed compressed data

  if data.len == 0:
    return @[]

  if maxOutputSize <= 0:
    raise newException(ValueError, "maxOutputSize must be positive")

  # Allocate output buffer
  result = newSeq[byte](maxOutputSize)

  # Decompress with bounds checking
  let decompressedSize = LZ4_decompress_safe(
    cast[cstring](unsafeAddr data[0]),
    cast[cstring](addr result[0]),
    data.len.cint,
    maxOutputSize.cint
  )

  if decompressedSize < 0:
    raise newException(IOError, "LZ4 decompression failed: corrupted data or insufficient buffer")

  # Resize to actual decompressed size
  result.setLen(decompressedSize)

proc decompress*(data: openArray[byte], maxOutputSize: int): seq[byte] =
  ## One-shot decompression.
  var decompressor = Lz4Decompressor.init()
  result = decompressor.decompress(data, maxOutputSize)

# Header and library setup
when defined(windows):
  {.passL: "-llz4".}
  {.passC: "-Ilz4/include".}
elif defined(macosx):
  {.passL: "-llz4".}
  {.passC: "-Ilz4/include".}
elif defined(linux):
  {.passL: "-llz4".}
  {.passC: "-Ilz4/include".}
else:
  {.error: "LZ4 not supported on this platform".}