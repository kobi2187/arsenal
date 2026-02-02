## RTOS Primitives
## ================
##
## Minimal Real-Time Operating System primitives.
## Suitable for embedded systems and bare metal programming.
##
## Features:
## - Cooperative task scheduler
## - Priority-based preemptive scheduler (future)
## - Semaphores, mutexes
## - Message queues
## - Timers
##
## Designed for:
## - Microcontrollers (ARM Cortex-M, RISC-V)
## - Deterministic real-time response
## - Minimal memory footprint
##
## Usage:
## ```nim
## import arsenal/embedded/rtos
##
## proc task1() =
##   while true:
##     # Do work
##     yield()
##
## proc task2() =
##   while true:
##     # Do work
##     yield()
##
## var scheduler = RtosScheduler.init()
## scheduler.addTask(task1, priority = 1)
## scheduler.addTask(task2, priority = 2)
## scheduler.run()
## ```

import std/options
import ../platform/config

# =============================================================================
# Task Control Block
# =============================================================================

type
  TaskState* = enum
    ## Task state.
    tsReady       ## Ready to run
    tsRunning     ## Currently running
    tsBlocked     ## Waiting for resource
    tsSuspended   ## Explicitly suspended
    tsTerminated  ## Finished execution

  TaskPriority* = range[0..255]
    ## Task priority (0 = lowest, 255 = highest)

  TaskFn* = proc() {.nimcall.}
    ## Task entry point function

  TaskControlBlock* = object
    ## Task metadata and state.
    id*: uint32
    name*: string
    priority*: TaskPriority
    state*: TaskState
    fn*: TaskFn
    stackBase*: pointer      ## Bottom of stack
    stackSize*: uint32       ## Stack size in bytes
    stackPointer*: pointer   ## Current stack pointer (for context switch)
    ticksRemaining*: uint32  ## Time slice remaining
    wakeTime*: uint64        ## Wake time for sleeping tasks

# =============================================================================
# Scheduler
# =============================================================================

type
  SchedulingPolicy* = enum
    spCooperative    ## Tasks yield voluntarily
    spRoundRobin     ## Time-sliced round-robin
    spPriority       ## Strict priority (highest runs first)
    spPreemptive     ## Preemptive priority scheduling

  RtosScheduler* = object
    ## Simple real-time task scheduler.
    tasks*: seq[TaskControlBlock]
    currentTask*: int
    policy*: SchedulingPolicy
    systemTick*: uint64
    ticksPerSecond*: uint32

proc init*(_: typedesc[RtosScheduler], policy: SchedulingPolicy = spCooperative): RtosScheduler =
  ## Create a new scheduler.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result.tasks = @[]
  ## result.currentTask = -1
  ## result.policy = policy
  ## result.systemTick = 0
  ## result.ticksPerSecond = 1000  # 1ms tick
  ## ```

  result.tasks = @[]
  result.currentTask = -1
  result.policy = policy
  result.systemTick = 0
  result.ticksPerSecond = 1000

proc addTask*(sched: var RtosScheduler, fn: TaskFn, priority: TaskPriority = 128, stackSize: uint32 = 4096) =
  ## Add a task to the scheduler.
  ##
  ## IMPLEMENTATION:
  ## 1. Allocate stack (alloc or static buffer)
  ## 2. Create TCB with task metadata
  ## 3. Initialize stack with fake frame for context switch
  ## 4. Add to task list
  ##
  ## Stack initialization (for context switch):
  ## - Set up return address to task function
  ## - Initialize registers (depending on architecture)

  # Allocate stack for the task
  let stackBase = alloc(stackSize)

  var tcb = TaskControlBlock(
    id: sched.tasks.len.uint32,
    name: "task" & $sched.tasks.len,
    priority: priority,
    state: tsReady,
    fn: fn,
    stackBase: stackBase,
    stackSize: stackSize,
    stackPointer: cast[pointer](cast[uint](stackBase) + stackSize),  # Stack grows downward
    ticksRemaining: 10,  # Default time slice
    wakeTime: 0
  )
  sched.tasks.add(tcb)

