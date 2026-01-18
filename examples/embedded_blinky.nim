## Embedded LED Blinky Example
## ============================
##
## This example demonstrates basic embedded GPIO control using Arsenal's HAL.
## It blinks an LED connected to a GPIO pin at 1 Hz.
##
## Target Platforms:
## - STM32F4 Discovery (LED on PA13)
## - Generic STM32F4 boards
## - RP2040 (Raspberry Pi Pico)
##
## Compilation:
## ```bash
## # For STM32F4 (ARM Cortex-M4)
## nim c --cpu:arm --os:standalone --gc:none --noMain \
##   -d:stm32f4 -d:bare_metal --noLinking \
##   --passC:"-mcpu=cortex-m4 -mthumb -mfloat-abi=hard -mfpu=fpv4-sp-d16" \
##   embedded_blinky.nim
##
## # Link with custom linker script
## arm-none-eabi-gcc -o firmware.elf embedded_blinky.o \
##   -T stm32f4.ld -nostdlib -lgcc
##
## # For RP2040 (Raspberry Pi Pico)
## nim c --cpu:arm --os:standalone --gc:none --noMain \
##   -d:rp2040 -d:bare_metal --noLinking \
##   --passC:"-mcpu=cortex-m0plus -mthumb" \
##   embedded_blinky.nim
## ```

import ../src/arsenal/embedded/hal
import ../src/arsenal/embedded/nolibc

# Hardware configuration
const
  CPU_FREQ = 16_000_000  # 16 MHz system clock
  LED_PIN = 13           # LED connected to pin 13
  BLINK_RATE_MS = 500    # Blink every 500ms (1 Hz)

when defined(stm32f4):
  const GPIO_PORT = GPIOA_BASE
elif defined(rp2040):
  const GPIO_PORT = GPIO_BASE
else:
  {.error: "Unsupported platform. Define stm32f4 or rp2040".}

# Entry point for bare-metal application
proc main() {.exportc: "_start", noreturn.} =
  ## Main entry point - called by bootloader/startup code

  # Initialize LED GPIO pin
  let led = GpioPort(base: GPIO_PORT)
  led.setMode(LED_PIN, modeOutput)

  # Optional: Initialize pin to known state
  led.write(LED_PIN, low)

  # Main loop - runs forever
  var blinkCount: uint32 = 0

  while true:
    # Turn LED on
    led.write(LED_PIN, high)
    delayMs(BLINK_RATE_MS, CPU_FREQ)

    # Turn LED off
    led.write(LED_PIN, low)
    delayMs(BLINK_RATE_MS, CPU_FREQ)

    # Increment counter (could be used for debugging)
    inc blinkCount

# Alternative: Using GPIO toggle for shorter code
proc mainToggle() {.exportc: "_start_toggle", noreturn.} =
  ## Alternative implementation using toggle() for more compact code

  let led = GpioPort(base: GPIO_PORT)
  led.setMode(LED_PIN, modeOutput)

  while true:
    led.toggle(LED_PIN)
    delayMs(BLINK_RATE_MS, CPU_FREQ)

# Advanced: Blink with different patterns
proc mainPattern() {.exportc: "_start_pattern", noreturn.} =
  ## Advanced example with different blink patterns

  let led = GpioPort(base: GPIO_PORT)
  led.setMode(LED_PIN, modeOutput)

  proc shortPulse() =
    led.write(LED_PIN, high)
    delayMs(100, CPU_FREQ)
    led.write(LED_PIN, low)
    delayMs(100, CPU_FREQ)

  proc longPulse() =
    led.write(LED_PIN, high)
    delayMs(500, CPU_FREQ)
    led.write(LED_PIN, low)
    delayMs(500, CPU_FREQ)

  while true:
    # SOS pattern: ... --- ...

    # S (short-short-short)
    for i in 0..<3:
      shortPulse()

    delayMs(300, CPU_FREQ)

    # O (long-long-long)
    for i in 0..<3:
      longPulse()

    delayMs(300, CPU_FREQ)

    # S (short-short-short)
    for i in 0..<3:
      shortPulse()

    # Pause between SOS sequences
    delayMs(2000, CPU_FREQ)

## Hardware Setup Notes
## =====================
##
## STM32F4 Discovery:
## - Built-in LED on PD12-PD15
## - External LED: Connect LED + 330Ω resistor to PA13
## - LED anode to pin, cathode to GND
##
## Raspberry Pi Pico (RP2040):
## - Built-in LED on GPIO 25
## - External LED: Connect LED + 330Ω resistor to GPIO 13
## - LED anode to pin, cathode to GND
##
## Current Limiting:
## - Typical LED forward voltage: 2.0V (red) - 3.3V (blue/white)
## - GPIO output: 3.3V
## - For 10mA LED current: R = (3.3V - 2.0V) / 10mA = 130Ω
## - Use 220Ω or 330Ω resistor (standard values)
##
## Startup Code Requirements:
## ==========================
##
## This example requires startup code to:
## 1. Initialize stack pointer
## 2. Copy .data section from Flash to RAM
## 3. Zero .bss section
## 4. Configure system clock
## 5. Call _start entry point
##
## Example startup code (minimal):
## ```asm
## .syntax unified
## .cpu cortex-m4
## .thumb
##
## .global Reset_Handler
## .section .text.Reset_Handler
## Reset_Handler:
##   ldr sp, =_estack          /* Set stack pointer */
##   bl SystemInit              /* Initialize clocks */
##   bl _start                  /* Jump to main */
##   b .                        /* Infinite loop if main returns */
## ```
##
## Linker Script Requirements:
## ```ld
## MEMORY
## {
##   FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 512K
##   RAM (rwx)  : ORIGIN = 0x20000000, LENGTH = 128K
## }
##
## SECTIONS
## {
##   .text : { *(.text*) } > FLASH
##   .data : { *(.data*) } > RAM AT> FLASH
##   .bss  : { *(.bss*) } > RAM
## }
## ```
##
## Performance Notes:
## ==================
##
## - GPIO write: 1-2 CPU cycles (atomic via BSRR on STM32)
## - delayMs: Software loop, ±5% accuracy
## - For precise timing: Use hardware timers (see HAL timer functions)
## - CPU frequency must match actual clock configuration
##
## Power Consumption:
## - Active mode: ~10-30 mA (CPU running)
## - Sleep mode: Use WFI instruction to reduce power
## - LED current: ~10-20 mA additional
##
## Example with low power:
## ```nim
## while true:
##   led.toggle(LED_PIN)
##   delayMs(100, CPU_FREQ)
##   {.emit: "asm volatile(\"wfi\");".}  # Wait for interrupt (low power)
## ```
##
## Debugging:
## ==========
##
## Use OpenOCD and GDB:
## ```bash
## # Terminal 1: Start OpenOCD
## openocd -f interface/stlink.cfg -f target/stm32f4x.cfg
##
## # Terminal 2: Connect with GDB
## arm-none-eabi-gdb firmware.elf
## (gdb) target extended-remote localhost:3333
## (gdb) load
## (gdb) monitor reset halt
## (gdb) continue
## ```
##
## LED not blinking? Check:
## 1. GPIO clock enabled (RCC_AHB1ENR for STM32F4)
## 2. Pin mode configured correctly
## 3. LED polarity (anode/cathode)
## 4. System clock frequency matches CPU_FREQ constant
## 5. Linker script loads code to correct address
