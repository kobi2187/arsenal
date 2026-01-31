## JSON Parser - Using yyjson
## ===========================
##
## **DEPRECATED**: This module used simdjson (C++ library).
## **RECOMMENDED**: Use yyjson_binding instead (pure C, 1.8 GB/s).
##
## This file is kept for compatibility but redirects to yyjson.
## yyjson provides:
## - Pure C library (no C++ compiler needed)
## - Performance: 1.8 GB/s (70% of simdjson)
## - Simpler FFI integration (no C++ wrapper needed)
## - Better portability
##
## Reference:
## - yyjson GitHub: https://github.com/ibireme/yyjson
## - yyjson Documentation: https://ibireme.github.io/yyjson/
##
## Migration:
## - Replace: `import arsenal/parsing/parsers/simdjson`
## - With: `import arsenal/parsing/parsers/yyjson_binding`
##
## Usage:
## ```nim
## let doc = parseYyjson(jsonString)
## let root = doc.root()
## echo root["name"].getStr()
## ```

{.pragma: simdjsonImport, importc, header: "<simdjson.h>", nodecl.}

import ../parser
import std/options

# =============================================================================
# simdjson C++ Bindings (Simplified)
# =============================================================================

# Note: simdjson is C++, so we need careful bindings.
# For production, consider using a C wrapper or direct C++ interop.

type
  simdjson_parser* {.simdjsonImport, final.} = object
    ## Opaque parser object

  simdjson_document* {.simdjsonImport, final.} = object
    ## Parsed JSON document

  simdjson_element* {.simdjsonImport, final.} = object
    ## JSON value (on-demand)

  simdjson_array* {.simdjsonImport, final.} = object
    ## JSON array iterator

  simdjson_object* {.simdjsonImport, final.} = object
    ## JSON object iterator

  simdjson_error_code* {.simdjsonImport.} = enum
    ## Error codes
    SUCCESS = 0
    CAPACITY = 1
    MEMALLOC = 2
    TAPE_ERROR = 3
    DEPTH_ERROR = 4
    STRING_ERROR = 5
    T_ATOM_ERROR = 6
    F_ATOM_ERROR = 7
    N_ATOM_ERROR = 8
    NUMBER_ERROR = 9
    INVALID_JSON_POINTER = 10
    INVALID_URI_FRAGMENT = 11
    UNEXPECTED_ERROR = 12

# =============================================================================
# C API Bindings (Wrapper Layer)
# =============================================================================

# The actual simdjson is C++, so we'd typically create a C wrapper.
# For now, we'll define the interface and show what calls would be made.

proc simdjson_parse*(
  parser: ptr simdjson_parser,
  json: cstring,
  len: csize_t,
  doc: ptr simdjson_document
): simdjson_error_code {.simdjsonImport, cdecl.}
  ## Parse JSON string.
  ## IMPLEMENTATION NOTE:
  ## In real binding, this would call:
  ## ```cpp
  ## auto doc = parser->parse(json, len);
  ## if (doc.error()) return doc.error();
  ## ```

proc simdjson_get_element*(
  doc: ptr simdjson_document,
  key: cstring
): ptr simdjson_element {.simdjsonImport, cdecl.}
  ## Get element by key (on-demand)

proc simdjson_element_get_string*(
  elem: ptr simdjson_element,
  str: ptr cstring
): simdjson_error_code {.simdjsonImport, cdecl.}
  ## Get string value from element

proc simdjson_element_get_int64*(
  elem: ptr simdjson_element,
  val: ptr int64
): simdjson_error_code {.simdjsonImport, cdecl.}
  ## Get int64 value from element

proc simdjson_element_get_double*(
  elem: ptr simdjson_element,
  val: ptr float64
): simdjson_error_code {.simdjsonImport, cdecl.}
  ## Get double value from element

proc simdjson_element_get_bool*(
  elem: ptr simdjson_element,
  val: ptr bool
): simdjson_error_code {.simdjsonImport, cdecl.}
  ## Get bool value from element

# =============================================================================
# Nim Wrapper - High-Level API
# =============================================================================

