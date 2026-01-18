## Embedded UART Echo Server Example
## ===================================
##
## This example demonstrates serial communication using Arsenal's UART HAL.
## It creates a simple echo server that receives characters and sends them back.
##
## Features:
## - Serial communication at 115200 baud
## - Echo received characters
## - LED blink on received data
## - Welcome message on startup
##
## Target Platform: STM32F4
##
## Hardware Setup:
## - UART TX: PA9 (USART1_TX)
## - UART RX: PA10 (USART1_RX)
## - LED: PA13
## - Connect USB-Serial adapter to view output
##
## Compilation:
## ```bash
## nim c --cpu:arm --os:standalone --gc:none --noMain \
##   -d:stm32f4 -d:bare_metal --noLinking \
##   --passC:"-mcpu=cortex-m4 -mthumb -mfloat-abi=hard" \
##   embedded_uart_echo.nim
##
## arm-none-eabi-gcc -o firmware.elf embedded_uart_echo.o \
##   -T stm32f4.ld -nostdlib -lgcc
## ```

import ../src/arsenal/embedded/hal
import ../src/arsenal/embedded/nolibc

# Configuration
const
  CPU_CLOCK = 72_000_000  # 72 MHz system clock
  UART_BAUD = baud115200  # 115200 bits/sec
  LED_PIN = 13

# Helper function to print strings
proc printStr(uart: Uart, s: string) =
  ## Send a string over UART
  for c in s:
    uart.write(c)

proc printCStr(uart: Uart, s: cstring) =
  ## Send a C string over UART
  var i = 0
  while s[i] != '\0':
    uart.write(s[i])
    inc i

proc printInt(uart: Uart, value: int) =
  ## Send an integer as decimal string over UART
  var buffer: array[32, char]
  let len = intToStr(value.int64, addr buffer[0], 10)
  for i in 0..<len:
    uart.write(buffer[i])

proc printHex(uart: Uart, value: uint32) =
  ## Send a number as hexadecimal string over UART
  var buffer: array[32, char]
  let len = intToStr(value.int64, addr buffer[0], 16)
  uart.write('0')
  uart.write('x')
  for i in 0..<len:
    uart.write(buffer[i])

# Entry point
proc main() {.exportc: "_start", noreturn.} =
  ## Main entry point

  # Initialize LED
  let led = GpioPort(base: GPIOA_BASE)
  led.setMode(LED_PIN, modeOutput)
  led.write(LED_PIN, low)

  # Initialize UART
  let uart = Uart(base: USART1_BASE)
  uart.init(UartConfig(baudRate: UART_BAUD), CPU_CLOCK)

  # Send welcome message
  printStr(uart, "\r\n")
  printStr(uart, "=====================================\r\n")
  printStr(uart, "Arsenal UART Echo Server\r\n")
  printStr(uart, "=====================================\r\n")
  printStr(uart, "System: STM32F4\r\n")
  printStr(uart, "Clock: ")
  printInt(uart, CPU_CLOCK div 1_000_000)
  printStr(uart, " MHz\r\n")
  printStr(uart, "Baud: ")
  printInt(uart, 115200)
  printStr(uart, "\r\n")
  printStr(uart, "Ready. Type characters to echo...\r\n")
  printStr(uart, "\r\n")

  # Main loop
  var charCount: uint32 = 0

  while true:
    # Check if data available
    if uart.available():
      # Read character
      let c = uart.read()

      # Blink LED on receive
      led.write(LED_PIN, high)

      # Echo character
      uart.write(c)

      # Handle special characters
      if c == '\r':
        # Carriage return - add line feed
        uart.write('\n')

      # Increment counter
      inc charCount

      # Turn off LED after short delay
      delayCycles(100000)  # Brief flash
      led.write(LED_PIN, low)

# Advanced example with command processing
proc mainCommands() {.exportc: "_start_commands", noreturn.} =
  ## Advanced example with simple command processing

  let led = GpioPort(base: GPIOA_BASE)
  led.setMode(LED_PIN, modeOutput)
  led.write(LED_PIN, low)

  let uart = Uart(base: USART1_BASE)
  uart.init(UartConfig(baudRate: UART_BAUD), CPU_CLOCK)

  # Welcome
  printStr(uart, "\r\nArsenal Command Shell\r\n")
  printStr(uart, "Commands: help, led on, led off, led toggle, status\r\n")
  printStr(uart, "> ")

  # Command buffer
  var cmdBuffer: array[64, char]
  var cmdLen: int = 0
  var ledState = false
  var cmdCount: uint32 = 0

  while true:
    if uart.available():
      let c = uart.read()

      if c == '\r' or c == '\n':
        # Command complete
        uart.write('\r')
        uart.write('\n')

        if cmdLen > 0:
          # Null-terminate
          cmdBuffer[cmdLen] = '\0'

          # Process command
          let cmd = cast[cstring](addr cmdBuffer[0])

          if strcmp(cmd, "help".cstring) == 0:
            printStr(uart, "Available commands:\r\n")
            printStr(uart, "  help       - Show this help\r\n")
            printStr(uart, "  led on     - Turn LED on\r\n")
            printStr(uart, "  led off    - Turn LED off\r\n")
            printStr(uart, "  led toggle - Toggle LED\r\n")
            printStr(uart, "  status     - Show system status\r\n")

          elif strcmp(cmd, "led on".cstring) == 0:
            led.write(LED_PIN, high)
            ledState = true
            printStr(uart, "LED on\r\n")

          elif strcmp(cmd, "led off".cstring) == 0:
            led.write(LED_PIN, low)
            ledState = false
            printStr(uart, "LED off\r\n")

          elif strcmp(cmd, "led toggle".cstring) == 0:
            led.toggle(LED_PIN)
            ledState = not ledState
            printStr(uart, "LED toggled\r\n")

          elif strcmp(cmd, "status".cstring) == 0:
            printStr(uart, "System Status:\r\n")
            printStr(uart, "  CPU Clock: ")
            printInt(uart, CPU_CLOCK div 1_000_000)
            printStr(uart, " MHz\r\n")
            printStr(uart, "  LED State: ")
            printStr(uart, if ledState: "ON\r\n" else: "OFF\r\n")
            printStr(uart, "  Commands: ")
            printInt(uart, cmdCount.int)
            printStr(uart, "\r\n")

          else:
            printStr(uart, "Unknown command: ")
            printCStr(uart, cmd)
            printStr(uart, "\r\n")
            printStr(uart, "Type 'help' for available commands\r\n")

          inc cmdCount
          cmdLen = 0

        # Print prompt
        printStr(uart, "> ")

      elif c == '\b' or c == 127:  # Backspace or DEL
        if cmdLen > 0:
          dec cmdLen
          uart.write('\b')
          uart.write(' ')
          uart.write('\b')

      elif cmdLen < 63:
        # Add to buffer
        cmdBuffer[cmdLen] = c
        inc cmdLen
        uart.write(c)  # Echo

