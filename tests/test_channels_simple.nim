## Simple Channel Test
## ===================

import ../src/arsenal/concurrency/channels/channel
import ../src/arsenal/concurrency/coroutines/coroutine
import ../src/arsenal/concurrency/scheduler

echo "Creating channel..."
let ch = newChan[int]()

echo "Creating sender coroutine..."
let sender = newCoroutine(proc() =
  echo "Sender: about to send 42"
  ch.send(42)
  echo "Sender: sent 42"
)

echo "Creating receiver coroutine..."
let receiver = newCoroutine(proc() =
  echo "Receiver: about to recv"
  let v = ch.recv()
  echo "Receiver: got ", v
)

echo "Adding to scheduler..."
ready(sender)
ready(receiver)

echo "Running scheduler..."
runAll()

echo "Done!"
