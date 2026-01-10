## Tests for CPU Feature Detection
## ================================

import std/unittest
import ../src/arsenal/platform/config

suite "CPU Feature Detection":

  test "detectCpuFeatures returns CpuFeatures object":
    let features = detectCpuFeatures()
    # Note: Currently returns defaults, full implementation pending
    check features.vendor == cvUnknown  # Stub implementation
    check features.brandString.len == 0  # Stub implementation

  test "x86 features are detected correctly":
    when defined(amd64) or defined(i386):
      let features = detectCpuFeatures()
      # SSE2 is baseline for x86_64
      when defined(amd64):
        check features.hasSSE2
      # These might not be present on all CPUs
      discard features.hasAVX2  # Just access to ensure no crash

  test "ARM features are detected correctly":
    when defined(arm64):
      let features = detectCpuFeatures()
      # NEON is baseline for ARM64
      check features.hasNEON

  test "detectCpuFeatures is idempotent":
    let f1 = detectCpuFeatures()
    let f2 = detectCpuFeatures()
    check f1.vendor == f2.vendor
    check f1.brandString == f2.brandString