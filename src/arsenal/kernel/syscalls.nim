## Raw System Calls
## =================
##
## Direct system call interface bypassing libc.
## Useful for:
## - Minimal binaries (no libc dependency)
## - Kernel development
## - Security-sensitive code (avoid libc hooks)
## - Performance-critical paths
##
## Platform Support:
## - Linux x86_64: syscall instruction
## - Linux ARM64: svc instruction
## - Future: Windows (NtDll), macOS (syscall)
##
## Usage:
## ```nim
## let fd = syscall(SYS_open, "/dev/null".cstring, O_RDONLY)
## discard syscall(SYS_close, fd)
## ```

import ../platform/config

# =============================================================================
# System Call Numbers (Linux x86_64)
# =============================================================================

when defined(linux) and defined(amd64):
  const
    SYS_read* = 0
    SYS_write* = 1
    SYS_open* = 2
    SYS_close* = 3
    SYS_stat* = 4
    SYS_fstat* = 5
    SYS_lstat* = 6
    SYS_poll* = 7
    SYS_lseek* = 8
    SYS_mmap* = 9
    SYS_mprotect* = 10
    SYS_munmap* = 11
    SYS_brk* = 12
    SYS_rt_sigaction* = 13
    SYS_rt_sigprocmask* = 14
    SYS_ioctl* = 16
    SYS_pipe* = 22
    SYS_select* = 23
    SYS_sched_yield* = 24
    SYS_dup* = 32
    SYS_dup2* = 33
    SYS_getpid* = 39
    SYS_socket* = 41
    SYS_connect* = 42
    SYS_accept* = 43
    SYS_sendto* = 44
    SYS_recvfrom* = 45
    SYS_bind* = 49
    SYS_listen* = 50
    SYS_fork* = 57
    SYS_execve* = 59
    SYS_exit* = 60
    SYS_wait4* = 61
    SYS_kill* = 62
    SYS_clone* = 56
    SYS_getcwd* = 79
    SYS_chdir* = 80
    SYS_mkdir* = 83
    SYS_rmdir* = 84
    SYS_unlink* = 87
    SYS_readlink* = 89
    SYS_gettimeofday* = 96
    SYS_getuid* = 102
    SYS_getgid* = 104
    SYS_geteuid* = 107
    SYS_getegid* = 108
    SYS_getppid* = 110
    SYS_getpgrp* = 111
    SYS_setsid* = 112
    SYS_prctl* = 157
    SYS_arch_prctl* = 158
    SYS_futex* = 202
    SYS_epoll_create* = 213
    SYS_epoll_ctl* = 233
    SYS_epoll_wait* = 232
    SYS_openat* = 257
    SYS_mkdirat* = 258
    SYS_unlinkat* = 263
    SYS_accept4* = 288
    SYS_epoll_create1* = 291

elif defined(linux) and defined(arm64):
  # ARM64 uses different syscall numbers
  const
    SYS_read* = 63
    SYS_write* = 64
    SYS_close* = 57
    SYS_openat* = 56
    SYS_mmap* = 222
    SYS_munmap* = 215
    SYS_brk* = 214
    SYS_exit* = 93
    SYS_getpid* = 172
    # ... (full ARM64 table)

# =============================================================================
# Raw Syscall Interface (Assembly)
# =============================================================================

