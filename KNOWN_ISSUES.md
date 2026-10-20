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
# Known Issues

This page documents real, current limitations of this repo -- things
that are true today, why they're true, and what it would take to
change them. It's not a roadmap; see [`ada/README.md`](ada/README.md)
and [`ada/SOFTWARE.md`](ada/SOFTWARE.md) for the planned direction.

## 1. The Ada target is single-task -- no Ravenscar tasking yet

The Ada port (`ada/f722ze-tiny/`) runs entirely as one procedural flow
(the environment task) in `app/src/main.adb`: initialize the LCD and
USART3, print a banner, then loop formatting/displaying a counter and
polling the console non-blockingly. There is no `task`, `protected`, or
`Ada.Synchronous_Task_Control.Suspension_Object` anywhere in the Ada
source -- this isn't a simplification of a larger design that's partly
wired up, it's genuinely all one sequential procedure, confirmed
directly against the code rather than assumed.

The intended design, described in [`ada/SOFTWARE.md`](ada/SOFTWARE.md),
is three concurrent units (Main, an LCD Sink task, and a UART Sink
task). None of that exists yet -- it's blocked on hardware, not on
design uncertainty -- see the next section for exactly why.

Since this page was first written, interrupt-driven USART3 I/O (both
directions) and a `Bifrost.TinyMon` console (`help`/`count` commands)
were added -- `Bifrost.UART` is no longer dropped from the build, and
is actively exercised. This was achieved *without* Ravenscar tasking,
which is the point worth noting here: a hand-extended vector table
(`Bifrost.Startup`, 16 entries -> 56, routing USART3's interrupt,
IRQn 39, to a real handler) plus lock-free single-producer/single-
consumer ring buffers (`Volatile`-qualified shared state, no
`protected` object) stand in for the `Ada.Interrupts.Attach_Handler` +
protected-object pattern a Ravenscar runtime would normally provide.
It's a real, working alternative for interrupt-driven I/O specifically
-- it does not provide task scheduling, rendezvous, or any of the rest
of what Ravenscar tasking would bring, so the three-task design above
is still blocked exactly as described.

## 2. Why NUCLEO-F722ZE can't host that design

This repo's Ada work started on a NUCLEO-F722ZE. Getting real Ada
tasking running on it turned out not to be a matter of flipping a
runtime switch, and the reason is worth spelling out in full, since
it's the actual justification for [`HARDWARE.md`](HARDWARE.md)'s
NUCLEO-F767ZI recommendation, not just an assertion.

GNAT's bare-metal runtime story has two tiers:

- **`light-*`** -- generic, non-tasking runtimes, board-agnostic
  within "any Cortex-M7 with a single-precision FPU" (`light-cortex-m7f`)
  or double-precision (`light-cortex-m7df`). This is what the Ada port
  currently builds against (`light-cortex-m7f`), and it's genuinely
  board-agnostic: nothing about it ties to the F722ZE specifically,
  which is why a hand-rolled, from-scratch vector table and linker
  script (`Bifrost.Startup`, `config/stm32f722ze.ld`) was workable at
  all -- AdaCore's own documentation confirms generic profiles like
  this one expect the user to supply their own startup code.
- **`light-tasking-*`** -- Ravenscar/Jorvik tasking support. The
  assumption going in was that a generic `light-tasking-cortex-m7f`
  would exist in parallel to `light-cortex-m7f`, needing only three
  new vector table entries (SVCall, PendSV, SysTick) pointed at the
  runtime's own handlers. **That assumption was wrong.** Listing every
  profile actually shipped in the installed GNAT-FSF-builds toolchain
  showed every single `light-tasking-*` entry tied to one specific,
  named board -- `light-tasking-stm32f746disco`,
  `light-tasking-nucleo_f401re`, `light-tasking-samv71`, and so on.
  There is no generic, board-agnostic tasking profile at all.

