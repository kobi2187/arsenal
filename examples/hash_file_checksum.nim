## File Checksum Example using Incremental Hashing
## =================================================
##
## This example demonstrates how to use Arsenal's hash functions
## (XXHash64 and WyHash) to compute file checksums efficiently.
##
## Features:
## - Incremental hashing (doesn't load entire file into memory)
## - Support for large files
## - Multiple hash algorithms
## - Progress reporting
## - Benchmarking
##
## Usage:
## ```bash
## nim c -r hash_file_checksum.nim /path/to/file.bin
## ```

import std/[os, times, strformat]
import ../src/arsenal/hashing/hashers/xxhash64
import ../src/arsenal/hashing/hashers/wyhash

const
  CHUNK_SIZE = 65536  # 64 KB chunks (good balance for I/O)
  SEED = DefaultSeed

proc formatBytes(bytes: int64): string =
  ## Format byte count as human-readable string
  if bytes < 1024:
    return &"{bytes} B"
  elif bytes < 1024 * 1024:
    return &"{bytes / 1024:.2f} KB"
  elif bytes < 1024 * 1024 * 1024:
    return &"{bytes / (1024 * 1024):.2f} MB"
  else:
    return &"{bytes / (1024 * 1024 * 1024):.2f} GB"

proc formatDuration(seconds: float): string =
  ## Format duration as human-readable string
  if seconds < 1.0:
    return &"{seconds * 1000:.2f} ms"
  elif seconds < 60.0:
    return &"{seconds:.2f} s"
  else:
    let mins = int(seconds / 60)
    let secs = seconds - float(mins * 60)
    return &"{mins}m {secs:.2f}s"

proc hashFileXXHash64*(filePath: string, showProgress = false): uint64 =
  ## Compute XXHash64 of file using incremental hashing
  ##
  ## Benefits:
  ## - Memory efficient: Only CHUNK_SIZE bytes in RAM at once
  ## - Works with files larger than available RAM
  ## - Can report progress for large files

  let file = open(filePath, fmRead)
  defer: file.close()

  var state = XxHash64.init(SEED)
  var buffer = newSeq[byte](CHUNK_SIZE)
  var totalBytes: int64 = 0
  let fileSize = getFileSize(filePath)

  let startTime = cpuTime()

  while true:
    let bytesRead = file.readBytes(buffer, 0, CHUNK_SIZE)
    if bytesRead == 0:
      break

    state.update(buffer[0..<bytesRead])
    totalBytes += bytesRead

    if showProgress and fileSize > 0:
      let progress = (totalBytes.float / fileSize.float * 100.0)
      let elapsed = cpuTime() - startTime
      let speed = if elapsed > 0: totalBytes.float / elapsed else: 0.0
      stderr.write(&"\rProgress: {progress:5.1f}% ({formatBytes(totalBytes)} / {formatBytes(fileSize)}) - {formatBytes(speed.int64)}/s   ")
      stderr.flushFile()

  if showProgress:
    stderr.write("\n")

  return state.finish()

proc hashFileWyHash*(filePath: string, showProgress = false): uint64 =
  ## Compute WyHash of file using incremental hashing

  let file = open(filePath, fmRead)
  defer: file.close()

  var state = WyHash.init(SEED)
  var buffer = newSeq[byte](CHUNK_SIZE)
  var totalBytes: int64 = 0
  let fileSize = getFileSize(filePath)

  let startTime = cpuTime()

  while true:
    let bytesRead = file.readBytes(buffer, 0, CHUNK_SIZE)
    if bytesRead == 0:
      break

    state.update(buffer[0..<bytesRead])
    totalBytes += bytesRead

    if showProgress and fileSize > 0:
      let progress = (totalBytes.float / fileSize.float * 100.0)
      let elapsed = cpuTime() - startTime
      let speed = if elapsed > 0: totalBytes.float / elapsed else: 0.0
      stderr.write(&"\rProgress: {progress:5.1f}% ({formatBytes(totalBytes)} / {formatBytes(fileSize)}) - {formatBytes(speed.int64)}/s   ")
      stderr.flushFile()

  if showProgress:
    stderr.write("\n")

  return state.finish()

