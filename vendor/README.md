# Vendor Directory

This directory contains third-party C/C++ libraries that Arsenal binds to.

## Libraries

- `libaco/` - Asymmetric coroutine library (fast context switching)
- `minicoro/` - Portable coroutine library (Windows fallback)
- `mimalloc/` - High-performance memory allocator
- `lz4/` - Fast compression library
- `zstd/` - High-compression ratio library
- `simdjson/` - SIMD-accelerated JSON parser
- `yyjson/` - Fast JSON parser
- `picohttpparser/` - Minimal HTTP parser

## Usage

Libraries are downloaded and built automatically during compilation using `{.compile.}` pragmas.

## Adding a new library

1. Download source to `vendor/library_name/`
2. Add `{.compile: "vendor/library_name/source.c".}` to the Nim binding file
3. Ensure license compatibility (MIT/BSD/Apache preferred)