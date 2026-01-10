## Go-Style Concurrency DSL
## ========================
##
## Provides Go-like syntax for spawning coroutines and working with channels.
##
## Usage:
## ```nim
## # Spawn a coroutine
## go:
##   echo "Running in coroutine"
##
## # Spawn with expression
## go echo "Also a coroutine"
##
## # Channels
## let ch = newChan[int]()
## go:
##   ch.send(42)
##
## let value = ch.recv()
## ```

import std/macros
import ../coroutines/coroutine
import ../channels/channel

# =============================================================================
# Scheduler
# =============================================================================

type
  Scheduler* = ref object
    ## Manages coroutine execution.
    ## A simple scheduler runs coroutines in a queue until all complete.
    ##
    ## More advanced schedulers can:
    ## - Use work-stealing across threads
    ## - Integrate with I/O event loops
    ## - Provide priority scheduling
    readyQueue: seq[Coroutine]
    running: bool

var defaultScheduler* {.threadvar.}: Scheduler
  ## Thread-local default scheduler.

proc newScheduler*(): Scheduler =
  ## Create a new scheduler.
  Scheduler(readyQueue: @[], running: false)

proc getScheduler*(): Scheduler =
  ## Get or create the thread-local default scheduler.
  if defaultScheduler.isNil:
    defaultScheduler = newScheduler()
  defaultScheduler

proc spawn*(sched: Scheduler, fn: CoroutineProc) =
  ## Spawn a new coroutine on this scheduler.
  ##
  ## IMPLEMENTATION:
  ## 1. Create coroutine with fn
  ## 2. Add to ready queue
  ##
  ## ```nim
  ## let coro = newCoroutine(fn)
  ## sched.readyQueue.add(coro)
  ## ```

  let coro = newCoroutine(fn)
  sched.readyQueue.add(coro)

proc ready*(sched: Scheduler, coro: Coroutine) =
  ## Mark a coroutine as ready to run (e.g., after I/O completes).
  ##
  ## IMPLEMENTATION:
  ## Simply add to ready queue if not already there.

  if coro.state == csSuspended:
    coro.state = csReady
    sched.readyQueue.add(coro)

proc runOne*(sched: Scheduler): bool =
  ## Run one coroutine step. Returns true if work was done.
  ##
  ## IMPLEMENTATION:
  ## 1. Pop coroutine from ready queue
  ## 2. Resume it
  ## 3. If still suspended, it yielded (may be re-added later)
  ## 4. If finished, clean up
  ##
  ## ```nim
  ## if sched.readyQueue.len == 0:
  ##   return false
  ##
  ## let coro = sched.readyQueue.pop()
  ## coro.resume()
  ##
  ## if coro.isFinished:
  ##   # Done, will be GC'd
  ##   discard
  ## # If suspended, it's waiting on something (channel, I/O)
  ## # and will be re-added when that completes
  ##
  ## return true
  ## ```

  if sched.readyQueue.len == 0:
    return false

  let coro = sched.readyQueue.pop()
  coro.resume()
  return true

proc runAll*(sched: Scheduler) =
  ## Run all coroutines until all complete or blocked.
  ##
  ## IMPLEMENTATION:
  ## Keep running while there's work to do.
  ##
  ## Note: This doesn't handle I/O. For I/O integration, use
  ## `runWithEventLoop` which polls for I/O between coroutine steps.

  sched.running = true
  while sched.readyQueue.len > 0:
    discard sched.runOne()
  sched.running = false

proc runForever*(sched: Scheduler) =
  ## Run the scheduler forever. For server applications.
  ##
  ## IMPLEMENTATION:
  ## Loop: run coroutines, then poll I/O event loop, repeat.
  ##
  ## ```nim
  ## while true:
  ##   while sched.runOne():
  ##     discard
  ##
  ##   # No more ready coroutines, wait for I/O
  ##   eventLoop.poll(timeout = if sched.readyQueue.len > 0: 0 else: -1)
  ## ```

  sched.running = true
  while true:
    while sched.runOne():
      discard
    # TODO: Integrate with I/O event loop
    # For now, just exit if nothing to do
    if sched.readyQueue.len == 0:
      break
  sched.running = false

# =============================================================================
# Go Macro
# =============================================================================

macro go*(body: untyped): untyped =
  ## Spawn a coroutine to execute the body.
  ##
  ## Usage:
  ## ```nim
  ## go:
  ##   echo "In coroutine"
  ##
  ## go echo "Single expression"
  ## ```
  ##
  ## IMPLEMENTATION:
  ## Generate code that:
  ## 1. Wraps the body in a closure
  ## 2. Calls scheduler.spawn() with that closure
  ##
  ## ```nim
  ## # go:
  ## #   echo "hello"
  ## # becomes:
  ## getScheduler().spawn(proc() {.closure.} =
  ##   echo "hello"
  ## )
  ## ```
  ##
  ## Variable capture: Nim closures capture by reference by default.
  ## For value capture, users should use `let x = x` pattern.

  result = quote do:
    getScheduler().spawn(proc() {.closure, gcsafe.} =
      `body`
    )

# =============================================================================
# Helper Procedures
# =============================================================================

proc spawn*(fn: CoroutineProc) =
  ## Spawn on the default scheduler.
  getScheduler().spawn(fn)

proc runScheduler*() =
  ## Run the default scheduler until all coroutines complete.
  getScheduler().runAll()

# =============================================================================
# Channel Receive Operator (Optional)
# =============================================================================

# Note: Nim doesn't support `<-` as a prefix operator, so we use recv()
# You could define a template or use a different operator:

template `<-`*[T](ch: Chan[T]): T =
  ## Alternative syntax: `let value = <-ch`
  ## Note: This may have parsing issues in some contexts.
  ch.recv()

template `<-`*[T](ch: BufferedChan[T]): T =
  ch.recv()
