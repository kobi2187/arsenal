## Async Socket Wrapper
## ====================
##
## Provides async socket operations that integrate with the event loop
## and coroutine scheduler.
##
## Usage:
## ```nim
## let loop = getEventLoop()
## let sock = newAsyncSocket()
##
## # In a coroutine:
## sock.connect(loop, "example.com", Port(80))
## sock.send(loop, "GET / HTTP/1.0\r\n\r\n")
## let data = sock.recv(loop, 1024)
## ```

import std/net
import std/nativesockets
import std/os
import std/strutils
import ./eventloop
import ../concurrency/coroutines/coroutine

export Port

type
  AsyncSocket* = ref object
    ## Asynchronous socket that works with event loop and coroutines.
    sock*: Socket
    fd*: SocketHandle

proc newAsyncSocket*(domain: Domain = AF_INET, sockType: SockType = SOCK_STREAM,
                     protocol: Protocol = IPPROTO_TCP): AsyncSocket =
  ## Create a new async socket.
  result = AsyncSocket()
  result.sock = newSocket(domain, sockType, protocol)
  result.fd = result.sock.getFd()

  # Set non-blocking mode
  result.fd.setBlocking(false)

proc connect*(sock: AsyncSocket, loop: EventLoop, address: string, port: Port) =
  ## Connect to a remote address. Blocks current coroutine until connected.
  try:
    sock.sock.connect(address, port)
  except OSError as e:
    # EINPROGRESS (115) or EWOULDBLOCK means connection in progress
    if e.errorCode.int32 == 115 or "in progress" in e.msg or "would block" in e.msg:
      # Wait for socket to become writable (connection complete)
      loop.waitForWrite(sock.fd)
    else:
      raise

proc send*(sock: AsyncSocket, loop: EventLoop, data: string): int =
  ## Send data on the socket. Blocks current coroutine until data can be sent.
  while true:
    try:
      sock.sock.send(data)
      return data.len
    except OSError as e:
      # EWOULDBLOCK/EAGAIN means socket buffer full
      if "would block" in e.msg or "again" in e.msg:
        loop.waitForWrite(sock.fd)
      else:
        raise

proc recv*(sock: AsyncSocket, loop: EventLoop, size: int): string =
  ## Receive data from socket. Blocks current coroutine until data available.
  while true:
    try:
      result = sock.sock.recv(size)
      if result.len > 0 or result.len == 0:  # 0 means EOF
        return result
    except OSError as e:
      # EWOULDBLOCK/EAGAIN means no data available yet
      if "would block" in e.msg or "again" in e.msg:
        loop.waitForRead(sock.fd)
      else:
        raise

proc close*(sock: AsyncSocket) =
  ## Close the socket.
  sock.sock.close()

proc bindAddr*(sock: AsyncSocket, port: Port, address = "") =
  ## Bind socket to address and port.
  sock.sock.bindAddr(port, address)

proc listen*(sock: AsyncSocket, backlog = SOMAXCONN) =
  ## Mark socket as listening for connections.
  sock.sock.listen(backlog)

proc accept*(sock: AsyncSocket, loop: EventLoop): AsyncSocket =
  ## Accept an incoming connection. Blocks current coroutine until client connects.
  while true:
    try:
      var client: Socket
      var address: string
      sock.sock.acceptAddr(client, address)

      result = AsyncSocket(sock: client, fd: client.getFd())
      result.fd.setBlocking(false)
      return result
    except OSError as e:
      if "would block" in e.msg or "again" in e.msg:
        loop.waitForRead(sock.fd)
      else:
        raise
