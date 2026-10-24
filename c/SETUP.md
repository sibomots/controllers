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
# Setup (C)

This page covers the **one-time** steps to prepare a build/flash/debug
environment for the C projects in this directory -- `f722ze-tiny`
(`bifrost`), `f767zi` (the same `bifrost` application on NUCLEO-F767ZI),
and `samv71-tiny`, all of which share the same ARM GCC toolchain and
shell setup below (`f767zi` needs no additional toolchain step beyond
what's here, unlike the Ada side -- see [`../ada/SETUP.md`](../ada/SETUP.md)).
Do these once per machine. Once done, see [`README.md`](README.md) for
the actual build and debug workflow you'll use every day, for whichever
project you're working on.

## Software Toolchain

The toolchain to build and load the application is the ARM GCC compiler toolchain.

This can be obtained from [ARM](https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads). It is not critical the release version (latest usually
best. What is important is the target host system to build on).

The target host system is NOT the HW, but rather the system you are using
to develop and cross-compile for the target.

In these instructions, an assumption is made that the user has a Windows
system. The Linux system requires almost the identical toolchain except
for the host version.

But, before that we need to settle on the actual Development Environment.

## Software Development Environment

There are two paths to take.

1.  Use an IDE
2.  Use the command line

### The IDE

There are a lot of options for the IDE to use. Usually the most effective
way to develop is with the IDE that is sponsored by (provided by) the
vendor of the silicon and/or the vendor of the development hardware. In
this case, ST-Micro offers a package called [STM32CubeProgrammer](https://www.st.com/en/development-tools/stm32cubeprog.html)

It will install not only an IDE but also the drivers for Windows that
enumerate the on-board debug IC (JTAG/SWD controller) to permit on-target
debugging and programming.

## IDEs Supporting the STM32 NUCLEO-F722ZE

Here are options for the IDE method of development.

### Official ST IDE
- **STM32CubeIDE**
  - Free, Eclipse-based.
  - Integrates STM32CubeMX (clock, pinmux, peripheral init).
  - Fully supported by ST for all Nucleo boards, including F722ZE.

---

### Third-Party Commercial IDEs
- **IAR Embedded Workbench for ARM (EWARM)**
  - Industry-standard, safety-critical ready.
  - BSPs available for Nucleo boards.
- **Keil MDK-ARM (uVision / Arm Development Studio)**
  - Long history with STM32.
  - CMSIS-Pack support for F7 family.
- **Segger Embedded Studio**
  - Free license for STM32 MCUs.
  - Tight integration with J-Link (can bypass onboard ST-Link).

---

### Open-Source / Community IDEs
- **PlatformIO (VS Code extension)**
  - Supports `ststm32` platform and NUCLEO-F722ZE.
  - HAL or bare-metal options.
- **Eclipse + GNU ARM plugin**
  - DIY setup with `arm-none-eabi-gcc` + OpenOCD.
- **CLion (JetBrains)**
  - Via PlatformIO plugin or custom CMake toolchain.
- **Embeetle IDE**
  - Lightweight embedded IDE, STM32 supported.

---

### Command-Line Toolchains
- **arm-none-eabi-gcc + CMake/Make**
  - Bare-metal workflows (what you're using now).
- **OpenOCD / ST-Link CLI**
  - For flashing and debugging.
- **GDB**
  - Source-level debugging.

---

### Other Options
- **Arduino IDE**
  - Via STM32duino core; limited but works for simple prototyping.
- **Mbed Studio**
  - Mbed OS support for Nucleo-144 boards.
- **VisualGDB (Visual Studio plugin)**
  - Commercial; integrates GCC + OpenOCD into Visual Studio.

---

### Recommended Paths
- **STM32CubeIDE** - Official, fully supported.
- **arm-none-eabi-gcc + CMake + OpenOCD** - Lean, script-able, and what you already use.
- **PlatformIO + VS Code** - Modern, lightweight, great for rapid development.

## Command Line

The alternative is to use command line tools and an interactive editor
(such as `vi`, or `emacs`) to develop.

For some this is not ideal, but for the author of this page using the
shell and `vi` is far more natural and efficient.

It's up to you.

# Setup of Build Environment

The setup instructions here are assuming the Command Line software
development environment. However, the same tools can be used within
Microsoft Visual Code and other IDE systems that permit third party
tools used for the build, flash and debugging steps.

All that matters is this:

1. You can edit the source code easily.
2. You can compile and link the object code easily.
3. You can flash and on-target debug (instruction by instruction *or* line
by line).

These are essential features no matter what development environment you choose.

## The Shell

In order to use the command line environment and to take advantage of
the Unix like tools in a shell, the author uses a compromise shell:

[git-sdk-64](https://github.com/git-for-windows/build-extra/releases)

This is preferred over the traditional *git for windows* setup because
the package management for the traditional Git For Windows is a pain.

Get this shell installer. Install Git-SDK-64.

Plain Git-for-Windows bash (the common one, installed via the usual Git
for Windows installer) is **not** sufficient for the build scripts in
this project: it ships a minimal MSYS2 runtime with no `/usr/bin/cmake`
or `/usr/bin/make`, and its bundled `pacman` (if present at all) is
restricted to Git's own self-update, not a general package manager.
git-sdk-64 is a full MSYS2 installation and provides both tools via
`pacman`.

## The Compiler

The author mentioned the ARM GCC toolchain.

For Windows Git-SDK-64, the variant you want is:

`arm-gnu-toolchain-14.2.rel1-mingw-w64-i686-arm-none-eabi.zip`

It's a ZIP file. Simply unzip the file inside a specific directory on your host. The author chooses `/c/arm`

```
$ mkdir /c/arm
$ cd /c/arm
$ unzip ZIPFILE
```

In your shell, you can setup `PATH` to include the directory holding the
toolchain applications:

Append to your `.bashrc`

```
export PATH=$PATH:/c/arm/bin
```

Either start a new shell, or just run the `.bashrc`

```
$ . ~/.bashrc
```

Test it can find the compiler:

```
$ which arm-none-eabi-gcc
/c/arm/bin/arm-none-eabi-gcc
```

If it does not find the compiler, then review the steps and try again.

Also install `cmake` and `make` from within the shell (needed by
`buildw.sh`, see [`README.md`](README.md)):

```
$ pacman -Syu mingw-w64-x86_64-cmake mingw-w64-x86_64-make
```

## Hardware Interface

In order to flash and debug on target you will need software that
comprehends JTAG/SWD and GDB. Which tool depends on which project:

- **`f722ze-tiny`** and **`f767zi`** (NUCLEO-F722ZE / NUCLEO-F767ZI):
  the open source solution to this is `openocd`, talking to the
  board's on-board ST-Link -- identical steps for both boards. See
  below for the full walkthrough.
- **`samv71-tiny`** (SAMV71 Xplained Ultra): a genuinely different
  debug chain -- **SEGGER J-Link**, not OpenOCD/ST-Link. Install the
  J-Link Software and Documentation Pack from SEGGER
  (https://www.segger.com/downloads/jlink/#J-LinkSoftwareAndDocumentationPack).
  `samv71-tiny/main/setupw.sh` wraps `JLinkGDBServer` directly (device
  ID `ATSAMV71Q21`) -- there is no OpenOCD config for this board in
  this project at all; skip the rest of this section if `samv71-tiny`
  is the only project you're setting up.

The walkthrough below (OpenOCD/ST-Link enumeration, drivers, the
expected `openocd` transcript) is specific to `f722ze-tiny`.

You can install `openocd` from within the shell. DO NOT install tools outside of
the shell.

From the shell:

```
$ pacman -Syu \
    mingw-w64-x86_64-openocd \
    mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-make
```

Enter *Yes* to all questions and proceed.

There is no point in trying to write the software or attempt to flash
it unless your openocd setup works.

Test it:

Attach your Devkit Board to your PC via micro-USB. On this particular
layout the jack is `CN1`.

Make sure you are using a USB cable that is for data and power, not just
power (if there are only two conductors in the wire, it's not a data USB
cable).

In Windows, under Device Manager, did the board enumerate?

![Enumerate the ST-Micro Device](../docs/img/device-mgr-enumerates.jpg)

If it did not enumerate, then the Windows drivers for interfacing the
JTAG controller on the devboard are not installed.

Disconnect the board before this step:

* Install STM32CubeProgrammer application. DO NOTHING ELSE WITH STM32CubeProgrammer. EXIT THE APPLICATION.
* Retry enumeration (disconnect and reconnect the board).

If proved that the board enumerates, then in a new shell window enter this:

```
$ export OPENOCD_SCRIPTS=/mingw64/share/openocd/scripts
openocd -f interface/stlink.cfg -f target/stm32f7x.cfg -c "adapter speed 2000"
```

The output should be like this:

```
Open On-Chip Debugger 0.12.0
Licensed under GNU GPL v2
For bug reports, read
        http://openocd.org/doc/doxygen/bugs.html
Info : auto-selecting first available session transport "hla_swd". To override use 'transport select <transport>'.
Info : The selected transport took over low-level target control. The results might differ compared to plain JTAG/SWD
adapter speed: 2000 kHz

Info : Listening on port 6666 for tcl connections
Info : Listening on port 4444 for telnet connections
Info : clock speed 2000 kHz
Info : STLINK V2J39M27 (API v2) VID:PID 0483:374B
Info : Target voltage: 3.247337
Info : [stm32f7x.cpu] Cortex-M7 r1p1 processor detected
Info : [stm32f7x.cpu] target has 8 breakpoints, 4 watchpoints
Info : starting gdb server for stm32f7x.cpu on 3333
Info : Listening on port 3333 for gdb connections
```

This means that the `openocd` application has connected to the target
hardware and is listening for GDB commands (via network on the host).

With this done, you're set up. Move on to [`README.md`](README.md) for
the actual build and debug workflow for whichever project you're
working on.

<hr>
Copyright 2025 Jeff Wandling<br>
