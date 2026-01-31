## Cryptographic Primitives
## =========================
##
## Low-level crypto primitives using proven libraries.
## Bindings to libsodium (recommended) or OpenSSL fallback.
##
## Why libsodium:
## - Modern, audited implementations
## - ChaCha20-Poly1305, Ed25519, X25519
## - Constant-time operations (timing attack resistant)
## - Simple API
##
## Usage:
## ```nim
## import arsenal/crypto/primitives
##
## # Random bytes
## var key: array[32, byte]
## randombytes(key)
##
## # Hash
## let hash = crypto_hash_sha256("hello".toOpenArrayByte(0, 4))
##
## # Symmetric encryption
## let encrypted = secretbox_encrypt(message, nonce, key)
## ```

{.pragma: sodiumImport, importc, header: "<sodium.h>".}

import std/options

# =============================================================================
# Initialization
# =============================================================================

proc sodium_init*(): cint {.sodiumImport.}
  ## Initialize libsodium. Call once at program start.
  ## Returns: 0 on success, -1 on failure, 1 if already initialized

proc initCrypto*(): bool =
  ## Initialize crypto library. Returns true on success.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result = sodium_init() >= 0
  ## ```

  result = sodium_init() >= 0

# =============================================================================
# Random Number Generation
# =============================================================================

proc randombytes_buf*(buf: pointer, size: csize_t) {.sodiumImport.}
  ## Fill buffer with random bytes (cryptographically secure)

proc randombytes_uniform*(upper_bound: uint32): uint32 {.sodiumImport.}
  ## Generate random number in range [0, upper_bound) without modulo bias

proc randombytes*[N: static[int]](arr: var array[N, byte]) =
  ## Fill array with random bytes.
  randombytes_buf(addr arr[0], N.csize_t)

proc randomBytes*(n: int): seq[byte] =
  ## Generate n random bytes.
  result = newSeq[byte](n)
  if n > 0:
    randombytes_buf(addr result[0], n.csize_t)

# =============================================================================
# Hashing
# =============================================================================

const
  crypto_hash_sha256_BYTES* = 32
  crypto_hash_sha512_BYTES* = 64
  crypto_generichash_BYTES* = 32  # BLAKE2b default

proc crypto_hash_sha256*(
  output: ptr byte,
  input: ptr byte,
  inputLen: culonglong
): cint {.sodiumImport.}
  ## SHA-256 hash

proc crypto_hash_sha512*(
  output: ptr byte,
  input: ptr byte,
  inputLen: culonglong
): cint {.sodiumImport.}
  ## SHA-512 hash

proc crypto_generichash*(
  output: ptr byte,
  outputLen: csize_t,
  input: ptr byte,
  inputLen: culonglong,
  key: ptr byte,
  keyLen: csize_t
): cint {.sodiumImport.}
  ## BLAKE2b generic hash (faster than SHA-2)

# High-level wrappers
proc sha256*(data: openArray[byte]): array[32, byte] =
  ## Compute SHA-256 hash.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## discard crypto_hash_sha256(
  ##   cast[ptr byte](addr result[0]),
  ##   cast[ptr byte](unsafeAddr data[0]),
  ##   data.len.culonglong
  ## )
  ## ```

  discard crypto_hash_sha256(
    cast[ptr byte](addr result[0]),
    cast[ptr byte](unsafeAddr data[0]),
    data.len.culonglong
  )

proc blake2b*(data: openArray[byte]): array[32, byte] =
  ## Compute BLAKE2b hash (faster than SHA-256).
  discard crypto_generichash(
    cast[ptr byte](addr result[0]), 32,
    cast[ptr byte](unsafeAddr data[0]), data.len.culonglong,
    nil, 0
  )

# =============================================================================
# Symmetric Encryption (ChaCha20-Poly1305)
# =============================================================================

const
  crypto_secretbox_KEYBYTES* = 32
  crypto_secretbox_NONCEBYTES* = 24
  crypto_secretbox_MACBYTES* = 16

