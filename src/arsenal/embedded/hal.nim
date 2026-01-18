## Hardware Abstraction Layer
## ===========================
##
## Low-level hardware access via Memory-Mapped I/O (MMIO).
## Provides safe abstractions for:
## - GPIO (General Purpose I/O)
## - Timers
## - UART (Serial)
## - SPI/I2C
##
## Designed for bare metal programming on microcontrollers.
##
## Usage:
## ```nim
## import arsenal/embedded/hal
##
## # Configure GPIO pin
## const LED_PIN = 13
## gpio.setMode(LED_PIN, modeOutput)
##
## # Blink LED
## while true:
##   gpio.write(LED_PIN, high)
##   delay(500)
##   gpio.write(LED_PIN, low)
##   delay(500)
## ```

import ../platform/config

# =============================================================================
# Memory-Mapped I/O Utilities
# =============================================================================

template volatileLoad*[T](address: uint): T =
  ## Read from memory-mapped register (volatile).
  ## Prevents compiler from caching or optimizing away the read.
  ##
  ## TECHNICAL NOTES:
  ## - C 'volatile' keyword forces actual memory access
  ## - Compiler cannot cache or reorder volatile accesses
  ## - Critical for MMIO where hardware may change values
  ## - Each read goes to hardware, not cached copy
  ##
  ## USAGE:
  ## ```nim
  ## let status = volatileLoad[uint32](UART_SR_REG)
  ## if (status and UART_RXNE) != 0:
  ##   let data = volatileLoad[uint32](UART_DR_REG)
  ## ```
  ##
  ## PERFORMANCE:
  ## - Direct memory access, no overhead
  ## - Same cost as C volatile read
  ## - Inlined completely

  {.emit: """
  `result` = *(volatile `T`*)(`address`);
  """.}

template volatileStore*[T](address: uint, value: T) =
  ## Write to memory-mapped register (volatile).
  ##
  ## TECHNICAL NOTES:
  ## - Ensures write reaches hardware immediately
  ## - Compiler cannot delay or coalesce writes
  ## - Write ordering preserved vs other volatile accesses
  ## - May need memory barrier for DMA/multi-core
  ##
  ## USAGE:
  ## ```nim
  ## volatileStore(GPIO_BSRR, 1'u32 shl pinNumber)  # Atomic bit set
  ## ```
  ##
  ## MEMORY BARRIERS:
  ## - For ARM Cortex-M, volatile is usually sufficient
  ## - For multi-core or DMA, add explicit barrier:
  ##   ```nim
  ##   volatileStore(reg, value)
  ##   {.emit: "asm volatile(\"dsb\" ::: \"memory\");".}  # Data synchronization barrier
  ##   ```

  {.emit: """
  *(volatile `T`*)(`address`) = `value`;
  """.}

