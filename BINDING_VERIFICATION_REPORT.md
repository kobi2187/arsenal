# Binding Verification Report

**Date**: 2026-01-31  
**Phase**: 2 - Binding Verification  
**Status**: In Progress

---

## Summary

Comparing C API signatures from vendor libraries against Nim importc declarations to identify any mismatches that could cause linking or runtime issues.

---

## 1. picohttpparser Verification

### C Header Summary (from vendor/picohttpparser/picohttpparser.h)

**Structures:**
```c
struct phr_header {
    const char *name;
    size_t name_len;
    const char *value;
    size_t value_len;
};

struct phr_chunked_decoder {
    size_t bytes_left_in_chunk;
    char consume_trailer;
    char _hex_count;
    char _state;
    uint64_t _total_read;
    uint64_t _total_overhead;
};
```

**Key Functions:**
```c
int phr_parse_request(const char *buf, size_t len, const char **method, 
                      size_t *method_len, const char **path, size_t *path_len,
                      int *minor_version, struct phr_header *headers, 
                      size_t *num_headers, size_t last_len);

int phr_parse_response(const char *buf, size_t len, int *minor_version, 
                       int *status, const char **msg, size_t *msg_len,
                       struct phr_header *headers, size_t *num_headers, 
                       size_t last_len);

int phr_parse_headers(const char *buf, size_t len, struct phr_header *headers, 
                      size_t *num_headers, size_t last_len);

size_t phr_decode_chunked(struct phr_chunked_decoder *decoder, 
                          const char **buf, size_t *bufsz);
```

### Nim Bindings (from src/arsenal/parsing/parsers/picohttpparser.nim)

**Issue 1**: Structure field name mismatch
- C: `phr_header.name`, `phr_header.value`
- Nim: Currently works (backticks escape C keywords)
- **Status**: ✅ OK

**Issue 2**: All parsing functions are stubbed and return errors
- `parseHttpRequest()` returns `err("Not implemented")`
- `parseHttpResponse()` returns `err("Not implemented")`
- `parseHeaders()` returns `err("Not implemented")`
- **Status**: ⚠️ REQUIRES IMPLEMENTATION

**Missing Implementations:**
- [ ] Wrapper for phr_parse_request() C function
- [ ] Wrapper for phr_parse_response() C function
- [ ] Wrapper for phr_parse_headers() C function
- [ ] Wrapper for phr_decode_chunked() (chunked encoding support)

**Verification Result**: ✅ Bindings are correct, implementation is stubbed

---

## 2. xxhash Verification

### C Header Summary (from vendor/xxhash/xxhash.h)

**One-shot Hashing:**
```c
typedef unsigned long long XXH64_hash_t;

XXH_PUREF XXH64_hash_t XXH64(const void* input, size_t length, XXH64_hash_t seed);
```

**Streaming Hashing:**
```c
typedef struct XXH64_state_s XXH64_state_t;

XXH64_state_t* XXH64_createState(void);
void XXH64_freeState(XXH64_state_t* statePtr);
void XXH64_reset(XXH64_state_t* statePtr, XXH64_hash_t seed);
XXH_errorcode XXH64_update(XXH64_state_t* statePtr, const void* input, size_t length);
XXH64_hash_t XXH64_digest(const XXH64_state_t* statePtr);
```

### Nim Bindings (from src/arsenal/hashing/hashers/xxhash64.nim)

**Current Implementation:**
- Uses simple XOR fallback instead of real xxHash64
- Line 136: `toFixed16(toFloat(x).sin)` → Wrong function, should be xxHash64 implementation
- **Status**: 🔴 BROKEN - Using fallback algorithm

**What's Needed:**
- [ ] Import C functions from xxhash.h
- [ ] Implement proper XXH64() one-shot hashing
- [ ] Implement XXH64_init/update/digest streaming
- [ ] Replace simple XOR with real algorithm

**Verification Result**: ⚠️ Bindings declarations needed, implementation incorrect

---

## 3. xxhash Verification (hasher.nim)

### Current Issues

**Lines 136**: 
```nim
# Returns simple XOR, should be real xxHash64
```

**Lines 175, 191** (incremental hashing):
- Not implemented - `discard` statements

**Lines 252** (wyhash):
- Simple XOR fallback instead of real algorithm

**Verification Result**: 🔴 CRITICAL - All hash functions return wrong results

---

## 4. Zstandard (zstd) Verification

### C Header Summary (from vendor/zstd/lib/zstd.h)