when defined(linux) and defined(amd64):
  proc syscall0*(number: clong): clong {.inline.} =
    ## System call with 0 arguments.
    ##
    ## IMPLEMENTATION:
    ## ```nim
    ## {.emit: """
    ## asm volatile(
    ##   "syscall"
    ##   : "=a"(`result`)
    ##   : "a"(`number`)
    ##   : "rcx", "r11", "memory"
    ## );
    ## """.}
    ## ```
    ##
    ## x86_64 syscall ABI:
    ## - Syscall number in RAX
    ## - Return value in RAX
    ## - Destroys RCX, R11

    {.emit: """
    asm volatile(
      "syscall"
      : "=a"(`result`)
      : "a"(`number`)
      : "rcx", "r11", "memory"
    );
    """.}

  proc syscall1*(number: clong, arg1: clong): clong {.inline.} =
    ## System call with 1 argument.
    ##
    ## IMPLEMENTATION:
    ## Argument in RDI

    {.emit: """
    asm volatile(
      "syscall"
      : "=a"(`result`)
      : "a"(`number`), "D"(`arg1`)
      : "rcx", "r11", "memory"
    );
    """.}

  proc syscall2*(number: clong, arg1, arg2: clong): clong {.inline.} =
    ## System call with 2 arguments.
    ## Arguments in RDI, RSI

    {.emit: """
    asm volatile(
      "syscall"
      : "=a"(`result`)
      : "a"(`number`), "D"(`arg1`), "S"(`arg2`)
      : "rcx", "r11", "memory"
    );
    """.}

  proc syscall3*(number: clong, arg1, arg2, arg3: clong): clong {.inline.} =
    ## System call with 3 arguments.
    ## Arguments in RDI, RSI, RDX

    {.emit: """
    asm volatile(
      "syscall"
      : "=a"(`result`)
      : "a"(`number`), "D"(`arg1`), "S"(`arg2`), "d"(`arg3`)
      : "rcx", "r11", "memory"
    );
    """.}

  proc syscall4*(number: clong, arg1, arg2, arg3, arg4: clong): clong {.inline.} =
    ## System call with 4 arguments.
    ## Arguments in RDI, RSI, RDX, R10

    var r10 {.noinit.}: clong = arg4
    {.emit: """
    asm volatile(
      "syscall"
      : "=a"(`result`)
      : "a"(`number`), "D"(`arg1`), "S"(`arg2`), "d"(`arg3`), "r"(`r10`)
      : "rcx", "r11", "memory"
    );
    """.}

  proc syscall5*(number: clong, arg1, arg2, arg3, arg4, arg5: clong): clong {.inline.} =
    ## System call with 5 arguments.
    ## Arguments in RDI, RSI, RDX, R10, R8

    var r10 {.noinit.}: clong = arg4
    var r8 {.noinit.}: clong = arg5
    {.emit: """
    asm volatile(
      "syscall"
      : "=a"(`result`)
      : "a"(`number`), "D"(`arg1`), "S"(`arg2`), "d"(`arg3`), "r"(`r10`), "r"(`r8`)
      : "rcx", "r11", "memory"
    );
    """.}

  proc syscall6*(number: clong, arg1, arg2, arg3, arg4, arg5, arg6: clong): clong {.inline.} =
    ## System call with 6 arguments.
    ## Arguments in RDI, RSI, RDX, R10, R8, R9

    var r10 {.noinit.}: clong = arg4
    var r8 {.noinit.}: clong = arg5
    var r9 {.noinit.}: clong = arg6
    {.emit: """
    asm volatile(
      "syscall"
      : "=a"(`result`)
      : "a"(`number`), "D"(`arg1`), "S"(`arg2`), "d"(`arg3`), "r"(`r10`), "r"(`r8`), "r"(`r9`)
      : "rcx", "r11", "memory"
    );
    """.}

elif defined(linux) and defined(arm64):
  # ARM64 uses SVC instruction
  proc syscall0*(number: clong): clong {.inline.} =
    ## IMPLEMENTATION:
    ## ```nim
    ## {.emit: """
    ## register long x8 asm("x8") = `number`;
    ## register long x0 asm("x0");
    ## asm volatile(
    ##   "svc #0"
    ##   : "=r"(x0)
    ##   : "r"(x8)
    ##   : "memory"
    ## );
    ## `result` = x0;
    ## """.}
    ## ```

    # Stub
    0

  # TODO: Implement syscall1-6 for ARM64

# =============================================================================
# Generic Syscall (Varargs Fallback)
# =============================================================================

