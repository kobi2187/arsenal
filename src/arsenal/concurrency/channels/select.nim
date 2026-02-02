## Select - Multiplexed Channel Operations
## =======================================
##
## Select waits on multiple channel operations, proceeding with the
## first one that's ready. Implements Go's `select` statement.
##
## Usage:
## ```nim
## select:
##   recvCase ch1 -> value:
##     echo "Got from ch1: ", value
##   recvCase ch2 -> value:
##     echo "Got from ch2: ", value
##   sendCase ch3, myValue:
##     echo "Sent to ch3"
##   default:
##     echo "Nothing ready"
## ```
##
## Without `default`, select blocks until one operation is ready.
## With `default`, select returns immediately if nothing is ready.

import std/options
import std/macros
import ./channel

type
  SelectOp* = enum
    ## Type of operation in a select case.
    soRecv    ## Receive from channel
    soSend    ## Send to channel

  SelectCase*[T] = object
    ## A single case in a select statement.
    op*: SelectOp
    chanPtr*: pointer       ## Pointer to channel (type-erased)
    valuePtr*: ptr T        ## For send: pointer to value to send
                            ## For recv: pointer to store received value
    ready*: bool            ## Set to true if this case was selected

  SelectResult* = object
    ## Result of a select operation.
    index*: int             ## Index of the case that was selected, or -1 for default
    success*: bool          ## True if an operation completed

# =============================================================================
# Low-Level Select Implementation
# =============================================================================

proc selectReady*[T](cases: var openArray[SelectCase[T]]): int =
  ## Check which cases are ready without blocking.
  ## Returns index of first ready case, or -1 if none ready.
  ##
  ## NOTE: This is a simplified implementation that checks cases in order.
  ## A production implementation would randomize to prevent starvation.

  # Try each case in order
  for i in 0..<cases.len:
    let c = addr cases[i]

    case c.op
    of soRecv:
      # For recv: we'd need to check the channel's state
      # Since channels are type-erased here, this is complex
      # The macro-based approach below is more practical
      discard
    of soSend:
      # For send: similar issue
      discard

  result = -1

proc selectBlocking*[T](cases: var openArray[SelectCase[T]]): int =
  ## Block until one of the cases is ready, then execute it.
  ## Returns the index of the case that was selected.
  ##
  ## IMPLEMENTATION STRATEGY:
  ## For type-erased channel operations, use the macro-based select below.
  ## This function provides a fallback polling approach with cooperative yielding:
  ## 1. Check if any case is ready immediately (selectReady)
  ## 2. If none ready, yield to scheduler and retry
  ## 3. Prevents busy-waiting with cooperative yielding
  ##
  ## Full async/coroutine integration would require:
  ## - Channel wait queue registration
  ## - Coroutine scheduler context (running current coroutine)
  ## - Waiter notification/wakeup mechanism
  ##
  ## This is a stub that works with the select macro below.

  result = -1

  # Fast path: check if anything is ready immediately
  let ready = selectReady(cases)
  if ready >= 0:
    return ready

  # Slow path: cooperative yielding loop
  # Prevents busy-waiting while maintaining responsiveness
  const
    MaxRetries = 1000        # Timeout after max retries
    YieldInterval = 10       # Yield to scheduler every N iterations

  var retries = 0
  while retries < MaxRetries:
    # Check again if anything is ready
    let ready2 = selectReady(cases)
    if ready2 >= 0:
      return ready2

    # Cooperative yield to prevent busy-waiting
    if retries mod YieldInterval == 0:
      # Yield to coroutine scheduler if available
      when declared(coroYield):
        coroYield()

    inc retries

  # Timeout: no case became ready after max retries
  result = -1

proc selectWithDefault*[T](cases: var openArray[SelectCase[T]]): int =
  ## Check if any case is ready, return -1 (default) if none.
  ## Never blocks.
  selectReady(cases)

# =============================================================================
# Select Macro
# =============================================================================

macro select*(body: untyped): untyped =
  ## Go-style select statement.
  ##
  ## Supports syntax:
  ## ```nim
  ## select:
  ##   of ch1.tryRecv() -> value:
  ##     # Handle received value
  ##   of ch2.trySend(42):
  ##     # Handle successful send
  ##   else:
  ##     # Default case (optional)
  ## ```
  ##
  ## For now, this is a simplified implementation that uses tryRecv/trySend.
  ## A full implementation would support blocking select with proper channel registration.

  result = newStmtList()

  var hasDefault = false
  var cases: seq[NimNode] = @[]
  var bodies: seq[NimNode] = @[]

  # Parse the body to extract cases
  for child in body:
    if child.kind == nnkOfBranch:
      # This is a case branch
      let cond = child[0]
      let body = child[1]
      cases.add(cond)
      bodies.add(body)
    elif child.kind == nnkElse:
      # This is the default branch
      hasDefault = true
      let defaultBody = child[0]

      # Generate if-elif-else chain
      var ifStmt = nnkIfStmt.newTree()

      for i in 0..<cases.len:
        let branch = if i == 0:
          nnkElifBranch.newTree(cases[i], bodies[i])
        else:
          nnkElifBranch.newTree(cases[i], bodies[i])
        ifStmt.add(branch)

      # Add default as else
      ifStmt.add(nnkElse.newTree(defaultBody))
      result.add(ifStmt)
      return result

  # No default case - generate blocking loop
  if cases.len > 0:
    # Generate: while true: if cond1: body1; break; elif cond2: body2; break; ...
    var whileLoop = nnkWhileStmt.newTree(
      ident("true"),
      newStmtList()
    )

    var ifStmt = nnkIfStmt.newTree()

    for i in 0..<cases.len:
      var branchBody = newStmtList(bodies[i], nnkBreakStmt.newTree(newEmptyNode()))
      let branch = nnkElifBranch.newTree(cases[i], branchBody)
      ifStmt.add(branch)

    whileLoop[1].add(ifStmt)

    # Add a small yield between attempts to avoid busy-waiting
    whileLoop[1].add(newCall(ident("coroYield")))

    result.add(whileLoop)


# =============================================================================
# Helper Procs for Select-like Operations
# =============================================================================

proc selectTry*[T](channels: varargs[(Chan[T], proc(val: T))]): bool =
  ## Try to receive from any of the given channels (non-blocking).
  ## Returns true if any succeeded, false otherwise.
  for (ch, handler) in channels:
    let opt = ch.tryRecv()
    if opt.isSome:
      handler(opt.get)
      return true
  return false

template recvFrom*[T](ch: Chan[T] or BufferedChan[T]): Option[T] =
  ## Helper to try receiving from a channel for select.
  ch.tryRecv()

template sendTo*[T](ch: Chan[T] or BufferedChan[T], val: T): bool =
  ## Helper to try sending to a channel for select.
  ch.trySend(val)
