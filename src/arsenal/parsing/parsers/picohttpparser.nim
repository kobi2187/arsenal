## picohttpparser - Fast HTTP Parser
## ==================================
##
## Bindings to picohttpparser, a minimal and fast HTTP parser.
## Zero-copy header parsing with excellent performance.
##
## Performance: Parses ~1GB/s of HTTP headers
## Zero-copy: Returns pointers into original buffer
##
## Reference: https://github.com/h2o/picohttpparser
##
## Features:
## - Zero dependencies (pure C)
## - Zero-copy (headers are slices of input)
## - Minimal memory allocation
## - Both request and response parsing
##
## Usage:
## ```nim
## let input = "GET /path HTTP/1.1\r\nHost: example.com\r\n\r\n"
## let req = parseHttpRequest(input.toOpenArrayByte(0, input.high))
## echo req.get().path  # "/path"
## ```

{.pragma: picoImport, importc, header: "picohttpparser.h".}

import ../parser
import std/options

# =============================================================================
# picohttpparser C Bindings
# =============================================================================

type
  phr_header* {.picoImport.} = object
    ## HTTP header (zero-copy)
    name*: cstring       ## Points into original buffer
    name_len*: csize_t
    value*: cstring      ## Points into original buffer
    value_len*: csize_t

proc phr_parse_request*(
  buf: cstring,
  len: csize_t,
  method: ptr cstring,
  method_len: ptr csize_t,
  path: ptr cstring,
  path_len: ptr csize_t,
  minor_version: ptr cint,
  headers: ptr phr_header,
  num_headers: ptr csize_t,
  last_len: csize_t
): cint {.picoImport.}
  ## Parse HTTP request.
  ## Returns:
  ## - Positive: Number of bytes consumed (successful parse)
  ## - -1: Parse error
  ## - -2: Incomplete (need more data)

proc phr_parse_response*(
  buf: cstring,
  len: csize_t,
  minor_version: ptr cint,
  status: ptr cint,
  msg: ptr cstring,
  msg_len: ptr csize_t,
  headers: ptr phr_header,
  num_headers: ptr csize_t,
  last_len: csize_t
): cint {.picoImport.}
  ## Parse HTTP response.
  ## Same return values as phr_parse_request

proc phr_parse_headers*(
  buf: cstring,
  len: csize_t,
  headers: ptr phr_header,
  num_headers: ptr csize_t,
  last_len: csize_t
): cint {.picoImport.}
  ## Parse headers only (for chunked encoding, etc.)

# =============================================================================
# Nim Wrapper - Request Parser
# =============================================================================

const MaxHeaders* = 100
  ## Maximum number of headers to parse

proc parseHttpRequest*(data: openArray[byte]): ParseResult[HttpRequest] =
  ## Parse HTTP request from byte buffer.
  ## Zero-copy: path and header values reference original buffer.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var method, path: cstring
  ## var methodLen, pathLen: csize_t
  ## var minorVersion: cint
  ## var headers: array[MaxHeaders, phr_header]
  ## var numHeaders = MaxHeaders.csize_t
  ##
  ## let bufPtr = cast[cstring](unsafeAddr data[0])
  ## let consumed = phr_parse_request(
  ##   bufPtr, data.len.csize_t,
  ##   addr method, addr methodLen,
  ##   addr path, addr pathLen,
  ##   addr minorVersion,
  ##   cast[ptr phr_header](addr headers[0]),
  ##   addr numHeaders,
  ##   0  # last_len for progressive parsing
  ## )
  ##
  ## if consumed < 0:
  ##   if consumed == -1:
  ##     return err[HttpRequest]("Parse error")
  ##   else:  # -2
  ##     return err[HttpRequest]("Incomplete request")
  ##
  ## # Build HttpRequest
  ## var req = HttpRequest()
  ## req.meth = parseMethod($method)  # TODO: implement parseMethod
  ## req.path = $path  # Copy to string
  ## req.version = HttpVersion(major: 1, minor: minorVersion.int)
  ##
  ## # Copy headers
  ## for i in 0..<numHeaders.int:
  ##   req.headers.add(HttpHeader(
  ##     name: headers[i].name[0..<headers[i].name_len.int],
  ##     value: headers[i].value[0..<headers[i].value_len.int]
  ##   ))
  ##
  ## req.bodyOffset = consumed.int
  ## ok(req, consumed.int)
  ## ```

  # Stub
  err[HttpRequest]("Not implemented")

proc parseHttpResponse*(data: openArray[byte]): ParseResult[HttpResponse] =
  ## Parse HTTP response from byte buffer.
  ##
  ## IMPLEMENTATION:
  ## Similar to parseHttpRequest, but uses phr_parse_response

  # Stub
  err[HttpResponse]("Not implemented")

