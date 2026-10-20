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
# Ada Software Design

This directory holds two Ada ports: `f722ze-tiny` (internally named
`Bifrost`, same name as the C version it was ported from, same target,
different language) and `samv71-tiny` (internally `Samv71_Tiny`, ported
from `c/samv71-tiny`). See [`README.md`](README.md) for how they
compare board-for-board; this document explains the architecture of
both. Most of what follows is written through `f722ze-tiny`'s specific
implementation choices, since it's the simpler of the two -- a true
from-scratch bare-metal port with no board-specific Ada runtime support
at all. `samv71-tiny` shares the same underlying GNAT/Ada concepts
(same binder-generated `main`/`adainit` chain, same general reasoning
for why a super-loop/event-driven structure makes sense) but diverges
sharply in *how* those concepts get realized, because its board has
real Ravenscar tasking support and `f722ze-tiny`'s doesn't -- each
divergence is called out explicitly below, and a dedicated section near
the end ("How samv71-tiny Differs") covers what's genuinely new there
rather than a variation on `f722ze-tiny`'s approach.

## Requirements

The requirements for an application are three-fold, same three as the C
version -- only the *language* used to satisfy each one changes. (This
section describes `f722ze-tiny`; see "How samv71-tiny Differs" below
for why points 1 and 2 don't apply to it the same way -- point 3, the
GNAT-generated `main`/`adainit` chain, is identical on both.)

1.  A linker configuration. The file usually ends with the `.ld` suffix. The linker configuration
is not source code, but is written in the language understood by the linker in the toolchain. Each
linker is going to have a slightly different language to define the configuration. They all will resemble
each other, but with some possible enhancements or differences. The linker configuration described in this
example application is the **GNU linker command language** -- the *exact same* linker, the *exact same*
`.ld` language, as the C version. GNAT's `arm-eabi-gcc` hands off to the same `ld` the ARM GCC toolchain
uses; the linker itself has no idea, and does not care, whether the object files it's stitching together
were produced by a C compiler or an Ada compiler. In this port, `config/stm32f722ze.ld` is carried over
from the C tree essentially unchanged -- memory map, sections, and all.

2. Entry point. The entry point of the software is a function that is designed to be invoked when the processor
comes out of reset. Additionally, besides the handler for reset (sometimes called `ResetHandler`) there
are other functions that are executed based upon events that occur. Faults, errors, and non-fatal interrupts
*fire* based on events and the **interrupt vector** is the sequential arrangement of addresses for each prescribed
handler. The **interrupt vector** is an array, in order of those *handlers*, one of them being the **Entry Point**.
On this system, the **interrupt vector** is written into non-volatile memory, at address 0. The machine (otherwise
known as the CPU, or MCU) comes out of reset and branches to the instruction addressed by the content of address 0.

   In the C version, this vector table and its Reset Handler are written in C (and a sliver of assembly) in
   `lowlevel/src/startup_stm32f722.c`. In this Ada port, the equivalent lives in `lowlevel/src/bifrost-startup.adb`
   -- a pure-Ada vector table (an array of `System.Address`, placed into the `.isr_vector` section via
   `pragma Linker_Section`) and a pure-Ada `Reset_Handler` that copies `.data` from flash to RAM, zeroes
   `.bss`, and calls onward into the application. There is no hand-written assembly anywhere in this port
   -- GNAT's `System.Machine_Code.Asm` is used only for the two `bkpt` instructions in the fault/default
   handler, and even that is inline Ada, not a separate `.s` file.

