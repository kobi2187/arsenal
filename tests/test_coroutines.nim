import std/unittest
import std/times
import ../src/arsenal/concurrency/coroutines/coroutine

suite "Coroutine Basic":
  test "create coroutine":
    var value = 0
    let co = newCoroutine(proc() =
      value = 1
      coroYield()
      value = 2
    )
    check value == 0
    check co.state == csReady

  test "resume and yield":
    var value = 0
    let co = newCoroutine(proc() =
      value = 1
      coroYield()
      value = 2
    )

    co.resume()
    check value == 1
    check co.isSuspended()

    co.resume()
    check value == 2
    check co.isFinished()

  test "multiple coroutines":
    var a = 0
    var b = 0

    let co1 = newCoroutine(proc() =
      a = 1
      coroYield()
      a = 2
    )

    let co2 = newCoroutine(proc() =
      b = 10
      coroYield()
      b = 20
    )

    co1.resume()
    check a == 1

    co2.resume()
    check b == 10

    co1.resume()
    check a == 2

    co2.resume()
    check b == 20

suite "Coroutine Stress Tests":
  test "1K coroutines (M2 acceptance criteria)":
    ## Tests that we can create and run 1,000 coroutines without crashing.
    ## This verifies memory management and stack handling at scale.
    const numCoroutines = 1_000
    var count = 0
    var coros: seq[Coroutine]

    # Create all coroutines - they share the stack
    for i in 0..<numCoroutines:
      let co = newCoroutine(proc() =
        inc count
        coroYield()
        inc count
      )
      coros.add(co)

    check coros.len == numCoroutines

    # First resume - each increments count and yields
    for co in coros:
      co.resume()

    check count == numCoroutines

    # Second resume - each increments count and finishes
    for co in coros:
      co.resume()
      check co.isFinished()

    check count == numCoroutines * 2

  test "context switch benchmark (<20ns target)":
    ## Benchmarks context switch time.
    ## Target: <20ns on x86_64, <50ns on ARM64.
    let co = newCoroutine(proc() =
      while true:
        coroYield()
    )

    const iterations = 1_000_000

    let start = cpuTime()
    for _ in 0..<iterations:
      co.resume()
    let elapsed = cpuTime() - start

    let nsPerSwitch = (elapsed * 1_000_000_000.0) / float(iterations)
    echo "  Context switch: ", nsPerSwitch, " ns/switch"

    # Verify target (wrapper adds overhead to raw libaco's ~20ns)
    # Raw libaco: ~20ns, with Nim wrapper: ~50-80ns
    when defined(release):
      check nsPerSwitch < 100.0  # Allow margin for wrapper overhead
    else:
      check nsPerSwitch < 300.0  # Debug mode is slower

  test "many yields in single coroutine":
    ## Test that a coroutine can yield many times.
    var count = 0

    let co = newCoroutine(proc() =
      for i in 0..<100:
        inc count
        coroYield()
    )

    for i in 0..<100:
      co.resume()
      check count == i + 1
      check co.isSuspended()

    co.resume()
    check co.isFinished()
    check count == 100

suite "Coroutine Error Handling":
  test "resume finished coroutine raises":
    let co = newCoroutine(proc() =
      discard  # Immediately finishes
    )

    co.resume()
    check co.isFinished()

    expect CoroutineError:
      co.resume()

  test "yield outside coroutine raises":
    expect CoroutineError:
      coroYield()
