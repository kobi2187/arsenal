## Arsenal Sorting - Unified High-Level API
## ===========================================
##
## This module provides a consistent, ergonomic API for all sorting
## algorithms. It wraps the underlying implementations without modifying them.
##
## You can use either:
## - This high-level API (consistent, discoverable)
## - Direct implementation modules (full control, all features)
##
## Usage:
## ```nim
## import arsenal/sorting
##
## # Sort array
## var arr = [5, 2, 8, 1, 9]
## arr.sort()  # Uses fastest algorithm
##
## # Get sorted copy
## let sorted = arr.sorted()
## ```

import arsenal/algorithms/sorting/pdqsort
import std/algorithm as stdalgo

export pdqsort  # Re-export for direct use

# =============================================================================
# UNIFIED SORTING API
# =============================================================================

# Re-export standard comparison
export cmp

proc sort*[T](arr: var openArray[T]) =
  ## Sort array in-place (uses pdqsort - fastest general-purpose)
  ##
  ## - Time: O(n log n) worst case, O(n) best case
  ## - Space: O(log n)
  ## - Stable: No
  ## - Adaptive: Yes (fast on nearly-sorted data)
  ##
  ## Example:
  ## ```nim
  ## var arr = [5, 2, 8, 1, 9]
  ## arr.sort()
  ## # arr is now [1, 2, 5, 8, 9]
  ## ```
  pdqsort(arr)

proc sort*[T](arr: var openArray[T], cmp: proc(a, b: T): int) =
  ## Sort array with custom comparison
  ##
  ## Example:
  ## ```nim
  ## # Sort descending
  ## arr.sort(proc(a, b: int): int = cmp(b, a))
  ## ```
  pdqsort(arr, cmp)

proc sorted*[T](arr: openArray[T]): seq[T] =
  ## Return sorted copy of array
  ##
  ## Example:
  ## ```nim
  ## let original = [5, 2, 8, 1, 9]
  ## let sorted = original.sorted()
  ## # original is unchanged
  ## # sorted is [1, 2, 5, 8, 9]
  ## ```
  result = @arr
  result.sort()

proc sorted*[T](arr: openArray[T], cmp: proc(a, b: T): int): seq[T] =
  ## Return sorted copy with custom comparison
  result = @arr
  result.sort(cmp)

# Convenience predicates
proc sortDescending*[T](arr: var openArray[T]) =
  ## Sort in descending order
  arr.sort(proc(a, b: T): int = cmp(b, a))

proc sortedDescending*[T](arr: openArray[T]): seq[T] =
  ## Return sorted copy in descending order
  arr.sorted(proc(a, b: T): int = cmp(b, a))

# Stability
proc sortStable*[T](arr: var openArray[T]) =
  ## Sort array in-place (stable)
  ##
  ## Preserves relative order of equal elements
  ## Uses standard library's stable sort
  stdalgo.sort(arr, cmp[T])

proc sortStable*[T](arr: var openArray[T], cmp: proc(a, b: T): int) =
  ## Stable sort with custom comparison
  stdalgo.sort(arr, cmp)

proc sortedStable*[T](arr: openArray[T]): seq[T] =
  ## Return stable sorted copy
  result = @arr
  result.sortStable()

proc sortedStable*[T](arr: openArray[T], cmp: proc(a, b: T): int): seq[T] =
  ## Return stable sorted copy with custom comparison
  result = @arr
  result.sortStable(cmp)

# Partial sorting
proc partialSort*[T](arr: var openArray[T], k: int) =
  ## Partially sort array so first k elements are sorted
  ##
  ## Faster than full sort when k << n
  ##
  ## Algorithm: Quickselect to partition, then insertion sort first k
  ## Complexity: O(n + k log k) average case vs O(n log n) for full sort
  ##
  ## Example:
  ## ```nim
  ## var arr = [9, 5, 2, 8, 1, 7, 3]
  ## arr.partialSort(3)
  ## # First 3 elements are smallest: [1, 2, 3, ...]
  ## # Remaining elements are unordered
  ## ```
  if k <= 0:
    return
  if k >= arr.len:
    arr.sort()
    return

  # Use quickselect to partition so that first k elements are the smallest
  # This is similar to quicksort partition but we only recurse on the side containing k
  proc partition[T](arr: var openArray[T], left, right: int): int =
    # Simple median-of-three pivot selection
    let mid = (left + right) div 2
    if arr[mid] < arr[left]:
      swap(arr[left], arr[mid])
    if arr[right] < arr[left]:
      swap(arr[left], arr[right])
    if arr[mid] < arr[right]:
      swap(arr[mid], arr[right])

    let pivot = arr[right]
    var i = left - 1

    for j in left..<right:
      if arr[j] <= pivot:
        inc i
        swap(arr[i], arr[j])

    swap(arr[i + 1], arr[right])
    return i + 1

  proc quickselect[T](arr: var openArray[T], left, right, k: int) =
    if left >= right:
      return

    let pivotIdx = partition(arr, left, right)

    if pivotIdx == k:
      return  # k-th element in position
    elif k < pivotIdx:
      quickselect(arr, left, pivotIdx - 1, k)  # Search left
    else:
      quickselect(arr, pivotIdx + 1, right, k)  # Search right

  # Use quickselect to ensure first k elements are the k smallest
  quickselect(arr, 0, arr.len - 1, k - 1)

  # Now sort just the first k elements with insertion sort (efficient for small k)
  for i in 1..<k:
    let key = arr[i]
    var j = i - 1
    while j >= 0 and arr[j] > key:
      arr[j + 1] = arr[j]
      dec j
    arr[j + 1] = key