3. An application. After the machine is initialized to the extent that the processor is ready to begin the application, then the startup defined by the handler for the **Reset Handler** is invoked. This function is called **main**.

   This is where Ada's model diverges most visibly from C's, even though the *end result at the hardware
   level* is identical. In C, `main` is just the function you wrote, called directly by the Reset Handler.
   In Ada, `main` is generated **by the GNAT binder** (`gnatbind`, invoked automatically by `gprbuild`) --
   it's a small, compiler-produced C-callable function named `main` that performs Ada package elaboration
   (`adainit`) before calling the actual Ada procedure you designated as the program's `Main` (here,
   `procedure Main` in `app/src/main.adb`), and would call `adafinal` after it returns (it never does,
   since `Main` is an infinite loop, same as the C side's `main`). Because GNAT's default binder behavior
   already produces a symbol literally named `main`, `Bifrost.Startup.Reset_Handler` can call it exactly
   the way the C Reset Handler calls C's `main` -- no Ada-specific glue is needed at the call site, only an
   `Import, Convention => C, External_Name => "main"` declaration so Ada knows the symbol exists.

## BSP and Drivers

BSP stands for Board Support Package. Drivers are routines that are designed to facilitate I/O or control
of peripherals of the MCU. An example is the UART drivers to configure data to be marshalled through the UART
for transmission or receive. Another example is the drivers for data transfer over I2C, SPI and other interfaces.
User applications use the driver functions to cause data or signals to be rendered onto the hardware.

When a BSP is devised, it is made so that all of the drivers that are specific to that instance of the board
support the capabilities that the board via the MCU provides. The same processing unit (MCU) may be used
on different boards and so each of the boards has a distinct BSP. The best source of the BSP and drivers
for the board is from the vendor of the board. Seldom do we re-write from scratch the entire BSP, although
it is common to adjust the BSP for requirements that are related to safety-critical software, or other
approval basis of the whole software system.

Some vendors also provide software tools that allow the software engineer to pick and choose certain properties
that *will be* part of the board design and therefore the BSP is customized for that particular board -- especially
if the board is a custom enterprise. The silicon (MCU, CPU, etc..) vendors usually provide these tools. An example
is the Texas Instruments HalCoGen tool for producing a driver set (BSP) for their processor families.

None of that tooling exists for Ada on **this board**. ST does not ship an Ada BSP, and the GNAT `light-cortex-m7f`
runtime that this port uses is deliberately minimal -- it provides the Ada language runtime (exception
plumbing to the extent the profile supports it, elaboration machinery, basic `System`/`Interfaces` packages)
but it has no notion of STM32 peripherals at all. This is the *same situation* the C version is in, just
without CMSIS/HAL as a fallback (see CMSIS, below) -- so, same as the C side chose to hand-write its own
low-level register access rather than pull in ST's full HAL, this Ada port hand-writes its own minimal
driver, `Bifrost.UART` (`lowlevel/src/bifrost-uart.ads/.adb`), directly against the USART3 register map
(memory-mapped via `with Volatile, Import, Address => ...` overlays -- Ada's equivalent of C's
`volatile uint32_t *` register pointers). There is no abstraction layer underneath it; it is the BSP, for
the one peripheral this application needs.

This "no BSP exists, hand-write everything" situation is specific to F722ZE/F767ZI, not a general statement
about Ada on Cortex-M -- `samv71-tiny`'s board (see "How samv71-tiny Differs" below) ships with a genuine,
AdaCore-maintained BSP (`Interfaces.SAM.*`, SVD-generated register packages covering PIO/PMC/EFC/UART) bundled
directly in the toolchain. `samv71-tiny` still hand-writes its own `USART1`/`WDT`/`MATRIX` register bindings
in the same SVD-generated style, but only because AdaCore's bundled packages happen not to cover the specific
USART peripheral (USART1) or watchdog/matrix registers this application needs -- not because no BSP exists at
all for that board, the way it genuinely doesn't for F722ZE.

# How Bifrost is Organized

In terms of the file structure, here is the layout of `bifrost`:

```
f722ze-tiny
├── bifrost.gpr
├── app
│   └── src
│       └── main.adb
├── behavioral
│   ├── calc
│   │   └── README.md
│   ├── client
│   │   └── README.md
│   └── src
│       ├── bifrost-tinymon.ads
│       └── bifrost-tinymon.adb
├── lowlevel
│   └── src
│       ├── bifrost.ads
│       ├── bifrost-startup.ads
│       ├── bifrost-startup.adb
│       ├── bifrost-uart.ads
│       ├── bifrost-uart.adb
│       ├── bifrost-delay_util.ads
│       └── bifrost-delay_util.adb
├── config
│   └── stm32f722ze.ld
├── buildw.sh
└── setupw.sh
```

The directory (`f722ze-tiny` -- the project file and internal package
names are still `bifrost`/`Bifrost`, the software's own identity, not
renamed along with the directory) contains `app`, `behavioral`, and
`lowlevel`, same three top-level roles as the C tree. Two structural
differences from the C tree, both deliberate:

* There is no top-level `interfaces` directory yet. The C tree's `interfaces` holds pure type/structure
  definitions with no implementation -- the rough equivalent in Ada would be a package spec (`.ads`) with
  no corresponding body, or one containing only type declarations. This hello-world port doesn't yet have
  any shared data structures that warrant pulling out into their own package, so `interfaces` has been
  deferred rather than built out speculatively ahead of need.
* There is no `inc`/`src` split within each component directory. C separates a public-facing `inc`
  (headers, the contract) from a private `src` (implementation) because C's header/source split is how it
  expresses a public interface at all. Ada already has this distinction built into the language itself --
  a package spec (`.ads`) *is* the public interface, and the package body (`.adb`) is the private
  implementation -- so there's no separate directory needed to express it; `.ads` and `.adb` simply live
  together in a single `src/` directory per component.

`behavioral/calc` and `behavioral/client` exist as empty placeholders (each holding only a `README.md`,
since git does not track empty directories) mirroring the C tree's directories of the same name and
intent -- reserved for the ohmmeter calculation and client logic respectively, not yet ported. What *is*
in `behavioral/` is `Bifrost.TinyMon` (`bifrost-tinymon.ads/.adb`), the console line editor/dispatcher
running over `Bifrost.UART`. See [`../README.md`](README.md#status) for the current state of what has
and has not been carried over from the C application.

## Major Components

* `Main` procedure is defined in software in `app` (`app/src/main.adb`) -- the Ada counterpart to C's
  `main` function living in `app`.
* The application relies on logic and routines implemented in `behavioral`. Low level and device driver
  software does not belong in `behavioral`.
* The `lowlevel` directory is designed to hold all of the specific BSP-like and drivers that are used by
  `behavioral` components -- in this port, that's the `Bifrost.UART` driver (interrupt-driven both
  directions, including the vector-table-extension plumbing `Bifrost.Startup` needs to route USART3's
  interrupt to it) and the `Bifrost.Startup` vector table/Reset Handler, both package pairs
  (`bifrost-*.ads`/`.adb`) rooted under the top-level `Bifrost` package (`bifrost.ads`), which exists
  purely to be the common namespace parent -- Ada requires a parent unit to exist (even if nearly empty)
  before you can declare children like `Bifrost.UART`.
* `interfaces` is where structures and types are defined. No compiled software per-se, but definitions of
data structures, and definitions that are integral to the shared format, structure, and properties of functionality
in the `behavioral` domain. In C++, this is where classes that provide only pure virtual methods are
defined; in Ada, the equivalent would be a package spec declaring only types (and perhaps abstract tagged
types with abstract/null-bodied primitive operations) with no implementation package body at all. We want
to limit `interfaces` from holding implementation, but rather only software definitions. Not yet populated
in this port, per the note above.

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

Neither Ada port in this directory uses CMSIS at all, by design, not by necessity. CMSIS is a C API (headers,
macros, `#define`d register structs) -- it is not something Ada can `with` the way it can an Ada library, and
binding to it would mean writing an Ada import layer around C declarations, which defeats the purpose of
a from-scratch Ada register overlay. `f722ze-tiny` already hand-writes its own register access (see BSP
and Drivers, above) directly against the memory map in the reference manual, so CMSIS-Core's role --
standardized register names and startup conventions -- is simply filled here by the Ada declarations in
`Bifrost.UART` and `Bifrost.Startup` themselves. `samv71-tiny` doesn't need CMSIS either, for a different
reason: its board-specific GNAT runtime already supplies the Ada-native equivalent (`Interfaces.SAM.*`,
`System.SAMV71`) directly -- see "How samv71-tiny Differs" below. None of CMSIS-DSP/RTOS/Driver/Pack are in
play at all for either project at this stage.

# How samv71-tiny Differs

`samv71-tiny` shares `f722ze-tiny`'s general Ada concepts (package
spec/body as the public/private split, the GNAT-generated `main`/
`adainit` binder chain from "Requirements" above) but its actual
architecture is built on real Ravenscar tasking, which changes enough
of the shape that it's described here on its own rather than as a
variant of the sections above.