Inspecting one of those board-specific profiles directly
(`light-tasking-stm32f746disco`) showed why they're packaged per-board
rather than generically: each one bundles its *own* `crt0`
(`start-rom.S`/`start-ram.S`), its *own* vector table (`handler.S`,
installed at runtime via the Cortex-M `VTOR` register rather than
hard-coded identically to the "light" profile's static table), and its
*own* linker script (`memory-map.ld`) -- all tied to that board's exact
silicon. For the F746-Discovery specifically, that meant a 1MB
Flash/ITCM-DTCM-SRAM memory layout utterly unlike the F722ZE's simple
512KB Flash / 256KB RAM map this project's linker script actually
describes. There was no F722ZE entry among any of the bundled
profiles, board-specific or otherwise.

That left three real options:

1. **Build a custom runtime from bb-runtimes source**, targeting a
   generic Cortex-M7 tasking configuration via AdaCore's own
   `ravenscar_build.gpr` machinery. Technically the most "correct" path,
   but a materially larger undertaking than this project's scope --
   building and validating a GNAT runtime from source, not just porting
   application code.
2. **Force-fit a mismatched board's bundled BSP onto the F722ZE.**
   Rejected: the memory map and (very likely) the SysTick clock-rate
   assumptions baked into any of the bundled profiles belong to a
   different, larger chip. Getting this wrong doesn't fail to build --
   it builds and then behaves incorrectly on real hardware, which is a
   much worse failure mode than a build error.
3. **Switch to a board with a real, verified silicon match** among the
   profiles actually shipped.

Option 3 is what [`HARDWARE.md`](HARDWARE.md) recommends: NUCLEO-F767ZI.
Its silicon, STM32F767ZI, was confirmed (against ST's own datasheets,
not assumed) to have an **identical** memory configuration to the
STM32F769NI that `light-tasking-stm32f769disco` was built for -- 2MB
Flash, 512KB SRAM split the same way across ITCM/DTCM/SRAM1/SRAM2. The
two parts differ in display-oriented peripherals (the F769 has
Chrom-ART, MIPI-DSI, JPEG; the F767 doesn't), not in core memory
architecture, so that bundled profile's `crt0`/vector-table/linker
script describe NUCLEO-F767ZI's actual hardware correctly, not an
approximation of it. F767ZI also keeps the NUCLEO-144 form factor and
on-board ST-Link debug probe this project already uses, and (unlike
NUCLEO-F746ZG, considered and ruled out when it turned out to be
obsolete/unavailable) is in active production and in stock.

While investigating this, the real handler symbol names the tasking
runtime expects were also confirmed directly from the installed
runtime source (`handler.S`): `__gnat_sv_call_trap`,
`__gnat_pend_sv_trap`, `__gnat_sys_tick_trap` -- declared `.weak`, with
the real Ravenscar kernel (GNARL) providing the strong override
elsewhere. This is useful, verified groundwork for Phase 2, but doesn't
change the bottom line: Phase 2 needs an actual NUCLEO-F767ZI in hand
to develop and verify against, not just the toolchain profile. One
specific risk already flagged for when that work starts: the bundled
profile's SysTick timing is presumably calibrated for the
F769-Discovery's own clock tree, not whatever NUCLEO-F767ZI defaults
to -- task periods would likely need empirical recalibration once
actually running, the same way `Bifrost.Delay_Util`'s busy-wait scaling
constants were originally derived for the C/Ada hello-world work.

## 3. Semihosting is not enabled -- runtime check failures trap silently

This is unrelated to tasking, but was discovered during the same LCD
port work and is still an open gap worth documenting on its own.

**What semihosting is**, for anyone unfamiliar: it's a mechanism that
lets code running on the target MCU ask an attached debug host (here,
OpenOCD) to perform I/O on its behalf -- printing a string, for
instance -- without the target having any actual console hardware of
its own. It works by executing a specific breakpoint instruction
(`bkpt 0xAB` on ARM); the debug host, if it's watching for this, catches
the breakpoint, performs the requested operation, and resumes the
target. If nothing is watching for it, that breakpoint instruction just
traps -- the target halts waiting for a host that isn't listening.

**Where this shows up in this project**: `GNAT.IO` on the
`light-cortex-m7f` runtime (and, so far as this project has checked,
the `light` family generally) is implemented on top of
`System.Semihosting.Put`. More importantly, the *default*
`Ada.Exceptions.Last_Chance_Handler` that this runtime ships --
installed automatically, nothing this project configured -- uses
`GNAT.IO.Put_Line` to print a diagnostic ("In last chance handler",
then either "Predefined exception raised at FILE:LINE" or a
user-supplied message, then "now suspending") before halting via
`System.Machine_Reset.Stop`. That diagnostic path runs on **every**
unhandled runtime check failure on this runtime -- a failed array
bounds check, a `Storage_Error`, anything -- not just the specific bug
that led to this being discovered.

**The gap**: `setupw.sh`'s OpenOCD invocation does not enable
semihosting (no `arm semihosting enable` in its server-mode command
list). So today, if a runtime check fails on real hardware, what
actually happens is a bare, unexplained `SIGTRAP` with the program
counter sitting inside `system.semihosting.put` -- not the readable
diagnostic message the runtime is actually trying to print. This is
exactly what the LCD port's debugging session initially looked like:
```
Program received signal SIGTRAP, Trace/breakpoint trap.
0x08001068 in system.semihosting.put ()
```
before the actual root cause (a malformed linker-script section
pattern, unrelated to semihosting itself -- see the git history around
the LCD port for the full diagnosis) was tracked down by reading the
installed runtime source directly rather than relying on the trap
message, since the trap message wasn't available.

**The fix, not yet applied**: add `arm semihosting enable` to the
`-c` command list in `setupw.sh`'s `--server` mode (alongside the
existing `adapter speed`/`transport select`/`gdb_port` commands). Once
enabled, the same class of failure would print its actual diagnostic
message to the gdb console instead of trapping opaquely -- a real
improvement to debuggability, independent of and not required for
either the tasking work in section 2 or any currently-working code
path.

<hr>
Copyright 2025 Jeff Wandling<br>
