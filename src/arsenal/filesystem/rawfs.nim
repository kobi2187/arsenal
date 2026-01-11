## Raw Filesystem Operations
## ==========================
##
## Direct filesystem access via syscalls.
## Leverages Nim's stdlib where appropriate and adds syscall-level primitives.
##
## What stdlib provides:
## - std/os: High-level file operations (recommended for most uses)
## - std/memfiles: Memory-mapped files (mmap wrapper)
##
## What this module adds:
## - Direct syscall access (no libc dependency)
## - Raw file I/O primitives
## - Lower-level control for systems programming

import ../platform/config

when defined(linux):
  import ../kernel/syscalls

# Re-export stdlib for convenience
import std/os
export os

import std/memfiles
export memfiles  # For memory-mapped files

# =============================================================================
# File Flags and Modes
# =============================================================================

const
  # Open flags (already defined in syscalls.nim, but repeat here)
  O_RDONLY* = 0
  O_WRONLY* = 1
  O_RDWR* = 2
  O_CREAT* = 0x40
  O_EXCL* = 0x80
  O_TRUNC* = 0x200
  O_APPEND* = 0x400
  O_NONBLOCK* = 0x800
  O_DIRECTORY* = 0x10000
  O_NOFOLLOW* = 0x20000
  O_CLOEXEC* = 0x80000

  # File permissions
  S_IRUSR* = 0o400  ## Read by owner
  S_IWUSR* = 0o200  ## Write by owner
  S_IXUSR* = 0o100  ## Execute by owner
  S_IRGRP* = 0o040  ## Read by group
  S_IWGRP* = 0o020  ## Write by group
  S_IXGRP* = 0o010  ## Execute by group
  S_IROTH* = 0o004  ## Read by others
  S_IWOTH* = 0o002  ## Write by others
  S_IXOTH* = 0o001  ## Execute by others

  S_IRWXU* = S_IRUSR or S_IWUSR or S_IXUSR  ## rwx by owner
  S_IRWXG* = S_IRGRP or S_IWGRP or S_IXGRP  ## rwx by group
  S_IRWXO* = S_IROTH or S_IWOTH or S_IXOTH  ## rwx by others

# =============================================================================
# Stat Structure
# =============================================================================

when defined(linux) and defined(amd64):
  type
    Stat* {.importc: "struct stat", header: "<sys/stat.h>".} = object
      ## File status information
      st_dev*: uint64        ## Device ID
      st_ino*: uint64        ## Inode number
      st_nlink*: uint64      ## Number of hard links
      st_mode*: uint32       ## File type and mode
      st_uid*: uint32        ## User ID
      st_gid*: uint32        ## Group ID
      st_rdev*: uint64       ## Device ID (if special file)
      st_size*: int64        ## File size in bytes
      st_blksize*: int64     ## Block size for I/O
      st_blocks*: int64      ## Number of 512B blocks allocated
      st_atime*: int64       ## Time of last access
      st_mtime*: int64       ## Time of last modification
      st_ctime*: int64       ## Time of last status change

  proc stat*(path: cstring, buf: ptr Stat): cint
    {.importc, header: "<sys/stat.h>".}
    ## Get file status

  proc fstat*(fd: cint, buf: ptr Stat): cint
    {.importc, header: "<sys/stat.h>".}
    ## Get file status by fd

  proc lstat*(path: cstring, buf: ptr Stat): cint
    {.importc, header: "<sys/stat.h>".}
    ## Get file status (don't follow symlinks)

# =============================================================================
# File Operations (via syscalls)
# =============================================================================