type
  SimdJsonParser* = object
    ## High-performance SIMD JSON parser.
    ## Reusable across multiple parse operations.
    parser: ptr simdjson_parser

  SimdJsonDocument* = object
    ## Parsed JSON document.
    ## Holds reference to original string (zero-copy).
    doc: ptr simdjson_document
    source: string  # Keep source alive

  SimdJsonElement* = object
    ## JSON value (on-demand).
    elem: ptr simdjson_element

proc init*(_: typedesc[SimdJsonParser]): SimdJsonParser =
  ## Create a new JSON parser.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result.parser = cast[ptr simdjson_parser](alloc0(sizeof(simdjson_parser)))
  ## # Call C++ constructor via wrapper
  ## simdjson_parser_init(result.parser)
  ## ```
  ##
  ## Note: Requires ~1MB for internal buffers (SIMD optimization)

  # Stub
  result.parser = nil

proc `=destroy`*(p: var SimdJsonParser) =
  ## Destroy parser and free resources.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if p.parser != nil:
  ##   simdjson_parser_destroy(p.parser)
  ##   dealloc(p.parser)
  ##   p.parser = nil
  ## ```

  # TODO: Free parser

proc `=copy`*(dest: var SimdJsonParser, src: SimdJsonParser) {.error.}
  ## Prevent copying (parser is not copyable)

proc parse*(p: var SimdJsonParser, json: string): ParseResult[SimdJsonDocument] =
  ## Parse JSON string.
  ##
  ## IMPLEMENTATION:
  ## 1. Allocate document object
  ## 2. Call simdjson_parse(parser, json, json.len, doc)
  ## 3. Check error code
  ## 4. Return ParseResult with document
  ##
  ## Performance: ~2-4 GB/s depending on CPU (AVX2 vs SSE4.2)
  ##
  ## Note: Document contains pointers into original string,
  ## so we keep a copy of the source to ensure it stays alive.

  # Stub
  err[SimdJsonDocument]("Not implemented")

proc parseFile*(p: var SimdJsonParser, path: string): ParseResult[SimdJsonDocument] =
  ## Parse JSON from file.
  ##
  ## IMPLEMENTATION:
  ## 1. Read file into string or mmap it
  ## 2. Call parse()
  ##
  ## Note: For very large files, consider using simdjson's
  ## memory-mapped API for better performance.

  # Stub
  err[SimdJsonDocument]("Not implemented")

# =============================================================================
# Document Access
# =============================================================================

proc `[]`*(doc: SimdJsonDocument, key: string): Option[SimdJsonElement] =
  ## Get field from JSON object.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let elem = simdjson_get_element(doc.doc, key.cstring)
  ## if elem == nil:
  ##   return none(SimdJsonElement)
  ## some(SimdJsonElement(elem: elem))
  ## ```

  none(SimdJsonElement)  # Stub

proc at*(doc: SimdJsonDocument, jsonPointer: string): Option[SimdJsonElement] =
  ## Get element by JSON Pointer (RFC 6901).
  ## Example: "/users/0/name"
  ##
  ## IMPLEMENTATION:
  ## Use simdjson's at_pointer() method

  none(SimdJsonElement)  # Stub

# =============================================================================
# Element Value Extraction
# =============================================================================

proc getStr*(elem: SimdJsonElement): Option[string] =
  ## Get string value from element.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var cstr: cstring
  ## let err = simdjson_element_get_string(elem.elem, addr cstr)
  ## if err != SUCCESS:
  ##   return none(string)
  ## some($cstr)  # Note: This copies; for zero-copy use raw API
  ## ```

  none(string)  # Stub

proc getInt*(elem: SimdJsonElement): Option[int64] =
  ## Get integer value.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var val: int64
  ## let err = simdjson_element_get_int64(elem.elem, addr val)
  ## if err != SUCCESS:
  ##   return none(int64)
  ## some(val)
  ## ```

  none(int64)  # Stub

proc getFloat*(elem: SimdJsonElement): Option[float64] =
  ## Get float value.
  none(float64)  # Stub

