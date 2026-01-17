## Echo Client - Test Client for Echo Server
## ==========================================
##
## Simple client to test the echo server.
##
## Usage:
##   nim c -r examples/echo_client.nim

import ../src/arsenal/io/async_socket
import ../src/arsenal/io/eventloop
import ../src/arsenal/concurrency
import std/strutils

const ServerPort = Port(8080)

proc testEcho() =
  let loop = getEventLoop()

  echo "Connecting to echo server on port ", ServerPort.int, "..."

  let sock = newAsyncSocket()

  go:
    try:
      # Connect to server
      sock.connect(loop, "127.0.0.1", ServerPort)
      echo "Connected!"

      # Send test message
      let message = "Hello, Arsenal Echo Server!\n"
      echo "Sending: ", message.strip()

      discard sock.send(loop, message)

      # Receive echo
      let response = sock.recv(loop, 1024)
      echo "Received: ", response.strip()

      # Verify echo
      if response == message:
        echo "✓ Echo test passed!"
      else:
        echo "✗ Echo test failed: expected '", message.strip(), "' but got '", response.strip(), "'"

      sock.close()

    except CatchableError as e:
      echo "Error: ", e.msg
      sock.close()

  loop.run()

when isMainModule:
  testEcho()