when defined(linux):
  proc openRaw*(path: string, flags: cint, mode: cint = 0o644): cint =
    ## Open file using raw syscall.
    ##
    ## IMPLEMENTATION:
    ## ```nim
    ## result = cast[cint](syscall(SYS_open, path.cstring, flags.clong, mode.clong))
    ## ```

    cast[cint](syscall(SYS_open, path.cstring, flags.clong, mode.clong))

  proc readRaw*(fd: cint, buf: pointer, count: int): int =
    ## Read from file descriptor.
    cast[int](syscall(SYS_read, fd.clong, buf, count.clong))

  proc writeRaw*(fd: cint, buf: pointer, count: int): int =
    ## Write to file descriptor.
    cast[int](syscall(SYS_write, fd.clong, buf, count.clong))

  proc closeRaw*(fd: cint): cint =
    ## Close file descriptor.
    cast[cint](syscall(SYS_close, fd.clong))

  proc unlinkRaw*(path: string): cint =
    ## Delete file.
    cast[cint](syscall(SYS_unlink, path.cstring))

  proc mkdirRaw*(path: string, mode: cint = 0o755): cint =
    ## Create directory.
    cast[cint](syscall(SYS_mkdir, path.cstring, mode.clong))

  proc rmdirRaw*(path: string): cint =
    ## Remove empty directory.
    cast[cint](syscall(SYS_rmdir, path.cstring))

# =============================================================================
# Seek Operations
# =============================================================================

const
  SEEK_SET* = 0  ## Seek from beginning
  SEEK_CUR* = 1  ## Seek from current position
  SEEK_END* = 2  ## Seek from end

when defined(linux):
  proc lseekRaw*(fd: cint, offset: int64, whence: cint): int64 =
    ## Seek to position in file.
    ##
    ## IMPLEMENTATION:
    ## ```nim
    ## result = cast[int64](syscall(SYS_lseek, fd.clong, offset, whence.clong))
    ## ```

    cast[int64](syscall(SYS_lseek, fd.clong, offset, whence.clong))

# =============================================================================
# Directory Operations
# =============================================================================

when defined(linux) and defined(amd64):
  const
    NAME_MAX* = 255

  type
    DirEnt64* {.importc: "struct dirent64", header: "<dirent.h>".} = object
      ## Directory entry (64-bit)
      d_ino*: uint64        ## Inode number
      d_off*: int64         ## Offset to next dirent
      d_reclen*: uint16     ## Length of this record
      d_type*: uint8        ## File type
      d_name*: array[NAME_MAX + 1, char]  ## Filename

    DIR* {.importc: "DIR", header: "<dirent.h>", incompleteStruct.} = object
      ## Directory stream

  proc opendir*(name: cstring): ptr DIR
    {.importc, header: "<dirent.h>".}
    ## Open directory stream

  proc readdir*(dirp: ptr DIR): ptr DirEnt64
    {.importc, header: "<dirent.h>".}
    ## Read next directory entry

  proc closedir*(dirp: ptr DIR): cint
    {.importc, header: "<dirent.h>".}
    ## Close directory stream

  iterator walkDir*(path: string): tuple[kind: uint8, name: string] =
    ## Iterate over directory entries.
    ##
    ## IMPLEMENTATION:
    ## ```nim
    ## let dir = opendir(path.cstring)
    ## if dir != nil:
    ##   while true:
    ##     let entry = readdir(dir)
    ##     if entry == nil: break
    ##     let name = $cast[cstring](addr entry.d_name[0])
    ##     if name notin [".", ".."]:
    ##       yield (entry.d_type, name)
    ##   discard closedir(dir)
    ## ```

    let dir = opendir(path.cstring)
    if dir != nil:
      while true:
        let entry = readdir(dir)
        if entry == nil: break
        let name = $cast[cstring](addr entry.d_name[0])
        if name notin [".", ".."]:
          yield (entry.d_type, name)
      discard closedir(dir)

# =============================================================================
# Memory-Mapped Files
# =============================================================================

## NOTE: For memory-mapped files, use std/memfiles (already exported above).
## It provides:
## - MemFile type
## - open(MemFile, filename, mode, mappedSize, offset)
## - mapMem(MemFile, mode, mappedSize, offset)
## - close(MemFile)
##
## Example:
## ```nim
## import std/memfiles
## var f = memfiles.open("file.bin")
## # Access f.mem (pointer) and f.size
## close(f)
## ```

# =============================================================================
# High-Level Helpers
# =============================================================================

