/* ============================================================================ */
/* This file is part of Bifrost                                                 */
/*                                                                              */
/* Copyright (c) 2025 Jeff Wandling                                             */
/* All Rights Reserved.                                                         */
/*                                                                              */
/* Licensed under BSD 3-Clause                                                  */
/* Redistribution and use in source and binary forms, with or without           */
/* modification, are permitted under the terms of the BSD 3-Clause license.     */
/* See the LICENSE file for the full text.                                      */
/* ============================================================================ */

/* STM32F722ZE (Cortex-M7 r1p1) — GCC linker script */
/* Flash: 512 KiB @ 0x08000000 */
/* SRAM: 256 KiB @ 0x20000000 (stack grows down from top of SRAM) */
/* NUCLEO-F722ZE is not the preferred board for Ada going forward --  */
/* see HARDWARE.md at the repo root. This is what the current         */
/* UART/LCD work was actually built and proven on.                    */

OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(Reset_Handler)

/* ---------------- Memory map ---------------- */
MEMORY
{
FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 512K
RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 256K
}

/* ---------------- Stack / heap sizing ---------------- */
_estack = ORIGIN(RAM) + LENGTH(RAM); /* top of RAM */
_Min_Heap_Size = 0x0000; /* set if you use malloc */
_Min_Stack_Size = 0x1000; /* 4 KiB default stack guard */

/* ---------------- Section layout ---------------- */
SECTIONS
{
/* Vector table at the beginning of FLASH */
.isr_vector :
{
KEEP(*(.isr_vector)) /* startup vector table */
} > FLASH

/* Optional: M7 ITCM stubs typically unused on F722; leave empty/omitted */

/* Text, RO data, and metadata in FLASH */
.text :
{
. = ALIGN(4);
*(.text) *(.text*) /* code */
*(.glue_7) *(.glue_7t)
*(.eh_frame)

. = ALIGN(4);
*(.rodata*)                       /* const data */

. = ALIGN(4);
KEEP(*(.init))
KEEP(*(.fini))

. = ALIGN(4);
/* C/C++ init/fini arrays */
PROVIDE_HIDDEN(__preinit_array_start = .);
KEEP(*(.preinit_array*))
PROVIDE_HIDDEN(__preinit_array_end = .);

. = ALIGN(4);
PROVIDE_HIDDEN(__init_array_start = .);
KEEP(*(SORT(.init_array.*)))
KEEP(*(.init_array*))
PROVIDE_HIDDEN(__init_array_end = .);

. = ALIGN(4);
PROVIDE_HIDDEN(__fini_array_start = .);
KEEP(*(SORT(.fini_array.*)))
KEEP(*(.fini_array*))
PROVIDE_HIDDEN(__fini_array_end = .);

. = ALIGN(4);
KEEP(*(.ctors)) KEEP(*(SORT(.ctors.*)))
KEEP(*(.dtors)) KEEP(*(SORT(.dtors.*)))

. = ALIGN(4);
KEEP(*(.ARM.extab* .gnu.linkonce.armextab.*))
KEEP(*(.ARM.exidx* .gnu.linkonce.armexidx.*))

. = ALIGN(4);
_etext = .;                       /* end of code/rodata in FLASH */


} > FLASH

/* -------- Optional: functions you want to execute from RAM --------
Place functions with: attribute((section(".ramfunc")))
These get VMA in RAM, LMA in FLASH, and are copied at startup. */
.ramfunc ALIGN(4) :
{
_sramfunc = .;
*(.ramfunc) *(.fastcode)
. = ALIGN(4);
_eramfunc = .;
} > RAM AT > FLASH
_siramfunc = LOADADDR(.ramfunc);

/* ---------------- Writable data (copied from FLASH to RAM) ---------------- */
.data : AT ( _etext )
{
. = ALIGN(4);
_sdata = .; /* vma: start of .data in RAM */
*(.data) *(.data*)
*(.gnu.linkonce.d*)
. = ALIGN(4);
_edata = .; /* vma: end of .data in RAM */
} > RAM
_sidata = LOADADDR(.data); /* lma: where to copy from in FLASH */

/* ---------------- Zero-init .bss ---------------- */
.bss (NOLOAD) :
{
. = ALIGN(4);
bss_start = .;
*(.bss) *(.bss*) *(COMMON)
. = ALIGN(4);
bss_end = .;
} > RAM

/* ---------------- No-init (retained across reset if not power-cycled) ---------------- */
.noinit (NOLOAD) :
{
. = ALIGN(4);
*(.noinit) *(.noinit*)
. = ALIGN(4);
} > RAM

/* ---------------- Heap and stack guard ---------------- */
. = ALIGN(8);
_end = .;
end = _end;

.heap (NOLOAD) :
{
. = ALIGN(8);
PROVIDE(heap_start = .);
. += _Min_Heap_Size;
PROVIDE(heap_end = .);
} > RAM

/* Reserve a minimum stack area at the end of RAM (not enforced by linker at runtime). */
/* The actual stack pointer is set to _estack by startup code. */
}

/* ---------------- Symbols for startup code ---------------- */
PROVIDE(_sbss = bss_start);
PROVIDE(_ebss = bss_end);
PROVIDE(_sdata = _sdata);
PROVIDE(_edata = _edata);
PROVIDE(_sidata = _sidata);

/* ---------------- Sanity checks ---------------- */
ASSERT(LENGTH(FLASH) >= 0x8000, "FLASH size unexpectedly small");
ASSERT(LENGTH(RAM) >= (_Min_Stack_Size + _Min_Heap_Size + 0x4000),
"RAM too small for requested stack/heap guard");

