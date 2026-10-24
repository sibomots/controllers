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
# Quick Primer

One-time steps to get a working build/flash/debug environment for this
repo. Steps only, no rationale -- see the linked `SETUP.md`/`README.md`
pages if something here doesn't make sense or doesn't work.

This repo has six board/language combinations. You probably don't need
all of them -- use the table below to find out which steps apply to
you, then do only those sections.

| You want to build... | Shell (Windows) | C toolchain | Ada toolchain | Extra Ada step | Debug tool |
|---|---|---|---|---|---|
| `c/f722ze-tiny` | yes | yes | -- | -- | OpenOCD |
| `c/f767zi` | yes | yes | -- | -- | OpenOCD |
| `c/samv71-tiny` | yes | yes | -- | -- | SEGGER J-Link |
| `ada/f722ze-tiny` | yes | -- | yes | -- | OpenOCD |
| `ada/f767zi` | yes | -- | yes | **yes** | OpenOCD |
| `ada/samv71-tiny` | yes | -- | yes | -- | SEGGER J-Link |

On native Linux, skip the "Shell" section entirely; everything else is
the same, just without the `w` suffix on build/setup scripts
(`build.sh`/`setup.sh` instead of `buildw.sh`/`setupw.sh`).

---

## 1. Shell (Windows only)

Install **git-sdk-64**: https://github.com/git-for-windows/build-extra/releases

Do not use plain Git-for-Windows bash -- it's missing `cmake`/`make`
and can't install them. git-sdk-64 is a different, fuller download.

---

## 2. C toolchain

Needed for: `c/f722ze-tiny`, `c/f767zi`, `c/samv71-tiny`.

1. Download the ARM GNU Toolchain: https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads
   (Windows: the `arm-none-eabi` build for your host, e.g.
   `arm-gnu-toolchain-<version>-mingw-w64-i686-arm-none-eabi.zip`.)
2. Extract it somewhere with **no spaces in the path**, e.g. `/c/arm`:
   ```
   $ mkdir /c/arm
   $ cd /c/arm
   $ unzip /path/to/arm-gnu-toolchain-*.zip
   ```
3. Add it to `PATH` (append to `~/.bashrc`):
   ```
   export PATH=$PATH:/c/arm/bin
   ```
4. Reload and verify:
   ```
   $ . ~/.bashrc
   $ which arm-none-eabi-gcc
   ```
5. Install `cmake` and `make` (Windows/git-sdk-64 only -- native Linux
   already has these or gets them from your package manager):
   ```
   $ pacman -Syu mingw-w64-x86_64-cmake mingw-w64-x86_64-make
   ```

---

## 3. Ada toolchain

Needed for: `ada/f722ze-tiny`, `ada/f767zi`, `ada/samv71-tiny`.

This is a **separate, independent** toolchain from the C one above --
install both if you need both; neither depends on or conflicts with
the other (confirmed: zero overlapping binary names between them).

1. Download two separate archives from
   https://github.com/alire-project/GNAT-FSF-builds/releases:
   - `gnat-arm-elf-<host>-<version>.tar.gz`
   - `gprbuild-<host>-<version>.tar.gz`
2. Extract both somewhere with **no spaces in the path**, e.g.
   `/c/ada-arm`:
   ```
   $ mkdir -p /c/ada-arm
   $ cd /c/ada-arm
   $ tar xf /path/to/gnat-arm-elf-*.tar.gz
   $ tar xf /path/to/gprbuild-*.tar.gz
   ```
3. Add both `bin/` directories to `PATH` (append to `~/.bashrc`):
   ```
   export PATH=$PATH:/c/ada-arm/gnat-arm-elf-windows64-x86_64-<version>/bin
   export PATH=$PATH:/c/ada-arm/gprbuild-x86_64-windows64-<version>/bin
   ```
4. Reload and verify:
   ```
   $ . ~/.bashrc
   $ which gprbuild
   $ which arm-eabi-gcc
   ```

**PATH ordering matters if you also have a system-installed `gprbuild`**
(e.g. from a Linux distro package). Put the toolchain's own `bin/`
directory *before* the system one on `PATH` (prepend, don't append),
or the wrong, older `gprbuild` can get picked up silently.

---

## 4. Extra one-time step: `ada/f767zi` only

Skip this unless you're building `ada/f767zi`.

From `ada/f767zi/`:
```
$ make -f runtime-overrides/toolchain.mk
```

If it errors out looking for a path, open `runtime-overrides/toolchain.mk`
and edit the `GNAT_PREFIX` line near the top to match wherever you
extracted the Ada toolchain in step 3 above, then re-run.

This only needs to be done once per machine. Everything after this
builds with the normal `bash buildw.sh` (or `build.sh`) command, same
as every other project in this repo.

---

## 5. Debug tool

Pick based on which board(s) you're using -- both tools can be
installed side by side if you need both.

### OpenOCD (NUCLEO-F722ZE / NUCLEO-F767ZI, via on-board ST-Link)

1. Install it:
   ```
   $ pacman -Syu mingw-w64-x86_64-openocd
   ```
2. Plug in the board (micro-USB, a data cable, not power-only).
3. Windows only: if the board doesn't show up in Device Manager, install
   **STM32CubeProgrammer**
   (https://www.st.com/en/development-tools/stm32cubeprog.html) purely
   for its USB drivers -- open it once, then close it, you don't need
   to use the application itself.
4. Verify OpenOCD can see the board:
   ```
   $ export OPENOCD_SCRIPTS=/mingw64/share/openocd/scripts
   $ openocd -f interface/stlink.cfg -f target/stm32f7x.cfg -c "adapter speed 2000"
   ```
   You should see it detect a Cortex-M7 processor and start listening
   for GDB connections. Ctrl-C to stop.

### SEGGER J-Link (SAMV71 Xplained Ultra)

1. Download and install the **J-Link Software and Documentation Pack**:
   https://www.segger.com/downloads/jlink/
2. Plug in the board.
3. That's it -- `setupw.sh`/`setup.sh` in `c/samv71-tiny/main/` and
   `ada/samv71-tiny/` both wrap `JLinkGDBServer` directly; there's
   nothing else to configure.

---

## 6. Verify everything

From whichever project directory you set up, run its build script and
confirm it produces an `.elf` with no errors:

```
$ bash buildw.sh      # or build.sh on native Linux
```

If that works, you're done -- move on to that language's `README.md`
for the day-to-day build/flash/debug workflow.

<hr>
Copyright 2025 Jeff Wandling<br>
