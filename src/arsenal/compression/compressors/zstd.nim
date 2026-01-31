## Zstandard Compression
## =====================
##
## Binding to Zstd, a modern compression algorithm by Facebook/Meta.
## Zstd offers the best compression ratio with configurable speed tradeoff.
##
## Performance:
## - Compression: 100-700 MB/s (level dependent)
## - Decompression: ~1000 MB/s
## - Ratio: 2.5-5.0x (excellent compression)
##
## Reference: RFC 8878 - Zstandard Compression
## C library: https://github.com/facebook/zstd

{.pragma: zstdImport, importc, header: "<zstd.h>".}

# =============================================================================
# Zstd Types
# =============================================================================

type
  ZSTD_CCtx* {.zstdImport.} = object
    ## Compression context

  ZSTD_DCtx* {.zstdImport.} = object
    ## Decompression context

  ZSTD_CStream* {.zstdImport.} = object
    ## Streaming compression context

  ZSTD_DStream* {.zstdImport.} = object
    ## Streaming decompression context

  ZSTD_inBuffer* {.zstdImport.} = object
    ## Input buffer descriptor
    src*: pointer      ## Pointer to input data
    size*: csize_t     ## Size of input buffer
    pos*: csize_t      ## Current read position

  ZSTD_outBuffer* {.zstdImport.} = object
    ## Output buffer descriptor
    dst*: pointer      ## Pointer to output buffer
    size*: csize_t     ## Size of output buffer
    pos*: csize_t      ## Current write position

  ZSTD_EndDirective* {.zstdImport.} = enum
    ## Streaming compression directive
    ZSTD_e_continue = 0  ## Continue compressing
    ZSTD_e_flush = 1     ## Flush current block
    ZSTD_e_end = 2       ## Finish compression

# =============================================================================
# Simple API (One-shot)
# =============================================================================

proc ZSTD_versionNumber*(): cuint {.zstdImport.}
  ## Get Zstd version number

proc ZSTD_compress*(
  dst: pointer, dstCapacity: csize_t,
  src: pointer, srcSize: csize_t,
  compressionLevel: cint
): csize_t {.zstdImport.}
  ## Compress data in one call.
  ## compressionLevel: 1 (fast) to 22 (best ratio), 0 = default (3)
  ## Returns compressed size, or error code (check with ZSTD_isError)

proc ZSTD_decompress*(
  dst: pointer, dstCapacity: csize_t,
  src: pointer, srcSize: csize_t
): csize_t {.zstdImport.}
  ## Decompress data in one call.
  ## Returns decompressed size, or error code

proc ZSTD_compressBound*(srcSize: csize_t): csize_t {.zstdImport.}
  ## Maximum compressed size for given input size

proc ZSTD_isError*(code: csize_t): cuint {.zstdImport.}
  ## Check if result is an error code

proc ZSTD_getErrorName*(code: csize_t): cstring {.zstdImport.}
  ## Get error message for error code

proc ZSTD_getFrameContentSize*(src: pointer, srcSize: csize_t): culonglong {.zstdImport.}
  ## Get decompressed size from frame header (if available)

# =============================================================================
# Context API (Reusable)
# =============================================================================

proc ZSTD_createCCtx*(): ptr ZSTD_CCtx {.zstdImport.}
  ## Create compression context (reusable)

proc ZSTD_freeCCtx*(cctx: ptr ZSTD_CCtx): csize_t {.zstdImport.}
  ## Free compression context

proc ZSTD_compressCCtx*(
  cctx: ptr ZSTD_CCtx,
  dst: pointer, dstCapacity: csize_t,
  src: pointer, srcSize: csize_t,
  compressionLevel: cint
): csize_t {.zstdImport.}
  ## Compress using reusable context

proc ZSTD_createDCtx*(): ptr ZSTD_DCtx {.zstdImport.}
  ## Create decompression context

proc ZSTD_freeDCtx*(dctx: ptr ZSTD_DCtx): csize_t {.zstdImport.}
  ## Free decompression context

proc ZSTD_decompressDCtx*(
  dctx: ptr ZSTD_DCtx,
  dst: pointer, dstCapacity: csize_t,
  src: pointer, srcSize: csize_t
): csize_t {.zstdImport.}
  ## Decompress using reusable context

# =============================================================================
# Streaming API
# =============================================================================

