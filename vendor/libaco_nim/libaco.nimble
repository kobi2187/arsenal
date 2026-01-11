version       = "0.1.0"
author       = "libaco bindings"
description   = "Nim bindings for libaco asymmetric coroutine library"
license       = "Apache-2.0"
srcDir       = "src"
installExt    = @["nim", "h", "c"]
requires "nim >= 2.0"

task build:
  exec "nim c -o:build/libaco.so ../libaco/aco.c ../libaco/acosw.S"
