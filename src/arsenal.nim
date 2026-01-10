## Arsenal - Universal Low-Level Nim Library
## ==========================================
##
## Arsenal provides atomic, composable, swappable primitives for
## high-performance systems programming in Nim.
##
## Core Modules:
## - `arsenal/platform` - CPU detection, platform constants
## - `arsenal/concurrency` - Coroutines, channels, lock-free structures
## - `arsenal/memory` - Allocators, SIMD memory ops
## - `arsenal/hashing` - High-performance hash functions
## - `arsenal/datastructures` - Swiss Tables, filters, etc.
##
## Design Pattern:
## Every module provides both unsafe primitives (maximum control)
## and safe wrappers (bounds-checked, tracked, idiomatic).

import arsenal/platform/config
import arsenal/platform/strategies

export config, strategies
