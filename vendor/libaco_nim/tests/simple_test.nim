import aco
import aco_private

echo "Testing libaco bindings..."

aco_thread_init(nil)
echo "Thread initialized"

let main_co = aco_create(nil, nil, 0, nil, nil)
echo "Main coroutine created"

let sstk = aco_share_stack_new(0)
echo "Shared stack created, size: ", getShareStackSize(sstk)

aco_destroy(main_co)
aco_share_stack_destroy(sstk)
echo "Cleanup done"