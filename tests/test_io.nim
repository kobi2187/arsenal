## I/O Integration Tests
## =====================
##
## Tests for event loop and async socket integration with coroutines.

import std/net
import ../src/arsenal/io/eventloop
import ../src/arsenal/io/async_socket
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

# =============================================================================
# Test Helpers
# =============================================================================

var testsPassed = 0
var testsFailed = 0

template test(name: string, body: untyped) =
  try:
    body
    echo "  [OK] ", name
    inc testsPassed
  except CatchableError as e:
    echo "  [FAIL] ", name, ": ", e.msg
    echo "  Stack trace:"
    echo e.getStackTrace()
    inc testsFailed

template check(cond: bool, msg: string = "") =
  if not cond:
    let fullMsg = if msg.len > 0: "Check failed: " & msg else: "Check failed"
    raise newException(AssertionDefect, fullMsg)

# =============================================================================
# Test 1: Event loop creation
# =============================================================================

proc testEventLoopCreation() =
  let loop = newEventLoop()
  check not loop.isNil, "Event loop should not be nil"
  loop.destroy()

# =============================================================================
# Test 2: Global event loop
# =============================================================================

proc testGlobalEventLoop() =
  let loop1 = getEventLoop()
  let loop2 = getEventLoop()
  check loop1 == loop2, "Global event loop should be singleton"

# =============================================================================
# Test 3: Socket creation
# =============================================================================

proc testAsyncSocketCreation() =
  let sock = newAsyncSocket()
  check not sock.isNil, "Async socket should not be nil"
  check sock.fd != SocketHandle(0), "Socket should have valid fd"
  sock.close()

# =============================================================================
# Test 4: Echo server/client test
# =============================================================================

var echoTestResult = ""

proc echoServer(loop: EventLoop, port: Port) {.gcsafe.} =
  {.cast(gcsafe).}:
    try:
      let serverSock = newAsyncSocket()
      serverSock.bindAddr(port, "127.0.0.1")
      serverSock.listen()

      # Accept one connection
      let client = serverSock.accept(loop)

      # Receive data
      let data = client.recv(loop, 1024)

      # Echo it back
      discard client.send(loop, data)

      client.close()
      serverSock.close()
    except CatchableError as e:
      echo "Server error: ", e.msg

proc echoClient(loop: EventLoop, port: Port) {.gcsafe.} =
  {.cast(gcsafe).}:
    try:
      let clientSock = newAsyncSocket()

      # Connect to server
      clientSock.connect(loop, "127.0.0.1", port)

      # Send message
      discard clientSock.send(loop, "Hello, Arsenal!")

      # Receive echo
      echoTestResult = clientSock.recv(loop, 1024)

      clientSock.close()
    except CatchableError as e:
      echo "Client error: ", e.msg

proc testEchoServerClient() =
  let loop = getEventLoop()
  let port = Port(19876)

  # Spawn server and client coroutines
  let server = newCoroutine(proc() {.gcsafe.} = echoServer(loop, port))
  let client = newCoroutine(proc() {.gcsafe.} = echoClient(loop, port))

  ready(server)
  ready(client)

  # Run event loop
  loop.run()

  check echoTestResult == "Hello, Arsenal!", "Echo test should return same message, got: " & echoTestResult

# =============================================================================
# Main
# =============================================================================

when isMainModule:
  echo "\n=== I/O Integration Tests ===\n"

  test "event loop creation":
    testEventLoopCreation()

  test "global event loop singleton":
    testGlobalEventLoop()

  test "async socket creation":
    testAsyncSocketCreation()

  echo "\nAsync I/O Tests:"
  test "echo server/client with event loop":
    testEchoServerClient()

  echo "\n=== Results: ", testsPassed, " passed, ", testsFailed, " failed ===\n"

  if testsFailed > 0:
    quit(1)
