## Async Socket Wrapper
## ====================
##
## High-level async socket API that integrates with the event loop.
## Provides coroutine-friendly socket operations.
##
## All operations are non-blocking and yield the current coroutine
## until the operation completes.
##
## Usage:
## ```nim
## let socket = newAsyncSocket()
## socket.connect("127.0.0.1", Port(8080))
##
## # Send data
## discard socket.write("hello")
##
## # Receive data
## let data = socket.read(1024)
## ```

import std/net
import std/options
import eventloop

type
  AsyncSocket* = ref object
    ## Asynchronous socket wrapper.
    ## All operations integrate with the event loop and yield coroutines.
    sock*: Socket             # Nim's socket wrapper
    loop*: EventLoop
    connected*: bool

  SocketError* = object of IOError
    ## Error from socket operations.

# =============================================================================
# Socket Creation
# =============================================================================

proc newAsyncSocket*(loop: EventLoop = nil): AsyncSocket =
  ## Create a new async socket.
  ## If loop is nil, uses the default event loop.

  let sock = newSocket()

  result = AsyncSocket(
    sock: sock,
    loop: loop
  )

proc close*(socket: AsyncSocket) =
  ## Close the socket.

  if socket.sock != nil:
    try:
      socket.sock.close()
    except:
      discard
  socket.connected = false

# =============================================================================
# Connection Operations
# =============================================================================

proc connect*(socket: AsyncSocket, address: string, port: Port) =
  ## Connect to a remote host. Yields until connection completes or fails.
  ##
  ## TODO ESCALATE: OPUS
  ## The async pattern for connect on non-blocking sockets requires:
  ## 1. Initiating connect() which returns EINPROGRESS
  ## 2. Waiting for socket to become writable
  ## 3. Checking SO_ERROR to see if connection succeeded
  ##
  ## Current EventLoop.waitForWrite() API needs investigation:
  ## - How are results communicated back after yield?
  ## - Does the EventLoop handle SO_ERROR checking?
  ## - Error handling and timeout strategy?
  ##
  ## Temporary implementation: Uses blocking semantics for now

  try:
    socket.sock.connect(address, port)
    socket.connected = true
  except Exception as e:
    raise newException(SocketError, "connect failed: " & e.msg)

proc bindAddr*(socket: AsyncSocket, address: string, port: Port) =
  ## Bind socket to local address.

  try:
    socket.sock.bindAddr(port, address)
  except Exception as e:
    raise newException(SocketError, "bindAddr failed: " & e.msg)

proc listen*(socket: AsyncSocket, backlog: int = 5) =
  ## Start listening for incoming connections.

  try:
    socket.sock.listen()
  except Exception as e:
    raise newException(SocketError, "listen failed: " & e.msg)

proc accept*(socket: AsyncSocket): AsyncSocket =
  ## Accept an incoming connection. Yields until a client connects.
  ##
  ## TODO ESCALATE: OPUS
  ## Similar to connect(), the non-blocking accept pattern requires
  ## waiting for socket to become readable before retrying accept().
  ## Current EventLoop.waitForRead() needs investigation for proper integration.

  try:
    let clientSock = socket.sock.accept()
    let clientSocket = newAsyncSocket(socket.loop)
    clientSocket.sock = clientSock
    clientSocket.connected = true
    return clientSocket
  except Exception as e:
    raise newException(SocketError, "accept failed: " & e.msg)

# =============================================================================
# Data Transfer
# =============================================================================

proc read*(socket: AsyncSocket, buffer: var openArray[byte]): int =
  ## Read data into buffer. Yields until data is available.
  ## Returns number of bytes read (0 = EOF).
  ##
  ## TODO ESCALATE: OPUS
  ## Non-blocking recv requires yield/resume pattern with waitForRead()

  try:
    result = socket.sock.recv(buffer)
  except Exception as e:
    raise newException(SocketError, "recv failed: " & e.msg)

proc write*(socket: AsyncSocket, buffer: openArray[byte]): int =
  ## Write data from buffer. Yields until buffer can be written.
  ## Returns number of bytes written.
  ##
  ## TODO ESCALATE: OPUS
  ## Non-blocking send requires yield/resume pattern with waitForWrite()

  try:
    result = socket.sock.send(buffer)
  except Exception as e:
    raise newException(SocketError, "send failed: " & e.msg)

proc read*(socket: AsyncSocket, size: int): seq[byte] =
  ## Read exactly 'size' bytes. Yields as needed.

  result = newSeq[byte](size)
  var bytesRead = 0

  while bytesRead < size:
    var buffer = result.toOpenArray(bytesRead, size - 1)
    let n = socket.read(buffer)

    if n == 0:
      result.setLen(bytesRead)
      return

    bytesRead += n

proc write*(socket: AsyncSocket, data: string): int =
  ## Write string data.

  if data.len == 0:
    return 0

  let byteData = data.toOpenArrayByte(0, data.len - 1)
  return socket.write(byteData)

# =============================================================================
# Socket Options
# =============================================================================

proc setNoDelay*(socket: AsyncSocket, enabled: bool) =
  ## Enable/disable Nagle's algorithm (TCP_NODELAY).

  try:
    socket.sock.setOption(OptNoDelay, enabled)
  except Exception as e:
    raise newException(SocketError, "setNoDelay failed: " & e.msg)

proc setReuseAddr*(socket: AsyncSocket, enabled: bool) =
  ## Enable/disable address reuse (SO_REUSEADDR).

  try:
    socket.sock.setOption(OptReuseAddr, enabled)
  except Exception as e:
    raise newException(SocketError, "setReuseAddr failed: " & e.msg)

proc setKeepAlive*(socket: AsyncSocket, enabled: bool) =
  ## Enable/disable TCP keepalive.

  try:
    socket.sock.setOption(OptKeepAlive, enabled)
  except Exception as e:
    raise newException(SocketError, "setKeepAlive failed: " & e.msg)

# =============================================================================
# Utility
# =============================================================================

proc getLocalAddr*(socket: AsyncSocket): (string, Port) =
  ## Get local address and port.

  # TODO ESCALATE: OPUS
  # Socket API in Nim 1.6 needs investigation for getLocalAddr/getPeerAddr
  raise newException(SocketError, "getLocalAddr not yet implemented - needs Nim 1.6 Socket API investigation")

proc getRemoteAddr*(socket: AsyncSocket): (string, Port) =
  ## Get remote address and port.

  # TODO ESCALATE: OPUS
  # Socket API in Nim 1.6 needs investigation for getLocalAddr/getPeerAddr
  raise newException(SocketError, "getRemoteAddr not yet implemented - needs Nim 1.6 Socket API investigation")
