# Phase 2 Escalation Requirements for OPUS

## Overview

Phase 2 (Embedded Systems) requires complex assembly implementation across multiple CPU architectures and is recommended for escalation to OPUS for expert review and implementation.

---

## Part 1: RTOS Scheduler Core

### 2.1.1: contextSwitch() - MULTI-PLATFORM ASSEMBLY IMPLEMENTATION

**File:** `src/arsenal/embedded/rtos.nim:190-224`
**Complexity:** HIGH
**Criticality:** SAFETY-CRITICAL
**Platforms Required:** 5 (x86_64, ARM64, x86, ARM, RISC-V)

#### What It Does:
- Saves register state from current task
- Restores register state to new task
- Switches execution context between tasks

#### Technical Requirements:

```nim
proc contextSwitch*(sched: var RtosScheduler, fromTask: var RtosTask, toTask: var RtosTask) =
  ## Platform-specific context save/restore
  ## Called when switching from one task to another
```

#### Implementation Approach:
Use Nim's `{.emit:}` pragma with inline assembly. Nim allows backtick substitution for variables:

```nim
{.emit: """
  // Assembly code here
  mov `var`, %rax  // Backticks allow variable references
""".}
```

---

### Platform-Specific Register Requirements:

#### x86_64 (System V AMD64 ABI):
**File Location:** Emit in contextSwitch() proc
**Registers to Save (callee-saved):**
- RBP (base pointer)
- RBX, R12-R15 (general purpose)
- RSP (stack pointer)

**Registers NOT saved (caller-saved):**
- RAX, RCX, RDX, RSI, RDI, R8-R11 (scratch)

**Implementation Template:**
```asm
; Save fromTask state
mov [fromTask+offset_rbp], rbp
mov [fromTask+offset_rsp], rsp
mov [fromTask+offset_rbx], rbx
mov [fromTask+offset_r12], r12
mov [fromTask+offset_r13], r13
mov [fromTask+offset_r14], r14
mov [fromTask+offset_r15], r15

; Restore toTask state
mov rbp, [toTask+offset_rbp]
mov rsp, [toTask+offset_rsp]
mov rbx, [toTask+offset_rbx]
mov r12, [toTask+offset_r12]
mov r13, [toTask+offset_r13]
mov r14, [toTask+offset_r14]
mov r15, [toTask+offset_r15]
```

**Critical Notes:**
- RSP must be 16-byte aligned for SSE/AVX on entry to function
- Stack grows downward; RSP points to top of stack
- Return address is on stack; context switch doesn't return normally
- Need to handle PC/RIP separately (task function entry point)

---

#### ARM64 (ARMv8 ABI):
**Registers to Save (callee-saved):**
- FP (frame pointer, X29)
- LR (link register, X30)
- X19-X28 (general purpose)
- SP (stack pointer)

**Registers NOT saved (caller-saved):**
- X0-X18, X30 (lr) (scratch)

**Implementation Template:**
```asm
; Save fromTask state
stp x29, x30, [fromTask, #offset_fp_lr]
stp x19, x20, [fromTask, #offset_x19_x20]
stp x21, x22, [fromTask, #offset_x21_x22]
stp x23, x24, [fromTask, #offset_x23_x24]
stp x25, x26, [fromTask, #offset_x25_x26]
stp x27, x28, [fromTask, #offset_x27_x28]
mov x0, sp
str x0, [fromTask, #offset_sp]

; Restore toTask state
ldr x0, [toTask, #offset_sp]
mov sp, x0
ldp x27, x28, [toTask, #offset_x27_x28]
ldp x25, x26, [toTask, #offset_x25_x26]
ldp x23, x24, [toTask, #offset_x23_x24]
ldp x21, x22, [toTask, #offset_x21_x22]
ldp x19, x20, [toTask, #offset_x19_x20]
ldp x29, x30, [toTask, #offset_fp_lr]
```

**Critical Notes:**
- SP must be 16-byte aligned
- Stack grows downward
- LR contains return address; requires special handling for first task
- STP/LDP are pair instructions (save 2 registers with offset)

---

