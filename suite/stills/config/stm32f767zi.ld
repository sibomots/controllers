/* ============================================================================ */
/* Stills -- NUCLEO-F767ZI bare-metal C minimal example.                      */
/*                                                                              */
/* Copyright (c) 2026 Jeff Wandling                                            */
/* All Rights Reserved.                                                        */
/*                                                                              */
/* Licensed under BSD 3-Clause                                                 */
/* Redistribution and use in source and binary forms, with or without          */
/* modification, are permitted under the terms of the BSD 3-Clause license.    */
/* See the LICENSE file for the full text.                                     */
/* ============================================================================ */

/* STM32F767ZI (Cortex-M7). Flash: 2048 KiB @ 0x08000000.
 * SRAM: 512 KiB @ 0x20000000, treated as one flat region.
 * Trimmed to only the sections this program uses -- no .ramfunc, no
 * .noinit, no heap, no C++ init/fini arrays; see DESIGN.md. */

OUTPUT_FORMAT("elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(Reset_Handler)

MEMORY
{
FLASH (rx)  : ORIGIN = 0x08000000, LENGTH = 2048K
RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 512K
}

_estack = ORIGIN(RAM) + LENGTH(RAM);     /* top of RAM */
_Min_Stack_Size = 0x1000;                /* 4 KiB stack guard, checked below */

SECTIONS
{
  /* Vector table at the very start of FLASH. */
  .isr_vector :
  {
    KEEP(*(.isr_vector))
  } > FLASH

  .text :
  {
    . = ALIGN(4);
    *(.text) *(.text*)
    *(.glue_7) *(.glue_7t)
    *(.eh_frame)

    . = ALIGN(4);
    *(.rodata*)

    . = ALIGN(4);
    _etext = .;
  } > FLASH

  .data : AT (_etext)
  {
    . = ALIGN(4);
    _sdata = .;
    *(.data) *(.data*)
    . = ALIGN(4);
    _edata = .;
  } > RAM
  _sidata = LOADADDR(.data);

  .bss (NOLOAD) :
  {
    . = ALIGN(4);
    bss_start = .;
    *(.bss) *(.bss*) *(COMMON)
    . = ALIGN(4);
    bss_end = .;
  } > RAM
}

ASSERT(LENGTH(FLASH) >= 0x8000, "FLASH size unexpectedly small");
ASSERT(LENGTH(RAM) >= _Min_Stack_Size, "RAM too small for stack guard");
