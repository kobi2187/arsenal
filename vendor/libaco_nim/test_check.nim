import std/[sequtils, os]

proc checkAcoLib() =
  let libacoDir = getEnv("LIBACO_DIR", "../libaco")
  echo fmt"Looking for libaco in: {libacoDir}"
  
  if not dirExists(libacoDir):
    echo "Error: libaco directory not found"
    echo "Please set LIBACO_DIR environment variable or run from libaco_nim directory"
    quit(1)
  
  let acoH = libacoDir / "aco.h"
  let acoC = libacoDir / "aco.c"
  let acoAsm = libacoDir / "acosw.S"
  
  if not fileExists(acoH):
    echo "Error: aco.h not found"
    quit(1)
  if not fileExists(acoC):
    echo "Error: aco.c not found"
    quit(1)
  if not fileExists(acoAsm):
    echo "Error: acosw.S not found"
    quit(1)
  
  echo "All required libaco files found!"
  echo ""
  echo "Next steps:"
  echo "1. Build library: nimble build"
  echo "2. Run tests: nimble c -r:tests/test_basic"
  echo "3. Run examples: nimble c -r:examples/basic_example"

proc main() =
  checkAcoLib()