when defined(linux):
  proc syscall*(number: clong): clong {.inline.} =
    syscall0(number)

  proc syscall*(number: clong, arg1: clong | pointer | cstring): clong {.inline.} =
    syscall1(number, cast[clong](arg1))

  proc syscall*(number: clong, arg1, arg2: clong | pointer | cstring): clong {.inline.} =
    syscall2(number, cast[clong](arg1), cast[clong](arg2))

  proc syscall*(number: clong, arg1, arg2, arg3: clong | pointer | cstring): clong {.inline.} =
    syscall3(number, cast[clong](arg1), cast[clong](arg2), cast[clong](arg3))

# =============================================================================
# High-Level Wrappers
# =============================================================================

when defined(linux):
  proc sys_write*(fd: cint, buf: pointer, count: csize_t): cssize_t =
    ## Write to file descriptor (raw syscall).
    cast[cssize_t](syscall(SYS_write, fd.clong, buf, count.clong))

  proc sys_read*(fd: cint, buf: pointer, count: csize_t): cssize_t =
    ## Read from file descriptor.
    cast[cssize_t](syscall(SYS_read, fd.clong, buf, count.clong))

  proc sys_close*(fd: cint): cint =
    ## Close file descriptor.
    cast[cint](syscall(SYS_close, fd.clong))

  proc sys_exit*(status: cint) {.noreturn.} =
    ## Exit process (no cleanup).
    discard syscall(SYS_exit, status.clong)
    while true: discard  # Never returns

  proc sys_getpid*(): cint =
    ## Get process ID.
    cast[cint](syscall(SYS_getpid))

  proc sys_mmap*(
    addr: pointer,
    length: csize_t,
    prot: cint,
    flags: cint,
    fd: cint,
    offset: clong
  ): pointer =
    ## Memory map (anonymous or file-backed).
    ##
    ## IMPLEMENTATION:
    ## On x86_64, mmap uses all 6 syscall arguments:
    ## - addr, length, prot, flags, fd, offset

    cast[pointer](syscall6(SYS_mmap,
      cast[clong](addr),
      length.clong,
      prot.clong,
      flags.clong,
      fd.clong,
      offset
    ))

  proc sys_munmap*(addr: pointer, length: csize_t): cint =
    ## Unmap memory.
    cast[cint](syscall(SYS_munmap, addr, length.clong))

# =============================================================================
# Constants (Linux)
# =============================================================================

when defined(linux):
  # File flags (open)
  const
    O_RDONLY* = 0
    O_WRONLY* = 1
    O_RDWR* = 2
    O_CREAT* = 0x40
    O_EXCL* = 0x80
    O_TRUNC* = 0x200
    O_APPEND* = 0x400
    O_NONBLOCK* = 0x800
    O_CLOEXEC* = 0x80000

  # mmap prot flags
  const
    PROT_NONE* = 0
    PROT_READ* = 1
    PROT_WRITE* = 2
    PROT_EXEC* = 4

  # mmap flags
  const
    MAP_SHARED* = 0x01
    MAP_PRIVATE* = 0x02
    MAP_ANONYMOUS* = 0x20
    MAP_FIXED* = 0x10

  # Error codes (negative return values)
  const
    EPERM* = 1
    ENOENT* = 2
    EINTR* = 4
    EIO* = 5
    EAGAIN* = 11
    ENOMEM* = 12
    EACCES* = 13
    EFAULT* = 14
    EBUSY* = 16
    EINVAL* = 22

# =============================================================================
# Error Handling
# =============================================================================

proc isError*(ret: clong): bool {.inline.} =
  ## Check if syscall returned an error.
  ## Linux syscalls return -errno on error.
  ret < 0 and ret >= -4095

proc getErrno*(ret: clong): cint {.inline.} =
  ## Extract errno from syscall return value.
  if isError(ret):
    cast[cint](-ret)
  else:
    0

# =============================================================================
# Example: No-Libc Hello World
# =============================================================================

## EXAMPLE:
## ```nim
## when defined(nolibc):
##   proc main() {.exportc: "_start", noreturn.} =
##     const msg = "Hello from raw syscalls!\n"
##     discard sys_write(1, msg.cstring, msg.len.csize_t)
##     sys_exit(0)
## ```
##
## Compile with:
## ```
## nim c --os:standalone --cpu:amd64 --gc:none --noMain hello.nim
## ```
