## Benchmarks for Embedded HAL Operations
## ========================================

import std/[times, strformat, sugar, algorithm]
import ../src/arsenal/embedded/hal

# Benchmark configuration
const
  ITERATIONS = 1_000_000
  CPU_FREQ = 16_000_000  # 16 MHz (typical for embedded)

# Mock hardware addresses for benchmarking
var mockGpioReg: uint32 = 0
var mockUartReg: uint32 = 0
const MOCK_GPIO_ADDR = cast[uint](addr mockGpioReg)
const MOCK_UART_ADDR = cast[uint](addr mockUartReg)

proc benchmark(name: string, iterations: int, fn: proc()) =
  ## Run a benchmark and print results
  let start = cpuTime()
  for i in 0..<iterations:
    fn()
  let elapsed = cpuTime() - start

  let opsPerSec = float(iterations) / elapsed
  let nsPerOp = (elapsed * 1_000_000_000.0) / float(iterations)

  echo &"{name:40} {opsPerSec:15.0f} ops/sec  {nsPerOp:8.2f} ns/op"

echo "Embedded HAL Benchmarks"
echo "======================="
echo ""

# Volatile MMIO Benchmarks
echo "Memory-Mapped I/O:"
echo "------------------"

benchmark "volatileLoad[uint32]", ITERATIONS:
  discard volatileLoad[uint32](MOCK_GPIO_ADDR)

benchmark "volatileStore[uint32]", ITERATIONS:
  volatileStore(MOCK_GPIO_ADDR, 0xDEADBEEF'u32)

benchmark "volatileLoad + volatileStore", ITERATIONS:
  let val = volatileLoad[uint32](MOCK_GPIO_ADDR)
  volatileStore(MOCK_GPIO_ADDR, val or 1)

echo ""

# Bit Manipulation Benchmarks
echo "Bit Manipulation:"
echo "-----------------"

benchmark "setBit", ITERATIONS:
  var reg: uint32 = 0
  setBit(reg, 13)

benchmark "clearBit", ITERATIONS:
  var reg: uint32 = 0xFFFFFFFF'u32
  clearBit(reg, 13)

benchmark "toggleBit", ITERATIONS:
  var reg: uint32 = 0
  toggleBit(reg, 13)

benchmark "testBit", ITERATIONS:
  var reg: uint32 = 0x2000
  discard testBit(reg, 13)

echo ""

# GPIO Benchmarks (simulated)
when defined(stm32f4) or not defined(bare_metal):
  echo "GPIO Operations (STM32F4):"
  echo "--------------------------"

  let gpio = GpioPort(base: GPIOA_BASE)

  benchmark "GPIO write (high)", ITERATIONS:
    gpio.write(13, high)

  benchmark "GPIO write (low)", ITERATIONS:
    gpio.write(13, low)

  benchmark "GPIO toggle", ITERATIONS:
    gpio.toggle(13)

  benchmark "GPIO read", ITERATIONS:
    discard gpio.read(13)

  echo ""

# Delay Benchmarks
echo "Timing Functions:"
echo "-----------------"

benchmark "delayCycles(10)", 100_000:
  delayCycles(10)

benchmark "delayCycles(100)", 10_000:
  delayCycles(100)

benchmark "delayUs(1, CPU_FREQ)", 10_000:
  delayUs(1, CPU_FREQ)

benchmark "delayUs(10, CPU_FREQ)", 1_000:
  delayUs(10, CPU_FREQ)

benchmark "delayMs(1, CPU_FREQ)", 100:
  delayMs(1, CPU_FREQ)

echo ""

# UART Benchmarks (simulated)
when defined(stm32f4) or not defined(bare_metal):
  echo "UART Operations (STM32F4):"
  echo "--------------------------"

  let uart = Uart(base: USART1_BASE)

  # Note: These benchmarks measure the overhead of the functions,
  # not actual UART transmission which is hardware-limited

  benchmark "UART available() check", ITERATIONS:
    discard uart.available()

  echo ""

echo "Performance Summary"
echo "==================="
echo ""
echo "Target Platform: Embedded (simulated)"
echo &"CPU Frequency: {CPU_FREQ} Hz"
echo ""
echo "Expected Performance on Real Hardware:"
echo "- volatileLoad/Store: 1-2 CPU cycles"
echo "- GPIO write (atomic): 1-2 CPU cycles"
echo "- GPIO read: 2-3 CPU cycles"
echo "- GPIO toggle: 1-4 CPU cycles (platform dependent)"
echo "- Bit operations: 1 CPU cycle (inline)"
echo ""
echo "Note: Benchmark numbers above are for simulation overhead."
echo "Real hardware performance will be limited by bus speeds and"
echo "peripheral clock frequencies."
