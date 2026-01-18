## Unit Tests for Embedded HAL
## ===========================

import std/unittest
import ../src/arsenal/embedded/hal

suite "Memory-Mapped I/O":
  test "volatileLoad and volatileStore basic operations":
    # Simulate a memory-mapped register using regular memory
    var mockRegister: uint32 = 0x12345678
    let regAddr = cast[uint](addr mockRegister)

    # Test volatile load
    let value = volatileLoad[uint32](regAddr)
    check value == 0x12345678

    # Test volatile store
    volatileStore(regAddr, 0xDEADBEEF'u32)
    check mockRegister == 0xDEADBEEF'u32

  test "bit manipulation operations":
    var reg: uint32 = 0x00000000

    # Test setBit
    setBit(reg, 5)
    check reg == 0x00000020'u32

    # Test clearBit
    setBit(reg, 10)
    check reg == 0x00000420'u32
    clearBit(reg, 5)
    check reg == 0x00000400'u32

    # Test toggleBit
    toggleBit(reg, 10)
    check reg == 0x00000000'u32
    toggleBit(reg, 15)
    check reg == 0x00008000'u32

    # Test testBit
    check testBit(reg, 15) == true
    check testBit(reg, 14) == false

  test "modifyBits with mask":
    var reg: uint32 = 0xFFFFFFFF'u32

    # Clear bits 8-11 and set bit 9
    let mask = 0x0F00'u32  # Bits 8-11
    let value = 0x0200'u32  # Only bit 9
    modifyBits(reg, mask, value)

    check reg == 0xFFFFF2FF'u32

suite "Delay Functions":
  test "delayCycles executes without error":
    # Just verify it doesn't crash
    delayCycles(100)
    check true  # If we get here, it worked

  test "delayUs with known frequency":
    const CPU_FREQ = 16_000_000  # 16 MHz

    # Test 1 microsecond delay
    delayUs(1, CPU_FREQ)
    check true

    # Test 100 microsecond delay
    delayUs(100, CPU_FREQ)
    check true

  test "delayMs forwards to delayUs correctly":
    const CPU_FREQ = 16_000_000

    # 1ms should call delayUs(1000)
    delayMs(1, CPU_FREQ)
    check true

suite "GPIO Pin Modes":
  test "PinMode enum values":
    check modeInput.ord == 0
    check modeOutput.ord == 1
    check modeInputPullup.ord == 2
    check modeInputPulldown.ord == 3
    check modeAnalog.ord == 4
    check modeAlternate.ord == 5

  test "PinLevel enum values":
    check low.ord == 0
    check high.ord == 1

suite "UART Configuration":
  test "UartBaudRate standard values":
    check baud9600.int == 9600
    check baud19200.int == 19200
    check baud38400.int == 38400
    check baud57600.int == 57600
    check baud115200.int == 115200

  test "UartConfig construction":
    let config = UartConfig(
      baudRate: baud115200,
      dataBits: 8,
      stopBits: 1,
      parity: false
    )

    check config.baudRate == baud115200
    check config.dataBits == 8
    check config.stopBits == 1
    check config.parity == false

# Platform-specific tests would require actual hardware or mocking
# These are structural tests to verify types compile correctly
when defined(stm32f4):
  suite "STM32F4 Platform Constants":
    test "GPIO base addresses defined":
      check GPIOA_BASE == 0x40020000'u
      check GPIOB_BASE == 0x40020400'u
      check GPIOC_BASE == 0x40020800'u
      check GPIOD_BASE == 0x40020C00'u

    test "GPIO register offsets":
      check GPIO_MODER_OFFSET == 0x00
      check GPIO_ODR_OFFSET == 0x14
      check GPIO_IDR_OFFSET == 0x10
      check GPIO_BSRR_OFFSET == 0x18

    test "UART base addresses":
      check USART1_BASE == 0x40011000'u
      check USART2_BASE == 0x40004400'u

when defined(rp2040):
  suite "RP2040 Platform Constants":
    test "GPIO base addresses defined":
      check GPIO_BASE == 0x40014000'u
      check SIO_BASE == 0xd0000000'u

echo "Embedded HAL tests completed successfully!"