proc schedule*(sched: var RtosScheduler): int =
  ## Select next task to run.
  ## Returns task index, or -1 if no task ready.
  ##
  ## IMPLEMENTATION:
  ## Depends on policy:
  ##
  ## **Cooperative**:
  ## - Return next ready task in round-robin order
  ##
  ## **Priority**:
  ## ```nim
  ## var highest = -1
  ## var highestPriority: TaskPriority = 0
  ## for i, task in sched.tasks:
  ##   if task.state == tsReady and task.priority > highestPriority:
  ##     highest = i
  ##     highestPriority = task.priority
  ## return highest
  ## ```
  ##
  ## **Round-Robin**:
  ## - Priority + time slicing
  ##
  ## **Preemptive**:
  ## - Like priority, but can interrupt running task

  case sched.policy
  of spCooperative, spRoundRobin:
    # Simple round-robin
    for i in 0..<sched.tasks.len:
      let idx = (sched.currentTask + i + 1) mod sched.tasks.len
      if sched.tasks[idx].state == tsReady:
        return idx
    return -1

  of spPriority, spPreemptive:
    # Priority-based
    var highest = -1
    var highestPriority: TaskPriority = 0
    for i, task in sched.tasks:
      if task.state == tsReady and task.priority > highestPriority:
        highest = i
        highestPriority = task.priority
    return highest

proc contextSwitch*(sched: var RtosScheduler, fromTask, toTask: int) =
  ## Switch from one task to another.
  ##
  ## IMPLEMENTATION:
  ## This is architecture-specific and requires assembly.
  ##
  ## **ARM Cortex-M**:
  ## ```nim
  ## # Save current context (R4-R11, SP)
  ## if fromTask >= 0:
  ##   {.emit: """
  ##   asm volatile(
  ##     "mrs r0, psp\n"           // Get current stack pointer
  ##     "stmdb r0!, {r4-r11}\n"   // Save R4-R11
  ##     "str r0, %0\n"            // Store SP to TCB
  ##     : "=m"(sched.tasks[fromTask].stackPointer)
  ##     :
  ##     : "r0"
  ##   );
  ##   """.}
  ##
  ## # Restore new context
  ## {.emit: """
  ## asm volatile(
  ##   "ldr r0, %0\n"              // Load new SP
  ##   "ldmia r0!, {r4-r11}\n"     // Restore R4-R11
  ##   "msr psp, r0\n"             // Set process stack pointer
  ##   :
  ##   : "m"(sched.tasks[toTask].stackPointer)
  ##   : "r0"
  ## );
  ## """.}
  ## ```
  ##
  ## **x86_64** (similar but different registers):
  ## - Save/restore: RBX, RBP, R12-R15, RSP
  ##
  ## **RISC-V**:
  ## - Save/restore callee-saved registers + SP

  # Stub - requires assembly implementation
  discard

proc taskYield*(sched: var RtosScheduler) =
  ## Yield CPU to another task (cooperative scheduling).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if sched.currentTask >= 0:
  ##   sched.tasks[sched.currentTask].state = tsReady
  ##
  ## let nextTask = sched.schedule()
  ## if nextTask >= 0 and nextTask != sched.currentTask:
  ##   let prevTask = sched.currentTask
  ##   sched.currentTask = nextTask
  ##   sched.tasks[nextTask].state = tsRunning
  ##   contextSwitch(sched, prevTask, nextTask)
  ## ```

  # Stub
  discard

proc run*(sched: var RtosScheduler) {.noreturn.} =
  ## Start the scheduler (never returns).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## while true:
  ##   let nextTask = sched.schedule()
  ##   if nextTask < 0:
  ##     # No task ready - idle or sleep
  ##     # On embedded: WFI (Wait For Interrupt)
  ##     when defined(arm):
  ##       {.emit: "asm volatile(\"wfi\");".}
  ##     continue
  ##
  ##   sched.currentTask = nextTask
  ##   sched.tasks[nextTask].state = tsRunning
  ##
  ##   # For cooperative: just call the task function
  ##   # For preemptive: set up timer interrupt
  ##   sched.tasks[nextTask].fn()
  ##
  ##   # Task returned - mark as terminated
  ##   sched.tasks[nextTask].state = tsTerminated
  ## ```

  while true:
    # Stub - simplified loop
    let nextTask = sched.schedule()
    if nextTask >= 0:
      sched.currentTask = nextTask
      sched.tasks[nextTask].state = tsRunning
      sched.tasks[nextTask].fn()
      sched.tasks[nextTask].state = tsTerminated