#### x86 (32-bit, System V i386 ABI):
**Registers to Save (callee-saved):**
- EBP (base pointer)
- EBX, ESI, EDI
- ESP (stack pointer)

**Registers NOT saved (caller-saved):**
- EAX, ECX, EDX (scratch)

**Implementation Template:**
```asm
; Save fromTask state
mov eax, ebp
mov [fromTask+offset_ebp], eax
mov [fromTask+offset_esp], esp
mov [fromTask+offset_ebx], ebx
mov [fromTask+offset_esi], esi
mov [fromTask+offset_edi], edi

; Restore toTask state
mov eax, [toTask+offset_esp]
mov esp, eax
mov ebp, [toTask+offset_ebp]
mov ebx, [toTask+offset_ebx]
mov esi, [toTask+offset_esi]
mov edi, [toTask+offset_edi]
```

**Critical Notes:**
- Stack grows downward
- Return address on stack
- 4-byte stack alignment typically required (may vary by OS)

---

#### ARM (32-bit, EABI):
**Registers to Save (callee-saved):**
- R4-R11 (general purpose)
- SP (stack pointer)
- LR (link register)

**Registers NOT saved (caller-saved):**
- R0-R3, R12 (scratch)

**Implementation Template:**
```asm
; Save fromTask state
stmdb sp!, {r4-r11, lr}
str sp, [fromTask, #offset_sp]
; ... save other registers to task structure

; Restore toTask state
ldr sp, [toTask, #offset_sp]
ldmia sp!, {r4-r11, pc}  ; Restores R4-R11 and returns to LR
```

**Critical Notes:**
- STMDB = store multiple, decrement before (grows stack downward)
- LDMIA = load multiple, increment after
- PC assignment with LDMIA causes return
- 4-byte or 8-byte alignment depending on ARM variant

---

#### RISC-V (64-bit):
**Registers to Save (callee-saved):**
- S0-S11 (saved registers)
- SP (stack pointer)
- RA (return address)

**Registers NOT saved (caller-saved):**
- T0-T6 (temporary)
- A0-A7 (argument)

**Implementation Template:**
```asm
; Save fromTask state
sd ra, 0(a0)      ; Save return address
sd sp, 8(a0)      ; Save stack pointer
sd s0, 16(a0)     ; Save S0-S11
sd s1, 24(a0)
; ... continue for S2-S11

; Restore toTask state
ld ra, 0(a1)      ; Load return address
ld sp, 8(a1)      ; Load stack pointer
ld s0, 16(a1)     ; Load S0-S11
ld s1, 24(a1)
; ... continue for S2-S11
jr ra             ; Jump to return address
```

**Critical Notes:**
- RISC-V uses load/store (ld/sd) for memory operations
- 16-byte stack alignment recommended
- RA (return address) equivalent to PC

---

### Task Structure Definition (Reference):

The RtosTask structure needs fields for all saved registers:

```nim
type
  RtosTask* = object
    # ... other fields

    # Saved context (platform-specific offsets needed)
    when defined(amd64):
      reg_rbp*: uint64
      reg_rbx*: uint64
      reg_r12*: uint64
      reg_r13*: uint64
      reg_r14*: uint64
      reg_r15*: uint64
      reg_rsp*: uint64
    elif defined(arm64):
      reg_fp*: uint64
      reg_lr*: uint64
      reg_x19*: uint64
      reg_x20*: uint64
      # ... x21-x28
      reg_sp*: uint64
    # ... similar for other platforms
```

---

### Implementation Checklist:

- [ ] Define task context structure with all register fields
- [ ] Implement x86_64 contextSwitch() with inline assembly
- [ ] Implement ARM64 contextSwitch() with inline assembly
- [ ] Implement x86 contextSwitch() with inline assembly
- [ ] Implement ARM (32-bit) contextSwitch() with inline assembly
- [ ] Implement RISC-V contextSwitch() with inline assembly
- [ ] Verify stack alignment for each platform
- [ ] Test context save/restore with simple task switches
- [ ] Verify callee-saved register preservation
- [ ] Review assembly for ABI compliance

---

### 2.1.2: yield() - MEDIUM COMPLEXITY (Can use Nim)

