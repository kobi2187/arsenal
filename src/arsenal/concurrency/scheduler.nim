## Coroutine Scheduler
## ===================
##
## Simple round-robin scheduler for coroutines.
## Manages the ready queue and handles blocking/waking.

import std/deques
import ./coroutines/coroutine

type
  Scheduler* = object
    ## Simple round-robin coroutine scheduler.
    readyQueue: Deque[Coroutine]
    currentCoro: Coroutine

var globalScheduler {.threadvar.}: Scheduler
  ## Thread-local scheduler instance

proc ready*(coro: Coroutine) =
  ## Add a coroutine to the ready queue.
  if coro != nil and not coro.isFinished():
    globalScheduler.readyQueue.addLast(coro)

proc schedule*(coro: Coroutine) =
  ## Alias for ready - add coroutine to scheduler.
  ready(coro)

proc spawn*(fn: proc() {.closure, gcsafe.}): Coroutine =
  ## Create a new coroutine and add it to the ready queue.
  result = newCoroutine(fn)
  ready(result)

proc runNext*(): bool =
  ## Run the next coroutine in the ready queue.
  ## Returns false if no coroutines are ready.
  if globalScheduler.readyQueue.len == 0:
    return false

  let coro = globalScheduler.readyQueue.popFirst()
  if coro.isFinished():
    # Skip finished coroutines
    return globalScheduler.readyQueue.len > 0

  globalScheduler.currentCoro = coro
  coro.resume()
  globalScheduler.currentCoro = nil

  # If coroutine suspended (not finished), it will be re-added
  # by whoever wakes it up
  return true

proc runAll*() =
  ## Run all coroutines until none are ready.
  while runNext():
    discard

proc runUntilEmpty*() =
  ## Run scheduler until ready queue is empty.
  runAll()

proc hasPending*(): bool =
  ## Check if there are pending coroutines.
  globalScheduler.readyQueue.len > 0

proc currentCoroutine*(): Coroutine =
  ## Get the currently running coroutine (scheduler context).
  globalScheduler.currentCoro
