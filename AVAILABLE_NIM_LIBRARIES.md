# Available Nim Libraries for Arsenal Integration

Instead of writing C bindings for remaining stubs, we can leverage mature Nim libraries that provide production-ready implementations.

## Compression Libraries

### ✅ Zippy - Pure Nim Compression
**Repository:** [guzba/zippy](https://github.com/guzba/zippy)
**Status:** Actively maintained (updated January 2025)
**Features:**
- Pure Nim implementation (no C dependencies)
- Deflate, zlib, gzip compression
- ZIP archive support (.zip files)
- Tarball support (.tar, .tar.gz, .tgz, .taz)
- Compile-time compression (bake assets into executables)
- Works with `--gc:arc`, `--gc:orc`, and default GC
- Performance comparable to zlib (sometimes faster)

**Install:**
```bash
nimble install zippy
```

**Usage:**
```nim
import zippy

# Compress/decompress
let compressed = compress("hello world")
let decompressed = uncompress(compressed)

# Archive operations
extractAll("archive.zip", "output/")
createZipArchive("output.zip", "source/")
```

**Arsenal Integration:**
- Replace: LZ4, Zstd wrapper stubs
- Use: `zippy` for general compression needs
- Note: Deflate/gzip covers most use cases; LZ4/Zstd bindings only if extreme speed needed

---

## Cryptography & Hashing

### ✅ nimcrypto - Pure Nim Crypto Library
**Repository:** [cheatfate/nimcrypto](https://github.com/cheatfate/nimcrypto)
**Status:** Mature, widely used in Nim ecosystem
**Features:**
- SHA-2 (SHA-224, SHA-256, SHA-384, SHA-512)
- SHA-3 (Keccak)
- Blake2 (Blake2b, Blake2s)
- RIPEMD-160
- MD5 (for compatibility)
- HMAC support
- PBKDF2 key derivation
- AES encryption

**Install:**
```bash
nimble install nimcrypto
```

**Usage:**
```nim
import nimcrypto

# SHA-256
let hash = sha256.digest("hello")

# Blake2b
let hash = blake2_256.digest(data)

# HMAC-SHA256
let mac = hmac_sha256("key", "message")
```

**Arsenal Integration:**
- Replace: Crypto hash stubs
- Use: For cryptographic hashing needs
- Benefit: Pure Nim, no external dependencies

---

### ✅ nim-libsodium - Libsodium Bindings
**Repository:** [FedericoCeratto/nim-libsodium](https://github.com/FedericoCeratto/nim-libsodium)
**Alternative:** [BundleFeed/nim-libsodium](https://github.com/BundleFeed/nim-libsodium) (static linking)
**Status:** Maintained
**Features:**
- Complete libsodium bindings
- Authenticated encryption
- Public-key cryptography
- Signatures
- Password hashing (Argon2)
- Key derivation
- Random number generation

**Install:**
```bash
nimble install libsodium
```

**Arsenal Integration:**
- Use: For advanced cryptography (signatures, encryption)
- Benefit: Battle-tested libsodium library

---

## HTTP Parsing

### ✅ httpbeast - High-Performance HTTP Server
**Repository:** [dom96/httpbeast](https://github.com/dom96/httpbeast)
**Status:** Mature
**Features:**
- Pure Nim HTTP/1.1 parser
- Zero-copy parsing
- Very fast (competitive with C parsers)
- Built on libuv for async I/O

**Alternative: stdlib asynchttpserver**
- Built into Nim standard library
- No external dependencies
- Good performance for most use cases

**Arsenal Integration:**
- Replace: picohttpparser binding stub
- Use: `httpbeast` for high-performance needs, stdlib for simplicity

---

## JSON Parsing

### ✅ jsony - Fast JSON Parser
**Repository:** [treeform/jsony](https://github.com/treeform/jsony)
**Status:** Actively maintained
**Features:**
- Pure Nim implementation
- Very fast (faster than stdlib json)
- Type-safe serialization/deserialization
- Relaxed parsing mode

**Install:**
```bash
nimble install jsony
```

---

## Platform-Specific Alternatives

### SIMD Operations
Instead of manual intrinsics, consider:
- **simd.nim** (stdlib): Cross-platform SIMD abstraction
- **vmath**: Vector math with SIMD support

### Atomics
- **std/atomics** (stdlib): Cross-platform atomic operations
- No need for MSVC-specific intrinsics when using stdlib

---

## Recommended Integration Strategy

### Phase 1: Use Existing Libraries (Immediate)
1. **Compression:** Integrate `zippy` for deflate/gzip
2. **Hashing:** Integrate `nimcrypto` for crypto hashes
3. **HTTP:** Use stdlib `asynchttpserver` or `httpbeast`

### Phase 2: Evaluate Need for Bindings (Future)
Only create bindings if specific requirements demand it:
- **LZ4/Zstd:** Only if benchmarks show zippy insufficient
- **Specialized crypto:** Only if nimcrypto/libsodium don't cover use case
- **SIMD:** Only after profiling shows stdlib insufficient

### Phase 3: Pure Nim Implementations (Long-term)
For maximum portability and Arsenal's goals:
- Consider pure Nim ports of key algorithms
- Contribute improvements back to ecosystem
- Maintain zero-dependency variants

---

## Benefits of This Approach

### ✅ Immediate Value
- Production-ready code today
- No binding maintenance burden
- Active community support

### ✅ Better Portability
- Pure Nim = works everywhere Nim works
- No C compiler quirks
- Easier cross-compilation

### ✅ Nim Ecosystem Growth
- Support existing projects
- Contribute improvements
- Build community connections

### ✅ Cleaner Codebase
- Less FFI complexity
- Better type safety
- More idiomatic Nim code

---

## Next Steps

1. **Evaluate** which stubs are actually needed vs. nice-to-have
2. **Integrate** existing libraries for real needs
3. **Document** library choices in Arsenal
4. **Benchmark** against requirements
5. **Contribute** improvements upstream when beneficial

---

## Sources

- [Zippy - Pure Nim compression](https://github.com/guzba/zippy)
- [nimcrypto - Cryptographic library](https://github.com/cheatfate/nimcrypto)
- [nim-libsodium - Libsodium bindings](https://github.com/FedericoCeratto/nim-libsodium)
- [Nim wrapper packages](https://github.com/topics/nim-wrapper)
- [Nim bindings topic](https://github.com/topics/bindings?l=nim)