proc parseHeaders*(data: openArray[byte]): ParseResult[seq[HttpHeader]] =
  ## Parse headers only (useful for chunked encoding).
  ##
  ## IMPLEMENTATION:
  ## Use phr_parse_headers

  # Stub
  err[seq[HttpHeader]]("Not implemented")

# =============================================================================
# Progressive Parsing
# =============================================================================

type
  HttpRequestParser* = object
    ## Stateful HTTP request parser for progressive/streaming parsing.
    ## Handles incomplete requests that arrive in chunks.
    buffer: seq[byte]
    lastLen: int

proc init*(_: typedesc[HttpRequestParser]): HttpRequestParser =
  ## Create progressive parser.
  result.buffer = @[]
  result.lastLen = 0

proc feed*(p: var HttpRequestParser, data: openArray[byte]): ParseResult[HttpRequest] =
  ## Feed more data to parser.
  ## Returns:
  ## - Ok with request if complete
  ## - Err with "incomplete" if more data needed
  ## - Err with "parse error" if invalid
  ##
  ## IMPLEMENTATION:
  ## 1. Append data to internal buffer
  ## 2. Call phr_parse_request with lastLen
  ## 3. If successful, extract request and clear buffer
  ## 4. If incomplete (-2), save lastLen for next call
  ## 5. If error (-1), return error

  # Stub
  err[HttpRequest]("Not implemented")

proc reset*(p: var HttpRequestParser) =
  ## Reset parser state.
  p.buffer.setLen(0)
  p.lastLen = 0

# =============================================================================
# Helper Functions
# =============================================================================

proc parseMethod(meth: string): HttpMethod =
  ## Parse HTTP method string.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## case meth
  ## of "GET": hmGet
  ## of "POST": hmPost
  ## of "PUT": hmPut
  ## of "DELETE": hmDelete
  ## of "HEAD": hmHead
  ## of "OPTIONS": hmOptions
  ## of "PATCH": hmPatch
  ## of "TRACE": hmTrace
  ## of "CONNECT": hmConnect
  ## else: raise newException(ValueError, "Unknown HTTP method: " & meth)
  ## ```

  hmGet  # Stub

proc `$`*(h: HttpHeader): string =
  ## Format header as "Name: Value"
  h.name & ": " & h.value

proc `$`*(req: HttpRequest): string =
  ## Format request for debugging.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result = $req.meth & " " & req.path & " HTTP/" & $req.version.major & "." & $req.version.minor & "\r\n"
  ## for h in req.headers:
  ##   result.add $h & "\r\n"
  ## ```

  ""  # Stub

# =============================================================================
# Chunked Transfer Encoding
# =============================================================================

proc parseChunkSize*(data: openArray[byte]): ParseResult[int] =
  ## Parse chunk size line from chunked transfer encoding.
  ## Format: "1a3f\r\n" -> 0x1a3f
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## # Find \r\n
  ## var i = 0
  ## while i < data.len and data[i] notin {'\r'.byte, '\n'.byte}:
  ##   inc i
  ##
  ## if i >= data.len or data[i] != '\r'.byte:
  ##   return err[int]("Invalid chunk size")
  ##
  ## # Parse hex number
  ## let sizeStr = cast[string](data[0..<i])
  ## try:
  ##   let size = parseHexInt(sizeStr)
  ##   ok(size, i + 2)  # +2 for \r\n
  ## except ValueError:
  ##   err[int]("Invalid hex in chunk size")
  ## ```

  # Stub
  err[int]("Not implemented")

# =============================================================================
# Platform Configuration
# =============================================================================

# picohttpparser is typically vendored (single .h file)
# Include the header directly or install as system library

when defined(windows):
  {.passC: "-I.".}
elif defined(macosx):
  {.passC: "-I.".}
elif defined(linux):
  {.passC: "-I.".}

# =============================================================================
# Performance Notes
# =============================================================================

## IMPLEMENTATION NOTES:
##
## picohttpparser optimizations:
##
## 1. **Zero-copy**: Headers reference original buffer
##    - Keep source buffer alive while using headers
##    - Copy to string only if needed
##
## 2. **Progressive parsing**: Reuse parser for chunked input
##    - lastLen parameter tracks parse state
##    - Avoids re-parsing already-seen data
##
## 3. **Header limits**: Set MaxHeaders based on use case
##    - Typical: 20-50 headers
##    - Adjust based on security vs performance needs
##
## 4. **Method parsing**: Use lookup table for speed
##    - 9 methods fit in small jump table
##    - Or use trie for zero-copy method enum
##
## 5. **Memory pooling**: Reuse parser objects
##    - Avoid allocation per request
##    - Thread-local parser pool
##
## Typical performance:
## - Simple request: ~10 nanoseconds
## - 20 headers: ~100 nanoseconds
## - Throughput: ~1 GB/s of header data
##
## Comparison to other parsers:
## - nodejs/http-parser: ~2x slower
## - nginx parser: Similar performance
## - Rust httparse: Similar performance