## No hand-written startup at all

`f722ze-tiny` has to hand-write its own vector table, Reset Handler,
and `.data`/`.bss` init (`Bifrost.Startup`) because no board-specific
Ada runtime exists for its board at all -- the generic `light-cortex-m7f`
profile expects the application to supply its own startup code, by
design. `samv71-tiny`'s `light-tasking-samv71` runtime is the opposite
situation: it's a real, board-calibrated bb-runtimes BSP, and its own
`start-rom.S`/`start-ram.S` supplies the vector table, Reset Handler
equivalent, and clock bring-up (`Setup_Pll`) already. There is no
`Samv71_Tiny.Startup` package in this port at all -- not an omission,
a consequence of the runtime already covering that ground.

## Interrupt-driven I/O, the Ravenscar way

`samv71-tiny`'s USART1 driver (`Samv71_Tiny.USART1`,
`lowlevel/src/samv71_tiny-usart1.ads/.adb`) is interrupt-driven in both
directions, same end goal as `f722ze-tiny`'s `Bifrost.UART`, but built
on the actual Ravenscar primitives the language provides for this: a
`protected Controller` type (declared in the body, not exported) owns
the TX/RX ring buffers and the real interrupt handler procedure, bound
to the hardware via `pragma Attach_Handler (Handler,
Ada.Interrupts.Names.USART1)`. Blocking `Put`/`Get` are protected
*entries* with barriers (`TX_Count < TX_Ring_Size` / `RX_Count > 0`) --
the runtime itself handles having the consumer block cheaply on the
barrier rather than busy-polling, which is exactly the language-level
guarantee `f722ze-tiny` can't get and has to approximate by hand (a
plain Ada ISR procedure placed directly into a hand-extended vector
table, plus lock-free single-producer/single-consumer ring buffers
coded explicitly as `Volatile` shared state, since there's no protected
object available to do that coordination for it).

