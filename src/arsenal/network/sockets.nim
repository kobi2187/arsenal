## Raw Socket Primitives
## ======================
##
## Low-level socket operations with direct POSIX access.
## Complements Nim's stdlib networking.
##
## What std/net provides:
## - Socket type with high-level abstractions
## - Blocking and async I/O via asyncnet
## - SSL/TLS support
## - DNS resolution
## **Uses libc wrappers** (accept, bind, etc.)
##
## What this module provides:
## - Direct POSIX socket access (can bypass libc on Linux)
## - Raw protocol control
## - Lower-level for systems programming
##
## **For most use cases, use std/net or std/asyncnet!**

import ../platform/config

when defined(linux):
  import ../kernel/syscalls

# Re-export std/net for convenience
import std/net
export net

# =============================================================================
# Socket Types and Constants
# =============================================================================

type
  SocketHandle* = distinct cint
    ## Raw socket file descriptor

  SocketDomain* = enum
    ## Address family
    AF_INET = 2    ## IPv4
    AF_INET6 = 10  ## IPv6
    AF_UNIX = 1    ## Unix domain sockets

  SocketType* = enum
    ## Socket type
    SOCK_STREAM = 1     ## TCP
    SOCK_DGRAM = 2      ## UDP
    SOCK_RAW = 3        ## Raw socket
    SOCK_SEQPACKET = 5  ## Sequenced packet

  SocketProtocol* = enum
    ## Protocol
    IPPROTO_TCP = 6
    IPPROTO_UDP = 17
    IPPROTO_ICMP = 1
    IPPROTO_RAW = 255

const
  SOCK_NONBLOCK* = 0x800     ## Non-blocking socket (Linux)
  SOCK_CLOEXEC* = 0x80000    ## Close-on-exec

  # Socket options
  SOL_SOCKET* = 1
  SO_REUSEADDR* = 2
  SO_KEEPALIVE* = 9
  SO_RCVBUF* = 8
  SO_SNDBUF* = 7
  SO_REUSEPORT* = 15

  # TCP options
  IPPROTO_TCP* = 6
  TCP_NODELAY* = 1

# =============================================================================
# Socket Creation
# =============================================================================

when defined(linux):
  proc socket*(domain: SocketDomain, sockType: SocketType, protocol: SocketProtocol): SocketHandle =
    ## Create a socket.
    ##
    ## IMPLEMENTATION:
    ## ```nim
    ## result = SocketHandle(syscall(SYS_socket, domain.clong, sockType.clong, protocol.clong))
    ## ```

    result = SocketHandle(syscall(SYS_socket, domain.clong, sockType.clong, protocol.clong))

  proc close*(sock: SocketHandle): cint =
    ## Close socket.
    cast[cint](syscall(SYS_close, sock.cint.clong))

elif defined(posix):
  # Use libc on other POSIX systems
  proc socket*(domain: cint, sockType: cint, protocol: cint): cint
    {.importc, header: "<sys/socket.h>".}

  proc close*(fd: cint): cint
    {.importc, header: "<unistd.h>".}

# =============================================================================
# Socket Address Structures
# =============================================================================

type
  SockAddrIn* {.importc: "struct sockaddr_in", header: "<netinet/in.h>".} = object
    ## IPv4 socket address
    sin_family*: cushort     # AF_INET
    sin_port*: cushort       # Port (network byte order)
    sin_addr*: InAddr
    sin_zero*: array[8, char]

  InAddr* {.importc: "struct in_addr", header: "<netinet/in.h>".} = object
    s_addr*: uint32  # IP address (network byte order)

  SockAddr* {.importc: "struct sockaddr", header: "<sys/socket.h>".} = object
    sa_family*: cushort
    sa_data*: array[14, char]

# =============================================================================
# Socket Operations
# =============================================================================

proc bind*(sockfd: cint, addr: ptr SockAddr, addrlen: cuint): cint
  {.importc, header: "<sys/socket.h>".}
  ## Bind socket to address

proc listen*(sockfd: cint, backlog: cint): cint
  {.importc, header: "<sys/socket.h>".}
  ## Listen for connections (TCP)

proc accept*(sockfd: cint, addr: ptr SockAddr, addrlen: ptr cuint): cint
  {.importc, header: "<sys/socket.h>".}
  ## Accept connection (TCP)

proc connect*(sockfd: cint, addr: ptr SockAddr, addrlen: cuint): cint
  {.importc, header: "<sys/socket.h>".}
  ## Connect to remote address

