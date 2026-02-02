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

# Helper for check with custom message (for compatibility)
template check*(cond: bool, msg: string) =
  doAssert cond, msg

# Import all test modules
include test_config
include test_strategies
include test_allocators
include test_atomics
include test_audio_media
include test_bits
include test_channels
include test_coroutines
include test_channels_simple
include test_concurrency_ergonomic
include test_spinlock
include test_spsc
include test_simd
include test_fft
include test_fixed
include test_go_dsl
include test_hash_functions
include test_hashing
include test_io
include test_libaco
include test_minicoro
include test_mpmc
include test_new_algorithms
include test_nolibc
include test_random
include test_select
include test_swiss_table
# include test_embedded_hal