# Checking if sorted
proc isSorted*[T](arr: openArray[T]): bool =
  ## Check if array is sorted in ascending order
  for i in 1..<arr.len:
    if arr[i] < arr[i-1]:
      return false
  true

proc isSorted*[T](arr: openArray[T], cmp: proc(a, b: T): int): bool =
  ## Check if array is sorted using custom comparison
  for i in 1..<arr.len:
    if cmp(arr[i], arr[i-1]) < 0:
      return false
  true

proc isSortedDescending*[T](arr: openArray[T]): bool =
  ## Check if array is sorted in descending order
  for i in 1..<arr.len:
    if arr[i] > arr[i-1]:
      return false
  true

# =============================================================================
# EXAMPLE USAGE
# =============================================================================

when isMainModule:
  import std/[random, times, strformat]

  echo "Arsenal Sorting - Unified API Demo"
  echo "==================================="
  echo ""

  # Basic sorting
  echo "1. Basic Sorting"
  echo "---------------"

  var arr1 = [5, 2, 8, 1, 9, 3, 7, 4, 6]
  echo "Original: ", arr1

  arr1.sort()
  echo "Sorted:   ", arr1
  echo "Is sorted: ", arr1.isSorted()
  echo ""

  # Sorted copy
  echo "2. Sorted Copy"
  echo "-------------"

  let original = [9, 5, 2, 8, 1]
  let sortedCopy = original.sorted()

  echo "Original: ", original
  echo "Sorted:   ", sortedCopy
  echo ""

  # Descending order
  echo "3. Descending Order"
  echo "------------------"

  var arr3 = [5, 2, 8, 1, 9]
  arr3.sortDescending()
  echo "Descending: ", arr3
  echo "Is sorted descending: ", arr3.isSortedDescending()
  echo ""

  # Custom comparison
  echo "4. Custom Comparison"
  echo "-------------------"

  type Person = object
    name: string
    age: int

  var people = @[
    Person(name: "Alice", age: 30),
    Person(name: "Bob", age: 25),
    Person(name: "Charlie", age: 35)
  ]

  # Sort by age
  people.sort(proc(a, b: Person): int = cmp(a.age, b.age))
  echo "Sorted by age:"
  for p in people:
    echo "  ", p.name, ": ", p.age
  echo ""

  # Stable sort
  echo "5. Stable Sort"
  echo "-------------"

  type Item = object
    value: int
    order: int

  var items = @[
    Item(value: 2, order: 1),
    Item(value: 1, order: 2),
    Item(value: 2, order: 3),
    Item(value: 1, order: 4)
  ]

  items.sortStable(proc(a, b: Item): int = cmp(a.value, b.value))
  echo "Stable sorted by value (preserves order for equal values):"
  for item in items:
    echo "  value=", item.value, ", order=", item.order
  echo ""

  # Performance benchmark
  echo "6. Performance Benchmark"
  echo "-----------------------"

  let sizes = [10_000, 100_000, 1_000_000]

  for n in sizes:
    var arr = newSeq[int](n)

    # Random data
    randomize(42)
    for i in 0..<n:
      arr[i] = rand(1_000_000)

    let start = cpuTime()
    arr.sort()
    let elapsed = cpuTime() - start

    echo "Sorted ", n, " random integers:"
    echo "  Time: ", (elapsed * 1000).formatFloat(ffDecimal, 2), " ms"
    echo "  Throughput: ", (n.float64 / elapsed / 1_000_000).formatFloat(ffDecimal, 2), " M elements/sec"
    echo "  Sorted: ", arr.isSorted()
    echo ""

  # Nearly sorted data (pdqsort should be fast)
  echo "7. Nearly Sorted Data (Adaptive Behavior)"
  echo "-----------------------------------------"

  let n = 1_000_000
  var nearlySorted = newSeq[int](n)
  for i in 0..<n:
    nearlySorted[i] = i

  # Shuffle 1% of elements
  randomize(123)
  for _ in 0..<(n div 100):
    let i = rand(n-1)
    let j = rand(n-1)
    swap(nearlySorted[i], nearlySorted[j])

  echo "Array: ", n, " elements, 99% sorted"
  let start = cpuTime()
  nearlySorted.sort()
  let elapsed = cpuTime() - start

  echo "  Time: ", (elapsed * 1000).formatFloat(ffDecimal, 2), " ms"
  echo "  Throughput: ", (n.float64 / elapsed / 1_000_000).formatFloat(ffDecimal, 2), " M elements/sec"
  echo "  (pdqsort is adaptive - fast on nearly-sorted data)"
  echo ""

  # Partial sort
  echo "8. Partial Sort (Top K)"
  echo "----------------------"

  var arr8 = newSeq[int](100)
  randomize(456)
  for i in 0..<100:
    arr8[i] = rand(1000)

  arr8.partialSort(10)
  echo "Partial sort (k=10) of 100 elements:"
  echo "  First 10 (smallest): ", arr8[0..<10]
  echo ""

  echo "All demos completed!"
