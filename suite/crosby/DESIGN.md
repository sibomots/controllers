# Crosby — Design Notes

Minimal bare-metal Ada "hello world" for NUCLEO-F767ZI: blink user LED
LD1 with a busy-wait counter. No timer peripheral, no Ravenscar task,
no protected object, no interrupt anywhere in the program.

## LED pin

LD1 is PB0. This is the board's documented default wiring (UM1974
Rev 11, Section 7.5 and Table 12's SB120/SB119 solder-bridge entry):
SB120 ON / SB119 OFF connects the green user LED to PB0; the
alternate wiring (SB119 ON / SB120 OFF) routes it to PA5 instead, but
that is not this board's default and is not what this program
targets.

## Runtime choice

`crosby.gpr` selects the `light-stm32f769disco` runtime — a
non-tasking GNAT runtime profile for this chip family. Choosing a
profile with no Ravenscar tasking support at all makes "no task" a
property of what the program can even link against, rather than just
a coding convention.

One consequence: this runtime profile's own clock bring-up routine
(`Setup_Pll`) has not been tuned for this specific board's actual
oscillator source. That means the chip's real clock rate at boot may
not match the theoretical configuration. This has no effect on
correctness here — the busy-wait counter makes no timing claim to
begin with — but it does mean the blink rate is not calibrated to any
specific wall-clock duration. A future program in this series that
needs calibrated timing should address this directly rather than
assume the clock is correct.

## Register access

`Crosby.LED` writes directly to GPIOB/RCC registers via the runtime's
bundled `Interfaces.STM32` packages — no HAL, no intermediate driver
layer. `On`/`Off` use the GPIO `BSRR` register (atomic set/reset)
rather than a read-modify-write on `ODR`, since `BSRR` is the correct,
race-free way to drive a single output pin regardless of whether
anything else happens to be touching the same port.

## The counter loop

`Counter` in `main.adb` is marked `Volatile`. Without that, an
optimizing compiler would be entitled to notice the loop's only
observable effect is time spent, and delete the counting entirely.
The iteration threshold is empirically chosen, not calibrated to a
real time duration.
