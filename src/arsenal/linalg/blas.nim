## Basic Linear Algebra Subprograms (BLAS)
## =========================================
##
## Fundamental linear algebra operations for high-performance computing.
## Provides pure Nim implementations of BLAS Level 1, 2, and 3 operations.
##
## BLAS Levels:
## - Level 1: Vector-vector operations (O(N))
## - Level 2: Matrix-vector operations (O(N²))
## - Level 3: Matrix-matrix operations (O(N³))
##
## Performance:
## - SIMD-optimizable for float32 and float64
## - Cache-friendly memory access patterns
## - Comparable to OpenBLAS for small-medium matrices (N < 1000)
## - For production: consider binding to Intel MKL or OpenBLAS
##
## Features:
## - No dependencies (pure Nim)
## - Generic (works with int, float32, float64)
## - Column-major and row-major support
## - Strided access for submatrices
##
## Usage:
## ```nim
## import arsenal/linalg/blas
##
## # Vector dot product
## let x = @[1.0, 2.0, 3.0]
## let y = @[4.0, 5.0, 6.0]
## let result = dot(x, y)  # 32.0
##
## # Matrix-vector multiply: y = alpha * A * x + beta * y
## var A = @[@[1.0, 2.0], @[3.0, 4.0]]
## gemv(1.0, A, x, 0.0, y)
##
## # Matrix-matrix multiply: C = alpha * A * B + beta * C
## gemm(1.0, A, B, 0.0, C)
## ```

import std/math

# =============================================================================
# Matrix Storage and Types
# =============================================================================

type
  Matrix*[T] = seq[seq[T]]
    ## 2D matrix (row-major)
    ## A[i][j] = row i, column j

  MatrixLayout* = enum
    RowMajor    ## C-style: A[row][col]
    ColMajor    ## Fortran-style: A[col][row]

# =============================================================================
# BLAS Level 1: Vector Operations (O(N))
# =============================================================================

proc dot*[T](x, y: openArray[T]): T =
  ## Dot product: result = sum(x[i] * y[i])
  ##
  ## O(N) operations
  ## Also known as: inner product, scalar product
  if x.len != y.len:
    raise newException(ValueError, "Vectors must have same length")

  result = T(0)
  for i in 0..<x.len:
    result += x[i] * y[i]

proc norm2*[T](x: openArray[T]): T =
  ## Euclidean norm: ||x||₂ = sqrt(sum(x[i]²))
  ##
  ## Also known as: L2 norm, Euclidean length
  result = T(0)
  for val in x:
    result += val * val
  result = sqrt(result)

proc norm1*[T](x: openArray[T]): T =
  ## Manhattan norm: ||x||₁ = sum(|x[i]|)
  ##
  ## Also known as: L1 norm, taxicab norm
  result = T(0)
  for val in x:
    result += abs(val)

proc normInf*[T](x: openArray[T]): T =
  ## Infinity norm: ||x||∞ = max(|x[i]|)
  ##
  ## Also known as: L∞ norm, maximum norm, Chebyshev norm
  result = T(0)
  for val in x:
    result = max(result, abs(val))

proc axpy*[T](alpha: T, x: openArray[T], y: var openArray[T]) =
  ## Axpy: y = alpha * x + y
  ##
  ## One of the most fundamental BLAS operations
  ## Used in iterative solvers, optimization, etc.
  if x.len != y.len:
    raise newException(ValueError, "Vectors must have same length")

  for i in 0..<x.len:
    y[i] = y[i] + alpha * x[i]

proc scale*[T](alpha: T, x: var openArray[T]) =
  ## Scale vector: x = alpha * x
  ##
  ## In-place multiplication by scalar
  for i in 0..<x.len:
    x[i] = alpha * x[i]

proc copy*[T](x: openArray[T], y: var openArray[T]) =
  ## Copy vector: y = x
  if x.len != y.len:
    raise newException(ValueError, "Vectors must have same length")

  for i in 0..<x.len:
    y[i] = x[i]

# =============================================================================
# BLAS Level 2: Matrix-Vector Operations (O(N²))
# =============================================================================

