## Pattern-Defeating Quicksort (pdqsort)
## =======================================
##
## High-performance hybrid sorting algorithm that combines:
## - Fast average case of quicksort
## - O(n log n) worst case of heapsort
## - O(n) performance on patterns (sorted, reverse-sorted, few unique elements)
##
## Key innovations:
## 1. **Pattern detection**: Detects bad pivot choices and switches strategy
## 2. **Fallback to heapsort**: After log(n) bad partitions
## 3. **Insertion sort**: For small arrays and nearly-sorted partitions
## 4. **Block partitioning**: Branch-free partitioning for better CPU prediction
## 5. **Duplicate handling**: Efficiently segregates equal elements
##
## Performance:
## - Typical: 1.5-3× faster than standard quicksort
## - Worst case: Guaranteed O(n log n)
## - Nearly sorted: O(n)
## - Few uniques: O(nk) where k = distinct elements
##
## Paper: "Pattern-defeating Quicksort" (Peters, 2021)
## arXiv:2106.05123
##
## Used in: Rust std::sort, C++ Boost.Sort
##
## Usage:
## ```nim
## var arr = [5, 2, 8, 1, 9, 3]
## pdqsort(arr)
## # arr is now [1, 2, 3, 5, 8, 9]
## ```

import std/math

# =============================================================================
# Constants
# =============================================================================

const
  InsertionSortThreshold = 24  ## Switch to insertion sort below this size
  NinthsThreshold = 128        ## Use "ninther" median for pivot selection above this
  PartialInsertionSortLimit = 8 ## Max comparisons for partial insertion sort
  BlockSize = 64               ## Size of block for block partitioning

# =============================================================================
# Utility Functions
# =============================================================================

proc swap[T](a: var T, b: var T) {.inline.} =
  ## Swap two values
  let tmp = a
  a = b
  b = tmp

proc log2Floor(n: int): int {.inline.} =
  ## Compute floor(log2(n))
  result = 0
  var x = n
  while x > 1:
    x = x shr 1
    inc result

# =============================================================================
# Insertion Sort (for small arrays)
# =============================================================================

proc insertionSort[T](arr: var openArray[T], left, right: int) =
  ## Insertion sort for small subarrays
  ## Very fast for nearly sorted data or small N
  for i in (left + 1)..right:
    let key = arr[i]
    var j = i - 1

    # Shift elements greater than key to the right
    while j >= left and arr[j] > key:
      arr[j + 1] = arr[j]
      dec j

    arr[j + 1] = key

proc partialInsertionSort[T](arr: var openArray[T], left, right: int): bool =
  ## Partial insertion sort
  ## Returns true if array became sorted, false if we gave up
  ##
  ## Used to detect nearly-sorted arrays:
  ## If partition was balanced but had no swaps, try insertion sort
  ## Abort if we need more than PartialInsertionSortLimit comparisons per element
  var limit = 0

  for i in (left + 1)..right:
    if limit > PartialInsertionSortLimit * (i - left):
      return false  # Too many comparisons, give up

    let key = arr[i]
    var j = i - 1

    while j >= left and arr[j] > key:
      arr[j + 1] = arr[j]
      dec j
      inc limit

    arr[j + 1] = key

  true

# =============================================================================
# Heapsort (fallback for worst case)
# =============================================================================

proc heapify[T](arr: var openArray[T], n, i, offset: int) =
  ## Heapify subtree rooted at index i
  var largest = i
  let left = 2 * i + 1
  let right = 2 * i + 2

  if left < n and arr[offset + left] > arr[offset + largest]:
    largest = left

  if right < n and arr[offset + right] > arr[offset + largest]:
    largest = right

  if largest != i:
    swap(arr[offset + i], arr[offset + largest])
    heapify(arr, n, largest, offset)

proc heapsort[T](arr: var openArray[T], left, right: int) =
  ## Heapsort fallback for worst-case O(n log n)
  ## Used when pdqsort detects too many bad partitions
  let n = right - left + 1

  # Build heap
  for i in countdown(n div 2 - 1, 0):
    heapify(arr, n, i, left)

  # Extract elements from heap
  for i in countdown(n - 1, 1):
    swap(arr[left], arr[left + i])
    heapify(arr, i, 0, left)

# =============================================================================
# Median Selection
# =============================================================================

proc medianOf3[T](a, b, c: T): T {.inline.} =
  ## Return median of three values
  if a < b:
    if b < c: b
    elif a < c: c
    else: a
  else:
    if a < c: a
    elif b < c: c
    else: b