**File:** `src/arsenal/embedded/rtos.nim:226-243`

Once contextSwitch() is working, yield() is straightforward:

```nim
proc yield*(sched: var RtosScheduler) =
  let currentTask = sched.currentTask

  # Mark current as ready
  currentTask.state = TaskState.Ready

  # Find next task to run
  let nextTask = sched.schedule()

  # If different task, switch context
  if nextTask != currentTask:
    sched.currentTask = nextTask
    nextTask.state = TaskState.Running
    contextSwitch(sched, currentTask, nextTask)
```

---

### 2.1.3: run() - MEDIUM COMPLEXITY

**File:** `src/arsenal/embedded/rtos.nim:245-271`

Implements the main scheduler loop:

```nim
proc run*(sched: var RtosScheduler) =
  while true:
    let nextTask = sched.schedule()
    if nextTask == nil:
      # Idle - optionally emit WFI on ARM
      when defined(arm):
        {.emit: "wfi".}
      continue

    nextTask.state = TaskState.Running
    sched.currentTask = nextTask

    # Call task function
    let result = nextTask.fn()
    nextTask.state = TaskState.Terminated
```

---

### 2.1.4: addTask() - MEDIUM COMPLEXITY

**File:** `src/arsenal/embedded/rtos.nim:86-128`

Allocates task stack and initializes context:

```nim
proc addTask*(sched: var RtosScheduler, fn: RtosTaskFn, stackSize: int = 4096): RtosTask =
  # Allocate stack
  let stackBase = malloc(stackSize)
  if stackBase == nil:
    raise newException(OSError, "Failed to allocate task stack")

  # Initialize registers based on platform
  when defined(amd64):
    result.reg_rsp = cast[uint64](cast[uint](stackBase) + stackSize)
    result.reg_rip = cast[uint64](fn)
  elif defined(arm64):
    result.reg_sp = cast[uint64](cast[uint](stackBase) + stackSize)
    result.reg_lr = cast[uint64](fn)
  # ... similar for other platforms
```

---

### 2.1.5-2.1.6: Semaphore.wait/signal - LOW COMPLEXITY

These can be implemented in pure Nim once the task switching works:

```nim
proc wait*(sem: var Semaphore) =
  sem.counter -= 1
  if sem.counter < 0:
    let task = running()
    sem.waitQueue.add(task)
    yield()

proc signal*(sem: var Semaphore) =
  sem.counter += 1
  if sem.counter <= 0 and sem.waitQueue.len > 0:
    let task = sem.waitQueue.pop(0)
    task.state = TaskState.Ready
```

---

## Part 2: Embedded HAL Implementation

### 2.2.1: RP2040 GPIO Implementation

**File:** `src/arsenal/embedded/hal.nim`
**Target:** Raspberry Pi Pico
**Complexity:** MEDIUM
**Required Knowledge:** RP2040 datasheet, ARM Cortex-M0+ architecture

#### Hardware References:
- RP2040 datasheet: GPIO and PADS_BANK0 register layout
- Register base addresses for GPIO peripheral
- Function select values (FUNCSEL 0-5)

#### Functions to Implement:

1. **GPIO.setMode(pin, mode)**
   - Access GPIO[pin].CTRL register
   - Set FUNCSEL bits for pin function (GPIO, SPI, UART, PWM, etc.)

2. **GPIO.write(pin, state)**
   - Set GPIO_OUT register bit for high, clear for low
   - Or use GPIO_OUT_SET/GPIO_OUT_CLR registers

3. **GPIO.read(pin)**
   - Read GPIO_IN register bit

4. **GPIO.toggle(pin)**
   - XOR GPIO_OUT register bit

---

### 2.2.2: RP2040 UART Implementation

**File:** `src/arsenal/embedded/hal.nim`
**Target:** Raspberry Pi Pico UART0/UART1
**Complexity:** MEDIUM

#### Hardware References:
- UART base addresses: UART0 @ 0x40034000, UART1 @ 0x40038000
- Register layout: UARTDR, UARTFR, UARTIBRD, UARTFBRD, UARTLCR_H, UARTCR

