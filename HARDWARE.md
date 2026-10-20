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
# Hardware Selection

This repo spans three boards across two vendor families -- each
application (C + Ada pair) targets its own board family deliberately,
not a general pool of interchangeable options:

- **`bifrost`** (directories `f722ze-tiny`) targets ST's STM32F7
  NUCLEO-144 family:
  - **NUCLEO-F767ZI** -- the preferred board, for both
    [`c/`](c/README.md) and [`ada/`](ada/README.md).
  - **NUCLEO-F722ZE** -- usable in a pinch, **C target only**.
- **`samv71-tiny`** (directories `samv71-tiny`) targets Microchip/Atmel's
  **SAMV71 Xplained Ultra** (ATSAMV71Q21B, Cortex-M7) -- a completely
  different vendor and silicon family from the STM32 pair above, not a
  related or interchangeable option. Both the C and Ada ports target
  this one board.

## Why two boards for `bifrost`, and why F767ZI is preferred

Both are ST NUCLEO-144 boards: same form factor, same on-board ST-Link
debug probe, closely related STM32F7-family peripheral IP (same USART
register layout, same GPIO model).

For the **C target**, that similarity is enough -- bare-metal C has no
runtime to speak of, so either board works, and F722ZE (the board this
project originally targeted) remains fine to use.

For the **Ada target**, the difference matters. Ada's bare-metal
runtime story has two tiers:

- `light-cortex-m7f` -- a *generic*, non-tasking runtime, board-agnostic
  within "any Cortex-M7 with a single-precision FPU." This is what the
  Ada port currently builds against, and it's what made F722ZE usable
  at all for the procedural (no tasking) phase of this project.
- `light-tasking-*` -- Ravenscar/tasking runtime support. Critically,
  **every tasking profile the installed GNAT-FSF toolchain ships is
  tied to a specific named board** (its own crt0, vector table, and
  linker script) -- there is no generic `light-tasking-cortex-m7f`.
  F722ZE has no match among them at all.

F767ZI does: its silicon (STM32F767ZI) is memory-map-identical to the
STM32F769NI that the toolchain's `light-tasking-stm32f769disco` profile
was built for (2MB Flash, 512KB SRAM split the same way across
ITCM/DTCM/SRAM1/SRAM2) -- confirmed by comparing ST's own datasheets,
not assumed. That makes F767ZI the board where Ada tasking (the
Main/LCD-Sink/UART-Sink task split planned for this project) is
actually achievable with this toolchain. F767ZI also has a
double-precision FPU (`cortex-m7df`), unlike F722ZE's single-precision
-only `cortex-m7f`.

## SAMV71 Xplained Ultra, and why it's not a tasking workaround for `bifrost`

Unlike F722ZE, the SAMV71 Xplained Ultra has a real, board-specific GNAT
BSP bundled in the installed toolchain -- `embedded-samv71`,
`light-samv71`, and critically `light-tasking-samv71` (confirmed
directly against files on disk: real startup assembly and a vector
table, `Setup_Pll` PLL bring-up calibrated for this exact board,
SVD-generated register packages for its PIO/PMC/EFC/UART peripherals).
`samv71-tiny`'s Ada port uses `light-tasking-samv71` and has real
Ravenscar tasking -- a protected-object-guarded, interrupt-driven
USART1 driver and a library-level console task -- something `bifrost`'s
Ada port cannot do on either of its own boards without an F767ZI in
hand (see above).

This isn't a path to get `bifrost` real tasking without buying an
F767ZI, though. SAMV71 and STM32F7 are unrelated silicon from different
vendors, with different peripheral register layouts, different clock
trees, and an entirely different debug chain (SEGGER J-Link, not
OpenOCD/ST-Link -- see `ada/SETUP.md`/`c/SETUP.md`). `samv71-tiny` is
its own separate application, not a drop-in substitute board for
`bifrost`. The useful takeaway it does provide: concrete, working proof
that GNAT's "every tasking profile is tied to a specific named board"
constraint (the core finding that drove the F767ZI recommendation
above) is a general toolchain property, not a `bifrost`-specific
problem -- SAMV71 simply already has a board-specific tasking profile
where F722ZE doesn't (yet).

## Current status

`bifrost`'s Ada port -- interrupt-driven, bidirectional UART I/O with a
TinyMon console, plus the LCD counter demo -- was built and proven on an
actual F722ZE (the board on hand at the time, before the F767ZI
preference was settled); see [`ada/README.md`](ada/README.md). Its
tasking phase is not yet implemented and is waiting on an F767ZI to
develop and verify against -- no source changes have been made for it
yet.

`samv71-tiny`'s Ada port is complete and fully verified on the SAMV71
Xplained Ultra: real Ravenscar tasking, interrupt-driven USART1 I/O, the
RTBus wire protocol, command dispatch, and a task-based TinyMon console,
all built against the real cross-compiler and, for the pure-logic
pieces, verified byte-for-byte against the real C implementation on the
host. See [`ada/README.md`](ada/README.md) for details.

## Porting notes (F722ZE <-> F767ZI, within `bifrost`)

If adapting board-specific code between the two: the memory map, clock
assumptions, and linker script differ (F722ZE: 512KB Flash / 256KB RAM,
HSI 16MHz no PLL; F767ZI: 2MB Flash / 512KB RAM). The peripheral
register layout (USART, GPIO) is close enough across the STM32F7 family
that porting driver code is mostly a matter of re-verifying addresses
and pin assignments against the target board's own reference manual,
not rewriting logic -- but it must be re-verified per board, not
assumed to carry over. (None of this applies to `samv71-tiny` --
different vendor, different architecture family in all but the shared
Cortex-M7 core; that's a separate application, not a porting target.)

<hr>
Copyright 2025 Jeff Wandling<br>
