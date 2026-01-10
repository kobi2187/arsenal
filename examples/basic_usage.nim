# Example: Basic Arsenal Usage
# =============================
#
# This example demonstrates basic usage of Arsenal's platform detection
# and optimization strategies.

import arsenal

echo "Arsenal Basic Example"
echo "===================="

# Detect CPU features
let cpu = detectCpuFeatures()
echo "CPU Vendor: ", cpu.vendor
echo "Brand: ", cpu.brandString
echo "Has AVX2: ", cpu.hasAVX2
echo "Has NEON: ", cpu.hasNEON
echo ""

# Demonstrate strategies
echo "Current strategy: ", getStrategy()
echo "Default buffer size: ", getConfig().defaultBufferSize

withStrategy(Throughput):
  echo "With Throughput strategy, buffer size: ", getConfig().defaultBufferSize

echo "Back to default, buffer size: ", getConfig().defaultBufferSize