proc send*(sockfd: cint, buf: pointer, len: csize_t, flags: cint): cssize_t
  {.importc, header: "<sys/socket.h>".}
  ## Send data (TCP)

proc recv*(sockfd: cint, buf: pointer, len: csize_t, flags: cint): cssize_t
  {.importc, header: "<sys/socket.h>".}
  ## Receive data (TCP)

proc sendto*(sockfd: cint, buf: pointer, len: csize_t, flags: cint,
             dest_addr: ptr SockAddr, addrlen: cuint): cssize_t
  {.importc, header: "<sys/socket.h>".}
  ## Send datagram (UDP)

proc recvfrom*(sockfd: cint, buf: pointer, len: csize_t, flags: cint,
               src_addr: ptr SockAddr, addrlen: ptr cuint): cssize_t
  {.importc, header: "<sys/socket.h>".}
  ## Receive datagram (UDP)

# =============================================================================
# Socket Options
# =============================================================================

proc setsockopt*(sockfd: cint, level: cint, optname: cint,
                 optval: pointer, optlen: cuint): cint
  {.importc, header: "<sys/socket.h>".}
  ## Set socket option

proc getsockopt*(sockfd: cint, level: cint, optname: cint,
                 optval: pointer, optlen: ptr cuint): cint
  {.importc, header: "<sys/socket.h>".}
  ## Get socket option

proc setReuseAddr*(sock: cint, enable: bool = true): cint =
  ## Enable SO_REUSEADDR (allows binding to same port quickly after close)
  var optval: cint = if enable: 1 else: 0
  setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, addr optval, sizeof(optval).cuint)

proc setNonBlocking*(sock: cint, enable: bool = true): cint =
  ## Set socket to non-blocking mode
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(linux):
  ##   let flags = fcntl(sock, F_GETFL, 0)
  ##   let newFlags = if enable: flags or O_NONBLOCK else: flags and not O_NONBLOCK
  ##   result = fcntl(sock, F_SETFL, newFlags)
  ## ```

  when defined(posix):
    # Declare fcntl
    proc fcntl(fd: cint, cmd: cint, arg: clong = 0): cint
      {.importc, header: "<fcntl.h>", varargs.}

    const
      F_GETFL = 3
      F_SETFL = 4

    let flags = fcntl(sock, F_GETFL)
    if flags < 0:
      return flags

    let newFlags = if enable: flags or SOCK_NONBLOCK.cint else: flags and not SOCK_NONBLOCK.cint
    result = fcntl(sock, F_SETFL, newFlags.clong)
  else:
    # Windows or other platforms
    0

# =============================================================================
# Byte Order Conversion
# =============================================================================

proc htons*(hostshort: uint16): uint16 {.importc, header: "<arpa/inet.h>".}
  ## Host to network byte order (short)

proc htonl*(hostlong: uint32): uint32 {.importc, header: "<arpa/inet.h>".}
  ## Host to network byte order (long)

proc ntohs*(netshort: uint16): uint16 {.importc, header: "<arpa/inet.h>".}
  ## Network to host byte order (short)

proc ntohl*(netlong: uint32): uint32 {.importc, header: "<arpa/inet.h>".}
  ## Network to host byte order (long)

# =============================================================================
# IP Address Conversion
# =============================================================================

proc inet_pton*(af: cint, src: cstring, dst: pointer): cint
  {.importc, header: "<arpa/inet.h>".}
  ## Convert IP address string to binary

proc inet_ntop*(af: cint, src: pointer, dst: cstring, size: cuint): cstring
  {.importc, header: "<arpa/inet.h>".}
  ## Convert binary IP address to string

proc ipv4ToUint32*(ip: string): uint32 =
  ## Convert IPv4 string to uint32 (network byte order)
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var addr: InAddr
  ## if inet_pton(AF_INET.cint, ip.cstring, addr (result)) != 1:
  ##   raise newException(ValueError, "Invalid IPv4 address")
  ## result = addr.s_addr
  ## ```

  var addr: InAddr
  if inet_pton(AF_INET.cint, ip.cstring, addr result) != 1:
    raise newException(ValueError, "Invalid IPv4 address")
  result = addr.s_addr

proc uint32ToIpv4*(ip: uint32): string =
  ## Convert uint32 (network byte order) to IPv4 string
  var buf: array[16, char]
  var addr = InAddr(s_addr: ip)
  discard inet_ntop(AF_INET.cint, addr buf[0].addr, 16)
  result = $cast[cstring](addr buf[0])