# =============================================================================
# Synchronization Primitives
# =============================================================================

type
  Semaphore* = object
    ## Counting semaphore for resource management.
    count*: int
    max*: int
    waitQueue*: seq[int]  ## Task IDs waiting

proc initSemaphore*(max: int, initial: int = 0): Semaphore =
  ## Create a semaphore with max count.
  Semaphore(count: initial, max: max, waitQueue: @[])

proc wait*(sem: var Semaphore, sched: var RtosScheduler) =
  ## Wait (P operation). Blocks if count == 0.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if sem.count > 0:
  ##   dec sem.count
  ## else:
  ##   # Block current task
  ##   if sched.currentTask >= 0:
  ##     sem.waitQueue.add(sched.currentTask)
  ##     sched.tasks[sched.currentTask].state = tsBlocked
  ##     yield(sched)
  ## ```

  # Stub
  if sem.count > 0:
    dec sem.count

proc signal*(sem: var Semaphore, sched: var RtosScheduler) =
  ## Signal (V operation). Wakes waiting task if any.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if sem.waitQueue.len > 0:
  ##   let taskId = sem.waitQueue[0]
  ##   sem.waitQueue.delete(0)
  ##   sched.tasks[taskId].state = tsReady
  ## elif sem.count < sem.max:
  ##   inc sem.count
  ## ```

  # Stub
  if sem.count < sem.max:
    inc sem.count

type
  Mutex* = object
    ## Binary mutex (semaphore with max=1).
    ## Supports priority inheritance (future).
    locked*: bool
    owner*: int  ## Task ID
    waitQueue*: seq[int]

proc initMutex*(): Mutex =
  Mutex(locked: false, owner: -1, waitQueue: @[])

proc lock*(m: var Mutex, sched: var RtosScheduler) =
  ## Acquire mutex. Blocks if already locked.
  if not m.locked:
    m.locked = true
    m.owner = sched.currentTask
  else:
    # Block
    if sched.currentTask >= 0:
      m.waitQueue.add(sched.currentTask)
      sched.tasks[sched.currentTask].state = tsBlocked
      taskYield(sched)

proc unlock*(m: var Mutex, sched: var RtosScheduler) =
  ## Release mutex. Wakes one waiting task.
  if m.owner == sched.currentTask:
    if m.waitQueue.len > 0:
      let taskId = m.waitQueue[0]
      m.waitQueue.delete(0)
      m.owner = taskId
      sched.tasks[taskId].state = tsReady
    else:
      m.locked = false
      m.owner = -1

# =============================================================================
# Message Queue
# =============================================================================

type
  MessageQueue*[T] = object
    ## Fixed-size message queue.
    buffer*: seq[T]
    capacity*: int
    head*: int
    tail*: int
    count*: int
    sendWaiters*: seq[int]
    recvWaiters*: seq[int]

proc initMessageQueue*[T](capacity: int): MessageQueue[T] =
  ## Create message queue with fixed capacity.
  MessageQueue[T](
    buffer: newSeq[T](capacity),
    capacity: capacity,
    head: 0,
    tail: 0,
    count: 0,
    sendWaiters: @[],
    recvWaiters: @[]
  )

proc send*[T](mq: var MessageQueue[T], msg: T, sched: var RtosScheduler): bool =
  ## Send message. Blocks if queue full.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## if mq.count < mq.capacity:
  ##   mq.buffer[mq.tail] = msg
  ##   mq.tail = (mq.tail + 1) mod mq.capacity
  ##   inc mq.count
  ##
  ##   # Wake receiver if any
  ##   if mq.recvWaiters.len > 0:
  ##     let taskId = mq.recvWaiters[0]
  ##     mq.recvWaiters.delete(0)
  ##     sched.tasks[taskId].state = tsReady
  ##   return true
  ## else:
  ##   # Block
  ##   if sched.currentTask >= 0:
  ##     mq.sendWaiters.add(sched.currentTask)
  ##     sched.tasks[sched.currentTask].state = tsBlocked
  ##     yield(sched)
  ##   return false
  ## ```

  # Stub
  if mq.count < mq.capacity:
    mq.buffer[mq.tail] = msg
    mq.tail = (mq.tail + 1) mod mq.capacity
    inc mq.count
    return true
  false

