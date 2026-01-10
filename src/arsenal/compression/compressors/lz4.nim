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
  ## IMPLEMENTATION:
  ## ```nim
  ## result.stream = LZ4_createStream()
  ## ```

  # Stub
  result.stream = nil

proc `=destroy`*(c: var Lz4Compressor) =
  ## Destroy compressor.
  ## IMPLEMENTATION:
  ## ```nim
  ## if c.stream != nil:
  ##   discard LZ4_freeStream(c.stream)
  ##   c.stream = nil
  ## ```

  # TODO: Free stream

proc compress*(c: var Lz4Compressor, data: openArray[byte]): seq[byte] =
  ## Compress data using LZ4.
  ## IMPLEMENTATION:
  ## 1. Calculate max compressed size with LZ4_compressBound
  ## 2. Allocate output buffer
  ## 3. Call LZ4_compress_default or streaming version
  ## 4. Return compressed data

  # Stub implementation
  result = @data  # No compression

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
  ## IMPLEMENTATION:
  ## ```nim
  ## result.stream = LZ4_createStreamDecode()
  ## ```

  # Stub
  result.stream = nil

proc `=destroy`*(d: var Lz4Decompressor) =
  ## Destroy decompressor.
  # TODO: Free stream

proc decompress*(d: var Lz4Decompressor, data: openArray[byte], maxOutputSize: int): seq[byte] =
  ## Decompress LZ4 data.
  ## maxOutputSize: Maximum expected output size for safety.
  ##
  ## IMPLEMENTATION:
  ## 1. Allocate output buffer of maxOutputSize
  ## 2. Call LZ4_decompress_safe or streaming version
  ## 3. Return decompressed data

  # Stub implementation
  result = @data  # No decompression

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