import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/coroutines/backend

echo "Starting repro"

proc main() =
  var value = 0
  let c = newCoroutine(proc() =
    echo "Inside coroutine"
    value = 1
    coroYield()
    value = 2
    echo "Exiting coroutine"
  )
  
  echo "Resuming 1"
  c.resume()
  echo "Resumed 1"
  if value != 1: quit("Value mismatch 1")
  
  echo "Resuming 2"
  c.resume()
  echo "Resumed 2"
  if value != 2: quit("Value mismatch 2")
  
  if not c.isFinished: quit("Not finished")
  
  stderr.writeLine("Destroying")
  c.destroy()
  stderr.writeLine("Destroyed")

main()
stderr.writeLine("Main finished")