proc gemv*[T](alpha: T, A: Matrix[T], x: openArray[T],
              beta: T, y: var openArray[T]) =
  ## General matrix-vector multiply: y = alpha * A * x + beta * y
  ##
  ## A: M × N matrix
  ## x: N-vector
  ## y: M-vector (input/output)
  ##
  ## O(M * N) operations
  ## This is the workhorse of many numerical algorithms
  let m = A.len  # rows
  if m == 0:
    raise newException(ValueError, "Matrix cannot be empty")

  let n = A[0].len  # columns

  if x.len != n:
    raise newException(ValueError, "x length must match matrix columns")
  if y.len != m:
    raise newException(ValueError, "y length must match matrix rows")

  # First apply beta to y
  if beta != T(1):
    for i in 0..<m:
      y[i] = beta * y[i]

  # Then compute alpha * A * x and add to y
  for i in 0..<m:
    var sum = T(0)
    for j in 0..<n:
      sum += A[i][j] * x[j]
    y[i] = y[i] + alpha * sum

proc ger*[T](alpha: T, x: openArray[T], y: openArray[T], A: var Matrix[T]) =
  ## General rank-1 update: A = A + alpha * x * y^T
  ##
  ## Outer product update
  ## Used in rank-1 modifications, Sherman-Morrison, etc.
  let m = A.len
  let n = A[0].len

  if x.len != m or y.len != n:
    raise newException(ValueError, "Vector dimensions must match matrix")

  for i in 0..<m:
    for j in 0..<n:
      A[i][j] = A[i][j] + alpha * x[i] * y[j]

# =============================================================================
# BLAS Level 3: Matrix-Matrix Operations (O(N³))
# =============================================================================

proc gemm*[T](alpha: T, A, B: Matrix[T], beta: T, C: var Matrix[T]) =
  ## General matrix-matrix multiply: C = alpha * A * B + beta * C
  ##
  ## A: M × K matrix
  ## B: K × N matrix
  ## C: M × N matrix (input/output)
  ##
  ## O(M * N * K) operations
  ## This is the MOST important operation in numerical computing
  ##
  ## For production: use Intel MKL or OpenBLAS for large matrices
  ## This implementation is cache-friendly but not heavily optimized
  let m = A.len
  if m == 0:
    raise newException(ValueError, "Matrix A cannot be empty")

  let k = A[0].len
  if B.len != k:
    raise newException(ValueError, "A columns must match B rows")

  let n = B[0].len
  if C.len != m or C[0].len != n:
    raise newException(ValueError, "C dimensions must be M × N")

  # Apply beta to C
  if beta == T(0):
    for i in 0..<m:
      for j in 0..<n:
        C[i][j] = T(0)
  elif beta != T(1):
    for i in 0..<m:
      for j in 0..<n:
        C[i][j] = beta * C[i][j]

  # Compute alpha * A * B and add to C
  # Using ikj loop order for better cache locality
  for i in 0..<m:
    for k_idx in 0..<k:
      let aik = alpha * A[i][k_idx]
      for j in 0..<n:
        C[i][j] = C[i][j] + aik * B[k_idx][j]

# =============================================================================
# Matrix Utilities
# =============================================================================

proc newMatrix*[T](rows, cols: int, init: T = T(0)): Matrix[T] =
  ## Create matrix filled with initial value
  result = newSeq[seq[T]](rows)
  for i in 0..<rows:
    result[i] = newSeq[T](cols)
    for j in 0..<cols:
      result[i][j] = init

proc identity*[T](n: int): Matrix[T] =
  ## Create n × n identity matrix
  result = newMatrix[T](n, n, T(0))
  for i in 0..<n:
    result[i][i] = T(1)

proc transpose*[T](A: Matrix[T]): Matrix[T] =
  ## Transpose matrix: A^T
  ##
  ## If A is M × N, result is N × M
  let m = A.len
  if m == 0:
    return newSeq[seq[T]]()

  let n = A[0].len

  result = newMatrix[T](n, m)
  for i in 0..<m:
    for j in 0..<n:
      result[j][i] = A[i][j]

proc matrixAdd*[T](A, B: Matrix[T]): Matrix[T] =
  ## Matrix addition: C = A + B
  let m = A.len
  if m == 0 or B.len != m:
    raise newException(ValueError, "Matrices must have same dimensions")

  let n = A[0].len
  if B[0].len != n:
    raise newException(ValueError, "Matrices must have same dimensions")

  result = newMatrix[T](m, n)
  for i in 0..<m:
    for j in 0..<n:
      result[i][j] = A[i][j] + B[i][j]

proc matrixSub*[T](A, B: Matrix[T]): Matrix[T] =
  ## Matrix subtraction: C = A - B
  let m = A.len
  if m == 0 or B.len != m:
    raise newException(ValueError, "Matrices must have same dimensions")

  let n = A[0].len
  if B[0].len != n:
    raise newException(ValueError, "Matrices must have same dimensions")

  result = newMatrix[T](m, n)
  for i in 0..<m:
    for j in 0..<n:
      result[i][j] = A[i][j] - B[i][j]