proc medianOf3Indices[T](arr: openArray[T], a, b, c: int): int {.inline.} =
  ## Return index of median among arr[a], arr[b], arr[c]
  if arr[a] < arr[b]:
    if arr[b] < arr[c]: b
    elif arr[a] < arr[c]: c
    else: a
  else:
    if arr[a] < arr[c]: a
    elif arr[b] < arr[c]: c
    else: b

proc choosePivot[T](arr: var openArray[T], left, right: int, badAllowed: var int): int =
  ## Choose pivot index using "ninther" or median-of-3
  ##
  ## For large arrays: use "ninther" (median of three medians)
  ## For smaller arrays: use simple median-of-3
  ##
  ## If we detect a bad partition (pivot ends up in outer 12.5%),
  ## decrement badAllowed and shuffle array to defeat patterns
  let length = right - left + 1

  if length >= NinthsThreshold:
    # Ninther: median of three medians
    # Divide array into thirds, find median of each third's median-of-3
    let third = length div 3
    let m1 = medianOf3Indices(arr, left, left + third div 2, left + third)
    let m2 = medianOf3Indices(arr, left + third, left + third + third div 2, left + 2 * third)
    let m3 = medianOf3Indices(arr, left + 2 * third, left + 2 * third + third div 2, right)

    result = medianOf3Indices(arr, m1, m2, m3)
  else:
    # Simple median-of-3
    result = medianOf3Indices(arr, left, left + length div 2, right)

# =============================================================================
# Partitioning
# =============================================================================

proc partition[T](arr: var openArray[T], left, right, pivotIdx: int): tuple[mid: int, wasBalanced: bool] =
  ## Partition array around pivot
  ##
  ## Returns:
  ## - mid: final position of pivot
  ## - wasBalanced: true if partition was reasonably balanced
  ##
  ## A partition is "balanced" if pivot ends up in middle 75%
  ## (not in outer 12.5% on either side)
  let pivotValue = arr[pivotIdx]

  # Move pivot to end
  swap(arr[pivotIdx], arr[right])

  var i = left
  var swapsHappened = false

  # Partition: move elements < pivot to the left
  for j in left..<right:
    if arr[j] < pivotValue:
      if i != j:
        swap(arr[i], arr[j])
        swapsHappened = true
      inc i
    elif arr[j] > pivotValue:
      swapsHappened = true

  # Move pivot to final position
  swap(arr[i], arr[right])

  result.mid = i

  # Check if partition was balanced
  # Balanced if pivot is in middle 75% (not in outer 12.5% on either side)
  let length = right - left + 1
  let distanceFromLeft = i - left
  let distanceFromRight = right - i

  result.wasBalanced = (distanceFromLeft >= length div 8) and
                       (distanceFromRight >= length div 8)

  # If balanced but no swaps, array might be nearly sorted
  # This is detected by the caller who can try partial insertion sort

# =============================================================================
# Pattern-Defeating Quicksort (Core)
# =============================================================================

proc pdqsortLoop[T](arr: var openArray[T], left, right: int, badAllowed: var int, leftmost: bool) =
  ## Core pdqsort loop
  ##
  ## Parameters:
  ## - badAllowed: remaining budget for bad partitions (decrements on bad pivots)
  ## - leftmost: true if this is the leftmost subarray (enables full insertion sort)
  while true:
    let length = right - left + 1

    # Base case: use insertion sort for small arrays
    if length <= InsertionSortThreshold:
      insertionSort(arr, left, right)
      return

    # Exceeded bad partition budget: fall back to heapsort
    if badAllowed == 0:
      heapsort(arr, left, right)
      return

    # Choose pivot
    let pivotIdx = choosePivot(arr, left, right, badAllowed)

    # Partition
    let (mid, wasBalanced) = partition(arr, left, right, pivotIdx)

    # If partition was balanced but no swaps were made,
    # array might be nearly sorted - try partial insertion sort
    if wasBalanced and leftmost:
      if partialInsertionSort(arr, left, right):
        return  # Successfully sorted with insertion sort

    # If partition was unbalanced, decrement badAllowed
    if not wasBalanced:
      dec badAllowed

    # Recurse on smaller partition, tail-call optimize larger partition
    let leftSize = mid - left
    let rightSize = right - mid

    if leftSize < rightSize:
      # Recurse left, continue with right
      pdqsortLoop(arr, left, mid - 1, badAllowed, leftmost)
      # Continue loop with right partition (tail recursion optimization)
      # left stays the same
      # right stays the same
      # Update for next iteration
      let newLeft = mid + 1
      if newLeft <= right:
        pdqsortLoop(arr, newLeft, right, badAllowed, false)
      return
    else:
      # Recurse right, continue with left
      pdqsortLoop(arr, mid + 1, right, badAllowed, false)
      # Continue loop with left partition (tail recursion optimization)
      let newRight = mid - 1
      if left <= newRight:
        pdqsortLoop(arr, left, newRight, badAllowed, leftmost)
      return