# =============================================================================
# High-Level Helpers
# =============================================================================

proc createTcpSocket*(nonBlocking: bool = false): cint =
  ## Create TCP socket.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## when defined(linux):
  ##   let flags = if nonBlocking: SOCK_NONBLOCK else: 0
  ##   result = socket(AF_INET, SOCK_STREAM.cint or flags, 0)
  ## else:
  ##   result = socket(AF_INET.cint, SOCK_STREAM.cint, IPPROTO_TCP.cint)
  ##   if nonBlocking:
  ##     discard setNonBlocking(result, true)
  ## ```

  when defined(linux):
    let flags = if nonBlocking: SOCK_NONBLOCK else: 0
    result = socket(AF_INET, SOCK_STREAM.cint or flags, IPPROTO_TCP.cint)
  else:
    result = socket(AF_INET.cint, SOCK_STREAM.cint, IPPROTO_TCP.cint)
    if nonBlocking:
      discard setNonBlocking(result, true)

proc createUdpSocket*(): cint =
  ## Create UDP socket.
  when defined(linux):
    socket(AF_INET, SOCK_DGRAM.cint, IPPROTO_UDP.cint)
  else:
    socket(AF_INET.cint, SOCK_DGRAM.cint, IPPROTO_UDP.cint)

proc makeSockAddr*(ip: string, port: uint16): SockAddrIn =
  ## Create socket address structure.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## result.sin_family = AF_INET.cushort
  ## result.sin_port = htons(port)
  ## result.sin_addr.s_addr = ipv4ToUint32(ip)
  ## ```

  result.sin_family = AF_INET.cushort
  result.sin_port = htons(port)
  result.sin_addr.s_addr = ipv4ToUint32(ip)

# =============================================================================
# Example: Simple TCP Echo Server
# =============================================================================

proc runEchoServer*(port: uint16) =
  ## Simple TCP echo server (blocking).
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## let sock = createTcpSocket()
  ## discard setReuseAddr(sock, true)
  ##
  ## var addr = makeSockAddr("0.0.0.0", port)
  ## discard bind(sock, cast[ptr SockAddr](addr addr), sizeof(addr).cuint)
  ## discard listen(sock, 10)
  ##
  ## echo "Listening on port ", port
  ## while true:
  ##   var clientAddr: SockAddrIn
  ##   var clientLen = sizeof(clientAddr).cuint
  ##   let client = accept(sock, cast[ptr SockAddr](addr clientAddr), addr clientLen)
  ##
  ##   # Echo loop
  ##   var buf: array[4096, byte]
  ##   while true:
  ##     let n = recv(client, addr buf[0], buf.len.csize_t, 0)
  ##     if n <= 0: break
  ##     discard send(client, addr buf[0], n.csize_t, 0)
  ##
  ##   discard close(client)
  ## ```

  # Stub - see implementation notes above
  echo "Echo server on port ", port

# =============================================================================
# Notes
# =============================================================================

## USAGE NOTES:
##
## **For most use cases (recommended):**
## ```nim
## import std/net
## let socket = newSocket()
## socket.connect("example.com", Port(80))
## socket.send("GET / HTTP/1.0\r\n\r\n")
## echo socket.recvLine()
## socket.close()
## ```
##
## **For async I/O (recommended):**
## ```nim
## import std/asyncnet, std/asyncdispatch
## proc handler() {.async.} =
##   let socket = newAsyncSocket()
##   await socket.connect("example.com", Port(80))
##   await socket.send("GET / HTTP/1.0\r\n\r\n")
##   echo await socket.recvLine()
## waitFor handler()
## ```
##
## **For raw socket access:**
## ```nim
## # TCP Client (low-level)
## let sock = createTcpSocket()
## var addr = makeSockAddr("127.0.0.1", 8080)
## discard connect(sock, cast[ptr SockAddr](addr addr), sizeof(addr).cuint)
## discard send(sock, "Hello".cstring, 5, 0)
## discard close(sock)
## ```
##
## **UDP Send (low-level):**
## ```nim
## let sock = createUdpSocket()
## var addr = makeSockAddr("127.0.0.1", 9000)
## discard sendto(sock, "Hello".cstring, 5, 0,
##                cast[ptr SockAddr](addr addr), sizeof(addr).cuint)
## ```
##
## **When to use this module:**
## - Custom protocols (raw sockets, ICMP)
## - Bypass libc (embedded, static linking)
## - Learning socket internals
## - **Otherwise, use std/net or std/asyncnet**
