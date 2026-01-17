## Arsenal Echo Server - M7 Integration Example
## ==============================================
##
## Demonstrates Arsenal's concurrency primitives working together:
## - M2: Coroutines (libaco/minicoro)
## - M3: Lock-free primitives (atomics, queues)
## - M4: Channels (Go-style CSP)
## - M5: I/O Integration (std/selectors with epoll/kqueue/IOCP)
## - M6: Go-style DSL (go macro, scheduler)
##
## Architecture:
## - Main coroutine: Accepts connections
## - Worker coroutines: Handle client echo logic
## - Event loop: Manages async I/O
##
## Usage:
##   nim c -r examples/echo_server.nim
##   # In another terminal:
##   echo "Hello, Arsenal!" | nc localhost 8080

import ../src/arsenal/concurrency
import ../src/arsenal/io/eventloop
import ../src/arsenal/io/async_socket
import std/strutils

# =============================================================================
# Configuration
# =============================================================================

const
  ServerPort = Port(8080)
  MaxConnections = 10_000
  BufferSize = 4096

# =============================================================================
# Statistics
# =============================================================================

var stats {.threadvar.}: ref object
  connectionsAccepted: Atomic[int]
  bytesReceived: Atomic[int]
  bytesSent: Atomic[int]
  activeConnections: Atomic[int]

proc initStats() =
  if stats.isNil:
    stats = new(object
      connectionsAccepted: Atomic[int]
      bytesReceived: Atomic[int]
      bytesSent: Atomic[int]
      activeConnections: Atomic[int]
    )
    stats.connectionsAccepted = atomic(0)
    stats.bytesReceived = atomic(0)
    stats.bytesSent = atomic(0)
    stats.activeConnections = atomic(0)

proc printStats() =
  if stats != nil:
    echo "\n=== Echo Server Statistics ==="
    echo "Connections accepted: ", stats.connectionsAccepted.value
    echo "Active connections: ", stats.activeConnections.value
    echo "Bytes received: ", stats.bytesReceived.value
    echo "Bytes sent: ", stats.bytesSent.value
    echo "=============================="

# =============================================================================
# Echo Handler
# =============================================================================

proc handleClient(clientSock: AsyncSocket, loop: EventLoop, clientNum: int) {.gcsafe.} =
  ## Handle a single client connection: read data and echo it back.
  {.cast(gcsafe).}:
    try:
      stats.activeConnections.inc()

      echo "[Client ", clientNum, "] Connected"

      var totalBytes = 0

      while true:
        # Read data from client
        let data = clientSock.recv(loop, BufferSize)

        if data.len == 0:
          # Client closed connection
          echo "[Client ", clientNum, "] Disconnected (", totalBytes, " bytes echoed)"
          break

        stats.bytesReceived.inc(data.len)
        totalBytes += data.len

        # Echo data back
        let sent = clientSock.send(loop, data)
        stats.bytesSent.inc(sent)

    except CatchableError as e:
      echo "[Client ", clientNum, "] Error: ", e.msg

    finally:
      stats.activeConnections.dec()
      clientSock.close()

# =============================================================================
# Accept Loop
# =============================================================================

proc acceptLoop(serverSock: AsyncSocket, loop: EventLoop) {.gcsafe.} =
  ## Accept incoming connections and spawn handler coroutines.
  {.cast(gcsafe).}:
    echo "Echo server listening on port ", ServerPort.int
    echo "Press Ctrl+C to stop"
    echo ""

    var clientNum = 0

    while true:
      try:
        # Accept new connection (blocks coroutine until client arrives)
        let clientSock = serverSock.accept(loop)

        inc clientNum
        stats.connectionsAccepted.inc()

        # Spawn coroutine to handle this client
        go:
          handleClient(clientSock, loop, clientNum)

      except CatchableError as e:
        echo "Accept error: ", e.msg
        break

# =============================================================================
# Main
# =============================================================================

proc main() =
  initStats()

  echo "\n=== Arsenal Echo Server (M7) ===\n"

  # Create event loop
  let loop = getEventLoop()

  # Create server socket
  let serverSock = newAsyncSocket()
  serverSock.bindAddr(ServerPort, "127.0.0.1")
  serverSock.listen()

  echo "Server socket created successfully"

  # Spawn accept coroutine
  go:
    acceptLoop(serverSock, loop)

  # Run event loop
  try:
    loop.run()
  except KeyboardInterrupt:
    echo "\n\nShutting down..."
  finally:
    printStats()
    serverSock.close()
    loop.destroy()

when isMainModule:
  main()