## Hardware Configuration
## ======================
##
## STM32F4 USART1 Pinout:
## - PA9:  USART1_TX (Alternate Function 7)
## - PA10: USART1_RX (Alternate Function 7)
##
## GPIO Configuration (Required):
## ```nim
## # Enable GPIOA clock
## volatileStore(RCC_AHB1ENR, volatileLoad[uint32](RCC_AHB1ENR) or (1'u32 shl 0))
##
## # Configure PA9 as AF7 (USART1_TX)
## let moder = volatileLoad[uint32](GPIOA_BASE + GPIO_MODER_OFFSET)
## volatileStore(GPIOA_BASE + GPIO_MODER_OFFSET, (moder and not (3'u32 shl (9 * 2))) or (2'u32 shl (9 * 2)))
##
## # Set AF7 for PA9
## let afrhReg = GPIOA_BASE + GPIO_AFRH_OFFSET
## let afrh = volatileLoad[uint32](afrhReg)
## volatileStore(afrhReg, (afrh and not (15'u32 shl ((9 - 8) * 4))) or (7'u32 shl ((9 - 8) * 4)))
## ```
##
## Clock Configuration:
## - Enable USART1 clock: RCC_APB2ENR |= (1 << 4)
## - System clock must be configured (HSI/HSE/PLL)
##
## USB-Serial Adapter Connection:
## - Adapter TX -> PA10 (MCU RX)
## - Adapter RX -> PA9 (MCU TX)
## - Adapter GND -> MCU GND
## - DO NOT connect VCC (MCU powered separately)
##
## Terminal Settings:
## - Baud: 115200
## - Data bits: 8
## - Parity: None
## - Stop bits: 1
## - Flow control: None
##
## Linux:
## ```bash
## screen /dev/ttyUSB0 115200
## # or
## minicom -D /dev/ttyUSB0 -b 115200
## ```
##
## macOS:
## ```bash
## screen /dev/cu.usbserial 115200
## ```
##
## Windows:
## - Use PuTTY or TeraTerm
## - COM port: Check Device Manager
##
## Performance:
## ============
##
## Baud Rate Calculation:
## - BRR = CPU_CLOCK / (16 * baud_rate)
## - For 72 MHz @ 115200: BRR = 72000000 / (16 * 115200) = 39.0625
## - Actual baud: 72000000 / (16 * 39) = 115385 baud (+0.16% error)
##
## Throughput:
## - 115200 baud = 11,520 bytes/sec (with 8N1)
## - ~87 μs per character
## - 10 bits per char (1 start + 8 data + 1 stop)
##
## CPU Usage:
## - Blocking I/O: 100% CPU while waiting
## - For efficiency: Use interrupts or DMA
## - Interrupt: Save/restore context (~50 cycles overhead)
## - DMA: Zero CPU, full throughput
##
## Buffer Sizes:
## - Command buffer: 64 bytes (tune for your needs)
## - Consider circular buffer for high-speed streaming
##
## Error Handling:
## ===============
##
## UART Status Register (SR) Flags:
## - PE (bit 0): Parity error
## - FE (bit 1): Framing error
## - NE (bit 2): Noise detected
## - ORE (bit 3): Overrun error
## - IDLE (bit 4): Idle line detected
##
## Example error checking:
## ```nim
## let sr = volatileLoad[uint32](USART1_BASE + UART_SR_OFFSET)
## if (sr and (1'u32 shl 3)) != 0:  # ORE
##   # Overrun error - data lost
##   printStr(uart, "\r\nWarning: UART overrun!\r\n")
## ```
##
## Debugging:
## ==========
##
## Common Issues:
## 1. No output:
##    - Check GPIO alternate function configuration
##    - Verify USART clock enabled
##    - Check baud rate calculation
##    - Verify TX/RX not swapped
##
## 2. Garbage characters:
##    - Baud rate mismatch
##    - Wrong CPU_CLOCK value
##    - System clock not configured
##
## 3. Missing characters:
##    - UART overrun (data too fast)
##    - Increase buffer size
##    - Use interrupts or DMA
##
## 4. Echo delays:
##    - LED delay too long
##    - Reduce delayCycles()