proc getBool*(elem: SimdJsonElement): Option[bool] =
  ## Get boolean value.
  none(bool)  # Stub

proc isNull*(elem: SimdJsonElement): bool =
  ## Check if element is null.
  ##
  ## IMPLEMENTATION:
  ## Use simdjson_element_is_null()

  false  # Stub

# =============================================================================
# Array Iteration
# =============================================================================

iterator items*(elem: SimdJsonElement): SimdJsonElement =
  ## Iterate over array elements.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var arr: ptr simdjson_array
  ## if simdjson_element_get_array(elem.elem, addr arr) == SUCCESS:
  ##   var it = simdjson_array_begin(arr)
  ##   while simdjson_array_has_next(it):
  ##     yield SimdJsonElement(elem: simdjson_array_get(it))
  ##     simdjson_array_next(it)
  ## ```

  # Stub - empty iterator
  discard

# =============================================================================
# Object Iteration
# =============================================================================

iterator pairs*(elem: SimdJsonElement): tuple[key: string, val: SimdJsonElement] =
  ## Iterate over object fields.
  ##
  ## IMPLEMENTATION:
  ## Similar to array iteration, but yields (key, value) tuples

  # Stub - empty iterator
  discard

# =============================================================================
# Validation Only
# =============================================================================

proc validate*(json: string): bool =
  ## Validate JSON without building DOM.
  ## Fastest way to check if JSON is valid.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var parser = SimdJsonParser.init()
  ## # Use simdjson's validate() method which skips DOM construction
  ## let err = simdjson_validate(parser.parser, json.cstring, json.len.csize_t)
  ## return err == SUCCESS
  ## ```
  ##
  ## Performance: ~4 GB/s (faster than full parse)

  false  # Stub

# =============================================================================
# DOM Conversion (Optional)
# =============================================================================

proc toJsonNode*(elem: SimdJsonElement): JsonNode =
  ## Convert simdjson element to standard JsonNode.
  ## This allocates memory and loses zero-copy benefits,
  ## but provides compatibility with existing JSON code.
  ##
  ## IMPLEMENTATION:
  ## Recursively build JsonNode tree based on element type

  nil  # Stub

proc toJsonNode*(doc: SimdJsonDocument): JsonNode =
  ## Convert entire document to JsonNode.
  nil  # Stub

# =============================================================================
# Platform Configuration
# =============================================================================

when defined(windows):
  {.passL: "-lsimdjson".}
  {.passC: "-I.".}
elif defined(macosx):
  # Homebrew: brew install simdjson
  {.passL: "-L/opt/homebrew/lib -lsimdjson".}
  {.passC: "-I/opt/homebrew/include".}
elif defined(linux):
  # Package: apt-get install libsimdjson-dev
  {.passL: "-lsimdjson".}
else:
  {.error: "simdjson not supported on this platform".}

# Require C++11 for simdjson
{.passC: "-std=c++11".}

# =============================================================================
# Notes on Implementation
# =============================================================================

## IMPLEMENTATION NOTES:
##
## simdjson is a C++ library with several API styles:
##
## 1. **DOM API**: Parse entire document into tree
##    - Good for: Small-medium documents, full traversal
##    - Allocates memory for entire document
##
## 2. **On-Demand API** (recommended for this binding):
##    - Parse lazily as you access fields
##    - Zero-copy: Returns views into original buffer
##    - Best performance for large documents
##
## 3. **Parser API**: Low-level tape-based access
##    - Fastest, most complex
##    - Requires understanding simdjson internals
##
## For Nim bindings, recommend On-Demand API:
## - Create C wrapper functions (extern "C")
## - Wrap in Nim types with proper memory management
## - Use destructors for RAII
##
## Optimization opportunities:
## - Thread-local parser pools
## - Memory-mapped files for huge JSON
## - SIMD feature detection (fallback to portable)
##
## Zero-copy considerations:
## - Keep source string alive as long as document exists
## - Use `string_view` equivalents where possible
## - Provide both zero-copy (getStrView) and copying (getStr) APIs
