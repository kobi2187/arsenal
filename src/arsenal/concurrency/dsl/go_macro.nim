## Go-Style Concurrency DSL
## ========================
##
## Provides Go-like syntax for spawning coroutines and working with channels.
##
## Usage:
## ```nim
## # Spawn a coroutine
## go:
##   echo "Running in coroutine"
##
## # Spawn with expression
## go echo "Also a coroutine"
##
## # Channels
## let ch = newChan[int]()
## go:
##   ch.send(42)
##
## let value = ch.recv()
## ```

import std/macros
import ../coroutines/coroutine
import ../channels/channel
import ../scheduler  # Use the unified scheduler

# =============================================================================
# Go Macro
# =============================================================================

macro go*(body: untyped): untyped =
  ## Spawn a coroutine to execute the body.
  ##
  ## Usage:
  ## ```nim
  ## go:
  ##   echo "In coroutine"
  ##
  ## go echo "Single expression"
  ## ```
  ##
  ## Generates code that wraps body in closure and spawns it.
  ## Variable capture: Nim closures capture by reference by default.
  ## For value capture, use `let x = x` pattern.

  result = quote do:
    discard spawn(proc() {.closure, gcsafe.} =
      `body`
    )

# =============================================================================
# Channel Receive Operator (Optional)
# =============================================================================

# Note: Nim doesn't support `<-` as a prefix operator, so we use recv()
# You could define a template or use a different operator:

template `<-`*[T](ch: Chan[T]): T =
  ## Alternative syntax: `let value = <-ch`
  ## Note: This may have parsing issues in some contexts.
  ch.recv()

template `<-`*[T](ch: BufferedChan[T]): T =
  ch.recv()
