<!--
// ============================================================================
// This file is part of Bifrost
//
// Copyright (c) 2025 Jeff Wandling
// All Rights Reserved.
//
// Licensed under BSD 3-Clause
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the terms of the BSD 3-Clause license.
// See the LICENSE file for the full text.
// ============================================================================
-->
# C Software Design

This directory holds three C applications: `f722ze-tiny` (internally
named `bifrost`), `f767zi` (the same `bifrost` application ported to
NUCLEO-F767ZI), and `samv71-tiny` (internally `m7`, the C reference
implementation `ada/samv71-tiny` was later ported from). See
[`README.md`](README.md) for how they compare board-for-board; this
document explains the architecture of all three. Most of what follows
is written through `f722ze-tiny`'s specific implementation choices --
`f767zi` is structurally identical to it (see "How `f767zi` Differs"
below), and `samv71-tiny` shares the same general requirements (linker
script, vector table, `main` after reset) but diverges in the
specifics, most notably in actually binding to a real vendor BSP where
`f722ze-tiny` has none. Each divergence is called out explicitly below
rather than left implicit.

The name of the software application is `bifrost`.

You can choose any name you wish. This is the name the author has chosen
to call the image.

## Requirements

The requirements for an application are three-fold:

1.  A linker configuration. The file usually ends with the `.ld` suffix.  The linker configuration
 is not source code, but is written in the language understood  by the linker in the toolchain.  Each
linker is going to have a slightly different language to define the configuration.  They all will resemble
each other, but with some possible enhancements or differences.  The linker configuration described in this
example application is the **GNU linker command language**.

2. Entry point.  The entry point of the software is a function that is designed to be invoked when the processor
comes out of reset.  Additionally, besides the handler for reset (sometimes called `ResetHandler`) there
are other functions that are executed based upon events that occur.   Faults, errors, and non-fatal interrupts
*fire* based on events and the **interrupt vector** is the sequential arrangement of addresses for each prescribed
handler. The **interrupt vector** is an array, in order of those *handlers*, one of them being the **Entry Point**.
On this system, the **interrupt vector** is written into non-volatile memory, at address 0.  The machine (otherwise
known as the CPU, or MCU) comes out of reset and branches to the instruction addressed by the content of address 0.

3. An application.  After the machine is initialized to the extent that the processor is ready to begin the application, then the startup defined by the handler for the **Reset Handler** is invoked. This function is called **main**.

## BSP and Drivers

BSP stands for Board Support Package.   Drivers are routines that are designed to facilitate I/O or control
of peripherals of the MCU.  An example is the UART drivers to configure data to be marshalled through the UART
for transmission or receive.  Another example is the drivers for data transfer over I2C, SPI and other interfaces.
User applications use the driver functions to cause data or signals to be rendered onto the hardware.  

When a BSP is devised, it is made so that all of the drivers that are specific to that instance of the board
support the capabilities that the board via the MCU provides.   The same processing unit (MCU) may be used
on different boards and so each of the boards has a distinct BSP.   The best source of the BSP and drivers
for the board is from the vendor of the board.  Seldom do we re-write from scratch the entire BSP, although
it is common to adjust the BSP for requirements that are related to safety-critical software, or other
approval basis of the whole software system.

Some vendors also provide software tools that allow the software engineer to pick and choose certain properties
that *will be* part of the board design and therefore the BSP is customized for that particular board -- especially
if the board is a custom enterprise. The silicon (MCU, CPU, etc..) vendors usually provide these tools.  An example
is the Texas Instruments HalCoGen tool for producing a driver set (BSP) for their processor families.

This describes `f722ze-tiny`'s situation exactly: no vendor BSP is used
at all. ST does ship STM32CubeMX/HAL for this board, but this project
doesn't pull it in -- `lowlevel/` hand-writes its own register access
directly against RM0431, the same way `interfaces`/`behavioral` assume
no HAL abstraction underneath them.

`samv71-tiny` is the opposite situation, and worth contrasting plainly:
`main/vendor/` carries a real vendor BSP as source -- CMSIS and the
Atmel/Microchip SAMV71 Device Family Pack -- pulled directly into the
build rather than hand-written from the reference manual. Its own
`lowlevel/` (`usart1.c`, `wdt.c`, `pio.c`, `pmc.c`, `tc0.c`) still talks
to peripheral registers fairly directly, in the DFP's own idiom, but it
is not starting from a blank register map the way `f722ze-tiny` is --
the DFP already supplies the base addresses, bitfield names, and
peripheral-ID constants this code builds on.