## A real console task, not a polled loop

`Samv71_Tiny.TinyMon`'s console (`lowlevel/src/samv71_tiny-tinymon.ads/.adb`)
runs as a library-level Ravenscar `task`, declared in the package body,
that blocks directly on `Samv71_Tiny.USART1`'s protected `Get` entry
and dispatches each byte as it arrives -- genuinely event-driven at the
language level, activated automatically by the runtime during
elaboration (before `Main`'s own body even begins, per Ravenscar's
standard task-activation order), no explicit "start the task" call
anywhere. `f722ze-tiny`'s `Bifrost.TinyMon` has no task to run on, so
it's a plain package whose `Parse` entry point gets polled
non-blockingly once per iteration of `Main`'s own loop instead
(`Bifrost.UART.Try_Get`, checked alongside the LCD update each pass) --
same console logic, same line editor, different activation model
entirely, forced by what each board's runtime actually provides.

## RTBus: a wire protocol, ported field-for-field

Unlike `f722ze-tiny` (which has no equivalent component at all),
`samv71-tiny` carries over the C tree's `rtbus/` component as
`Samv71_Tiny.RTBus` -- a MIL-1553-style packet format: frame sync, a
header with a CRC-16 checksum, a payload preamble, variable-length
arguments, and a trailing CRC-32 over the payload. The C structs are
`__attribute__((packed, aligned(1)))`; the Ada port mirrors this with
`pragma Pack` *and* an explicit `Alignment => 1` on each record type --
`Pack` alone wasn't sufficient and produced real "program execution may
be erroneous (RM 13.3(27))" warnings, since these records are always
overlaid onto an arbitrary, only-byte-aligned offset inside a
caller-owned raw buffer, never a standalone naturally-aligned object.
`Samv71_Tiny.CRC16`/`Samv71_Tiny.CRC32` are direct algorithmic ports of
the C reference. `Samv71_Tiny.Cmd_Handler` ports the tokenizer/state-
machine command dispatcher behind the console's `cmda`/`cmdb`/`cmdc`
stand-in commands (same deliberate minimalism as the C side -- these
aren't meant to be meaningful commands on their own, just a working,
verified proof of the whole pipeline), and `Samv71_Tiny.Exec_Cmd` ports
the LED-toggle side effects those commands trigger.

