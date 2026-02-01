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
import std/nativesockets
import std/options
import std/os
import std/strutils
import eventloop
import ../concurrency/coroutines/coroutine

type
  AsyncSocket* = ref object
    ## Asynchronous socket wrapper.
    ## All operations integrate with the event loop and yield coroutines.
    sock*: Socket             # Nim's socket wrapper
    fd*: SocketHandle         # File descriptor for event loop integration
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
  let fd = sock.getFd()

  # Set non-blocking mode for async operations
  fd.setBlocking(false)

  result = AsyncSocket(
    sock: sock,
    fd: fd,
    loop: if loop.isNil: getEventLoop() else: loop
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
  ## Non-blocking connect pattern:
  ## 1. Initiate connect() which returns EINPROGRESS on non-blocking socket
  ## 2. Wait for socket to become writable (connection complete or failed)
  ## 3. Check SO_ERROR to verify connection succeeded

  try:
    socket.sock.connect(address, port)
    socket.connected = true
  except OSError as e:
    # EINPROGRESS (115) or EWOULDBLOCK means connection in progress
    if e.errorCode == 115.OSErrorCode or "in progress" in e.msg.toLowerAscii or "would block" in e.msg.toLowerAscii:
      # Wait for socket to become writable (connection complete)
      socket.loop.waitForWrite(socket.fd)
      socket.connected = true
    else:
      raise newException(SocketError, "connect failed: " & e.msg)
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
  ## Non-blocking accept pattern:
  ## 1. Try accept() - if EWOULDBLOCK/EAGAIN, wait for socket readable
  ## 2. When readable, retry accept()

  while true:
    try:
      var client: Socket
      var address: string
      socket.sock.acceptAddr(client, address)

      let clientFd = client.getFd()
      clientFd.setBlocking(false)

      result = AsyncSocket(
        sock: client,
        fd: clientFd,
        loop: socket.loop,
        connected: true
      )
      return result
    except OSError as e:
      if "would block" in e.msg.toLowerAscii or "again" in e.msg.toLowerAscii:
        socket.loop.waitForRead(socket.fd)
      else:
        raise newException(SocketError, "accept failed: " & e.msg)
    except Exception as e:
      raise newException(SocketError, "accept failed: " & e.msg)

# =============================================================================
# Data Transfer
# =============================================================================

proc read*(socket: AsyncSocket, buffer: var openArray[byte]): int =
  ## Read data into buffer. Yields until data is available.
  ## Returns number of bytes read (0 = EOF).
  ##
  ## Non-blocking recv pattern:
  ## 1. Try recv() - if EWOULDBLOCK/EAGAIN, wait for socket readable
  ## 2. When readable, retry recv()

  while true:
    try:
      result = socket.sock.recv(buffer)
      return result  # Success (including 0 for EOF)
    except OSError as e:
      if "would block" in e.msg.toLowerAscii or "again" in e.msg.toLowerAscii:
        socket.loop.waitForRead(socket.fd)
      else:
        raise newException(SocketError, "recv failed: " & e.msg)
    except Exception as e:
      raise newException(SocketError, "recv failed: " & e.msg)

proc write*(socket: AsyncSocket, buffer: openArray[byte]): int =
  ## Write data from buffer. Yields until buffer can be written.
  ## Returns number of bytes written.
  ##
  ## Non-blocking send pattern:
  ## 1. Try send() - if EWOULDBLOCK/EAGAIN, wait for socket writable
  ## 2. When writable, retry send()

  while true:
    try:
      result = socket.sock.send(buffer)
      if result > 0:
        return result
    except OSError as e:
      if "would block" in e.msg.toLowerAscii or "again" in e.msg.toLowerAscii:
        socket.loop.waitForWrite(socket.fd)
      else:
        raise newException(SocketError, "send failed: " & e.msg)
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

proc getLocalAddr*(socket: AsyncSocket, domain: Domain = AF_INET): (string, Port) =
  ## Get local address and port.
  ## Uses nativesockets.getLocalAddr() to retrieve socket's bound address.

  try:
    result = nativesockets.getLocalAddr(socket.fd, domain)
  except Exception as e:
    raise newException(SocketError, "getLocalAddr failed: " & e.msg)

proc getRemoteAddr*(socket: AsyncSocket, domain: Domain = AF_INET): (string, Port) =
  ## Get remote address and port (peer address).
  ## Uses nativesockets.getPeerAddr() to retrieve connected peer's address.

  try:
    result = nativesockets.getPeerAddr(socket.fd, domain)
  except Exception as e:
    raise newException(SocketError, "getRemoteAddr failed: " & e.msg)
