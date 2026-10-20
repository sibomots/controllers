<!--
-- ============================================================================
-- This file is part of Bifrost
--
-- Copyright (c) 2025 Jeff Wandling
-- All Rights Reserved.
--
-- Licensed under BSD 3-Clause
-- Redistribution and use in source and binary forms, with or without
-- modification, are permitted under the terms of the BSD 3-Clause license.
-- See the LICENSE file for the full text.
-- ============================================================================
-->
# Setup (Ada)

This page covers the **one-time** steps to prepare a build/flash/debug
environment for the Ada version of `bifrost`. Do these once per machine.
Once done, see [`README.md`](README.md) for the actual build and debug
workflow you'll use every day.

(Historical note: this document supersedes [`INTRO.md`](INTRO.md)'s "Dev
Environment" section, which referred to the now-discontinued GNAT
Community installer. `INTRO.md` is kept as-is for background/reference,
not as a setup guide.)

## Software Toolchain

The toolchain to build and load the application is the GNAT Ada
cross-compiler, targeting `arm-eabi`.

This fully replaces the ARM GCC toolchain the C version uses -- not
alongside it, instead of it. A plain `arm-none-eabi-gcc` has no GNAT
front end and cannot compile `.adb`/`.ads` files at all; you need the
dedicated GNAT ARM ELF build, which contains `arm-eabi-gnatmake`,
`arm-eabi-gcc` (a GNAT-aware variant), `arm-eabi-gnatbind` (the Ada
*binder*), and the pre-built bare-metal Ada runtimes (RTS) the compiler
needs.

This can be obtained from the
[GNAT-FSF-builds releases](https://github.com/alire-project/GNAT-FSF-builds/releases)
(maintained by the Alire project, but these are plain archives -- no
Alire package manager involved in using them this way; see below for
why that matters). As with the C toolchain, the release version isn't
critical -- what matters is the host you're building on (Windows x86_64,
in these instructions) and the target (`arm-elf`).

The target host system is NOT the HW, but rather the system you are using
to develop and cross-compile for the target -- same distinction the C
side makes.

In these instructions, an assumption is made that the user has a Windows
system, same as the C side.

But, before that we need to settle on the actual Development Environment.

## Software Development Environment

There are two paths to take, same as the C side.

1.  Use an IDE
2.  Use the command line

### The IDE

AdaCore, the primary steward of GNAT, offers their own IDE:
[GNAT Studio](https://www.adacore.com/gnatstudio) (formerly GPS, the GNAT
Programming Studio) -- free, and the closest Ada equivalent to what
STM32CubeIDE is for the C/ST ecosystem. There is also an official "Ada &
SPARK" extension for VS Code, built on the same Ada Language Server that
powers GNAT Studio's own code intelligence.

## IDEs Supporting Ada on the STM32 NUCLEO-144 Boards

Here are options for the IDE method of development.

### Official AdaCore IDEs
- **GNAT Studio**
  - Free, AdaCore's own IDE (formerly GPS).
  - Project-file aware (`.gpr`), integrated debugger, GNATformat.
  - Continuous-release cadence, roughly quarterly.
- **VS Code + "Ada & SPARK" extension**
  - Official AdaCore extension, built on the Ada Language Server.
  - Completion, navigation, and tooltips for both `.adb`/`.ads` and `.gpr` files.

---

### Legacy / Historical
- **Eclipse + GNATbench**
  - AdaCore's older Eclipse-based plugin, largely superseded by GNAT Studio.

---

