// ============================================================================
// Stills -- NUCLEO-F767ZI bare-metal C minimal example.
//
// Copyright (c) 2026 Jeff Wandling
// All Rights Reserved.
//
// Licensed under BSD 3-Clause
// Redistribution and use in source and binary forms, with or without
// modification, are permitted under the terms of the BSD 3-Clause license.
// See the LICENSE file for the full text.
// ============================================================================

// Vector table + Reset_Handler for STM32F767ZI, hand-written against
// the ARMv7-M architecture's own fixed exception layout. No external
// IRQ handler entries: this program enables no peripheral interrupt,
// so a vendor-sized vector table covering every possible IRQ would be
// dead weight. See DESIGN.md.
#include <stdint.h>

extern uint32_t _estack;

extern uint32_t _sidata; // LMA for .data (FLASH)
extern uint32_t _sdata;  // VMA start .data (RAM)
extern uint32_t _edata;  // VMA end .data (RAM)

extern uint32_t bss_start;
extern uint32_t bss_end;

extern int main(void);

void Reset_Handler(void);
void Default_Handler(void);

// The fixed Cortex-M system exceptions this vector table has slots
// for. Everything other than Reset is wired to Default_Handler: if
// any of these fires, spinning in a known, breakpointable location is
// more useful than silently resetting.
void NMI_Handler(void) __attribute__((weak, alias("Default_Handler")));
void HardFault_Handler(void) __attribute__((weak, alias("Default_Handler")));
void MemManage_Handler(void) __attribute__((weak, alias("Default_Handler")));
void BusFault_Handler(void) __attribute__((weak, alias("Default_Handler")));
void UsageFault_Handler(void) __attribute__((weak, alias("Default_Handler")));
void SVC_Handler(void) __attribute__((weak, alias("Default_Handler")));
void DebugMon_Handler(void) __attribute__((weak, alias("Default_Handler")));
void PendSV_Handler(void) __attribute__((weak, alias("Default_Handler")));
void SysTick_Handler(void) __attribute__((weak, alias("Default_Handler")));

static inline void copy_section(uint32_t *dst, const uint32_t *src, uint32_t *dst_end)
{
    while (dst < dst_end)
    {
        *dst++ = *src++;
    }
}

static inline void zero_section(uint32_t *dst, uint32_t *dst_end)
{
    while (dst < dst_end)
    {
        *dst++ = 0u;
    }
}

// Vector table: the architectural 16 slots only (MSP + Reset + the 7
// fixed system exceptions + 4 reserved + SVC/DebugMon/PendSV/SysTick),
// placed at the start of FLASH by the linker script's ".isr_vector"
// section.
__attribute__((section(".isr_vector"))) __attribute__((used))
void (*const g_pfnVectors[])(void) = {
    (void (*)(void))(&_estack), // 0  Initial MSP
    Reset_Handler,               // 1  Reset
    NMI_Handler,                 // 2  NMI
    HardFault_Handler,           // 3  HardFault
    MemManage_Handler,           // 4  MemManage
    BusFault_Handler,            // 5  BusFault
    UsageFault_Handler,          // 6  UsageFault
    0, 0, 0, 0,                  // 7-10 Reserved
    SVC_Handler,                 // 11 SVCall
    DebugMon_Handler,            // 12 DebugMonitor
    0,                           // 13 Reserved
    PendSV_Handler,              // 14 PendSV
    SysTick_Handler,             // 15 SysTick
};

void Reset_Handler(void)
{
    copy_section(&_sdata, &_sidata, &_edata);
    zero_section(&bss_start, &bss_end);

    (void)main();

    // main() never returns -- only reached if that invariant is
    // broken.
    while (1)
    {
        __asm__ volatile("bkpt 1");
    }
}

void Default_Handler(void)
{
    while (1)
    {
        __asm__ volatile("bkpt 1");
    }
}