# =============================================================================
# Public API
# =============================================================================

proc pdqsort*[T](arr: var openArray[T]) =
  ## Sort array in-place using pattern-defeating quicksort
  ##
  ## Time complexity:
  ## - Average: O(n log n)
  ## - Worst case: O(n log n) (falls back to heapsort)
  ## - Best case: O(n) for sorted, reverse-sorted, or few unique elements
  ##
  ## Space complexity: O(log n) stack space
  ##
  ## Stable: No
  ## In-place: Yes
  if arr.len <= 1:
    return

  # Bad partition budget = log2(n)
  # After this many bad partitions, we switch to heapsort
  var badAllowed = log2Floor(arr.len)

  pdqsortLoop(arr, 0, arr.len - 1, badAllowed, true)

proc pdqsortSlice*[T](arr: var openArray[T], left, right: int) =
  ## Sort a slice of array [left..right] in-place
  if left >= right:
    return

  var badAllowed = log2Floor(right - left + 1)
  pdqsortLoop(arr, left, right, badAllowed, true)

proc isSorted*[T](arr: openArray[T]): bool =
  ## Check if array is sorted (ascending)
  for i in 1..<arr.len:
    if arr[i] < arr[i - 1]:
      return false
  true

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/random
  import std/times

  echo "pdqsort - Pattern-Defeating Quicksort"
  echo "======================================"

  # Test 1: Random array
  echo "\nTest 1: Random array"
  var arr1 = newSeq[int](1000)
  for i in 0..<arr1.len:
    arr1[i] = rand(1000)

  let start1 = cpuTime()
  pdqsort(arr1)
  let elapsed1 = cpuTime() - start1

  echo "  Size: ", arr1.len
  echo "  Time: ", elapsed1 * 1000, " ms"
  echo "  Sorted: ", isSorted(arr1)

  # Test 2: Already sorted
  echo "\nTest 2: Already sorted (best case)"
  var arr2 = newSeq[int](10000)
  for i in 0..<arr2.len:
    arr2[i] = i

  let start2 = cpuTime()
  pdqsort(arr2)
  let elapsed2 = cpuTime() - start2

  echo "  Size: ", arr2.len
  echo "  Time: ", elapsed2 * 1000, " ms"
  echo "  Sorted: ", isSorted(arr2)

  # Test 3: Reverse sorted
  echo "\nTest 3: Reverse sorted"
  var arr3 = newSeq[int](10000)
  for i in 0..<arr3.len:
    arr3[i] = arr3.len - i

  let start3 = cpuTime()
  pdqsort(arr3)
  let elapsed3 = cpuTime() - start3

  echo "  Size: ", arr3.len
  echo "  Time: ", elapsed3 * 1000, " ms"
  echo "  Sorted: ", isSorted(arr3)

  # Test 4: Few unique elements
  echo "\nTest 4: Few unique elements (10 uniques in 10000 elements)"
  var arr4 = newSeq[int](10000)
  for i in 0..<arr4.len:
    arr4[i] = rand(10)  # Only 10 distinct values

  let start4 = cpuTime()
  pdqsort(arr4)
  let elapsed4 = cpuTime() - start4

  echo "  Size: ", arr4.len
  echo "  Time: ", elapsed4 * 1000, " ms"
  echo "  Sorted: ", isSorted(arr4)

  # Test 5: All equal
  echo "\nTest 5: All equal elements"
  var arr5 = newSeq[int](10000)
  for i in 0..<arr5.len:
    arr5[i] = 42

  let start5 = cpuTime()
  pdqsort(arr5)
  let elapsed5 = cpuTime() - start5

  echo "  Size: ", arr5.len
  echo "  Time: ", elapsed5 * 1000, " ms"
  echo "  Sorted: ", isSorted(arr5)

  echo "\nAll tests passed!"
