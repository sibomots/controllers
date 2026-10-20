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
# Embedded Firmware, in C and in Ada

This repository is a growing collection of small, bare-metal embedded
firmware applications, each implemented twice -- once in C, once in
Ada -- for direct, side-by-side comparison on real hardware. Both
languages solve the same problem per application and are
built/flashed/debugged with the same category of tools (a
cross-compiler, a project-based build system, a debug probe, and GDB)
-- only the language, toolchain, and low-level startup code differ.

- [`c/`](c/README.md) -- the C implementations.
- [`ada/`](ada/README.md) -- the Ada ports of the same applications.

## What's here

Two independent applications live here so far, on two different
vendors' silicon:

| Application | Directories | Board | Vendor |
|---|---|---|---|
| **bifrost** | `f722ze-tiny` (`c/f722ze-tiny`, `ada/f722ze-tiny`) | NUCLEO-F722ZE / NUCLEO-F767ZI | STMicroelectronics (STM32F7) |
| **samv71-tiny** | `samv71-tiny` (`c/samv71-tiny`, `ada/samv71-tiny`) | SAMV71 Xplained Ultra | Microchip/Atmel (SAMV71) |

`bifrost` is an LCD-counter demo with an interrupt-driven, bidirectional
TinyMon console over UART -- originally laid as the foundation for a
small ohmmeter application (see `ada/SOFTWARE.md`/`c/SOFTWARE.md`).
`samv71-tiny` is a from-scratch port of a MIL-1553-style binary packet
protocol (`rtbus`) and a stand-in command dispatcher, also fronted by
its own TinyMon console -- an unrelated application, not a variant of
`bifrost`.

The directory names (`f722ze-tiny`, `samv71-tiny`) follow a
board-then-app naming convention; the applications' own internal
identities (`Bifrost.*` Ada packages, `bifrost.gpr`, the C `bifrost`
CMake project; `Samv71_Tiny.*` / `samv71_tiny.gpr` / C's `m7_*` targets)
are unrelated to and unaffected by that directory naming.

## Target Hardware

Three boards across two vendor families are used, deliberately, not a
general family of interchangeable options. See
[`HARDWARE.md`](HARDWARE.md) for the full rationale -- including why
`bifrost`'s Ada port prefers NUCLEO-F767ZI over F722ZE, and why
`samv71-tiny`'s board, despite being unrelated silicon, isn't a
shortcut around that preference.

## Where to go next

Each language tree is self-contained and documented with the same
three-document structure, covering both applications under that
language:

- `README.md` -- synopsis of the software, how to build it, how to debug it.
- `SETUP.md` -- one-time toolchain install/setup for that language.
- `SOFTWARE.md` -- the software design/architecture document.

Start with [`c/README.md`](c/README.md) or [`ada/README.md`](ada/README.md),
whichever language you're interested in -- each links onward to its own
`SETUP.md` and `SOFTWARE.md`. See [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md)
for current, real limitations and why they exist (notably: `bifrost`'s
Ada target has no Ravenscar tasking yet and runs its console via a
polled, interrupt-fed main loop instead, unlike `samv71-tiny`'s Ada
port, which has real tasking and a genuine console task -- a difference
in available toolchain support per board, not a design choice).

<hr>
Copyright 2025 Jeff Wandling<br>

