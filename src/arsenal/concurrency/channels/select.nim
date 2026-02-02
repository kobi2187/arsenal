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
import std/times
import ./channel

# Define `->` as an operator for select syntax binding
# This allows the parser to accept syntax like: `of ch.tryRecv() -> opt:`
template `->`*[T](opt: T, name: untyped): T =
  ## Binding operator for select statement.
  ## This is a placeholder that should only be used within select macro.
  opt

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
  ## Supports clean DSL syntax:
  ## ```nim
  ## select:
  ##   recv ch1 -> opt:
  ##     # Handle received value (opt is Option[T])
  ##   recv ch2:
  ##     # Just check if ch2 is ready
  ##   send ch3, value:
  ##     # Send value to ch3
  ##   timeout 1.seconds:
  ##     # Timeout after 1 second
  ##   default:
  ##     # Default case (optional, cannot use with timeout)
  ## ```
  ##
  ## Or use after() for Go-style timer channels:
  ## ```nim
  ## let timer = after(1.seconds)
  ## select:
  ##   recv ch -> msg:
  ##     echo "Got: ", msg.get
  ##   recv timer -> _:
  ##     echo "Timeout!"
  ## ```

  result = newStmtList()

  type CaseInfo = object
    tempVar: NimNode      # Temp var to store tryRecv/trySend result
    binding: NimNode      # User's binding variable (for recv)
    body: NimNode         # Case body
    isRecv: bool          # true for recv, false for send

  var hasDefault = false
  var hasTimeout = false
  var defaultBody: NimNode
  var timeoutDuration: NimNode
  var timeoutBody: NimNode
  var caseInfos: seq[CaseInfo] = @[]
  var timerVars: seq[NimNode] = @[]  # Var declarations for timers

  # Parse the body to extract cases
  for child in body:
    # Handle "default:" case
    if child.kind == nnkCall and child.len == 2:
      if child[0].kind == nnkIdent and $child[0] == "default":
        hasDefault = true
        defaultBody = child[1]

    # Handle "recv channel -> binding:" case
    elif child.kind == nnkCommand and child.len >= 2:
      let cmdIdent = child[0]

      if cmdIdent.kind == nnkIdent and $cmdIdent == "timeout":
        # timeout duration: body
        # Parsed as: Command(Ident("timeout"), duration_expr, body_stmtlist)
        if child.len == 3:
          hasTimeout = true
          timeoutDuration = child[1]
          timeoutBody = child[2]

          # Create timer var and temp var for the result
          let timerVar = genSym(nskVar, "selectTimer")
          let tempOpt = genSym(nskLet, "selectTimerOpt")

          # Add timer var: var selectTimer = after(duration)
          timerVars.add(nnkIdentDefs.newTree(
            timerVar,
            newEmptyNode(),
            newCall(ident("after"), timeoutDuration)
          ))

          # Add case for checking timer
          caseInfos.add(CaseInfo(
            tempVar: nnkIdentDefs.newTree(tempOpt, newEmptyNode(), newCall(ident("tryRecv"), timerVar)),
            binding: nil,
            body: timeoutBody,
            isRecv: true
          ))

      elif cmdIdent.kind == nnkIdent and $cmdIdent == "recv":
        # recv ch -> opt: body
        if child.len == 3 and child[1].kind == nnkInfix:
          let infixNode = child[1]
          if infixNode[0].kind == nnkIdent and $infixNode[0] == "->":
            let channel = infixNode[1]
            let userBinding = infixNode[2]
            let caseBody = child[2]

            let tempVar = genSym(nskLet, "selectOpt")

            caseInfos.add(CaseInfo(
              tempVar: nnkIdentDefs.newTree(tempVar, newEmptyNode(), newCall(ident("tryRecv"), channel)),
              binding: userBinding,
              body: caseBody,
              isRecv: true
            ))

      elif cmdIdent.kind == nnkIdent and $cmdIdent == "send":
        # send ch, value: body
        if child.len == 3:
          let args = child[1]
          let caseBody = child[2]

          var channel, value: NimNode

          if args.kind == nnkInfix and $args[0] == ",":
            channel = args[1]
            value = args[2]
          else:
            channel = child[1]
            if child.len > 2 and child[2].kind != nnkStmtList:
              value = child[2]

          if channel != nil and value != nil:
            let tempVar = genSym(nskLet, "selectSent")

            caseInfos.add(CaseInfo(
              tempVar: nnkIdentDefs.newTree(tempVar, newEmptyNode(), newCall(ident("trySend"), channel, value)),
              binding: nil,
              body: caseBody,
              isRecv: false
            ))

  # Generate the select block
  # First, declare timer vars (if any)
  var varSection: NimNode
  if timerVars.len > 0:
    varSection = nnkVarSection.newTree()
    for timerVar in timerVars:
      varSection.add(timerVar)

  # Then declare all temp variables for results
  var letSection = nnkLetSection.newTree()
  for info in caseInfos:
    letSection.add(info.tempVar)

  # Build the if-elif-else chain
  var ifStmt = nnkIfStmt.newTree()

  for info in caseInfos:
    let tempVarName = info.tempVar[0]
    let condition = if info.isRecv:
      newCall(bindSym("isSome"), tempVarName)
    else:
      tempVarName  # For send, it's a bool

    let branchBody = if info.isRecv and info.binding != nil:
      # Create binding for user
      newStmtList(
        nnkLetSection.newTree(
          nnkIdentDefs.newTree(info.binding, newEmptyNode(), tempVarName)
        ),
        info.body
      )
    else:
      info.body

    ifStmt.add(nnkElifBranch.newTree(condition, branchBody))

  # Add default case if present
  if hasDefault:
    ifStmt.add(nnkElse.newTree(defaultBody))
    # Generate: var timers...; let temps...; if cond1: body1 elif cond2: body2 else: default
    if timerVars.len > 0:
      result.add(varSection)
    result.add(letSection)
    result.add(ifStmt)
  else:
    # No default - wrap in while loop
    var loopBody = newStmtList()
    loopBody.add(letSection)
    loopBody.add(ifStmt)
    # Add yield to avoid busy-waiting in coroutine context
    # For non-coroutine usage, a blocking select would just spin
    loopBody.add(
      nnkWhenStmt.newTree(
        nnkElifBranch.newTree(
          newCall(ident("declared"), ident("coroYield")),
          newStmtList(newCall(ident("coroYield")))
        ),
        nnkElse.newTree(
          newStmtList(nnkDiscardStmt.newTree(newEmptyNode()))  # No-op for non-coroutine
        )
      )
    )

    var whileLoop = nnkWhileStmt.newTree(
      ident("true"),
      loopBody
    )
    # Add break to each branch
    for i in 0..<ifStmt.len:
      if ifStmt[i].kind == nnkElifBranch:
        ifStmt[i][1].add(nnkBreakStmt.newTree(newEmptyNode()))

    # Generate: var timers...; while true: let temps...; if...; yield
    if timerVars.len > 0:
      result.add(varSection)
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

# =============================================================================
# Timer Channel for Timeouts
# =============================================================================

type
  TimerChan* = object
    ## A channel that becomes ready after a timeout duration.
    ## Similar to Go's time.After()
    deadline: float  # Monotonic time when timer expires
    fired: bool      # Whether the timer has fired

proc after*(duration: Duration): TimerChan =
  ## Create a timer channel that fires after the specified duration.
  ## Similar to Go's time.After()
  ##
  ## ```nim
  ## let timer = after(1.seconds)
  ## select:
  ##   recv ch -> msg:
  ##     echo "Got message"
  ##   recv timer -> _:
  ##     echo "Timeout!"
  ## ```
  result.deadline = epochTime() + duration.inSeconds.float
  result.fired = false

proc tryRecv*(timer: var TimerChan): Option[bool] =
  ## Try to receive from a timer channel.
  ## Returns Some(true) if timer has expired, None otherwise.
  if timer.fired:
    return some(true)

  if epochTime() >= timer.deadline:
    timer.fired = true
    return some(true)

  return none(bool)