proc crypto_secretbox_easy*(
  c: ptr byte,
  m: ptr byte,
  mlen: culonglong,
  n: ptr byte,
  k: ptr byte
): cint {.sodiumImport.}
  ## Encrypt with ChaCha20-Poly1305

proc crypto_secretbox_open_easy*(
  m: ptr byte,
  c: ptr byte,
  clen: culonglong,
  n: ptr byte,
  k: ptr byte
): cint {.sodiumImport.}
  ## Decrypt and verify

type
  SecretKey* = array[crypto_secretbox_KEYBYTES, byte]
  Nonce* = array[crypto_secretbox_NONCEBYTES, byte]

proc encrypt*(plaintext: openArray[byte], nonce: Nonce, key: SecretKey): seq[byte] =
  ## Encrypt data with ChaCha20-Poly1305.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result = newSeq[byte](plaintext.len + crypto_secretbox_MACBYTES)
  ## discard crypto_secretbox_easy(
  ##   addr result[0],
  ##   unsafeAddr plaintext[0],
  ##   plaintext.len.culonglong,
  ##   unsafeAddr nonce[0],
  ##   unsafeAddr key[0]
  ## )
  ## ```

  result = newSeq[byte](plaintext.len + crypto_secretbox_MACBYTES)
  discard crypto_secretbox_easy(
    addr result[0],
    unsafeAddr plaintext[0],
    plaintext.len.culonglong,
    unsafeAddr nonce[0],
    unsafeAddr key[0]
  )

proc decrypt*(ciphertext: openArray[byte], nonce: Nonce, key: SecretKey): Option[seq[byte]] =
  ## Decrypt and verify. Returns none if authentication fails.

  if ciphertext.len < crypto_secretbox_MACBYTES:
    return none(seq[byte])

  var plaintext = newSeq[byte](ciphertext.len - crypto_secretbox_MACBYTES)
  let res = crypto_secretbox_open_easy(
    addr plaintext[0],
    unsafeAddr ciphertext[0],
    ciphertext.len.culonglong,
    unsafeAddr nonce[0],
    unsafeAddr key[0]
  )

  if res == 0:
    some(plaintext)
  else:
    none(seq[byte])

# =============================================================================
# Public-Key Cryptography (Ed25519)
# =============================================================================

const
  crypto_sign_PUBLICKEYBYTES* = 32
  crypto_sign_SECRETKEYBYTES* = 64
  crypto_sign_BYTES* = 64

proc crypto_sign_keypair*(
  pk: ptr byte,
  sk: ptr byte
): cint {.sodiumImport.}
  ## Generate Ed25519 keypair

proc crypto_sign_detached*(
  sig: ptr byte,
  siglen: ptr culonglong,
  m: ptr byte,
  mlen: culonglong,
  sk: ptr byte
): cint {.sodiumImport.}
  ## Sign message (detached signature)

proc crypto_sign_verify_detached*(
  sig: ptr byte,
  m: ptr byte,
  mlen: culonglong,
  pk: ptr byte
): cint {.sodiumImport.}
  ## Verify signature. Returns 0 on success, -1 on failure

type
  PublicKey* = array[crypto_sign_PUBLICKEYBYTES, byte]
  SigningKey* = array[crypto_sign_SECRETKEYBYTES, byte]
  Signature* = array[crypto_sign_BYTES, byte]

proc generateKeypair*(): tuple[public: PublicKey, secret: SigningKey] =
  ## Generate Ed25519 keypair.
  discard crypto_sign_keypair(
    cast[ptr byte](addr result.public[0]),
    cast[ptr byte](addr result.secret[0])
  )

proc sign*(message: openArray[byte], secretKey: SigningKey): Signature =
  ## Sign message with Ed25519.
  var siglen: culonglong
  discard crypto_sign_detached(
    cast[ptr byte](addr result[0]),
    addr siglen,
    cast[ptr byte](unsafeAddr message[0]),
    message.len.culonglong,
    cast[ptr byte](unsafeAddr secretKey[0])
  )