# How Bifrost is Organized

In terms of the file structure, here is the layout of `bifrost`


```
f722ze-tiny
├── CMakeLists.txt
├── app
│   ├── CMakeLists.txt
│   ├── inc
│   └── src
│       └── main.c
├── behavioral
│   ├── CMakeLists.txt
│   ├── calc
│   │   ├── CMakeLists.txt
│   │   ├── inc
│   │   └── src
│   ├── client
│   │   ├── CMakeLists.txt
│   │   ├── inc
│   │   └── src
│   ├── inc
│   └── src
├── interfaces
│   ├── CMakeLists.txt
│   └── inc
├── lowlevel
│   ├── CMakeLists.txt
│   ├── inc
│   ├── src
│   │   └── startup_stm32f722.c
│   └── stm32f722ze.ld
```

The directory (`f722ze-tiny` -- the CMake project name, build targets, and executable are still named `bifrost`/`bifrost_*`, the software's own identity, not renamed along with the directory) contains `app`, `behavioral`, `interfaces`, and `lowlevel`

## Major Components

* `main` function is defined in software in `app`.
* The application relies on logic and routines implemented in `behavioral`.   Low level and device driver software
does not belong in `behavioral`
* The `lowlevel` directory is designed to hold all of the specific BSP-like and drivers that are used by `behavioral`
components.
* `interfaces` is where structures and types are defined.  No compiled software per-se, but definitions of
data structures, and definitions that are integral to the shared format, structure, and properties of functionality
in the `behavioral` domain.   When C++ is used, this is where classes that provide only pure virtual methods are
defined.  We want to limit `interfaces` from holding implementation, but rather only software definitions through
header files only.

Sometimes at a peer level to this list of `behavioral`, `app`, `interfaces`, and `lowlevel` we might find whole third party components, like CMSIS.

CMSIS = Cortex Microcontroller Software Interface Standard.

It's an ARM-defined standard software layer for Cortex-M microcontrollers. The idea is to provide a common API and naming scheme so code is portable across vendors.

## CMSIS

- CMSIS-Core:
  - Startup code, system initialization, and register definitions for Cortex-M CPUs.
  - Defines standard names for registers, exceptions, NVIC, SysTick, etc.

- CMSIS-DSP:
  - Optimized math/DSP library (FFT, filters, vector ops).

- CMSIS-RTOS API:
  - Standard RTOS API layer (so code can switch RTOS kernels more easily).

- CMSIS-Driver:
  - Standard interfaces for peripherals (I2C, SPI, USART, etc.).

- CMSIS-Pack:
  - Packaging system for device support, drivers, middleware, examples.


In short: CMSIS is the vendor-neutral glue between ARM Cortex-M hardware and higher-level middleware/application code, making embedded software portable and consistent.

The two projects in this directory actually differ here, concretely:
`f722ze-tiny` doesn't use CMSIS at all -- no `vendor/` directory, no
CMSIS-Core, nothing; every register access is hand-written directly
against RM0431 (see BSP and Drivers, above). `samv71-tiny` does use it
-- `main/vendor/CMSIS/5.4.0` is a real, present dependency, alongside
the Atmel/Microchip SAMV71 Device Family Pack, both pulled in as
source and compiled as part of the build, not merely referenced in
documentation.

# How `f767zi` Differs

Nothing architecturally -- `f767zi` uses the exact same `app`/
`behavioral`/`lowlevel`/`interfaces` layout, the same CMake project
name (`bifrost`), the same component structure, and the same source
files as `f722ze-tiny`, copied over verbatim except for the files
listed below. This target deliberately keeps `f722ze-tiny`'s
HSI-16MHz/no-PLL clock approach rather than bringing up a PLL for this
chip, so none of the register-level driver code (`usart3.c`, `gpio.h`,
`delay.c`, `lcd_NHD_0108HZ.c`) needed any change at all -- the STM32F7
family's peripheral memory map is identical across F722ZE and F767ZI.

Only three things actually differ:

* `config/stm32f767zi.ld` -- `FLASH` 2048K (was 512K), `RAM` 512K (was
  256K). Verified in the linked ELF's own map file, not just the
  linker-script source: `FLASH` length `0x00200000`, `RAM` length
  `0x00080000`.
* `config/src/startup_stm32f767.c` -- renamed from
  `startup_stm32f722.c` (and the file's own internal comment updated
  to match); the vector table and `Reset_Handler` logic inside it are
  unchanged.
* Two stale comment references to the old startup filename, in
  `gpio.h` and `usart3.h` (`USART3_IRQn`'s and `USART3_IRQHandler`'s
  own cross-reference comments), updated to point at the new name.

Not yet flashed to physical NUCLEO-F767ZI hardware -- verified so far
by a real `cmake`/`arm-none-eabi-gcc` build only (clean, no warnings,
correct `FLASH`/`RAM` lengths in the resulting map file).

# How samv71-tiny is Organized

`samv71-tiny` does not use `f722ze-tiny`'s `app`/`behavioral`/
`interfaces`/`lowlevel` layout at the top level the same way -- its
actual project root is one directory deeper, at
`c/samv71-tiny/main/` (that's where `CMakeLists.txt` lives, not at
`c/samv71-tiny/` itself):

```
samv71-tiny/main
├── CMakeLists.txt
├── build.sh / buildw.sh / setupw.sh
├── app
│   └── src
│       └── main.c
├── lowlevel
│   ├── include  (atmel_start.h, board.h, chip_init.h, pio.h, pmc.h, tc0.h, usart1.h, wdt.h)
│   └── src      (board_init.c, chip_init.c, pio.c, pmc.c, tc0.c, usart1.c, wdt.c)
├── rtbus
│   ├── include  (cmd_handler.h, crc.h, crc_16.h, exec_cmd.h, rtbus.h, rtpacket.h)
│   └── src      (cmd_handler.c, crc.c, crc16.c, exec_cmd.c, rtbus.c)
├── startup
│   └── src      (startup_samv71q21b.c, system_samv71q21b.c)
├── tinymon
│   ├── include/tinymon.h
│   └── src/tinymon.c
├── behavioral     (empty placeholder, same intent as f722ze-tiny's
│                    behavioral/calc, behavioral/client -- not ported)
└── vendor          (CMSIS + the Atmel/Microchip SAMV71 DFP, see above)
```

`rtbus` and `tinymon` are top-level components here, not nested under
`behavioral` the way `f722ze-tiny` structures its console -- a direct
consequence of this project predating `f722ze-tiny`'s own directory
conventions, not a deliberate divergence to track. CMake project name
is `m7` (not `bifrost` or `samv71_tiny`), with library targets
`m7_app`/`m7_lowlevel`/`m7_rtbus`/`m7_tinymon`/`m7_startup`, and the
final executable is explicitly renamed via `OUTPUT_NAME`/`SUFFIX` to
`image.elf` -- matching `ada/samv71-tiny`'s own `bin/image.elf` exactly
even though neither name was coordinated with the other at the CMake/
`.gpr` level; it's just where both independently landed.

# The Main Super Loop

Inside the `main` function we find that the super-loop is the most reliable and simplest way
to organize cyclical behavior of the application.

In this application specifically, and in many other applications where cyclical operation
is essential, then the super-loop is the preferred solution:

## The Super Loop Steps


A skeleton of `main` would look like this:

```
main() {

   // Preliminaries
   //   All preliminaries that must be performed before the system is ready to be
   //   initialized.
   pre_initialize();

   // Setup as warranted
   //   All setup and preparation that is specific to the Application (not the machine)
   initialize();

   // The degree to which <i>setup</i> is subdivided is up to the programmer.  
 
   // Now, commence the loop forever.
   while (1) {

        // A wrapper function that may end up calling many other functions,
        // but results in the slate of state is populated with all sensed values
        // that can be known -- we do that here.  

        // Examples:
        //     GatherInputs calls:
        //          read_user_inputs();
        //          read_temperature(); 
        //          read_voltage();
        //          read_current();
        //          read_messages();
        //          read_busses();
        //          etc
      
        // The result after GatherInput is finished is all that can be known is
        // recorded in a Slate of State -- a vector perhaps -- of all the metrics
        // which can ever be known by the software. 

        GatherInputs();


        // Next, we calculate.  By calculate we refer to the logic and decision
        // making processes.  We analyze results gathered, we determine next steps,
        // choices are made, but no action to affect the system is taken.

        // The actual choices to make (updates to state) are recorded into the state vector.

        // Examples:
        //   Calculate calls:
        //         deduce_operation_from_state();
        //         test_thermal_redlines();
        //         derive_resistance();
        //         state_update(); 
        //         etc

        Calculate();


        // Next, we act.  By render, we mean to apply onto hardware signal or data
        // which actuates, activates, or otherwise invokes dynamic behavior of the system
        // based solely on the state, state vector and derived values.

        // Examples:
        //   Render calls:
        //       power_up();
        //       power_down();
        //       update_user_display();
        //       apply_mux();
        //       send_data_on_peripheral();
        //       etc
 
        Render();


        // Next, optionally, we have a step for Telemetry.
        //
        // It is the practice of this application to treat the word telemetry to mean
        // data that is intended to be released off the target.
        //
        // Examples:
        //   Telemetry calls:
        //        debug_log();
        //        etc
        //
        // We do not want to use Telemetry as a method to perform data transfers between
        // hardware components of the device for the operation.
 
        // Instead, we want  telemetry to be used as a method to send data off the target
        // In our application here, we may choose to enforce that telemetry is merely a debug
        // benefit and in the release version of the system there is no literal telemetry.
        //
        // Or perhaps we have a requirement that when directed by the user through the 
        // controls, telemetry is dumped in some fashion -- perhaps over a serial port,
        // or perhaps over an Ethernet port, etc.
         
        Telemeter();


        // Waiting for Sync is the last step.  As the name implies here we wait. We wait
        // for a signal prepared by the setup to allow execution to return to the top of
        // of this super-loop.

        // When the software execution is characterized, and when we have requirements
        // for the cyclical rate of the system, then we choose a timer structure that
        // will ensure the best chance to resume execution at the top of the loop on a 
        // regular cadence.

        // Example:
        //      Suppose the update (rendering) of the display is required to be at 10Hz.
        //      Suppose the potential for input gathering must be at 100Hz.
        //      Then,
        //        At 100Hz, a timer will fire that will modify a discrete value
        //        tested by WaitForSync()

        //        However, we can choose in each of the major steps of the SuperLoop to
        //        ignore the request for processing unless that functionality is required
        //        at the 10Hz.  We slice the time-line.
        //
        //       Waiting can be performed by polling a register, or by simply sleeping
        //       in such a way to reduce power consumption.  Only upon waking up
        //       at the onset of a new cycle are systems re-powered.  That's an extreme
        //       case, but the point is -- we often want the behavior to be very 
        //       close to deterministic.
        //
        //       The alternative is to make the Super Loop free-running -- which means
        //       We do not wait for sync pulse. We simply restart the loop immediately
        //       over and over.
        //
        //       Several kinds of peripherals like ADC would not benefit from free-running
        //       flow control since the preparation of an *ADC read* must be followed later
        //       by an operation to complete the act of reading the ADC.   It takes time --
        //       and deciding the best cyclical rate is based on all of the factors of the
        //       underlying hardware.

        WaitForSync();
   }

   // we never get here.

}
```

`f722ze-tiny`'s actual `main.c` does not use this literal phase
structure today -- it's a much smaller, free-running loop (LCD update
plus a non-blocking console poll each pass).