proc readFile*(path: string): string =
  ## Read entire file into string (using raw syscalls).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(linux):
  ##   let fd = openRaw(path, O_RDONLY)
  ##   if fd < 0:
  ##     raise newException(IOError, "Cannot open file: " & path)
  ##
  ##   var st: Stat
  ##   if fstat(fd, addr st) != 0:
  ##     discard closeRaw(fd)
  ##     raise newException(IOError, "Cannot stat file")
  ##
  ##   result = newString(st.st_size)
  ##   let n = readRaw(fd, result.cstring, st.st_size.int)
  ##   discard closeRaw(fd)
  ##
  ##   if n != st.st_size:
  ##     raise newException(IOError, "Incomplete read")
  ## ```

  when defined(linux):
    let fd = openRaw(path, O_RDONLY)
    if fd < 0:
      raise newException(IOError, "Cannot open file: " & path)

    var st: Stat
    if fstat(fd, addr st) != 0:
      discard closeRaw(fd)
      raise newException(IOError, "Cannot stat file")

    result = newString(st.st_size)
    if st.st_size > 0:
      let n = readRaw(fd, cast[pointer](result.cstring), st.st_size.int)
      if n != st.st_size:
        discard closeRaw(fd)
        raise newException(IOError, "Incomplete read")

    discard closeRaw(fd)
  else:
    # Fallback to stdlib
    result = std/os.readFile(path)

proc writeFile*(path: string, content: string) =
  ## Write string to file (using raw syscalls).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(linux):
  ##   let fd = openRaw(path, O_WRONLY or O_CREAT or O_TRUNC, 0o644)
  ##   if fd < 0:
  ##     raise newException(IOError, "Cannot open file: " & path)
  ##
  ##   let n = writeRaw(fd, content.cstring, content.len)
  ##   discard closeRaw(fd)
  ##
  ##   if n != content.len:
  ##     raise newException(IOError, "Incomplete write")
  ## ```

  when defined(linux):
    let fd = openRaw(path, O_WRONLY or O_CREAT or O_TRUNC, 0o644)
    if fd < 0:
      raise newException(IOError, "Cannot open file: " & path)

    let n = writeRaw(fd, cast[pointer](content.cstring), content.len)
    discard closeRaw(fd)

    if n != content.len:
      raise newException(IOError, "Incomplete write")
  else:
    std/os.writeFile(path, content)

proc getFileSize*(path: string): int64 =
  ## Get file size in bytes.
  when defined(linux):
    var st: Stat
    if stat(path.cstring, addr st) != 0:
      return -1
    result = st.st_size
  else:
    getFileSize(path)

proc fileExists*(path: string): bool =
  ## Check if file exists.
  when defined(linux):
    var st: Stat
    stat(path.cstring, addr st) == 0
  else:
    std/os.fileExists(path)

# =============================================================================
# Notes
# =============================================================================

## USAGE NOTES:
##
## **For most use cases (recommended):**
## ```nim
## import std/os
## writeFile("test.txt", "hello")  # High-level, portable
## let content = readFile("test.txt")
## ```
##
## **For memory-mapped files:**
## ```nim
## import std/memfiles
## var f = memfiles.open("bigfile.bin")  # mmap the file
## # Access f.mem (pointer) and f.size
## close(f)
## ```
##
## **For raw syscalls (no libc dependency):**
## ```nim
## when defined(linux):
##   let fd = openRaw("test.txt", O_RDWR or O_CREAT, 0o644)
##   discard writeRaw(fd, "hello".cstring, 5)
##   discard closeRaw(fd)
## ```
##
## **Directory walking:**
## ```nim
## for kind, name in walkDir("/tmp"):
##   echo name, " (type: ", kind, ")"
## ```
##
## **Performance:**
## - Raw syscalls: ~50 ns overhead
## - libc wrappers (std/os): ~100 ns overhead
## - For small files, difference is negligible
## - For many operations, syscalls can be faster
##
## **When to use this module:**
## - Minimal binaries (no libc dependency)
## - Performance-critical paths
## - Learning syscall internals
## - Otherwise, use std/os and std/memfiles