#### Functions to Implement:

1. **UART.write(byte)**
   - Check UARTFR.TXFF (transmit FIFO full)
   - Write to UARTDR
   - Could implement buffered version

2. **UART.read() -> byte**
   - Check UARTFR.RXFE (receive FIFO empty)
   - Read from UARTDR
   - Handle error flags in UARTRSR

3. **UART.available() -> bool**
   - Check UARTFR.RXFE bit

---

## Quality Assurance Requirements

### Code Review Checklist:
- [ ] Register offsets match datasheet exactly
- [ ] Endianness correct (ARM is little-endian)
- [ ] Bit shifts and masks are correct
- [ ] Memory-mapped I/O volatility handled (volatile reads/writes)
- [ ] No race conditions with interrupt handlers
- [ ] Assembly syntax correct for target CPU
- [ ] ABI compliance verified

### Testing Strategy:
- [ ] Unit tests for each context switch platform
- [ ] Integration tests for task scheduling
- [ ] Hardware testing on actual Raspberry Pi Pico (if available)
- [ ] Assembly correctness verification via disassembly

---

## Estimated Effort

| Task | Complexity | Estimated Time |
|------|-----------|-----------------|
| x86_64 contextSwitch | HIGH | 2-3 hours |
| ARM64 contextSwitch | HIGH | 2-3 hours |
| x86 contextSwitch | MEDIUM | 1-2 hours |
| ARM (32-bit) contextSwitch | MEDIUM | 1-2 hours |
| RISC-V contextSwitch | MEDIUM | 1-2 hours |
| yield()/run() | MEDIUM | 1-2 hours |
| addTask() | MEDIUM | 1-2 hours |
| Semaphore ops | LOW | 0.5-1 hour |
| GPIO implementation | MEDIUM | 2-3 hours |
| UART implementation | MEDIUM | 2-3 hours |
| Testing & verification | HIGH | 2-3 hours |
| **Total** | - | **18-26 hours** |

---

## Dependencies & Prerequisites

### Required Knowledge:
- x86_64, ARM64, x86, ARM, RISC-V assembly languages
- Calling conventions and ABI for each architecture
- Task context structures and stack layouts
- RP2040 datasheet familiarity
- Inline assembly in Nim ({.emit:} pragma)

### Prerequisites Completed:
- ✅ Phase 1 (I/O operations) completed
- ✅ Project compiles successfully
- ✅ Core infrastructure in place

### Prerequisites Still Needed:
- [ ] RtosTask structure finalization with platform-specific fields
- [ ] Testing framework setup for embedded code
- [ ] Hardware targets (if testing on real hardware)

---

## Recommendation

**Escalate this phase to OPUS** because:

1. **Safety-Critical Code:** Incorrect context switching breaks the entire scheduler
2. **Multi-Platform:** Requires expertise across 5 different CPU architectures
3. **Assembly Expertise:** Need careful verification of register save/restore sequences
4. **ABI Compliance:** Each platform has different calling conventions and register usage
5. **High Risk:** Small mistakes (register ordering, stack alignment) cause crashes
6. **Time-Consuming:** 18-26 hours of specialized work

### Success Criteria:
- [ ] All 5 platform implementations tested and verified
- [ ] Context switching tested with actual task switching
- [ ] No memory corruption or register leaks
- [ ] ABI compliance verified
- [ ] Performance acceptable for real-time embedded systems

---

## References

### x86_64 (System V AMD64 ABI):
- AMD64 Architecture Programmer's Manual
- System V AMD64 ABI supplement

### ARM64 (ARMv8):
- ARM Cortex-A Series Programmer's Guide
- ARM Architecture Reference Manual

### ARM (32-bit EABI):
- ARM EABI Specification
- ARM Cortex-M0+ Technical Reference Manual

### RISC-V:
- RISC-V Specification (Volume I: Unprivileged ISA)
- RISC-V ABI Specification

### RP2040:
- Raspberry Pi RP2040 Datasheet
- Pico SDK Documentation

---

**Prepared for escalation to OPUS**
**Date:** 2026-01-31
**Status:** Ready for expert implementation