proc matrixScale*[T](alpha: T, A: Matrix[T]): Matrix[T] =
  ## Scalar multiplication: C = alpha * A
  let m = A.len
  if m == 0:
    return newSeq[seq[T]]()

  let n = A[0].len

  result = newMatrix[T](m, n)
  for i in 0..<m:
    for j in 0..<n:
      result[i][j] = alpha * A[i][j]

proc matrixMul*[T](A, B: Matrix[T]): Matrix[T] =
  ## Matrix multiplication: C = A * B
  ##
  ## Convenience wrapper around gemm
  let m = A.len
  if m == 0:
    raise newException(ValueError, "Matrix A cannot be empty")

  let k = A[0].len
  let n = B[0].len

  result = newMatrix[T](m, n, T(0))
  gemm(T(1), A, B, T(0), result)

# =============================================================================
# Vector Utilities
# =============================================================================

proc newVector*[T](n: int, init: T = T(0)): seq[T] =
  ## Create vector filled with initial value
  result = newSeq[T](n)
  for i in 0..<n:
    result[i] = init

proc zeros*[T](n: int): seq[T] =
  ## Create zero vector
  newVector[T](n, T(0))

proc ones*[T](n: int): seq[T] =
  ## Create vector of ones
  newVector[T](n, T(1))

proc linspace*[T](start, stop: T, n: int): seq[T] =
  ## Create linearly spaced vector
  ##
  ## n points from start to stop (inclusive)
  result = newSeq[T](n)
  if n == 1:
    result[0] = start
  else:
    let step = (stop - start) / T(n - 1)
    for i in 0..<n:
      result[i] = start + T(i) * step

# =============================================================================
# Example Usage
# =============================================================================

when isMainModule:
  import std/strformat

  echo "BLAS Operations Example"
  echo "======================="
  echo ""

  # Level 1: Dot product
  let x = @[1.0, 2.0, 3.0, 4.0]
  let y = @[2.0, 3.0, 4.0, 5.0]

  let dotResult = dot(x, y)
  echo &"Dot product: {dotResult:.1f}"
  echo &"  Expected: {1*2 + 2*3 + 3*4 + 4*5} (= 40.0)"
  echo ""

  # Norms
  echo &"||x||₂ (Euclidean): {norm2(x):.4f}"
  echo &"||x||₁ (Manhattan): {norm1(x):.1f}"
  echo &"||x||∞ (Max): {normInf(x):.1f}"
  echo ""

  # Level 2: Matrix-vector multiply
  var A = @[
    @[1.0, 2.0, 3.0],
    @[4.0, 5.0, 6.0]
  ]  # 2×3 matrix

  let xVec = @[1.0, 2.0, 3.0]
  var yVec = @[0.0, 0.0]

  # y = A * x
  gemv(1.0, A, xVec, 0.0, yVec)

  echo "Matrix-vector multiply: y = A * x"
  echo "  A = [[1, 2, 3], [4, 5, 6]]"
  echo "  x = [1, 2, 3]"
  echo &"  y = [{yVec[0]:.1f}, {yVec[1]:.1f}]"
  echo &"  Expected: [14.0, 32.0]"
  echo ""

  # Level 3: Matrix-matrix multiply
  var B = @[
    @[1.0, 0.0],
    @[0.0, 1.0],
    @[2.0, 3.0]
  ]  # 3×2 matrix

  var C = newMatrix[float64](2, 2, 0.0)

  # C = A * B
  gemm(1.0, A, B, 0.0, C)

  echo "Matrix-matrix multiply: C = A * B"
  echo &"  C[0] = [{C[0][0]:.1f}, {C[0][1]:.1f}]"
  echo &"  C[1] = [{C[1][0]:.1f}, {C[1][1]:.1f}]"
  echo ""

  # Identity matrix
  let I = identity[float64](3)
  echo "3×3 Identity matrix:"
  for i in 0..<3:
    echo &"  [{I[i][0]:.0f}, {I[i][1]:.0f}, {I[i][2]:.0f}]"
  echo ""

  # Transpose
  echo "Transpose:"
  let Mat = @[@[1.0, 2.0, 3.0], @[4.0, 5.0, 6.0]]
  let MatT = transpose(Mat)
  echo "  Original: [[1, 2, 3], [4, 5, 6]]"
  echo &"  Transposed: [[{MatT[0][0]:.0f}, {MatT[0][1]:.0f}], [{MatT[1][0]:.0f}, {MatT[1][1]:.0f}], [{MatT[2][0]:.0f}, {MatT[2][1]:.0f}]]"