`samv71-tiny`'s `main.c` is the one place in this entire repo that
genuinely uses this skeleton's phase names, not just the general
reasoning behind it:

```c
int main(void)
{
    system_init();
    setup_console();
    while (1) {
        GatherInputs();
        Calculate();
        RenderOutput();
        WaitForCycle();
    }
}
```

`GatherInputs`/`Calculate`/`RenderOutput` each call a handful of
sub-functions, matching the skeleton's `GatherInputs`/`Calculate`/
`Render` naming almost exactly (this project has no separate
`Telemeter()` phase). Worth being honest about rather than overselling,
though: most of those per-phase calls --
`process_device_input`/`normalize_data`/`convert_engineering_units`/
`update_state_vector`/`render_cross_talk` -- are empty, literally
`void f(void) {}`, confirmed by reading the file directly. Only
`process_user_input()` (in `GatherInputs`), `build_user_messages()`/
`print_user_messages()` (in `Calculate`/`RenderOutput`), and
`render_pins()` (in `RenderOutput`) do real work, and all of it comes
from the console/command-dispatch pipeline (`tinymon`/`rtbus`). So:
real use of the pattern's *shape*, genuinely closer to this skeleton
than `f722ze-tiny` is today -- but scaffolding for behavior that was
never filled in, not a fully worked example of every phase pulling its
weight.

<hr>
Copyright 2025 Jeff Wandling