### Command-Line Toolchains
- **GNAT ARM ELF + gprbuild**
  - Bare-metal workflows (what you're using now).
- **OpenOCD / ST-Link CLI**
  - For flashing and debugging -- identical tooling to the C side.
- **GDB**
  - Source-level debugging; GNAT-produced ELF binaries carry standard
    DWARF debug info, so this is the *same* `arm-none-eabi-gdb` the C
    side already uses, not a separate Ada-specific debugger.

---

### Recommended Paths
- **GNAT Studio** - Official, fully supported, closest analog to STM32CubeIDE.
- **GNAT ARM ELF + gprbuild + OpenOCD** - Lean, script-able, and what you already use.
- **VS Code + Ada & SPARK extension** - Modern, lightweight, shares tooling with GNAT Studio.

## Command Line

The alternative is to use command line tools and an interactive editor
(such as `vi`, or `emacs`) to develop -- same choice, same rationale, as
the C side. It's up to you.

# Setup of Build Environment

The setup instructions here are assuming the Command Line software
development environment, same as the C side. All that matters is this:

1. You can edit the source code easily.
2. You can compile and link the object code easily.
3. You can flash and on-target debug (instruction by instruction *or* line
by line).

These are essential features no matter what development environment you choose.

## The Shell

Same shell as the C side, for the same reason:
[git-sdk-64](https://github.com/git-for-windows/build-extra/releases).

Plain Git-for-Windows bash doesn't work for this project -- its minimal
MSYS2 root never populates `/usr/bin/cmake`/`/usr/bin/make`, and its
bundled pacman (if any) is restricted to Git's own self-update. That
limitation applies here too, since the Ada build also needs real
MSYS2-rooted tooling underneath `gprbuild` (even though, unlike the C
side, this build doesn't invoke `cmake`/`make` itself -- `gprbuild` is
its own self-contained build orchestrator; see [`SOFTWARE.md`](SOFTWARE.md)
for why Ada's project-file model replaces CMake entirely rather than
sitting alongside it).

Get this shell installer. Install Git-SDK-64.

## The Compiler

Unlike the C side's single-ZIP ARM GNU toolchain, the Ada toolchain
comes as **two separate standalone archives** -- the cross-compiler and
`gprbuild` are published independently:

- `gnat-arm-elf-windows-x86_64-<version>.tar.gz`
- `gprbuild-windows-x86_64-<version>.tar.gz`

Both from [GNAT-FSF-builds releases](https://github.com/alire-project/GNAT-FSF-builds/releases).

A note on *why* these are fetched this way rather than through Alire
(AdaCore's current, actively-promoted package/toolchain manager): Alire
takes liberties over install location that weren't acceptable here --
no control over the path, and no avoiding spaces in it. These are plain
`.tar.gz` archives instead, extracted wherever you choose, same
philosophy as the C side's ARM GNU toolchain ZIP.

Pick a path with no spaces, same as `/c/arm` for the C toolchain -- the
author uses `/c/ada-arm`:

```
$ mkdir -p /c/ada-arm
$ cd /c/ada-arm
$ tar xf /path/to/gnat-arm-elf-windows-x86_64-<version>.tar.gz
$ tar xf /path/to/gprbuild-windows-x86_64-<version>.tar.gz
```

In your shell, set up `PATH` to include both toolchains' `bin/`
directories. Append to your `.bashrc`:

```
export PATH=$PATH:/c/ada-arm/gnat-arm-elf-windows64-x86_64-<version>/bin
export PATH=$PATH:/c/ada-arm/gprbuild-x86_64-windows64-<version>/bin
```

Either start a new shell, or just run the `.bashrc`:

```
$ . ~/.bashrc
```

Test it can find the tools:

```
$ which gprbuild
$ which arm-eabi-gcc
```

If it does not find them, review the steps and try again.

### A note on the runtime (RTS)

The cross-compiler archive ships with prebuilt runtime profiles under
`<prefix>/arm-eabi/lib/gnat/`. Older AdaCore documentation (and some
general GNAT material) calls the minimal bare-metal runtime "ZFP"
(Zero-Footprint) -- as of GNAT Pro 22, AdaCore renamed this family to
**`light`** (and `light-tasking` replaces what used to be called
`ravenscar-sfp`). There is no separate "ZFP" download; it's already in
this archive under its current name.

Which profile applies depends on which board you're building for --
this toolchain serves **two** separate Ada projects in this repo
(`f722ze-tiny` and `samv71-tiny`, see [`README.md`](README.md) for how
they compare), each on a different board with a different level of
runtime support:

- **NUCLEO-F722ZE** (`f722ze-tiny`; C-only-in-a-pinch, see
  [`../HARDWARE.md`](../HARDWARE.md)): no out-of-box board-specific
  profile exists, so this project uses the generic **`light-cortex-m7f`**
  -- specifically the `f` (single-precision FPU) variant, not `df`
  (single+double), because the STM32F722's Cortex-M7 has a
  single-precision-only hardware FPU (confirmed against ST's RM0431).
  This is a *non-tasking* profile -- no `light-tasking-cortex-m7f`
  exists generically, and F722ZE has no board-specific tasking profile
  either (see below).
- **NUCLEO-F767ZI** (the preferred board for `f722ze-tiny`'s future
  tasking work, once Ada tasking is involved): its STM32F767ZI silicon
  has a double-precision FPU (`cortex-m7df`), and -- unlike F722ZE --
  it has a real match among the toolchain's board-specific
  `light-tasking-*` profiles: `light-tasking-stm32f769disco`, built
  for the STM32F769NI, which is memory-map-identical to the F767ZI's
  STM32F767ZI (confirmed against ST's datasheets, not assumed). This
  is the profile `f722ze-tiny`'s tasking phase will use once that
  board is in hand -- not yet wired into that project.
- **SAMV71 Xplained Ultra** (`samv71-tiny`): unlike either STM32
  board above, this one has a *genuine* board-specific GNAT BSP bundled
  in the toolchain -- three profiles exist (`embedded-samv71`,
  `light-samv71`, `light-tasking-samv71`), confirmed directly on disk
  (real `start-rom.S`/`start-ram.S` startup assembly and vector table,
  `Setup_Pll`, `Interfaces.SAM.*` SVD-generated register packages).
  `samv71-tiny` uses **`light-tasking-samv71`** -- real Ravenscar/
  Jorvik tasking, available and in active use today, not a future
  phase blocked on hardware the way `f722ze-tiny`'s tasking is.

## Hardware Interface

In order to flash and debug on target you need software that
comprehends JTAG/SWD and GDB. Which tool depends on which project:

- **`f722ze-tiny`** (NUCLEO-F722ZE): `openocd` talking to the
  board's on-board ST-Link -- **identical requirement and identical
  tool** to the C side. If you already set this up for the C build,
  there is nothing new to install here; OpenOCD doesn't care what
  compiler produced the ELF file it's flashing.

  ```
  $ pacman -Syu mingw-w64-x86_64-openocd
  ```

  See [`../c/SETUP.md`](../c/SETUP.md) for the full enumeration/driver
  walkthrough (STM32CubeProgrammer driver install, Device Manager
  verification, the expected `openocd` output transcript, etc.) -- it's
  the same board, same ST-Link, same steps, not repeated here.

- **`samv71-tiny`** (SAMV71 Xplained Ultra): a genuinely different
  debug chain -- **SEGGER J-Link**, not OpenOCD/ST-Link. Install the
  J-Link Software and Documentation Pack from SEGGER
  (https://www.segger.com/downloads/jlink/). This matches the C port's
  own `setupw.sh` exactly (`c/samv71-tiny/main/setupw.sh`) -- same
  physical board, same debugger, regardless of which language built
  the image being debugged.

With this done, you're set up. Move on to [`README.md`](README.md) for
the actual build and debug workflow for whichever project you're
working on.

<hr>
Copyright 2025 Jeff Wandling<br>