proc benchmarkHashFile*(filePath: string) =
  ## Benchmark different hash algorithms on the same file

  let fileSize = getFileSize(filePath)

  echo ""
  echo "File Checksum Benchmark"
  echo "======================="
  echo &"File: {filePath}"
  echo &"Size: {formatBytes(fileSize)}"
  echo ""

  # XXHash64 benchmark
  echo "Computing XXHash64..."
  let xxStart = cpuTime()
  let xxHash = hashFileXXHash64(filePath, showProgress = false)
  let xxElapsed = cpuTime() - xxStart
  let xxThroughput = fileSize.float / xxElapsed

  echo &"  Hash:       0x{xxHash:016X}"
  echo &"  Time:       {formatDuration(xxElapsed)}"
  echo &"  Throughput: {formatBytes(xxThroughput.int64)}/s"
  echo ""

  # WyHash benchmark
  echo "Computing WyHash..."
  let wyStart = cpuTime()
  let wyHash = hashFileWyHash(filePath, showProgress = false)
  let wyElapsed = cpuTime() - wyStart
  let wyThroughput = fileSize.float / wyElapsed

  echo &"  Hash:       0x{wyHash:016X}"
  echo &"  Time:       {formatDuration(wyElapsed)}"
  echo &"  Throughput: {formatBytes(wyThroughput.int64)}/s"
  echo ""

  # Comparison
  echo "Performance Comparison:"
  echo &"  XXHash64: {xxThroughput / (1024.0 * 1024.0 * 1024.0):.2f} GB/s"
  echo &"  WyHash:   {wyThroughput / (1024.0 * 1024.0 * 1024.0):.2f} GB/s"
  echo &"  Speedup:  {wyThroughput / xxThroughput:.2f}x"
  echo ""

proc verifyFileIntegrity*(filePath: string, expectedHash: uint64, algorithm = "wyhash"): bool =
  ## Verify file integrity by comparing hash

  echo &"Verifying {filePath}..."

  let actualHash = case algorithm:
    of "xxhash64":
      hashFileXXHash64(filePath, showProgress = true)
    of "wyhash":
      hashFileWyHash(filePath, showProgress = true)
    else:
      raise newException(ValueError, "Unknown algorithm: " & algorithm)

  echo ""
  echo &"Expected: 0x{expectedHash:016X}"
  echo &"Actual:   0x{actualHash:016X}"

  if actualHash == expectedHash:
    echo "✓ Checksum MATCH - File is intact"
    return true
  else:
    echo "✗ Checksum MISMATCH - File is corrupted or modified"
    return false

# Main program
when isMainModule:
  if paramCount() < 1:
    echo "File Checksum Tool"
    echo "=================="
    echo ""
    echo "Usage:"
    echo "  hash_file_checksum <file>              - Compute and compare hashes"
    echo "  hash_file_checksum --bench <file>      - Benchmark hash algorithms"
    echo "  hash_file_checksum --verify <file> <hash> [algo]  - Verify file integrity"
    echo ""
    echo "Algorithms: xxhash64, wyhash (default)"
    echo ""
    echo "Examples:"
    echo "  hash_file_checksum video.mp4"
    echo "  hash_file_checksum --bench largefile.bin"
    echo "  hash_file_checksum --verify download.iso 0x1234567890ABCDEF wyhash"
    quit(1)

  let arg1 = paramStr(1)

  if arg1 == "--bench":
    if paramCount() < 2:
      echo "Error: --bench requires file path"
      quit(1)
    benchmarkHashFile(paramStr(2))

  elif arg1 == "--verify":
    if paramCount() < 3:
      echo "Error: --verify requires file path and expected hash"
      quit(1)

    let filePath = paramStr(2)
    let expectedHashStr = paramStr(3)
    let algorithm = if paramCount() >= 4: paramStr(4) else: "wyhash"

    # Parse hash (hex string)
    var expectedHash: uint64
    try:
      expectedHash = parseUInt(expectedHashStr.replace("0x", ""), 16).uint64
    except:
      echo "Error: Invalid hash format. Use hex format: 0x1234567890ABCDEF"
      quit(1)

    let verified = verifyFileIntegrity(filePath, expectedHash, algorithm)
    quit(if verified: 0 else: 1)

  else:
    # Default: compute hashes and compare
    let filePath = arg1

    if not fileExists(filePath):
      echo &"Error: File not found: {filePath}"
      quit(1)

    let fileSize = getFileSize(filePath)

    echo ""
    echo "File Checksum Calculator"
    echo "========================"
    echo &"File: {filePath}"
    echo &"Size: {formatBytes(fileSize)}"
    echo ""

    # Compute both hashes
    echo "Computing XXHash64..."
    let xxStart = cpuTime()
    let xxHash = hashFileXXHash64(filePath, showProgress = fileSize > 10_000_000)
    let xxElapsed = cpuTime() - xxStart

    echo ""
    echo "Computing WyHash..."
    let wyStart = cpuTime()
    let wyHash = hashFileWyHash(filePath, showProgress = fileSize > 10_000_000)
    let wyElapsed = cpuTime() - wyStart

    # Results
    echo ""
    echo "Results:"
    echo "--------"
    echo &"XXHash64: 0x{xxHash:016X}  ({formatDuration(xxElapsed)}, {formatBytes((fileSize.float / xxElapsed).int64)}/s)"
    echo &"WyHash:   0x{wyHash:016X}  ({formatDuration(wyElapsed)}, {formatBytes((fileSize.float / wyElapsed).int64)}/s)"
    echo ""

    echo "Save these hashes to verify file integrity later!"
    echo ""

