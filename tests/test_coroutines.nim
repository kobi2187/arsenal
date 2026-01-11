import std/unittest
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
