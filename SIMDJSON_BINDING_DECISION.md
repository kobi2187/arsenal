# simdjson Binding Decision - Phase 5

## Challenge
simdjson is a C++ library, not C. Nim's native FFI (`importc`) is designed for C, not C++.

## Decision: Create C Wrapper Layer

### Implementation Strategy
1. **Header**: `vendor/simdjson-wrapper.h` - C interface specification
2. **Implementation**: `vendor/simdjson-wrapper.cpp` - C++ wrapper using `extern "C"`
3. **Compilation**: Compile wrapper alongside Nim code using C++ compiler
4. **Bindings**: Nim bindings in `src/arsenal/parsing/parsers/simdjson.nim` target C interface

### Why This Approach?
- ✅ Full access to simdjson's latest features
- ✅ Maintains C interface for Nim compatibility
- ✅ Minimal C++ knowledge needed (just wrapper functions)
- ✅ Flexible and maintainable
- ❌ Requires C++ compiler available

### Alternative Approaches Considered

**Option 1: Use simdjson-c**
- Status: No official C bindings available
- Status: Community forks exist but unmaintained
- Verdict: Rejected

**Option 2: Pure Nim JSON Parser**
- Pros: No dependencies, simpler
- Cons: Much slower than simdjson
- Verdict: Not viable for performance-critical use case

**Option 3: Skip simdjson**
- Pros: Simplifies implementation
- Cons: Loses gigabytes/second performance
- Verdict: Not acceptable for arsenal's use case

## Next Steps

1. Create `simdjson-wrapper.cpp` with essential functions
2. Update Nim bindings to use wrapper C interface
3. Add compilation flags to include C++ standard library
4. Test with sample JSON data
5. Benchmark against expected throughput

## Fallback Plan

If C++ compilation becomes problematic:
- Use system package: `apt-get install libsimdjson-dev`
- Rely on pre-built shared library
- Update bindings to load from system library path

---

**Status**: In Progress - Wrapper header created, awaiting implementation
**Timeline**: 2-3 hours for full implementation
**Blockers**: None (requires C++ compiler, which is typically available)
