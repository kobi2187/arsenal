#!/usr/bin/env nim
## Test Runner for Arsenal
## =======================
##
## Runs all unit tests for the Arsenal library.
##
## Usage:
##   nim c -r tests/test_all.nim
##   nimble test

import std/unittest
import std/os

# Import all test modules
include test_config
include test_strategies

# Platform tests (when implemented)
# when defined(amd64) or defined(i386):
#   include test_bits

# Concurrency tests (when implemented)
# include test_atomics
# include test_spinlock
# include test_spsc_queue
# include test_mpmc_queue
# include test_coroutines
# include test_channels
# include test_select

# Memory tests (when implemented)
# include test_allocator

# Hashing tests (when implemented)
# include test_hasher

# Tests are run automatically by unittest when isMainModule