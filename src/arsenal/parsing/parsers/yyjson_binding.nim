## yyjson - Pure C, High-Performance JSON Parser
## ============================================
##
## Bindings to yyjson, a high-performance pure C JSON parser.
## Performance: ~1.8 GB/s (70% of simdjson, but pure C, no C++ complexity)
##
## Reference:
## - GitHub: https://github.com/ibireme/yyjson
## - Documentation: https://ibireme.github.io/yyjson/
##
## Features:
## - Pure C library (no C++ required)
## - Zero-copy reading, streaming parsing
## - Both reading and writing support
## - Configurable memory allocator
## - Compact and portable

{.pragma: yyjsonImport, importc, header: "<yyjson.h>".}

import std/options

# =============================================================================
# yyjson C Types (Simplified)
# =============================================================================

type
  YyJsonDocHandle* {.yyjsonImport, final.} = object
    ## Opaque JSON document handle

  YyJsonValHandle* {.yyjsonImport, final.} = object
    ## Opaque JSON value handle

  YyJsonReadErr* {.yyjsonImport, final.} = object
    ## Error information from parsing
    code*: uint32
    msg*: cstring
    pos*: csize_t

  YyJsonReadFlag* = enum
    ## Parser options flags
    YYJSON_READ_ALLOW_TRAILING_COMMAS = 1
    YYJSON_READ_ALLOW_INF_AND_NAN = 2
    YYJSON_READ_INSITU = 4  # Modify input buffer in-place

  YyJsonWriteFlag* = enum
    ## Writer options flags
    YYJSON_WRITE_PRETTY = 1
    YYJSON_WRITE_ESCAPE_UNICODE = 2

# =============================================================================
# yyjson C API Functions
# =============================================================================

proc yyjson_read*(
  data: cstring,
  len: csize_t,
  flags: YyJsonReadFlag,
  alloc: pointer,
  err: ptr YyJsonReadErr
): ptr YyJsonDocHandle {.yyjsonImport.}
  ## Read JSON from string.

proc yyjson_read_file*(
  path: cstring,
  flags: YyJsonReadFlag,
  alloc: pointer,
  err: ptr YyJsonReadErr
): ptr YyJsonDocHandle {.yyjsonImport.}
  ## Read JSON from file.

proc yyjson_doc_get_root*(
  doc: ptr YyJsonDocHandle
): ptr YyJsonValHandle {.yyjsonImport.}
  ## Get root value of document.

proc yyjson_doc_free*(
  doc: ptr YyJsonDocHandle
) {.yyjsonImport.}
  ## Free document and all associated values.

proc yyjson_obj_get*(
  obj: ptr YyJsonValHandle,
  key: cstring
): ptr YyJsonValHandle {.yyjsonImport.}
  ## Get object field by key.

proc yyjson_arr_get*(
  arr: ptr YyJsonValHandle,
  idx: csize_t
): ptr YyJsonValHandle {.yyjsonImport.}
  ## Get array element by index.

proc yyjson_get_string*(
  val: ptr YyJsonValHandle
): cstring {.yyjsonImport.}
  ## Get string value (NULL if not a string).

proc yyjson_get_sint*(
  val: ptr YyJsonValHandle
): int64 {.yyjsonImport.}
  ## Get signed integer value.

proc yyjson_get_uint*(
  val: ptr YyJsonValHandle
): uint64 {.yyjsonImport.}
  ## Get unsigned integer value.

proc yyjson_get_real*(
  val: ptr YyJsonValHandle
): float64 {.yyjsonImport.}
  ## Get floating-point value.

proc yyjson_get_bool*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}
  ## Get boolean value.

proc yyjson_is_str*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}

proc yyjson_is_int*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}

proc yyjson_is_real*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}

proc yyjson_is_bool*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}

proc yyjson_is_null*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}

proc yyjson_is_arr*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}

proc yyjson_is_obj*(
  val: ptr YyJsonValHandle
): bool {.yyjsonImport.}