proc setBit*(reg: var uint32, bit: int) {.inline.} =
  ## Set bit in register (read-modify-write).
  reg = reg or (1'u32 shl bit)

proc clearBit*(reg: var uint32, bit: int) {.inline.} =
  ## Clear bit in register.
  reg = reg and not (1'u32 shl bit)

proc toggleBit*(reg: var uint32, bit: int) {.inline.} =
  ## Toggle bit in register.
  reg = reg xor (1'u32 shl bit)

proc testBit*(reg: uint32, bit: int): bool {.inline.} =
  ## Test if bit is set.
  (reg and (1'u32 shl bit)) != 0

proc modifyBits*(reg: var uint32, mask: uint32, value: uint32) {.inline.} =
  ## Modify bits using mask.
  ## IMPLEMENTATION:
  ## ```nim
  ## reg = (reg and not mask) or (value and mask)
  ## ```
  reg = (reg and not mask) or (value and mask)

# =============================================================================
# GPIO (General Purpose I/O)
# =============================================================================

type
  PinMode* = enum
    ## GPIO pin modes.
    modeInput         ## Input (high impedance)
    modeOutput        ## Output (push-pull)
    modeInputPullup   ## Input with pull-up resistor
    modeInputPulldown ## Input with pull-down resistor
    modeAnalog        ## Analog input (ADC)
    modeAlternate     ## Alternate function (UART, SPI, etc.)

  PinLevel* = enum
    ## Digital logic levels.
    low = 0
    high = 1

  GpioPort* = object
    ## GPIO port abstraction.
    ## Base address varies by hardware.
    base*: uint

# Platform-specific base addresses
when defined(stm32f4):
  # STM32F4 GPIO base addresses
  const
    GPIOA_BASE* = 0x40020000'u
    GPIOB_BASE* = 0x40020400'u
    GPIOC_BASE* = 0x40020800'u
    GPIOD_BASE* = 0x40020C00'u

  # GPIO register offsets (STM32)
  const
    GPIO_MODER_OFFSET* = 0x00    # Mode register
    GPIO_OTYPER_OFFSET* = 0x04   # Output type register
    GPIO_OSPEEDR_OFFSET* = 0x08  # Output speed register
    GPIO_PUPDR_OFFSET* = 0x0C    # Pull-up/pull-down register
    GPIO_IDR_OFFSET* = 0x10      # Input data register
    GPIO_ODR_OFFSET* = 0x14      # Output data register
    GPIO_BSRR_OFFSET* = 0x18     # Bit set/reset register
    GPIO_LCKR_OFFSET* = 0x1C     # Lock register
    GPIO_AFRL_OFFSET* = 0x20     # Alternate function low register
    GPIO_AFRH_OFFSET* = 0x24     # Alternate function high register

elif defined(rp2040):
  # Raspberry Pi Pico (RP2040) GPIO
  const
    GPIO_BASE* = 0x40014000'u
    SIO_BASE* = 0xd0000000'u

# =============================================================================
# GPIO Functions
# =============================================================================

proc setMode*(port: GpioPort, pin: int, mode: PinMode) =
  ## Configure GPIO pin mode.
  ##
  ## TECHNICAL NOTES:
  ## - STM32: Each pin = 2 bits in MODER register (4 modes)
  ## - Read-Modify-Write pattern for register updates
  ## - Must configure pull-up/down separately in PUPDR
  ## - Some modes require additional registers (OTYPER, OSPEEDR)
  ##
  ## IMPLEMENTATION (STM32):
  ## - MODER[1:0] for pin 0, MODER[3:2] for pin 1, etc.
  ## - 00 = Input, 01 = Output, 10 = Alternate, 11 = Analog
  ##
  ## ATOMICITY:
  ## - GPIO config is NOT atomic - disable interrupts if needed
  ## - Or use bit-banding for Cortex-M3/M4
  ##
  ## PERFORMANCE:
  ## - ~10 CPU cycles per mode change
  ## - Volatile loads/stores prevent caching

  when defined(stm32f4):
    # Each pin uses 2 bits in MODER register
    let modeReg = port.base + GPIO_MODER_OFFSET
    let shift = pin * 2
    var moder = volatileLoad[uint32](modeReg)

    # Clear existing mode bits
    moder = moder and not (0b11'u32 shl shift)

    # Set new mode
    let modeVal = case mode
      of modeInput: 0b00'u32
      of modeOutput: 0b01'u32
      of modeAlternate: 0b10'u32
      of modeAnalog: 0b11'u32
      else: 0b00'u32  # Input pullup/pulldown handled below

    moder = moder or (modeVal shl shift)
    volatileStore(modeReg, moder)

    # Configure pull-up/pull-down if needed
    if mode in {modeInputPullup, modeInputPulldown}:
      let pupdrReg = port.base + GPIO_PUPDR_OFFSET
      var pupdr = volatileLoad[uint32](pupdrReg)
      pupdr = pupdr and not (0b11'u32 shl shift)
      let pullVal = if mode == modeInputPullup: 0b01'u32 else: 0b10'u32
      pupdr = pupdr or (pullVal shl shift)
      volatileStore(pupdrReg, pupdr)

  elif defined(rp2040):
    # RP2040: Function select via GPIO_CTRL register
    # TODO: Implement RP2040-specific configuration
    discard

  else:
    {.error: "GPIO setMode not implemented for this platform".}

proc write*(port: GpioPort, pin: int, level: PinLevel) =
  ## Write to GPIO pin.
  ##
  ## TECHNICAL NOTES:
  ## - STM32 BSRR: Bit Set/Reset Register provides ATOMIC writes
  ## - Lower 16 bits set pins, upper 16 bits reset pins
  ## - Write-only register, no read-modify-write needed
  ## - Single instruction, interrupt-safe, no race conditions
  ##
  ## PERFORMANCE:
  ## - 1 volatile store = 1 CPU cycle + bus latency
  ## - Much faster than read-modify-write on ODR
  ## - Atomic even without disabling interrupts
  ##
  ## ALTERNATIVES (other MCUs):
  ## - RP2040: Separate SET/CLR/XOR registers per GPIO bank
  ## - nRF52: OUT register with atomic set/clear aliases
  ##
  ## USAGE:
  ## ```nim
  ## const LED = 13
  ## port.write(LED, high)  # LED on
  ## port.write(LED, low)   # LED off
  ## ```

  when defined(stm32f4):
    let bsrrReg = port.base + GPIO_BSRR_OFFSET
    if level == high:
      # Set bit (BSx - lower 16 bits)
      volatileStore(bsrrReg, 1'u32 shl pin)
    else:
      # Reset bit (BRx - upper 16 bits)
      volatileStore(bsrrReg, 1'u32 shl (pin + 16))

  elif defined(rp2040):
    # RP2040 has separate SET/CLR registers
    if level == high:
      volatileStore(SIO_BASE + 0x14, 1'u32 shl pin)  # GPIO_OUT_SET
    else:
      volatileStore(SIO_BASE + 0x18, 1'u32 shl pin)  # GPIO_OUT_CLR

  else:
    {.error: "GPIO write not implemented for this platform".}

proc read*(port: GpioPort, pin: int): PinLevel =
  ## Read from GPIO pin.
  ##
  ## TECHNICAL NOTES:
  ## - Reads Input Data Register (IDR) for current pin state
  ## - Returns actual pin voltage, not output register value
  ## - Works for both input and output pins
  ## - For outputs, reads actual pin state (may differ from ODR if overdriven)
  ##
  ## ELECTRICAL:
  ## - Input threshold: typically 0.3*VDD (low) to 0.7*VDD (high)
  ## - Schmitt trigger prevents noise on slow edges
  ## - Pull-up/down resistors affect floating pins
  ##
  ## PERFORMANCE:
  ## - 1 volatile load + bit test = ~2-3 cycles
  ##
  ## DEBOUNCING:
  ## - Hardware: External RC filter or Schmitt trigger
  ## - Software: Read multiple times, check consistency
  ## ```nim
  ## proc readDebounced(port: GpioPort, pin: int): PinLevel =
  ##   let s1 = port.read(pin)
  ##   delayUs(1)  # 1μs delay
  ##   let s2 = port.read(pin)
  ##   if s1 == s2: s1 else: readDebounced(port, pin)
  ## ```

  when defined(stm32f4):
    let idrReg = port.base + GPIO_IDR_OFFSET
    let idr = volatileLoad[uint32](idrReg)
    if testBit(idr, pin): high else: low

  elif defined(rp2040):
    let value = volatileLoad[uint32](SIO_BASE + 0x04)  # GPIO_IN
    if testBit(value, pin): high else: low

  else:
    {.error: "GPIO read not implemented for this platform".}

proc toggle*(port: GpioPort, pin: int) =
  ## Toggle GPIO pin.
  ##
  ## TECHNICAL NOTES:
  ## - Read current state and write opposite
  ## - Not atomic unless using hardware toggle register
  ## - Race condition possible with interrupts
  ##
  ## ATOMIC TOGGLE (platform-specific):
  ## - STM32: No dedicated toggle register, use read-modify-write
  ## - RP2040: Use GPIO_OUT_XOR register for atomic toggle
  ##
  ## PROTECTION:
  ## ```nim
  ## {.push checks: off.}  # Disable runtime checks for speed
  ## proc toggleFast(port: GpioPort, pin: int) =
  ##   # Disable interrupts for atomicity
  ##   {.emit: "uint32_t primask = __get_PRIMASK(); __disable_irq();".}
  ##   port.toggle(pin)
  ##   {.emit: "__set_PRIMASK(primask);".}  # Restore interrupt state
  ## {.pop.}
  ## ```

  when defined(stm32f4):
    # STM32: Read-modify-write (not atomic)
    let odrReg = port.base + GPIO_ODR_OFFSET
    var odr = volatileLoad[uint32](odrReg)
    toggleBit(odr, pin)
    volatileStore(odrReg, odr)

  elif defined(rp2040):
    # RP2040: Atomic toggle via XOR register
    volatileStore(SIO_BASE + 0x1C, 1'u32 shl pin)  # GPIO_OUT_XOR

  else:
    {.error: "GPIO toggle not implemented for this platform".}

# =============================================================================
# UART (Universal Asynchronous Receiver/Transmitter)
# =============================================================================

type
  UartBaudRate* = enum
    ## Standard baud rates.
    baud9600 = 9600
    baud19200 = 19200
    baud38400 = 38400
    baud57600 = 57600
    baud115200 = 115200

  UartConfig* = object
    ## UART configuration.
    baudRate*: UartBaudRate
    dataBits*: int     # 7, 8, 9
    stopBits*: int     # 1, 2
    parity*: bool

  Uart* = object
    ## UART peripheral.
    base*: uint

when defined(stm32f4):
  const
    USART1_BASE* = 0x40011000'u
    USART2_BASE* = 0x40004400'u

  # UART register offsets
  const
    USART_SR_OFFSET* = 0x00   # Status register
    USART_DR_OFFSET* = 0x04   # Data register
    USART_BRR_OFFSET* = 0x08  # Baud rate register
    USART_CR1_OFFSET* = 0x0C  # Control register 1

  # Status register bits
  const
    USART_SR_TXE* = (1 shl 7)   # Transmit data register empty
    USART_SR_RXNE* = (1 shl 5)  # Read data register not empty

proc init*(uart: Uart, config: UartConfig, clockFreq: uint32) =
  ## Initialize UART.
  ##
  ## TECHNICAL NOTES:
  ## - Baud Rate Register (BRR) calculation varies by MCU
  ## - STM32: BRR = APB_CLK / baudRate (assuming 16x oversampling)
  ## - Must enable peripheral clock first (RCC register)
  ## - Configure TX/RX pins as alternate function
  ##
  ## BAUD RATE ACCURACY:
  ## - Error = |actual - desired| / desired
  ## - Keep error < 2% for reliable communication
  ## - Use higher clock or different prescaler if needed
  ##
  ## CONFIGURATION STEPS:
  ## 1. Enable clock (RCC_APBxENR)
  ## 2. Configure GPIO pins (AF mode)
  ## 3. Set baud rate (BRR register)
  ## 4. Enable UART, TX, RX (CR1 register)
  ## 5. Optional: Configure data bits, stop bits, parity
  ##
  ## COMMON PITFALLS:
  ## - Forgetting to enable peripheral clock → registers stuck at 0
  ## - Wrong clock frequency → baud rate mismatch
  ## - Not configuring GPIO alternate function → no signal on pins

  when defined(stm32f4):
    # Calculate baud rate divisor
    # BRR = f_CK / (16 * baud_rate) for 16x oversampling
    let brr = clockFreq div config.baudRate.uint32
    volatileStore(uart.base + USART_BRR_OFFSET, brr)

    # Configure CR1: 8 data bits, no parity, enable UART
    var cr1: uint32 = 0
    cr1 = cr1 or (1'u32 shl 13)  # UE: UART enable
    cr1 = cr1 or (1'u32 shl 3)   # TE: Transmitter enable
    cr1 = cr1 or (1'u32 shl 2)   # RE: Receiver enable

    volatileStore(uart.base + USART_CR1_OFFSET, cr1)

  elif defined(rp2040):
    # RP2040: Different UART configuration
    # TODO: Implement RP2040 UART init
    discard

  else:
    {.error: "UART not implemented for this platform".}

proc write*(uart: Uart, c: char) =
  ## Write character to UART.
  ##
  ## TECHNICAL NOTES:
  ## - Blocking: waits for TX register empty (TXE bit)
  ## - Polling SR register for TXE flag
  ## - Writing to DR clears TXE automatically
  ##
  ## PERFORMANCE:
  ## - At 115200 baud: ~87 μs per character
  ## - Blocking: wastes CPU cycles while waiting
  ##
  ## NON-BLOCKING ALTERNATIVES:
  ## - Interrupt-driven: TX interrupt when TXE set
  ## - DMA: Fire-and-forget, no CPU involvement
  ##
  ## USAGE (printf-style):
  ## ```nim
  ## proc putc(c: char) = uart.write(c)
  ## proc print(s: string) =
  ##   for c in s:
  ##     putc(c)
  ## print("Hello, World!\n")
  ## ```

  when defined(stm32f4):
    # Wait for TX register empty
    while (volatileLoad[uint32](uart.base + USART_SR_OFFSET) and USART_SR_TXE) == 0:
      discard  # Busy wait (could yield in RTOS)

    # Write character to data register
    volatileStore(uart.base + USART_DR_OFFSET, c.uint32)

  else:
    {.error: "UART write not implemented for this platform".}

proc read*(uart: Uart): char =
  ## Read character from UART (blocking).
  ##
  ## TECHNICAL NOTES:
  ## - Blocks until data available (RXNE bit set)
  ## - Reading DR clears RXNE flag automatically
  ## - No timeout - will wait forever if no data
  ##
  ## ERROR HANDLING:
  ## - Check SR for framing error (FE), overrun (ORE), noise (NE)
  ## - Clear errors by reading SR then DR
  ##
  ## TIMEOUT VERSION:
  ## ```nim
  ## proc readTimeout*(uart: Uart, timeoutUs: uint32): Option[char] =
  ##   var elapsed = 0'u32
  ##   while not uart.available():
  ##     if elapsed >= timeoutUs:
  ##       return none(char)
  ##     delayUs(1)
  ##     inc elapsed
  ##   return some(uart.read())
  ## ```

  when defined(stm32f4):
    # Wait for RX not empty
    while (volatileLoad[uint32](uart.base + USART_SR_OFFSET) and USART_SR_RXNE) == 0:
      discard  # Busy wait

    # Read character from data register
    result = volatileLoad[uint32](uart.base + USART_DR_OFFSET).char

  else:
    {.error: "UART read not implemented for this platform".}

proc available*(uart: Uart): bool =
  ## Check if data is available to read.
  ##
  ## TECHNICAL NOTES:
  ## - Non-blocking: returns immediately
  ## - Checks RXNE flag in status register
  ## - Use for polling-style reception
  ##
  ## USAGE:
  ## ```nim
  ## while true:
  ##   if uart.available():
  ##     let c = uart.read()
  ##     processChar(c)
  ##   # Do other work...
  ## ```

  when defined(stm32f4):
    (volatileLoad[uint32](uart.base + USART_SR_OFFSET) and USART_SR_RXNE) != 0

  else:
    {.error: "UART available not implemented for this platform".}

# =============================================================================
# Timer
# =============================================================================

type
  HardwareTimer* = object
    ## Hardware timer peripheral.
    base*: uint

when defined(stm32f4):
  const
    TIM1_BASE* = 0x40010000'u
    TIM2_BASE* = 0x40000000'u

  # Timer register offsets
  const
    TIM_CR1_OFFSET* = 0x00   # Control register 1
    TIM_CNT_OFFSET* = 0x24   # Counter register
    TIM_PSC_OFFSET* = 0x28   # Prescaler register
    TIM_ARR_OFFSET* = 0x2C   # Auto-reload register

proc init*(timer: HardwareTimer, prescaler: uint16, period: uint32) =
  ## Initialize timer.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## volatileStore(timer.base + TIM_PSC_OFFSET, prescaler.uint32)
  ## volatileStore(timer.base + TIM_ARR_OFFSET, period)
  ## ```

  # Stub
  discard

proc start*(timer: HardwareTimer) =
  ## Start timer.
  ##
  ## IMPLEMENTATION:
  ## ```nim
  ## var cr1 = volatileLoad[uint32](timer.base + TIM_CR1_OFFSET)
  ## cr1 = cr1 or 1'u32  # CEN bit
  ## volatileStore(timer.base + TIM_CR1_OFFSET, cr1)
  ## ```

  # Stub
  discard

proc stop*(timer: HardwareTimer) =
  ## Stop timer.
  var cr1 = volatileLoad[uint32](timer.base + TIM_CR1_OFFSET)
  cr1 = cr1 and not 1'u32
  volatileStore(timer.base + TIM_CR1_OFFSET, cr1)

proc getCount*(timer: HardwareTimer): uint32 =
  ## Get current counter value.
  volatileLoad[uint32](timer.base + TIM_CNT_OFFSET)

# =============================================================================
# SPI (Serial Peripheral Interface)
# =============================================================================

type
  SpiMode* = enum
    ## SPI modes (CPOL, CPHA).
    spiMode0 = 0  # CPOL=0, CPHA=0
    spiMode1 = 1  # CPOL=0, CPHA=1
    spiMode2 = 2  # CPOL=1, CPHA=0
    spiMode3 = 3  # CPOL=1, CPHA=1

  Spi* = object
    base*: uint

proc init*(spi: Spi, mode: SpiMode, clockDiv: int) =
  ## Initialize SPI.
  ## IMPLEMENTATION: Configure SPI mode, clock divider, enable SPI

  # Stub
  discard

proc transfer*(spi: Spi, data: byte): byte =
  ## Transfer byte (full duplex).
  ## IMPLEMENTATION:
  ## 1. Write to data register
  ## 2. Wait for TX complete
  ## 3. Read from data register
  ## 4. Return received byte

  # Stub
  0

# =============================================================================
# Delay Functions
# =============================================================================

proc delayCycles*(cycles: uint32) =
  ## Delay for specified CPU cycles.
  ##
  ## TECHNICAL NOTES:
  ## - Busy-wait loop consuming CPU cycles
  ## - Timing depends on compiler optimization level
  ## - NOP instruction = 1 cycle on most ARMs
  ## - Volatile prevents loop optimization away
  ##
  ## ACCURACY:
  ## - Exact on simple cores (Cortex-M0/M0+)
  ## - Less accurate on complex cores (cache, pipeline, branch prediction)
  ## - For precise timing, use hardware timers instead
  ##
  ## USAGE:
  ## ```nim
  ## # Toggle pin at ~1 MHz (assuming 16 MHz CPU)
  ## while true:
  ##   gpio.write(pin, high)
  ##   delayCycles(8)  # 0.5 μs at 16 MHz
  ##   gpio.write(pin, low)
  ##   delayCycles(8)
  ## ```
  ##
  ## ALTERNATIVES:
  ## - DWT cycle counter (Cortex-M3+): More accurate
  ## - Hardware timer: Best accuracy, non-blocking

  when defined(arm):
    {.emit: """
    for (volatile uint32_t i = 0; i < `cycles`; i++) {
      asm volatile("nop");  // One NOP per cycle
    }
    """.}
  else:
    # Fallback for non-ARM platforms
    {.emit: """
    for (volatile uint32_t i = 0; i < `cycles`; i++) {
      // Busy wait
    }
    """.}

proc delayUs*(microseconds: uint32, cpuFreq: uint32) =
  ## Delay for microseconds.
  ## cpuFreq: CPU frequency in Hz
  ##
  ## TECHNICAL NOTES:
  ## - Converts microseconds to CPU cycles
  ## - Assumes linear relationship (no sleep modes)
  ## - Overhead: function call + multiplication (~10-20 cycles)
  ##
  ## ACCURACY:
  ## - ±5% typical for short delays (< 100 μs)
  ## - Better for longer delays
  ## - Hardware timer recommended for precision
  ##
  ## EXAMPLE CALCULATIONS:
  ## - 16 MHz CPU: 16 cycles/μs → delayUs(10) = 160 cycles
  ## - 72 MHz CPU: 72 cycles/μs → delayUs(10) = 720 cycles
  ##
  ## POWER CONSUMPTION:
  ## - Busy-wait: Maximum power (CPU active)
  ## - For power efficiency, use sleep mode + timer interrupt
  ##
  ## USAGE:
  ## ```nim
  ## const CPU_FREQ = 72_000_000  # 72 MHz
  ## delayUs(100, CPU_FREQ)  # 100 μs delay
  ## ```

  let cyclesPerUs = cpuFreq div 1_000_000
  let totalCycles = microseconds * cyclesPerUs

  # Account for function call overhead (approximate)
  let adjustedCycles = if totalCycles > 20: totalCycles - 20 else: 0

  delayCycles(adjustedCycles)

proc delayMs*(milliseconds: uint32, cpuFreq: uint32) =
  ## Delay for milliseconds.
  delayUs(milliseconds * 1000, cpuFreq)

# =============================================================================
# Notes
# =============================================================================

## IMPLEMENTATION NOTES:
##
## **Memory Barriers**:
## - Always use volatile for MMIO access
## - Add memory barriers after critical writes:
##   ```nim
##   volatileStore(reg, value)
##   {.emit: "asm volatile(\"\" ::: \"memory\");".}
##   ```
##
## **Clock Configuration**:
## - Must enable peripheral clocks before accessing registers
## - Example (STM32): Set RCC_APB1ENR bits
##
## **Interrupts**:
## - UART RX: Use interrupt + ring buffer
## - Timers: Configure NVIC interrupt vector
## - GPIO EXTI: External interrupt on pin change
##
## **DMA**:
## - Use DMA for high-throughput peripherals (UART, SPI)
## - Configure DMA channel, start transfer, wait for completion
##
## **Power Management**:
## - Disable unused peripherals to save power
## - Use low-power modes (sleep, stop, standby)
##
## **Hardware-Specific**:
## - This is a generic HAL - actual implementation depends on MCU
## - Supported platforms: STM32, RP2040, nRF52, ESP32, etc.
## - Each needs specific register addresses and bit layouts
