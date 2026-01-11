# libaco_nim - Nim bindings for libaco

Nim bindings for the libaco asymmetric coroutine library.

[![License](https://img.shields.io/badge/Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Nim Version](https://img.shields.io/badge/nim-2.2-blue.svg)](https://nim-lang.org)

## About libaco

libaco is a blazing fast and lightweight C asymmetric coroutine library:
- Context switching between coroutines in ~10ns (standalone stack)
- Memory efficient: 10M coroutines with shared stacks cost only 2.8GB
- Supports x86 and x86-64 (Sys V ABI)
- Thread-local design: one instance per thread

## Features

- **Full API Coverage**: All 10 public libaco functions
- **Type Safe**: Opaque types prevent misuse of C structures
- **Idiomatic**: Nim-friendly coroutine entry points with closures
- **Zero-overhead abstractions**: Compile-time helpers for common patterns
- **Multi-threading ready**: Thread-safe by design
- **Platform support**: Linux, macOS, Windows (x86/x86_64)

## Installation

### Quick Start

```bash
# Clone the repository
git clone <repo-url>
cd libaco_nim

# Build the library (requires cc compiler)
nimble build

# Run basic example
nimble c -r:examples/basic_example
```

### From Source

```bash
# Build libaco from source
cd ../libaco
gcc -O2 -fPIC -DNDEBUG acosw.S aco.c -c -o libaco.so

# Or use provided build script
bash make.sh
```

## API Reference

### Initialization

```nim
import aco

# Initialize libaco for current thread
# last_word_co_fp: Optional callback for coroutine exit errors
aco_thread_init(nil)
```

### Stack Management

```nim
# Create a shared stack (2MB default, with guard page)
let sstk = aco_share_stack_new(0)

# Create with custom size and guard page disabled
let sstk2 = aco_share_stack_new2(1024 * 1024, 0)

# Destroy when done
aco_share_stack_destroy(sstk)
```

### Coroutine Creation

```nim
# Create main coroutine (uses thread's default stack)
let main_co = aco_create(nil, nil, 0, nil, nil)

# Create coroutine with shared stack
let co = aco_create(
  main_co,              # Parent main coroutine
  sstk,                   # Shared stack
  0,                      # Initial save stack size (64B default)
  cast[aco_cofuncp_t](co_fp),  # Entry function
  addr(co_arg)              # User argument
)

# Create main coroutine with argument
let main_co_with_arg = aco_create(nil, nil, 0, nil, addr(my_value))
```

### Coroutine Control

```nim
# Resume coroutine from main (caller must be main coroutine)
aco_resume(co)

# Yield from coroutine to main (caller must be coroutine)
aco_yield()

# Get current coroutine (caller must be coroutine)
let current = aco_get_co()

# Get coroutine argument (caller must be coroutine)
let arg = aco_get_arg()

# Check if coroutine is main coroutine
if aco_is_main_co(co):
  echo "This is a main coroutine"

# Check if coroutine has ended
if co.is_end != 0:
  echo "Coroutine has finished"
```

### Cleanup

```nim
# Destroy coroutine
aco_destroy(co)

# Destroy main coroutine
aco_destroy(main_co)
```

## Usage Examples

### Basic Coroutine

```nim
import aco

proc my_coroutine() =
  echo "Coroutine starting"
  var count = 0
  while count < 5:
    echo fmt"Count: {count}"
    aco_yield()
    inc(count)
  echo "Coroutine ending"
  aco_yield()

proc main() =
  aco_thread_init(nil)
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)
  
  var count = 0
  let co = aco_create(main_co, sstk, 0, 
                  cast[aco_cofuncp_t](my_coroutine), nil)
  
  while not co.is_end:
    echo fmt"Main: resuming coroutine (count: {count})"
    aco_resume(co)
    inc(count)
  
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)

when isMainModule:
  main()
```

### Passing Arguments

```nim
import aco

type Worker = object
  total: int

proc worker() =
  var w = cast[ptr Worker](aco_get_arg())
  w.total = 0
  for i in 1..10:
    w.total += i
    aco_yield()

proc main() =
  aco_thread_init(nil)
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)
  
  var worker = Worker(total: 0)
  let co = aco_create(main_co, sstk, 0, 
                  cast[aco_cofuncp_t](worker), addr(worker))
  
  aco_resume(co)
  echo fmt"Worker result: {worker.total}"
  
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)

when isMainModule:
  main()
```

### Multiple Coroutines

```nim
import aco, std/sequtils

proc coroutine1() =
  echo "Coroutine 1"
  var count = 0
  while count < 3:
    echo fmt"C1: {count}"
    aco_yield()
    inc(count)

proc coroutine2() =
  echo "Coroutine 2"
  var count = 0
  while count < 3:
    echo fmt"C2: {count}"
    aco_yield()
    inc(count)

proc scheduler() =
  let cos = @[
    aco_create(nil, nil, 0, cast[aco_cofuncp_t](coroutine1), nil),
    aco_create(nil, nil, 0, cast[aco_cofuncp_t](coroutine2), nil)
  ]
  
  var idx = 0
  while idx < 6:
    for co in cos:
      aco_resume(co)
    inc(idx)

proc main() =
  aco_thread_init(nil)
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk1 = aco_share_stack_new(0)
  let sstk2 = aco_share_stack_new(0)
  
  cos[0].share_stack = sstk1
  cos[1].share_stack = sstk2
  
  scheduler()
  
  for co in cos:
    aco_destroy(co)
  
  aco_share_stack_destroy(sstk1)
  aco_share_stack_destroy(sstk2)
  aco_destroy(main_co)

when isMainModule:
  main()
```

### Shared Stack (Copy Stack)

```nim
import aco
import aco_private

proc coroutine1() =
  echo "Coroutine 1 on shared stack"
  var data = newSeq[int](10)  # Allocate on heap for sharing
  for i in 0..9:
    data.add(i * 10)
    echo fmt"C1: stack depth {i}, data size {data.len * 8} bytes"
    aco_yield()

proc coroutine2() =
  echo "Coroutine 2 on shared stack"
  var data = newSeq[int](10)
  for i in 0..9:
    data.add(i * 20)
    echo fmt"C2: stack depth {i}, data size {data.len * 8} bytes"
    aco_yield()

proc main() =
  aco_thread_init(nil)
  let main_co = aco_create(nil, nil, 0, nil, nil)
  
  # Both coroutines share the same stack (copy stack)
  let sstk = aco_share_stack_new(0)
  
  let co1 = aco_create(main_co, sstk, 0, 
                   cast[aco_cofuncp_t](coroutine1), nil)
  let co2 = aco_create(main_co, sstk, 0, 
                   cast[aco_cofuncp_t](coroutine2), nil)
  
  var count = 0
  while count < 2:
    aco_resume(co1)
    aco_resume(co2)
    inc(count)
  
  echo fmt"Save stack stats for co1:"
  echo fmt"  Max copy size: {getSaveStackMaxCopySize(co1)} bytes"
  echo fmt"  Save count: {getSaveStackSaveCount(co1)}"
  echo fmt"  Restore count: {getSaveStackRestoreCount(co1)}"
  
  aco_destroy(co1)
  aco_destroy(co2)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)

when isMainModule:
  main()
```

## Advanced Usage

### Stack Statistics

```nim
import aco
import aco_private

proc my_coroutine() =
  # Do some work
  aco_yield()
  
proc main() =
  aco_thread_init(nil)
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)
  
  let co = aco_create(main_co, sstk, 0, 
                  cast[aco_cofuncp_t](my_coroutine), nil)
  
  aco_resume(co)
  
  # Access stack statistics
  echo fmt"Max copy stack size: {getSaveStackMaxCopySize(co)} bytes"
  echo fmt"Save count: {getSaveStackSaveCount(co)}"
  echo fmt"Restore count: {getSaveStackRestoreCount(co)}"
  
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)

when isMainModule:
  main()
```

### Checking Coroutine State

```nim
import aco
import aco_private

proc my_coroutine() =
  echo "Coroutine starting"
  aco_yield()
  echo "Coroutine ending"
  aco_yield()

proc main() =
  aco_thread_init(nil)
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)
  
  let co = aco_create(main_co, sstk, 0, 
                  cast[aco_cofuncp_t](my_coroutine), nil)
  
  aco_resume(co)
  
  # Check coroutine state
  if isCoroutineEnded*(co):
    echo "Coroutine has finished"
  elif getShareStackOwner*(sstk) == co:
    echo "Coroutine currently owns shared stack"
  else:
    echo "Coroutine yielded, doesn't own stack"
  
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)

when isMainModule:
  main()
```

## Building

### Static Library

```bash
# Build static library for linking
nimble build
```

This creates `build/libaco.so` (Linux), `build/libaco.dylib` (macOS), or `build/libaco.dll` (Windows).

### Dynamic Library

```bash
# Build dynamic library for runtime loading
nimble build -d:dynamic
```

### Cross-compilation

```bash
# Cross-compile for different platforms
nimble c --cpu:i386 -d:dynamic
nimble c --cpu:amd64 -d:dynamic
```

## Performance Tips

1. **Minimize Stack Usage in Yield Points**: Reduce local variables at yield points for better performance with shared stacks
2. **Use Standalone Stacks for I/O-bound Coroutines**: When possible, give each coroutine its own stack to avoid copy overhead
3. **Pre-allocate Save Stack Size**: If you know maximum stack usage, set `save_stack_sz` accordingly to avoid runtime resizing
4. **Avoid Sharing Large Data on Stack**: Allocate large data structures on heap instead of stack

## Thread Safety

libaco is designed for thread-local use. Each thread should have its own instance:

```nim
import std/[locks, threads]

var thread: seq[Thread[void -> void]]

proc workerThread(arg: pointer) {.thread.} =
  let fn = cast[proc()](arg)
  aco_thread_init(nil)
  
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)
  let co = aco_create(main_co, sstk, 0, cast[aco_cofuncp_t](fn), nil)
  
  aco_resume(co)
  
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)

proc main() =
  var threads: seq[Thread[void -> void]]
  let workers = 4
  
  for i in 0..<workers:
    let t = createThread(workerThread, addr(some_worker_func))
    threads.add(t)
  
  for t in threads:
    joinThread(t)
```

## Error Handling

libaco will abort on errors (like returning from coroutine instead of calling `aco_exit()`). For production use, you should:

1. Always call `aco_exit()` to terminate coroutines
2. Use `aco_thread_init()` with a custom error handler for better error reporting
3. Validate coroutine state before operations

```nim
import aco

proc error_handler() {.cdecl.} =
  echo "Coroutine error detected!"
  quit(1)

proc main() =
  aco_thread_init(cast[aco_cofuncp_t](error_handler))
  # ... rest of code
```

## Comparison with C

### C Code
```c
#include "aco.h"
#include <stdio.h>

void co_fp() {
    int* arg = (int*)aco_get_arg();
    printf("Coroutine: %d\n", *arg);
    aco_yield();
}

int main() {
    aco_thread_init(NULL);
    aco_t* main_co = aco_create(NULL, NULL, 0, NULL, NULL);
    aco_share_stack_t* sstk = aco_share_stack_new(0);
    
    int value = 42;
    aco_t* co = aco_create(main_co, sstk, 0, co_fp, &value);
    
    aco_resume(co);
    aco_resume(co);
    
    aco_destroy(co);
    aco_share_stack_destroy(sstk);
    aco_destroy(main_co);
    return 0;
}
```

### Nim Code
```nim
import aco

proc co_fp() =
  let arg = cast[ptr int](aco_get_arg())
  echo fmt"Coroutine: {arg[]}"
  aco_yield()

proc main() =
  aco_thread_init(nil)
  let main_co = aco_create(nil, nil, 0, nil, nil)
  let sstk = aco_share_stack_new(0)
  
  var value = 42
  let co = aco_create(main_co, sstk, 0, 
                  cast[aco_cofuncp_t](co_fp), addr(value))
  
  aco_resume(co)
  aco_resume(co)
  
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)
```

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Application Code                         │
│                                                             │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                     libaco_nim Bindings       │  │
│  │                                                     │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  ┌─────────────┐  │  │
│  │  │  │  Main Thread │  │  │
│  │  │  │                 │  │  │
│  │  │  │  ┌────────────────────┐  │  │
│  │  │  │  Main Coroutine │  │  │
│  │  │  │  (thread stack)  │  │  │
│  │  │  │                 │  │  │
│  │  │  │  ┌────────┐  │  │  │
│  │  │  │  │ Coroutines  │  │
│  │  │  │  │  │  │
│  │  │  │  │ ┌───────┐  │  │
│  │  │  │  │ Co 1     │  │  │
│  │  │  │  │ (shared)  │  │  │
│  │  │  │  │  │  │  │
│  │  │  │  │  Co 2     │  │  │
│  │  │  │  │ (shared)  │  │  │
│  │  │  │  │  │  │  │
│  │  │  │  Co N     │  │  │
│  │  │  │  │ (shared)  │  │  │
│  │  │  │  │  │  │  │
│  │  │  │  │              │  │  │
│  │  │  │  Save Stacks (private)  │  │  │
│  │  │  │              │  │  │
│  │  │  │  Shared Stack 1 (2MB)  │  │  │
│  │  │  │  Shared Stack 2 (2MB)  │  │  │
│  │  │  │              │  │  │
│  │  └────────────────────────┘  │  │
│  │                     │  │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
```

## License

Apache License 2.0 - see LICENSE file for details.

## References

- [libaco GitHub](https://github.com/hnes/libaco)
- [libaco Documentation](https://libaco.org)
- [Nim Manual](https://nim-lang.org/docs/manual.html)
- [Nim FFI Guide](https://nim-lang.org/docs/backends.html#interfacing-with-cc-foreign-function-interface)

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a branch for your feature
3. Make your changes with tests
4. Submit a pull request

## Changelog

### 0.1.0 (Current)
- Initial release
- Complete libaco API bindings
- Comprehensive documentation
- Example programs
- Build system