proc verify*(signature: Signature, message: openArray[byte], publicKey: PublicKey): bool =
  ## Verify Ed25519 signature.
  crypto_sign_verify_detached(
    cast[ptr byte](unsafeAddr signature[0]),
    cast[ptr byte](unsafeAddr message[0]),
    message.len.culonglong,
    cast[ptr byte](unsafeAddr publicKey[0])
  ) == 0

# =============================================================================
# Key Derivation
# =============================================================================

const
  crypto_kdf_KEYBYTES* = 32
  crypto_kdf_CONTEXTBYTES* = 8

proc crypto_kdf_derive_from_key*(
  subkey: ptr byte,
  subkeyLen: csize_t,
  subkeyId: uint64,
  ctx: ptr byte,
  key: ptr byte
): cint {.sodiumImport.}
  ## Derive subkey from master key

proc deriveKey*(masterKey: array[32, byte], context: array[8, byte], id: uint64): array[32, byte] =
  ## Derive subkey from master key.
  ##
  ## IMPLEMENTATION:
  ## Useful for deriving multiple keys from one master key.
  ## Context should be application-specific (e.g., "MyApp001")

  discard crypto_kdf_derive_from_key(
    cast[ptr byte](addr result[0]),
    32,
    id,
    cast[ptr byte](unsafeAddr context[0]),
    cast[ptr byte](unsafeAddr masterKey[0])
  )

# =============================================================================
# Memory Protection
# =============================================================================

proc sodium_memzero*(pnt: pointer, len: csize_t) {.sodiumImport.}
  ## Securely zero memory (prevents compiler optimization)

proc sodium_mlock*(`addr`: pointer, len: csize_t): cint {.sodiumImport.}
  ## Lock memory (prevent swapping to disk)

proc sodium_munlock*(`addr`: pointer, len: csize_t): cint {.sodiumImport.}
  ## Unlock memory

proc secureZero*[T](data: var T) =
  ## Securely zero sensitive data.
  sodium_memzero(addr data, sizeof(T).csize_t)

# =============================================================================
# Constant-Time Comparison
# =============================================================================

proc sodium_memcmp*(b1: pointer, b2: pointer, len: csize_t): cint {.sodiumImport.}
  ## Constant-time memory comparison (timing attack resistant)

proc constantTimeEqual*[N](a, b: array[N, byte]): bool =
  ## Constant-time equality check.
  sodium_memcmp(unsafeAddr a[0], unsafeAddr b[0], N.csize_t) == 0

# =============================================================================
# Platform Configuration
# =============================================================================

when defined(windows):
  {.passL: "-lsodium".}
elif defined(macosx):
  {.passL: "-L/opt/homebrew/lib -lsodium".}
  {.passC: "-I/opt/homebrew/include".}
elif defined(linux):
  {.passL: "-lsodium".}

# =============================================================================
# Notes
# =============================================================================

## IMPLEMENTATION NOTES:
##
## **Why libsodium?**
## - Industry standard (used by Signal, WireGuard, etc.)
## - Audited implementations
## - Constant-time operations
## - Safe defaults (can't misuse easily)
##
## **Algorithms:**
## - ChaCha20-Poly1305: Fast authenticated encryption
## - Ed25519: Fast signature scheme (faster than RSA/ECDSA)
## - BLAKE2b: Fast hash (faster than SHA-2, secure as SHA-3)
## - X25519: Key exchange (not included here, but available)
##
## **Security Notes:**
## - Always use randombytes() for keys/nonces
## - Never reuse nonces with same key
## - Use secureZero() to clear sensitive data
## - Use constantTimeEqual() for secret comparisons
##
## **Installation:**
## - macOS: `brew install libsodium`
## - Ubuntu: `apt-get install libsodium-dev`
## - Windows: Build from source or use vcpkg
