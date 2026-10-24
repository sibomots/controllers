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
# Runtime Clock-Bringup Overrides (one-time toolchain step)

`gnat_user/s-bbbopa.ads` and `gnat_user/setup_pll.adb` in this directory
are **not** part of this project's own `Source_Dirs` -- `bifrost.gpr`
never references either, and neither is picked up by a normal
`gprbuild` run as-is. Both have to be copied into the installed GNAT
toolchain's own runtime directory once per machine, the same category
of one-time step `../SETUP.md` already covers for toolchain install.

## Why this exists

`bifrost.gpr` selects the `light-tasking-stm32f769disco` runtime --
chosen because NUCLEO-F767ZI's STM32F767ZI silicon is memory-map-
identical to the STM32F769NI that runtime profile targets (see
`../../../HARDWARE.md`). But that profile's own board-clock constants, in
`<gnat-prefix>/arm-eabi/lib/gnat/light-tasking-stm32f769disco/gnat/
s-bbbopa.ads`, are calibrated for the STM32F769-**Discovery** board's own
25MHz crystal -- a different board from NUCLEO-F767ZI, whose HSE is 8MHz
(ST-LINK MCO by default, or the board's own reference-design crystal if
populated -- both land on 8MHz; see the comments in this directory's
`s-bbbopa.ads` for the full derivation). Left unmodified, `Setup_Pll`
(the runtime's clock bring-up routine, called automatically before `Main`
ever runs) would compute its PLL multiplier for the wrong input clock --
silently; this is not a build-time error, the board would just come up
at the wrong SYSCLK, with wrong UART baud and wrong SysTick timing.

The runtime's own `README` (same directory tree, one level up from
`gnat/`) documents the fix directly: "Change the values in that package
to reflect your specific board, as necessary. The runtime system uses
them to configure the clocks so changes will take effect automatically."
The installed runtime ships an empty `gnat_user/` directory for exactly
this, searched *before* the runtime's own `gnat/` directory (per that
runtime's `ada_source_path` file). Nothing in this project's own
`Source_Dirs` can reach into the runtime's internal unit-shadowing search
order the same way, which is why this lives outside `bifrost.gpr`
entirely rather than as a normal project source file.

That "changes will take effect automatically" line is accurate for
`gnatmake` used the classic, non-project way (`gnatmake -a`) -- it really
will walk the whole affected dependency chain and recompile it on its
own. It is **not** accurate for `gprbuild`, confirmed directly by testing
rather than assumed: `gprbuild -P bifrost.gpr` never recompiles
predefined/runtime units on its own, with or without `-a` (which it
silently accepts and does nothing with); `gnatmake -P ... -a` doesn't
help either, since project-mode `gnatmake` is just a thin wrapper around
`gprbuild` internally and drops `-a` outright ("switch -a is ignored").
Left at just a file drop into `gnat_user/`, every ordinary `gprbuild`
build of this project would keep failing at bind ("X must be recompiled")
forever. `toolchain.mk` (see below) is what actually makes this work --
not a convenience, the only thing that does.

## A second issue: an unexplained ~1/3 clock undershoot (open)

Real hardware behaves strangely in a way no register inspection
explains: `RCC_CR`/`RCC_CFGR` report `HSERDY`/`PLLRDY` both set, `SW`/
`SWS` = PLL, `HPRE` = /1, `PPRE1` = /4 -- every register consistent
with the intended `PCLK1` = 50MHz. But the clock actually reaching
peripherals measures at very close to 1/3 of that, confirmed two
independent ways on real hardware: the UART needs a terminal set to
38400 instead of the ~115200 the `BRR` math targets for 50MHz, and
`Ada.Real_Time` measured against a real, stopwatch-timed 30-second
interval ticks at almost exactly 1/3 the intended rate. Both land on
the same ratio. `HSERDY`/`PLLRDY` only confirm the oscillator
*stabilized* at something, not that it stabilized at the right
frequency, which is why register-reading alone didn't catch this.

**A disproven theory, kept for the record so it isn't retried blind:**
this board's HSE -- until a real crystal is populated at X3 -- comes
from the ST-LINK's own MCO output, an *actively*-driven digital clock
signal, not a passive crystal. The stock `setup_pll.adb` hardcodes
`HSE_Bypass : constant Boolean := False`, which configures the chip's
crystal-oscillator amplifier circuit -- feeding an actively-driven
signal into that circuit instead of bypass mode is a real, known
failure mode (the amplifier can lock onto a parasitic subharmonic of
the drive signal). This looked like a strong candidate fix and was
applied (`gnat_user/setup_pll.adb` here sets `HSE_Bypass => True`), but
**real-hardware retest after this fix disproved it**: rebuilt with the
fix in place, reflashed, still 38400 baud -- no change at all. The
`HSE_Bypass => True` change is left in place (not reverted, since it
isn't shown to be harmful either), but it is not the fix, and the real
root cause of the 1/3 undershoot is still unknown.

**Current workaround, applied where it's actually needed:**
`lowlevel/src/bifrost-uart.adb`'s `USART3_Periph.BRR` is set to target
the *measured* ~16.667MHz (50MHz/3) effective clock directly
(`Mantissa=9, Fraction=1, BRR=145`) rather than the theoretical 50MHz
value (`Mantissa=27, Fraction=2, BRR=434`) -- a symptom-level patch,
not a fix, documented as such in that file's own comment. If the real
root cause is ever found and fixed upstream (in the clock tree itself,
not here), the BRR value needs to go back to targeting the true 50MHz,
and `Ada.Real_Time`-driven timing elsewhere in this port should be
re-checked too, since it rides the same clock tree and would also be
running 3x faster than intended once the real fix lands.

## Install step

One time, per machine, after installing the toolchain per `../SETUP.md`:

1. Open `toolchain.mk` and edit `GNAT_PREFIX` near the top to wherever
   the GNAT-FSF-builds ARM ELF archive was actually extracted on this
   machine (`/c/ada-arm/gnat-arm-elf-windows64-x86_64-<version>` per
   `../SETUP.md`'s own convention on Windows; `/opt/gnat-arm-elf-...`
   is a typical native-Linux location).
2. From this directory:
   ```
   $ make -f toolchain.mk
   ```
   (Requires the real MSYS2-rooted `make` under git-sdk-64 on Windows --
   plain Git-for-Windows bash doesn't provide it, same requirement
   `../../c/SETUP.md` already notes for that shell.)

This does more than copy files -- it actually recompiles the whole
affected dependency chain (via classic `gnatmake -a`, confirmed to be
the one tool that does this correctly) and writes the results directly
into the toolchain's own `adalib/`, permanently, verified end to end:
after running it, a completely ordinary `bash build.sh` (or `buildw.sh`)
-- no special flags, same as `f722ze-tiny`/`samv71-tiny`'s own builds --
compiles, binds, and links clean. `setup_pll.adb` specifically gets its
own separate compile pass inside the Makefile, because it's never
discovered by the main recompile pass at all: nothing in this
application's own Ada source "withs" it (`Setup_Pll` is called only
from the runtime's assembly-level startup code), so gnatmake's
`with`-clause-based dependency walk has no path to it regardless of
`-a` -- confirmed directly, not assumed, after the first version of
this Makefile silently skipped it.

Only ever touches `light-tasking-stm32f769disco`'s own directory tree --
see this file's own header for why that doesn't affect `f722ze-tiny`
(`light-cortex-m7f`) or `samv71-tiny` (`light-tasking-samv71`) at all.
Safe to re-run after editing `gnat_user/` content (e.g. a future
board-parameter tweak) -- it just redoes the patch with the new content.