Verified beyond "it compiles": the pure-logic pieces (RTBus, CRC16/
CRC32, Cmd_Handler, TinyMon's line editor) have no hardware dependency
at all, so each was additionally checked with a native host-side test
(plain `gnatmake`, not the ARM cross-compiler) comparing raw output
bytes against the real C reference implementation compiled and run
natively with the same inputs -- byte-for-byte identical, confirmed,
not just plausible-looking.

## Directory layout

`samv71-tiny` does not use `f722ze-tiny`'s `app`/`behavioral`/`lowlevel`
three-way split. It mirrors `c/samv71-tiny`'s own component names
instead:

```
samv71-tiny
├── samv71_tiny.gpr
├── app
│   └── src
│       └── main.adb
└── lowlevel
    └── src
        ├── samv71_tiny.ads
        ├── samv71_tiny-board.ads
        ├── samv71_tiny-usart_regs.ads
        ├── samv71_tiny-wdt_regs.ads
        ├── samv71_tiny-matrix_regs.ads
        ├── samv71_tiny-usart1.ads / .adb
        ├── samv71_tiny-crc16.ads / .adb
        ├── samv71_tiny-crc32.ads / .adb
        ├── samv71_tiny-rtbus.ads / .adb
        ├── samv71_tiny-cmd_handler.ads / .adb
        ├── samv71_tiny-exec_cmd.ads / .adb
        └── samv71_tiny-tinymon.ads / .adb
```

Everything -- including `samv71_tiny-board.ads`, the board-constants
package -- lives flat under `lowlevel/src/`, confirmed directly against
the filesystem. This is a real, deliberate difference from
`f722ze-tiny`, not an oversight: `bifrost.gpr` has a `Board_Kind`
scenario variable selecting between sibling
`lowlevel/board/<name>/src/` directories (so a wrong board's constants
are structurally excluded from the build, not merely present and
guarded), because `f722ze-tiny` is written to be portable to a
different board's register map in principle (F722ZE vs. F767ZI).
`samv71_tiny.gpr` has no such scenario variable at all -- this port
targets exactly one board, so there was never a reason to carve out a
separate per-board directory for one set of constants that will only
ever have one entry. No separate top-level `rtbus/`/`tinymon/`
directories either, the way the C tree has them -- this port never grew
large enough to need app-level component boundaries beyond the
`app`/`lowlevel` split. No `behavioral/` at all: there's no ohmmeter
calc/client logic ported here either (same gap `f722ze-tiny` has), and
what little application logic exists (`Cmd_Handler`, `Exec_Cmd`,
`TinyMon`) stayed in `lowlevel/src/` alongside the drivers rather than
getting its own directory for a distinction that wouldn't have mattered
yet at this size.

## One more real, verified hardware-behavior difference

The C firmware's USART1 baud divisor constants were computed for a
300MHz peripheral clock, but the actual clock tree divides Master Clock
by 3 before it reaches any peripheral (100MHz) -- 115200 / 3 = 38400,
which is why the real hardware's PuTTY session has always needed to be
set to 38400 baud, a latent bug nobody had diagnosed before this port's
work. The Ada port does not reproduce it: it uses the runtime's own
`Setup_Pll` unmodified (settling at its native PLLA/2 = 150MHz MCK) and
computes a fresh, correct 115200-baud divisor (`CD => 81, FP => 3`) for
that actual clock, rather than carrying the C side's mismatched
constants forward.

# The Main Super Loop

Inside the `Main` procedure we find that the super-loop is the most reliable and simplest way
to organize cyclical behavior of the application -- this is pure software architecture, and it does not
change one bit from the C version to the Ada version. The loop *construct* changes (`while (1) { }` becomes
`loop ... end loop;`), but the *design reasoning* for structuring `main`/`Main` this way is identical,
language-agnostic, and reproduced here in full rather than just referenced, same as the C document does.

In this application specifically, and in many other applications where cyclical operation
is essential, then the super-loop is the preferred solution:

## The Super Loop Steps

A skeleton of `Main` would look like this:

```ada
procedure Main is
begin

   -- Preliminaries
   --   All preliminaries that must be performed before the system is ready to be
   --   initialized.
   Pre_Initialize;

   -- Setup as warranted
   --   All setup and preparation that is specific to the Application (not the machine)
   Initialize;

   -- The degree to which <i>setup</i> is subdivided is up to the programmer.

   -- Now, commence the loop forever.
   loop

      -- A wrapper procedure that may end up calling many other procedures,
      -- but results in the slate of state is populated with all sensed values
      -- that can be known -- we do that here.

      -- Examples:
      --     Gather_Inputs calls:
      --          Read_User_Inputs;
      --          Read_Temperature;
      --          Read_Voltage;
      --          Read_Current;
      --          Read_Messages;
      --          Read_Busses;
      --          etc

      -- The result after Gather_Inputs is finished is all that can be known is
      -- recorded in a Slate of State -- a record or array perhaps -- of all the metrics
      -- which can ever be known by the software.

      Gather_Inputs;


      -- Next, we calculate. By calculate we refer to the logic and decision
      -- making processes. We analyze results gathered, we determine next steps,
      -- choices are made, but no action to affect the system is taken.

      -- The actual choices to make (updates to state) are recorded into the state vector.

      -- Examples:
      --   Calculate calls:
      --         Deduce_Operation_From_State;
      --         Test_Thermal_Redlines;
      --         Derive_Resistance;
      --         State_Update;
      --         etc

      Calculate;


      -- Next, we act. By render, we mean to apply onto hardware signal or data
      -- which actuates, activates, or otherwise invokes dynamic behavior of the system
      -- based solely on the state, state vector and derived values.

      -- Examples:
      --   Render calls:
      --       Power_Up;
      --       Power_Down;
      --       Update_User_Display;
      --       Apply_Mux;
      --       Send_Data_On_Peripheral;
      --       etc

      Render;


      -- Next, optionally, we have a step for Telemetry.
      --
      -- It is the practice of this application to treat the word telemetry to mean
      -- data that is intended to be released off the target.
      --
      -- Examples:
      --   Telemeter calls:
      --        Debug_Log;
      --        etc
      --
      -- We do not want to use Telemetry as a method to perform data transfers between
      -- hardware components of the device for the operation.

      -- Instead, we want telemetry to be used as a method to send data off the target.
      -- In our application here, we may choose to enforce that telemetry is merely a debug
      -- benefit and in the release version of the system there is no literal telemetry.
      --
      -- Or perhaps we have a requirement that when directed by the user through the
      -- controls, telemetry is dumped in some fashion -- perhaps over a serial port,
      -- or perhaps over an Ethernet port, etc.

      Telemeter;


      -- Waiting for Sync is the last step. As the name implies here we wait. We wait
      -- for a signal prepared by the setup to allow execution to return to the top of
      -- this super-loop.

      -- When the software execution is characterized, and when we have requirements
      -- for the cyclical rate of the system, then we choose a timer structure that
      -- will ensure the best chance to resume execution at the top of the loop on a
      -- regular cadence.

      -- Example:
      --      Suppose the update (rendering) of the display is required to be at 10Hz.
      --      Suppose the potential for input gathering must be at 100Hz.
      --      Then,
      --        At 100Hz, a timer will fire that will modify a discrete value
      --        tested by Wait_For_Sync.

      --        However, we can choose in each of the major steps of the Super Loop to
      --        ignore the request for processing unless that functionality is required
      --        at the 10Hz. We slice the time-line.
      --
      --       Waiting can be performed by polling a register, or by simply sleeping
      --       in such a way to reduce power consumption. Only upon waking up
      --       at the onset of a new cycle are systems re-powered. That's an extreme
      --       case, but the point is -- we often want the behavior to be very
      --       close to deterministic.
      --
      --       The alternative is to make the Super Loop free-running -- which means
      --       We do not wait for sync pulse. We simply restart the loop immediately
      --       over and over.
      --
      --       Several kinds of peripherals like ADC would not benefit from free-running
      --       flow control since the preparation of an *ADC read* must be followed later
      --       by an operation to complete the act of reading the ADC. It takes time --
      --       and deciding the best cyclical rate is based on all of the factors of the
      --       underlying hardware.

      Wait_For_Sync;
   end loop;

   -- we never get here.

end Main;
```

The actual `Main` in `app/src/main.adb` today is a much smaller, free-running loop: initialize the LCD and
`Bifrost.UART`, show `Bifrost.TinyMon`'s welcome banner, then forever format/display the counter and poll
`Bifrost.UART.Try_Get` non-blockingly, feeding any byte to `Bifrost.TinyMon.Parse` -- it hasn't grown into
the full `Gather_Inputs`/`Calculate`/`Render`/`Telemeter`/`Wait_For_Sync` phase structure yet, same as the
C version's current `main.c`. The skeleton above is the target shape once ohmmeter behavior gets ported
into `behavioral`, not a description of what exists today.

`samv71-tiny` doesn't use this `Gather_Inputs`/`Calculate`/`Render`/`Telemeter`/`Wait_For_Sync` phase
structure either -- but unlike `f722ze-tiny`, it doesn't need to approximate the structure's real goal
(deterministic, concurrent handling of multiple event sources) by hand, because it already has actual
concurrency via Ravenscar tasking (see "How samv71-tiny Differs" above). Its `Main` does one-time hardware
bring-up and then simply parks; the `TinyMon` console task and the USART1 interrupt handler are the
concurrent units actually doing the work, scheduled by the runtime rather than by a hand-written phase
loop. In that sense `samv71-tiny` is closer to the *spirit* of this skeleton -- genuinely concurrent event
handling -- than `f722ze-tiny` is today, even though neither project uses this literal phase-named
structure yet.

<hr>
Copyright 2025 Jeff Wandling
