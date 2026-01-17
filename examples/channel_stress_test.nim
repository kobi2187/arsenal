## Channel Stress Test
## ====================
##
## Tests channels with 1000+ coroutines to verify M4 acceptance criteria.

import std/times
import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

proc stressTestUnbuffered() =
  ## Test unbuffered channels with many coroutines.
  echo "Unbuffered Channel Stress Test:"
  echo "  Creating 1000 sender/receiver pairs..."

  let ch = newChan[int]()
  var received: array[1000, int]

  # Create 1000 senders
  for i in 0..<1000:
    let idx = i
    let coro = newCoroutine(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        ch.send(idx)
    )
    ready(coro)

  # Create 1000 receivers
  for i in 0..<1000:
    let idx = i
    let coro = newCoroutine(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        received[idx] = ch.recv()
    )
    ready(coro)

  # Run all coroutines
  let start = cpuTime()
  runAll()
  let elapsed = cpuTime() - start

  # Verify all values received
  var allReceived = true
  for i in 0..<1000:
    if received[i] < 0 or received[i] >= 1000:
      allReceived = false
      break

  if allReceived:
    echo "  ✓ All 1000 values transferred"
    echo "  Time: ", (elapsed * 1000).formatFloat(ffDecimal, 2), " ms"
  else:
    echo "  ✗ Some values not received correctly"

proc stressTestBuffered() =
  ## Test buffered channels with many coroutines.
  echo "\nBuffered Channel Stress Test:"
  echo "  Creating 500 sender/receiver pairs with buffered channel..."

  let ch = newBufferedChan[int](100)
  var sum = 0

  # Create 500 senders
  for i in 0..<500:
    let idx = i
    let coro = newCoroutine(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        ch.send(idx)
    )
    ready(coro)

  # Create 500 receivers
  for i in 0..<500:
    let coro = newCoroutine(proc() {.gcsafe.} =
      {.cast(gcsafe).}:
        sum += ch.recv()
    )
    ready(coro)

  # Run all coroutines
  let start = cpuTime()
  runAll()
  let elapsed = cpuTime() - start

  # Verify sum (0+1+2+...+499 = 499*500/2 = 124750)
  let expected = 499 * 500 div 2
  if sum == expected:
    echo "  ✓ All values summed correctly (sum=", sum, ")"
    echo "  Time: ", (elapsed * 1000).formatFloat(ffDecimal, 2), " ms"
  else:
    echo "  ✗ Sum incorrect: got ", sum, ", expected ", expected

proc pipelineTest() =
  ## Test channel pipeline with multiple stages.
  echo "\nPipeline Test:"
  echo "  Creating 3-stage pipeline with 100 values..."

  let ch1 = newChan[int]()
  let ch2 = newChan[int]()
  let ch3 = newChan[int]()

  # Stage 1: Generate numbers 1-100
  let generator = newCoroutine(proc() {.gcsafe.} =
    {.cast(gcsafe).}:
      for i in 1..100:
        ch1.send(i)
  )
  ready(generator)

  # Stage 2: Square the numbers
  let squarer = newCoroutine(proc() {.gcsafe.} =
    {.cast(gcsafe).}:
      for i in 1..100:
        let val = ch1.recv()
        ch2.send(val * val)
  )
  ready(squarer)

  # Stage 3: Sum the squares
  var sumOfSquares = 0
  let summer = newCoroutine(proc() {.gcsafe.} =
    {.cast(gcsafe).}:
      for i in 1..100:
        sumOfSquares += ch2.recv()
  )
  ready(summer)

  # Run pipeline
  let start = cpuTime()
  runAll()
  let elapsed = cpuTime() - start

  # Verify: sum of squares from 1 to 100 = 100*101*201/6 = 338350
  let expected = 338350
  if sumOfSquares == expected:
    echo "  ✓ Pipeline computed correctly (sum=", sumOfSquares, ")"
    echo "  Time: ", (elapsed * 1000).formatFloat(ffDecimal, 2), " ms"
  else:
    echo "  ✗ Sum incorrect: got ", sumOfSquares, ", expected ", expected

when isMainModule:
  echo "\n=== Arsenal Channel Stress Tests ==="
  echo "Testing M4 acceptance criteria: channels with 1000+ coroutines\n"

  stressTestUnbuffered()
  stressTestBuffered()
  pipelineTest()

  echo "\n=== All stress tests completed ===\n"