**Context Types:**
```c
typedef struct ZSTD_CCtx_s ZSTD_CCtx;  /* opaque compression context */
typedef struct ZSTD_DCtx_s ZSTD_DCtx;  /* opaque decompression context */
```

**One-shot Compression:**
```c
size_t ZSTD_compress( void* dst, size_t dstCapacity,
                      const void* src, size_t srcSize,
                      int compressionLevel);

size_t ZSTD_decompress( void* dst, size_t dstCapacity,
                        const void* src, size_t srcSize);
```

**Context Creation:**
```c
ZSTD_CCtx* ZSTD_createCCtx(void);
void ZSTD_freeCCtx(ZSTD_CCtx* cctx);

ZSTD_DCtx* ZSTD_createDCtx(void);
void ZSTD_freeDCtx(ZSTD_DCtx* dctx);
```

### Nim Bindings (from src/arsenal/compression/compressors/zstd.nim)

**Current Status**: ✅ Bindings present, 🔴 Implementation stubbed

**Missing Implementations:**
- [ ] `ZstdCompressor.init()` - Create compression context
- [ ] `compress()` - Actual compression using ZSTD_compress()
- [ ] `ZstdDecompressor.init()` - Create decompression context
- [ ] `decompress()` - Actual decompression
- [ ] Streaming compressor (initStream, compressChunk, finish)

**Verification Result**: ✅ Bindings OK, 🔴 Implementation needed

---

## 5. simdjson Verification

### C++ vs. Nim Challenge

**Issue**: simdjson is a C++ library, not C
- Cannot directly use `importc` with C++ header
- Options:
  1. Use simdjson-c (C bindings) if available
  2. Create C wrapper with `extern "C"`
  3. Use pure-Nim JSON parser alternative

### Decision Point ⚠️

**ACTION REQUIRED**: Choose simdjson binding approach before proceeding

**Option A: simdjson-c**
- Pros: Official bindings if available
- Cons: May lag behind main library updates
- Research: Check if simdjson-c is maintained

**Option B: Create C Wrapper**
- Pros: Full control, latest simdjson features
- Cons: Requires C++ compilation setup
- Implementation: Create `simdjson-wrapper.c` with `extern "C"` functions

**Option C: Pure-Nim Alternative**
- Pros: No external dependencies, simpler setup
- Cons: May be slower than simdjson
- Options: msgpack/json, yaml, jsonutils

---

## Summary Table

| Library | Bindings | Implementation | Status | Action |
|---------|----------|----------------|--------|--------|
| **picohttpparser** | ✅ OK | 🔴 Stubbed | Ready | Implement wrappers |
| **xxhash** | ✅ OK | 🔴 Wrong | Critical | Replace XOR with real algorithm |
| **zstd** | ✅ OK | 🔴 Stubbed | Ready | Implement compression functions |
| **simdjson** | ⚠️ TBD | 🔴 Stubbed | Blocked | Choose binding approach |

---

## Recommendations

### Immediate (Next Phase)

1. **Implement xxHash64** (Phase 3)
   - Most critical - used everywhere
   - Straightforward C → Nim binding
   - Start immediately

2. **Implement picohttpparser** (Phase 4)
   - Create Nim wrappers around C functions
   - Handle zero-copy API carefully
   - Requires understanding of original buffer lifecycle

3. **Implement Zstandard** (Phase 6)
   - Simpler than JSON parsing
   - Context-based API maps well to Nim objects
   - Follow zstd examples in C

### Blocked (Needs Decision)

4. **simdjson binding approach**
   - Research simdjson-c availability and maintenance status
   - If not available, decide: wrapper vs. alternative library
   - Make decision before Phase 5

---

## Notes

### Binding Comparison Notes

- All C function signatures are compatible with Nim importc
- Parameter types (cstring, csize_t, cint) properly map to C types
- Return types properly map (int → cint, size_t → csize_t)
- No platform-specific issues detected in signatures

### Next Steps

1. ✅ Phase 1 Complete: Vendor libraries cloned
2. 🔄 Phase 2 In Progress: Binding verification
3. ⏭️  Phase 3: Implement xxHash64 (start immediately)
4. ⏭️  Phase 4: Implement picohttpparser
5. ⏭️  Phase 5: Resolve simdjson approach
6. ⏭️  Phase 6: Implement Zstandard

---

**Generated**: 2026-01-31  
**Phase**: 2 - Binding Verification  
**Status**: In Progress  
**Action Items**: 4 major decisions/implementations needed