proc ZSTD_createCStream*(): ptr ZSTD_CStream {.zstdImport.}
  ## Create streaming compression context

proc ZSTD_freeCStream*(zcs: ptr ZSTD_CStream): csize_t {.zstdImport.}
  ## Free streaming compression context

proc ZSTD_initCStream*(zcs: ptr ZSTD_CStream, compressionLevel: cint): csize_t {.zstdImport.}
  ## Initialize compression stream

proc ZSTD_compressStream2*(
  cctx: ptr ZSTD_CCtx,
  output: var ZSTD_outBuffer,
  input: var ZSTD_inBuffer,
  endOp: ZSTD_EndDirective
): csize_t {.zstdImport.}
  ## Streaming compression (modern API)

proc ZSTD_createDStream*(): ptr ZSTD_DStream {.zstdImport.}
  ## Create streaming decompression context

proc ZSTD_freeDStream*(zds: ptr ZSTD_DStream): csize_t {.zstdImport.}
  ## Free streaming decompression context

proc ZSTD_initDStream*(zds: ptr ZSTD_DStream): csize_t {.zstdImport.}
  ## Initialize decompression stream

proc ZSTD_decompressStream*(
  zds: ptr ZSTD_DStream,
  output: var ZSTD_outBuffer,
  input: var ZSTD_inBuffer
): csize_t {.zstdImport.}
  ## Streaming decompression

proc ZSTD_CStreamOutSize*(): csize_t {.zstdImport.}
  ## Recommended output buffer size for compression streaming

proc ZSTD_DStreamOutSize*(): csize_t {.zstdImport.}
  ## Recommended output buffer size for decompression streaming

# Helper wrappers to avoid ambiguous call issues
proc createCCtx(): ptr ZSTD_CCtx = ZSTD_createCCtx()
proc createDCtx(): ptr ZSTD_DCtx = ZSTD_createDCtx()

# =============================================================================
# Nim Wrapper - Compressor
# =============================================================================

import ../compressor

type
  ZstdCompressor* = object
    ## Zstd compression wrapper with configurable level.
    ctx: ptr ZSTD_CCtx
    level: CompressionLevel

proc init*(_: typedesc[ZstdCompressor], level: CompressionLevel = DefaultLevel): ZstdCompressor =
  ## Create Zstd compressor with compression level.
  ## Level 1 (fastest) to 22 (best ratio).

  let ctx = createCCtx()
  if ctx == nil:
    raise newException(ResourceExhaustedError, "Failed to create Zstd compression context")
  result = ZstdCompressor(ctx: ctx, level: level)

proc `=destroy`*(c: var ZstdCompressor) =
  ## Destroy compressor and free resources.
  if c.ctx != nil:
    discard ZSTD_freeCCtx(c.ctx)
    c.ctx = nil

proc `=copy`*(dest: var ZstdCompressor, src: ZstdCompressor) {.error.}
  ## Prevent copying (context is not copyable)

proc compress*(c: var ZstdCompressor, data: openArray[byte]): seq[byte] =
  ## Compress data using Zstd.

  if data.len == 0:
    return @[]

  # Calculate max compressed size
  let maxSize = ZSTD_compressBound(data.len.csize_t)

  # Allocate output buffer
  result = newSeq[byte](maxSize)

  # Perform compression
  let compressedSize = ZSTD_compressCCtx(
    c.ctx,
    addr result[0], maxSize,
    unsafeAddr data[0], data.len.csize_t,
    c.level.cint
  )

  # Check for errors
  if ZSTD_isError(compressedSize) != 0:
    raise newException(IOError, "Zstd compression error: " & $ZSTD_getErrorName(compressedSize))

  # Resize to actual compressed size
  result.setLen(compressedSize)

proc compress*(data: openArray[byte], level: CompressionLevel = DefaultLevel): seq[byte] =
  ## One-shot compression with specified level.
  var compressor = ZstdCompressor.init(level)
  result = compressor.compress(data)

# =============================================================================
# Nim Wrapper - Decompressor
# =============================================================================

type
  ZstdDecompressor* = object
    ## Zstd decompression wrapper.
    ctx: ptr ZSTD_DCtx

proc init*(_: typedesc[ZstdDecompressor]): ZstdDecompressor =
  ## Create Zstd decompressor.

  result.ctx = createDCtx()
  if result.ctx == nil:
    raise newException(ResourceExhaustedError, "Failed to create Zstd decompression context")

