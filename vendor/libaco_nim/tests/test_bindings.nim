import aco
import aco_private

proc testBasic() =
  echo "Testing basic libaco functionality..."
  
  # Initialize libaco for this thread
  aco_thread_init(nil)
  echo "✓ Thread initialized"
  
  # Create main coroutine
  let main_co = aco_create(nil, nil, 0, nil, nil)
  doAssert main_co != nil
  echo "✓ Main coroutine created"
  
  # Create shared stack
  let sstk = aco_share_stack_new(0)  # 0 means default 2MB
  doAssert sstk != nil
  echo "✓ Shared stack created"
  
  # Test shared stack properties
  doAssert getShareStackSize(sstk) > 0
  doAssert isShareStackGuardPageEnabled(sstk) == true
  echo "✓ Shared stack properties verified"
  
  # Test coroutine creation
  proc dummy_proc() =
    echo "Dummy coroutine executed"
    aco_yield()
    aco_exit()
  
  let co = aco_create(main_co, sstk, 0, cast[aco_cofuncp_t](dummy_proc), nil)
  doAssert co != nil
  echo "✓ Coroutine created"
  
  # Test coroutine execution
  aco_resume(co)
  echo "✓ Coroutine resumed"
  
  # Test coroutine state
  doAssert isCoroutineEnded(co) == false
  doAssert getShareStackOwner(sstk) != nil
  echo "✓ Coroutine state verified"
  
  # Resume again (should finish)
  aco_resume(co)
  doAssert isCoroutineEnded(co) == true
  echo "✓ Coroutine completed"
  
  # Clean up
  aco_destroy(co)
  aco_share_stack_destroy(sstk)
  aco_destroy(main_co)
  echo "✓ Cleanup completed"
  
  echo "\nAll basic tests passed! ✓"

proc main() =
  testBasic()

when isMainModule:
  main()