proc yyjson_arr_size*(
  arr: ptr YyJsonValHandle
): csize_t {.yyjsonImport.}
  ## Get array size.

proc yyjson_obj_size*(
  obj: ptr YyJsonValHandle
): csize_t {.yyjsonImport.}
  ## Get object field count.

# =============================================================================
# Nim Wrapper - High-Level API
# =============================================================================

type
  YyjsonDocument* = object
    ## High-level wrapper for yyjson document
    doc: ptr YyJsonDocHandle
    source: string  # Keep source alive

  YyjsonValue* = object
    ## High-level wrapper for yyjson value
    val: ptr YyJsonValHandle

proc parseYyjson*(json: string): YyjsonDocument =
  ## Parse JSON string using yyjson.
  ## Performance: ~1.8 GB/s
  var err: YyJsonReadErr
  let doc = yyjson_read(json.cstring, json.len.csize_t, YyJsonReadFlag(0), nil, addr err)

  if doc == nil:
    raise newException(ValueError, "JSON parse error at position " & $err.pos & ": " & $err.msg)

  result.doc = doc
  result.source = json

proc `=destroy`*(doc: var YyjsonDocument) =
  ## Free yyjson document
  if doc.doc != nil:
    yyjson_doc_free(doc.doc)
    doc.doc = nil

proc `=copy`*(dest: var YyjsonDocument, src: YyjsonDocument) {.error.}
  ## Prevent copying (document owns resources)

proc root*(doc: YyjsonDocument): YyjsonValue =
  ## Get root value
  result.val = yyjson_doc_get_root(doc.doc)

proc getStr*(val: YyjsonValue): Option[string] =
  ## Get string value
  if yyjson_is_str(val.val):
    let s = yyjson_get_string(val.val)
    if s != nil:
      return some($s)
  none(string)

proc getInt*(val: YyjsonValue): Option[int64] =
  ## Get integer value
  if yyjson_is_int(val.val):
    return some(yyjson_get_sint(val.val))
  none(int64)

proc getUint*(val: YyjsonValue): Option[uint64] =
  ## Get unsigned integer value
  if yyjson_is_int(val.val):
    return some(yyjson_get_uint(val.val))
  none(uint64)

proc getFloat*(val: YyjsonValue): Option[float64] =
  ## Get floating-point value
  if yyjson_is_real(val.val):
    return some(yyjson_get_real(val.val))
  none(float64)

proc getBool*(val: YyjsonValue): Option[bool] =
  ## Get boolean value
  if yyjson_is_bool(val.val):
    return some(yyjson_get_bool(val.val))
  none(bool)

proc isNull*(val: YyjsonValue): bool =
  ## Check if value is null
  yyjson_is_null(val.val)

proc `[]`*(val: YyjsonValue, key: string): Option[YyjsonValue] =
  ## Get object field by key
  if yyjson_is_obj(val.val):
    let field = yyjson_obj_get(val.val, key.cstring)
    if field != nil:
      return some(YyjsonValue(val: field))
  none(YyjsonValue)

proc `[]`*(val: YyjsonValue, idx: int): Option[YyjsonValue] =
  ## Get array element by index
  if yyjson_is_arr(val.val):
    let elem = yyjson_arr_get(val.val, idx.csize_t)
    if elem != nil:
      return some(YyjsonValue(val: elem))
  none(YyjsonValue)

proc len*(val: YyjsonValue): int =
  ## Get array or object size
  if yyjson_is_arr(val.val):
    return yyjson_arr_size(val.val).int
  elif yyjson_is_obj(val.val):
    return yyjson_obj_size(val.val).int
  0

# =============================================================================
# Platform Configuration
# =============================================================================

when defined(windows):
  {.passL: "-lyyjson".}
  {.passC: "-I.".}
elif defined(macosx):
  {.passL: "-L/opt/homebrew/lib -lyyjson".}
  {.passC: "-I/opt/homebrew/include".}
elif defined(linux):
  {.passL: "-lyyjson".}
else:
  {.error: "yyjson not supported on this platform".}
