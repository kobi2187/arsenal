# Arsenal Vendor Libraries

This directory contains third-party C/C++ libraries required for Arsenal functionality.

## Cloned Libraries

### 1. picohttpparser
- **Source**: https://github.com/h2o/picohttpparser
- **Cloned**: 2026-01-31
- **Purpose**: Fast, zero-copy HTTP request/response parsing
- **License**: MIT (see picohttpparser/LICENSE)
- **Key Files**:
  - `picohttpparser.h` - Main API header
  - `picohttpparser.c` - Implementation
- **Status**: ✅ Ready for binding verification

### 2. simdjson  
- **Source**: https://github.com/simdjson/simdjson
- **Cloned**: 2026-01-31
- **Purpose**: Fast JSON parsing (SIMD-accelerated)
- **License**: Apache 2.0 (see simdjson/LICENSE)
- **Key Files**:
  - `simdjson.h` - Main C++ API header
  - `simdjson.cpp` - Implementation
- **Status**: ⚠️ C++ library - needs C wrapper or simdjson-c bindings
- **Note**: Requires decision on C++ → Nim binding approach

### 3. xxhash
- **Source**: https://github.com/Cyan4973/xxHash
- **Cloned**: 2026-01-31
- **Purpose**: Fast, non-cryptographic hash function (14+ GB/s)
- **License**: BSD (see xxhash/LICENSE)
- **Key Files**:
  - `xxhash.h` - API header
  - `xxhash.c` - Implementation
- **Status**: ✅ Ready for binding verification

### 4. zstd
- **Source**: https://github.com/facebook/zstd
- **Cloned**: 2026-01-31
- **Purpose**: Fast, efficient compression (Facebook's Zstandard)
- **License**: BSD (see zstd/LICENSE)
- **Key Files**:
  - `lib/zstd.h` - Main API header
  - `lib/zstd.c` - Implementation
- **Status**: ✅ Ready for binding verification

## Already Present

### libaco
- **Type**: Coroutine library (hand-coded x86_64 assembly)
- **Location**: `libaco/`
- **Status**: ✅ Compiled and ready

### libaco_nim
- **Type**: Nim bindings for libaco
- **Location**: `libaco_nim/`
- **Status**: ✅ Already integrated

### minicoro
- **Type**: Alternative coroutine library
- **Location**: `minicoro/`
- **Status**: ✅ Available as alternative

## LZ4
- **Status**: Likely available as system package
- **Install**: `apt-get install liblz4-dev`
- **Alternative**: Could clone from https://github.com/lz4/lz4 if needed

---

## Binding Verification Checklist

### Phase 2 Tasks

- [ ] Compare picohttpparser.h with Nim bindings
- [ ] Verify all function signatures match
- [ ] Check macro definitions
- [ ] Document any mismatches

- [ ] Decide on simdjson C++ binding approach
- [ ] Research simdjson-c (if available)
- [ ] Plan C wrapper if needed
- [ ] Document decision

- [ ] Compare xxhash.h with Nim bindings
- [ ] Verify hash functions present
- [ ] Check streaming API (init/update/finish)

- [ ] Compare zstd.h with Nim bindings
- [ ] Verify compression context creation
- [ ] Check streaming API

---

## Next Steps

1. **Phase 2**: Binding Verification (see TODO_IMPLEMENTATION.txt)
2. **Phase 3**: Implement Hashing (xxHash64, wyhash)
3. **Phase 4**: Implement HTTP Parsing (picohttpparser)
4. **Phase 5**: Implement JSON Parsing (simdjson)
5. **Phase 6**: Implement Compression (Zstandard)

---

**Generated**: 2026-01-31
**Status**: All required libraries cloned and ready for binding verification