## Use Cases
## =========
##
## 1. File Integrity Verification:
## ```bash
## # Compute checksum
## hash_file_checksum important.zip
## # Output: WyHash: 0x1234567890ABCDEF
##
## # Later, verify file wasn't corrupted
## hash_file_checksum --verify important.zip 0x1234567890ABCDEF wyhash
## ```
##
## 2. Large File Hashing:
## ```nim
## # Efficient for multi-GB files
## let hash = hashFileWyHash("/data/large_video.mp4", showProgress = true)
## # Progress: 45.3% (2.3 GB / 5.0 GB) - 450 MB/s
## ```
##
## 3. Deduplication:
## ```nim
## import std/tables
## var fileHashes = initTable[uint64, string]()
##
## for file in walkFiles("*.jpg"):
##   let hash = hashFileWyHash(file)
##   if hash in fileHashes:
##     echo &"Duplicate: {file} == {fileHashes[hash]}"
##   else:
##     fileHashes[hash] = file
## ```
##
## 4. Download Verification:
## ```nim
## proc downloadAndVerify(url, expectedHash: string) =
##   # Download file
##   exec(&"wget {url} -O download.bin")
##
##   # Verify checksum
##   let hash = hashFileWyHash("download.bin")
##   if &"0x{hash:016X}" == expectedHash:
##     echo "Download verified!"
##   else:
##     echo "Checksum mismatch - corrupted download!"
##     removeFile("download.bin")
## ```
##
## Performance Characteristics
## ===========================
##
## Chunk Size Impact:
## - Too small (< 4 KB): Excessive syscall overhead
## - Optimal (64 KB): Good balance of I/O and memory
## - Too large (> 1 MB): Wastes memory, no speed gain
##
## Bottlenecks:
## - SSD (500-3500 MB/s): Hash is faster, I/O limited
## - HDD (100-200 MB/s): Hash is faster, I/O limited
## - Network (1-100 MB/s): Hash is faster, I/O limited
## - RAM (10+ GB/s): Hash becomes bottleneck
##
## Expected Throughput:
## - XXHash64: 8-10 GB/s (CPU-limited)
## - WyHash: 15-18 GB/s (CPU-limited)
## - Typical file I/O: 0.5-3 GB/s (I/O-limited)
##
## Result: For most files, hashing is not the bottleneck!
##
## Memory Usage:
## - Incremental hashing: CHUNK_SIZE + state (~64 KB + 64 bytes)
## - One-shot hashing: Entire file in memory (not suitable for large files)
## - Arsenal's incremental API enables memory-efficient hashing
##
## Comparison to Other Tools:
## - md5sum: ~300 MB/s (cryptographic, slower)
## - sha256sum: ~200 MB/s (cryptographic, much slower)
## - xxhsum: ~8 GB/s (comparable to Arsenal)
## - Arsenal WyHash: ~15 GB/s (fastest non-crypto hash)
##
## When to Use Which Algorithm:
## =============================
##
## XXHash64:
## - Widely used and tested
## - Good for compatibility
## - Excellent distribution
## - Stable specification
##
## WyHash:
## - Maximum speed (1.5-2x faster)
## - Simpler algorithm
## - Excellent for internal use
## - Best for hash tables
##
## Cryptographic (SHA-256, etc):
## - Security-critical checksums
## - Digital signatures
## - Password hashing
## - Much slower (but necessary)
##
## For file integrity: WyHash or XXHash64 (both excellent)
## For security: Use SHA-256 or better
