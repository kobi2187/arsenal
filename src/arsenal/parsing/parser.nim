## Parsing Abstraction
## ====================
##
## High-performance parsers for common data formats.
## Focus on zero-copy, SIMD-accelerated implementations.
##
## Available Parsers:
## - JSON: simdjson (gigabytes/sec with SIMD)
## - HTTP: picohttpparser (zero-copy header parsing)
##
## Design Principles:
## - Zero-copy where possible (return slices, not copies)
## - Validation at parse time (fail fast)
## - Streaming support for large inputs
## - SIMD acceleration for throughput

import std/[options, tables, strutils]

# =============================================================================
# Parse Result
# =============================================================================

type
  ParseError* = object of CatchableError
    ## Base exception for parsing errors
    line*: int
    column*: int
    offset*: int

  ParseResult*[T] = object
    ## Result of a parse operation.
    case success*: bool
    of true:
      value*: T
      bytesConsumed*: int  ## How many bytes were parsed
    of false:
      error*: string
      errorOffset*: int

proc ok*[T](value: T, bytesConsumed: int = 0): ParseResult[T] =
  ## Create successful parse result.
  ParseResult[T](
    success: true,
    value: value,
    bytesConsumed: bytesConsumed
  )

proc err*[T](error: string, offset: int = 0): ParseResult[T] =
  ## Create failed parse result.
  ParseResult[T](
    success: false,
    error: error,
    errorOffset: offset
  )

proc isOk*[T](r: ParseResult[T]): bool {.inline.} =
  r.success

proc isErr*[T](r: ParseResult[T]): bool {.inline.} =
  not r.success

proc get*[T](r: ParseResult[T]): T =
  ## Get value from result, raises if error.
  if not r.success:
    raise newException(ParseError, r.error)
  r.value

proc getOrDefault*[T](r: ParseResult[T], default: T): T =
  ## Get value or return default if error.
  if r.success: r.value else: default

# =============================================================================
# JSON Types
# =============================================================================

type
  JsonNodeKind* = enum
    ## JSON value types
    jnkNull
    jnkBool
    jnkNumber
    jnkString
    jnkArray
    jnkObject

  JsonNode* = ref object
    ## JSON value (variant object).
    ## For high-performance use cases, consider using simdjson's
    ## on-demand API to avoid allocating nodes.
    case kind*: JsonNodeKind
    of jnkNull:
      discard
    of jnkBool:
      boolVal*: bool
    of jnkNumber:
      floatVal*: float64
      intVal*: int64
      isInt*: bool
    of jnkString:
      strVal*: string
    of jnkArray:
      elems*: seq[JsonNode]
    of jnkObject:
      fields*: OrderedTable[string, JsonNode]

proc `[]`*(n: JsonNode, key: string): JsonNode =
  ## Get object field.
  if n.kind != jnkObject:
    raise newException(ValueError, "Not an object")
  result = n.fields.getOrDefault(key, nil)

proc `[]`*(n: JsonNode, index: int): JsonNode =
  ## Get array element.
  if n.kind != jnkArray:
    raise newException(ValueError, "Not an array")
  result = n.elems[index]

proc len*(n: JsonNode): int =
  ## Get array length or object field count.
  case n.kind
  of jnkArray: n.elems.len
  of jnkObject: n.fields.len
  else: 0

# =============================================================================
# HTTP Types
# =============================================================================

type
  HttpMethod* = enum
    ## HTTP request methods
    hmGet = "GET"
    hmPost = "POST"
    hmPut = "PUT"
    hmDelete = "DELETE"
    hmHead = "HEAD"
    hmOptions = "OPTIONS"
    hmPatch = "PATCH"
    hmTrace = "TRACE"
    hmConnect = "CONNECT"

  HttpVersion* = object
    ## HTTP version (e.g., HTTP/1.1)
    major*: int
    minor*: int

  HttpHeader* = object
    ## Single HTTP header (zero-copy).
    ## name and value are slices into original buffer.
    name*: string
    value*: string

  HttpRequest* = object
    ## Parsed HTTP request (zero-copy where possible).
    ## Path and header values reference original buffer.
    meth*: HttpMethod
    path*: string
    version*: HttpVersion
    headers*: seq[HttpHeader]
    bodyOffset*: int  ## Where body starts in original buffer

  HttpResponse* = object
    ## Parsed HTTP response.
    version*: HttpVersion
    statusCode*: int
    statusMessage*: string
    headers*: seq[HttpHeader]
    bodyOffset*: int

proc getHeader*(req: HttpRequest, name: string): Option[string] =
  ## Get header value by name (case-insensitive).
  let nameLower = name.toLowerAscii()
  for h in req.headers:
    if h.name.toLowerAscii() == nameLower:
      return some(h.value)
  none(string)

proc hasHeader*(req: HttpRequest, name: string): bool =
  ## Check if header exists.
  req.getHeader(name).isSome

# =============================================================================
# Parser Concepts
# =============================================================================

type
  JsonParser* = concept parser
    ## JSON parser interface.
    ## Can parse from string, seq[byte], or file.
    parser.parse(string) is ParseResult[JsonNode]
    parser.parseFile(string) is ParseResult[JsonNode]

  HttpParser* = concept parser
    ## HTTP parser interface.
    ## Parses requests and responses from byte buffers.
    parser.parseRequest(openArray[byte]) is ParseResult[HttpRequest]
    parser.parseResponse(openArray[byte]) is ParseResult[HttpResponse]

# =============================================================================
# Export Parser Implementations
# =============================================================================

import ./parsers/simdjson
export simdjson

when not defined(arsenal_no_picohttpparser):
  import ./parsers/picohttpparser
  export picohttpparser
