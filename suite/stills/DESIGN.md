# Stills — Design Notes

Minimal bare-metal C "hello world" for NUCLEO-F767ZI: blink user LED
LD1 with a busy-wait counter, relying on nothing from the toolchain
beyond the compiler's own translation work, as far as that's
reasonable.

## LED pin

LD1 is PB0. This is the board's documented default wiring (UM1974
Rev 11, Section 7.5 and Table 12's SB120/SB119 solder-bridge entry):
SB120 ON / SB119 OFF connects the green user LED to PB0; the
alternate wiring (SB119 ON / SB120 OFF) routes it to PA5 instead, but
that is not this board's default and is not what this program
targets.

## No standard library

`CMakeLists.txt` links with `-nostdlib`, not just `-nostartfiles`.
This program never calls into newlib's `libc.a`/`libm.a` at all —
there is nothing in it that would need to. The vector table is
trimmed to the 16 architectural Cortex-M system-exception slots only;
this program enables no peripheral interrupt (nothing ever calls
`NVIC_EnableIRQ`), so a full vendor-sized table covering every
possible external IRQ would be dead weight, not rigor. The linker
script is similarly trimmed to just `.isr_vector`/`.text`/`.data`/
`.bss` — no `.ramfunc`, `.noinit`, heap, or C++ init/fini arrays,
since nothing here uses malloc, RAM-resident functions, or C++ static
constructors.

There is no C++ language enabled in this build at all, for the same
reason.

## Verification

After building, every defined symbol in the final `stills.elf` was
diffed against every symbol defined across the project's own object
files. The only symbols
present in the ELF but not traceable to a project `.c` file are
`_estack`, `_sdata`, `_edata`, `_etext`, `_sidata`, `bss_start`,
`bss_end`, and `_Min_Stack_Size` — all pure address labels assigned
directly by the linker script's own location-counter statements, zero
instruction bytes, not code. The resulting binary is 412 bytes of
`.text`, all of it traceable to this project's own three source files.

## Register access

`led.c` writes directly to GPIOB/RCC registers via hand-derived
addresses in `gpio.h` — no CMSIS header, no vendor device header.
`led_on`/`led_off` use the GPIO `BSRR` register (atomic set/reset)
rather than a read-modify-write on `ODR`.

## The counter loop

`counter` in `main.c` is `volatile`. Without that, an optimizing
compiler would be entitled to notice the loop's only observable effect
is time spent, and delete the counting entirely. The iteration
threshold is empirically chosen, not calibrated to a real time
duration.