proc recv*[T](mq: var MessageQueue[T], sched: var RtosScheduler): Option[T] =
  ## Receive message. Blocks if queue empty.
  if mq.count > 0:
    let msg = mq.buffer[mq.head]
    mq.head = (mq.head + 1) mod mq.capacity
    dec mq.count
    return some(msg)
  none(T)

# =============================================================================
# Timer
# =============================================================================

type
  Timer* = object
    ## Software timer.
    id*: int
    expiry*: uint64      ## System tick when timer expires
    period*: uint64      ## Period for periodic timers (0 = one-shot)
    callback*: proc()    ## Callback function
    active*: bool

proc createTimer*(callback: proc(), period: uint64): Timer =
  ## Create a timer.
  Timer(
    id: 0,
    expiry: 0,
    period: period,
    callback: callback,
    active: false
  )

proc startTimer*(timer: var Timer, sched: var RtosScheduler, delayTicks: uint64) =
  ## Start timer.
  timer.expiry = sched.systemTick + delayTicks
  timer.active = true

proc stopTimer*(timer: var Timer) =
  ## Stop timer.
  timer.active = false

proc tickTimers*(sched: var RtosScheduler, timers: var openArray[Timer]) =
  ## Process timers (call from tick interrupt).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## for timer in timers.mitems:
  ##   if timer.active and sched.systemTick >= timer.expiry:
  ##     timer.callback()
  ##     if timer.period > 0:
  ##       # Periodic - reschedule
  ##       timer.expiry = sched.systemTick + timer.period
  ##     else:
  ##       # One-shot - deactivate
  ##       timer.active = false
  ## ```

  # Stub
  discard

# =============================================================================
# System Tick
# =============================================================================

proc systemTickHandler*(sched: var RtosScheduler, timers: var openArray[Timer]) =
  ## System tick interrupt handler.
  ## Call this from timer interrupt (e.g., SysTick on ARM).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## inc sched.systemTick
  ##
  ## # Process timers
  ## tickTimers(sched, timers)
  ##
  ## # Handle sleeping tasks
  ## for task in sched.tasks.mitems:
  ##   if task.state == tsBlocked and task.wakeTime > 0:
  ##     if sched.systemTick >= task.wakeTime:
  ##       task.state = tsReady
  ##       task.wakeTime = 0
  ##
  ## # For preemptive scheduling: check if time slice expired
  ## if sched.policy in {spRoundRobin, spPreemptive}:
  ##   if sched.currentTask >= 0:
  ##     dec sched.tasks[sched.currentTask].ticksRemaining
  ##     if sched.tasks[sched.currentTask].ticksRemaining == 0:
  ##       # Trigger context switch
  ##       yield(sched)
  ## ```

  inc sched.systemTick
  tickTimers(sched, timers)

# =============================================================================
# Notes
# =============================================================================

## IMPLEMENTATION NOTES:
##
## **Context Switching**:
## - Requires assembly for each architecture
## - Must save/restore all callee-saved registers
## - Stack pointer must be saved to TCB
##
## **Stack Allocation**:
## - Can use static arrays for fixed task count
## - Or dynamic allocation (if heap available)
## - Stack size depends on task needs (2-4 KB typical)
##
## **Interrupt Safety**:
## - Disable interrupts during critical sections
## - Use atomic operations where possible
## - Priority inversion: Use priority inheritance for mutexes
##
## **Real-Time Guarantees**:
## - Worst-case execution time (WCET) for all scheduler operations
## - Priority scheduling ensures highest priority task always runs
## - Avoid unbounded loops in scheduler
##
## **Memory Footprint**:
## - TCB: ~64 bytes per task
## - Scheduler: ~100 bytes
## - Total: < 1 KB for small systems
