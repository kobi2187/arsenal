# Arsenal Stub Implementation Guide

## Quick Reference

This guide helps implement the 69+ stub functions across arsenal library.

### Key Principles

1. **Simplicity First**: Keep implementations simple and straightforward
2. **Platform Differentiation**: Use `when` clauses for OS-specific code
3. **Assembly in Nim**: Use `{.emit:}` pragma for platform-specific assembly
4. **Escalate When Needed**: Use `# TODO ESCALATE: OPUS` for complex integration

### Implementation Patterns

#### Pattern 1: Platform-Specific Code (sockets, I/O)

```nim
proc someFunction() =
  when defined(windows):
    # Windows implementation
    discard ioctlsocket(fd, FIONBIO, addr mode)
  else:
    # Unix/Linux implementation
    let flags = fcntl(fd, F_GETFL, 0)
    discard fcntl(fd, F_SETFL, flags or O_NONBLOCK)
```

#### Pattern 2: Inline Assembly (RTOS, embedded)

```nim
proc contextSwitch(sched: var RtosScheduler, fromTask, toTask: int) =
  ## Platform-specific context switching
  when defined(amd64):
    let fromCtx = addr sched.tasks[fromTask].context
    let toCtx = addr sched.tasks[toTask].context
    
    {.emit: """
    // Save current context (fromTask)
    asm volatile(
      "movq %%rsp, %0\n"
      "movq %%rbp, %1\n"
      "movq %%rbx, %2\n"
      "movq %%r12, %3\n"
      "movq %%r13, %4\n"
      "movq %%r14, %5\n"
      "movq %%r15, %6\n"
      : "=m"(`fromCtx`.sp),
        "=m"(`fromCtx`.bp),
        // ... etc
      : "r" (fromCtx)
    );
    
    // Load new context (toTask)
    asm volatile(
      "movq %0, %%rsp\n"
      "movq %1, %%rbp\n"
      // ... etc
      : 
      : "m"(`toCtx`.sp),
        "m"(`toCtx`.bp),
        // ... etc
    );
    """.}
```

#### Pattern 3: Simple Syscall Wrapper

```nim
proc bindAddr*(socket: AsyncSocket, address: string, port: Port) =
  ## Bind socket to local address
  let fd = socket.fd
  var addr: SockAddr
  var addrLen: SockLen
  
  # Resolve address
  let ai = getaddrinfo(address.cstring, $port.int)
  if ai == nil:
    raise newException(SocketError, "getaddrinfo failed")
  
  addr = ai.ai_addr[]
  addrLen = ai.ai_addrlen
  
  # Call bind()
  let ret = bind(fd, addr, addrLen)
  if ret < 0:
    raise newException(SocketError, "bind failed: " & $errno)
```

#### Pattern 4: Error Handling (avoid discard)

Instead of:
```nim
proc someFunc() =
  # ... implementation ...
  discard  # BAD: silently ignores errors
```

Do:
```nim
proc someFunc() =
  # ... implementation ...
  if someCondition:
    raise newException(ValueError, "Descriptive error message")
  # or return error code
  result = errorCode
```

### Escalation Pattern

For async socket operations, use the established pattern:

```nim
proc asyncSocketOperation(socket: AsyncSocket) =
  ## Async operation pattern:
  ## 1. Try the operation (may return EAGAIN/EWOULDBLOCK)
  ## 2. If would block, wait for I/O readiness via EventLoop
  ## 3. Retry when resumed by the event loop

  while true:
    try:
      # Attempt the operation
      result = socket.sock.recv(buffer)
      return result
    except OSError as e:
      # Check for would-block errors (cross-platform)
      if "would block" in e.msg.toLowerAscii or "again" in e.msg.toLowerAscii:
        # Wait for socket to become readable, yields coroutine
        socket.loop.waitForRead(socket.fd)
      else:
        raise newException(SocketError, "operation failed: " & e.msg)
```

This pattern is now implemented for connect(), accept(), read(), and write() in socket.nim.

## File Organization

### Phase 1: Core I/O

```
src/arsenal/io/
├── socket.nim              (11 async socket operations)
├── backends/
│   ├── kqueue.nim          (4 BSD event operations)
│   └── iocp.nim            (4 Windows event operations)
└── eventloop.nim           (dependency)
```

### Phase 2: Embedded

```
src/arsenal/embedded/
├── rtos.nim                (6 scheduler + 2 semaphore operations)
├── hal.nim                 (10+ GPIO/UART operations)
└── nolibc.nim              (embedded utilities)
```

### Phase 3: Utilities

```
src/arsenal/
├── binary/formats/
│   ├── pe.nim              (2 import/export parsing)
│   └── macho.nim           (1 load command handling)
├── hashing/hasher.nim      (2 wyhash operations)
└── numeric/fixed.nim       (1 sqrt operation)
```

## Testing Strategy

For each implementation, add tests:

```nim
# In tests/test_socket.nim
import arsenal/io/socket

test "connect to server":
  let socket = newAsyncSocket()
  socket.connect("127.0.0.1", Port(8080))
  check socket.connected == true
  socket.close()

test "socket read/write":
  let socket = newAsyncSocket()
  # ... write test data ...
  let data = socket.read(1024)
  check data.len > 0
```

## Debugging Tips

### Assembly Debugging
- Verify register constraints match ABI
- Check stack alignment (usually 16-byte on x86_64)
- Validate callee-saved registers
- Test on actual hardware when possible

### Event Loop Debugging
- Add logging at yield/resume points
- Trace event registration and completion
- Validate coroutine state transitions
- Check for deadlocks in event handling

### Platform Debugging
- Test kqueue separately on BSD/macOS
- Test IOCP separately on Windows
- Use conditional compilation flags for testing
- Validate syscall error codes

## Common Pitfalls

1. **Forgetting Platform Guards**: Always use `when defined()`
2. **Assembly Register Constraints**: Wrong constraints = silent corruption
3. **Coroutine State**: Forgetting to save/restore program counter
4. **Error Handling**: Using `discard` in error paths
5. **Stack Layout**: Different on each architecture
6. **Byte Order**: Little-endian vs big-endian assumptions

## Checklist for Each Implementation

- [ ] Implementation follows documented approach in comments
- [ ] Platform-specific code uses `when` clauses
- [ ] Error handling is explicit (no `discard` in critical paths)
- [ ] Assembly code commented with register purposes
- [ ] Tests written and passing
- [ ] Code reviewed (assembly: escalate to OPUS)
- [ ] Documentation updated
- [ ] Commit message references STUBS_TODO.txt item

## Escalation Triggers

**ESCALATE TO OPUS** if:
1. Assembly verification needed for correctness
2. Platform-specific behaviors conflict
3. Error handling edge cases unclear
4. Performance characteristics unexpected

**Mark with**: `# TODO ESCALATE: OPUS - [Issue description]`

**RESOLVED:** Socket async operations now use the established pattern in socket.nim.
Coroutine integration follows: try operation -> catch EAGAIN -> waitForRead/Write -> retry.

## Progress Tracking

Track progress in STUBS_TODO.txt:
- Update status as implementations complete
- Note any blockers or research findings
- Record time spent vs estimated
- Document decision rationale

## References

- **Nim Inline Assembly**: https://nim-lang.org/docs/system.html#emit.m,string
- **x86-64 ABI**: https://en.wikipedia.org/wiki/X86_calling_conventions
- **ARM64 ABI**: https://github.com/ARM-software/abi-aa
- **kqueue**: man kqueue (on BSD/macOS)
- **IOCP**: Windows documentation
- **wyhash**: https://github.com/wangyi-fudan/wyhash