proc `=destroy`*(d: var ZstdDecompressor) =
  ## Destroy decompressor and free resources.
  if d.ctx != nil:
    discard ZSTD_freeDCtx(d.ctx)
    d.ctx = nil

proc `=copy`*(dest: var ZstdDecompressor, src: ZstdDecompressor) {.error.}
  ## Prevent copying

proc decompress*(d: var ZstdDecompressor, data: openArray[byte], maxOutputSize: int = 0): seq[byte] =
  ## Decompress Zstd data.
  ## maxOutputSize: Expected output size (0 = auto-detect from frame header)

  if data.len == 0:
    return @[]

  # Determine output size
  var outputSize = maxOutputSize
  if outputSize == 0:
    # Try to get size from frame header
    let frameSize = ZSTD_getFrameContentSize(unsafeAddr data[0], data.len.csize_t)
    let unknownSize = not (frameSize.int64 >= 0)  # -1 means unknown size
    if not unknownSize and frameSize > 0:
      outputSize = frameSize.int
    else:
      # Use a conservative estimate: typically 2-5x expansion for text/JSON
      outputSize = (data.len * 4).max(1024)

  # Allocate output buffer
  result = newSeq[byte](outputSize)

  # Perform decompression
  let decompressedSize = ZSTD_decompressDCtx(
    d.ctx,
    addr result[0], outputSize.csize_t,
    unsafeAddr data[0], data.len.csize_t
  )

  # Check for errors
  if ZSTD_isError(decompressedSize) != 0:
    raise newException(IOError, "Zstd decompression error: " & $ZSTD_getErrorName(decompressedSize))

  # Resize to actual decompressed size
  result.setLen(decompressedSize)

proc decompress*(data: openArray[byte], maxOutputSize: int = 0): seq[byte] =
  ## One-shot decompression.
  var decompressor = ZstdDecompressor.init()
  result = decompressor.decompress(data, maxOutputSize)

# =============================================================================
# Streaming Wrapper
# =============================================================================

type
  ZstdStreamCompressor* = object
    ## Streaming Zstd compressor for chunk-by-chunk compression.
    stream: ptr ZSTD_CStream
    level: CompressionLevel
    buffer: seq[byte]

proc initStream*(_: typedesc[ZstdCompressor], level: CompressionLevel = DefaultLevel): ZstdStreamCompressor =
  ## Create streaming compressor (buffered implementation).
  ## Accumulates chunks and compresses them together.

  result.stream = nil
  result.level = level
  result.buffer = newSeq[byte]()

proc compressChunk*(s: var ZstdStreamCompressor, data: openArray[byte], flush: bool = false): seq[byte] =
  ## Compress a chunk of data (buffers internally).
  ## For streaming, data is accumulated until finish() is called.

  # Accumulate data in buffer
  s.buffer.add(data)

  # If flush requested and buffer is large, compress it
  if flush and s.buffer.len > 0:
    result = compress(s.buffer, s.level)
    s.buffer.setLen(0)
  else:
    result = @[]

proc finish*(s: var ZstdStreamCompressor): seq[byte] =
  ## Finish compression and return compressed data.

  if s.buffer.len > 0:
    result = compress(s.buffer, s.level)
    s.buffer.setLen(0)
  else:
    result = @[]

proc `=destroy`*(s: var ZstdStreamCompressor) =
  ## Clean up streaming compressor.
  if s.stream != nil:
    discard ZSTD_freeCStream(s.stream)
    s.stream = nil

# =============================================================================
# Platform Configuration
# =============================================================================

when defined(windows):
  {.passL: "-lzstd".}
  {.passC: "-I.".}
elif defined(macosx):
  # Homebrew install: brew install zstd
  {.passL: "-L/opt/homebrew/lib -lzstd".}
  {.passC: "-I/opt/homebrew/include".}
elif defined(linux):
  # Package manager: apt-get install libzstd-dev / yum install zstd-devel
  {.passL: "-lzstd".}
else:
  {.error: "Zstd not supported on this platform".}

# =============================================================================
# Constants
# =============================================================================

const
  ZstdMinLevel* = 1
  ZstdMaxLevel* = 22
  ZstdDefaultLevel* = 3
