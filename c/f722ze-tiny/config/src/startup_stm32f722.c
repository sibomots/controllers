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
#include <stdint.h>

// File: startup_stm32f722xx.c
// Build with: -mcpu=cortex-m7 -mthumb -ffreestanding -fno-builtin -O0

// Linker symbols
extern uint32_t _estack;

extern uint32_t _sidata; // LMA for .data (FLASH)
extern uint32_t _sdata;  // VMA start .data (RAM)
extern uint32_t _edata;  // VMA end .data (RAM)

extern uint32_t bss_start;
extern uint32_t bss_end;

extern uint32_t _siramfunc; // LMA for .ramfunc (FLASH)
extern uint32_t _sramfunc;  // VMA start .ramfunc (RAM)
extern uint32_t _eramfunc;  // VMA end .ramfunc (RAM)

extern void __libc_init_array(void);
extern int main(void);

// void SystemInit(void); // usually provided by CMSIS system file; weak below

// Forward declarations
void Reset_Handler(void);
void Default_Handler(void);

// Cortex-M core exceptions (weak aliases to Default_Handler)
void NMI_Handler(void) __attribute__((weak, alias("Default_Handler")));
void HardFault_Handler(void) __attribute__((weak, alias("Default_Handler")));
void MemManage_Handler(void) __attribute__((weak, alias("Default_Handler")));
void BusFault_Handler(void) __attribute__((weak, alias("Default_Handler")));
void UsageFault_Handler(void) __attribute__((weak, alias("Default_Handler")));
void SVC_Handler(void) __attribute__((weak, alias("Default_Handler")));
void DebugMon_Handler(void) __attribute__((weak, alias("Default_Handler")));
void PendSV_Handler(void) __attribute__((weak, alias("Default_Handler")));
void SysTick_Handler(void) __attribute__((weak, alias("Default_Handler")));

// A minimal but practical subset of STM32F7 peripheral IRQs.
// Add concrete handlers as you enable peripherals in your app.
void WWDG_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void PVD_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TAMP_STAMP_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void RTC_WKUP_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void FLASH_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void RCC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void EXTI0_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void EXTI1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void EXTI2_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void EXTI3_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void EXTI4_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream0_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream2_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream3_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream4_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream5_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream6_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void ADC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN1_TX_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN1_RX0_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN1_RX1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN1_SCE_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void EXTI9_5_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM1_BRK_TIM9_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM1_UP_TIM10_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM1_TRG_COM_TIM11_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM1_CC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM2_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM3_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM4_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C1_EV_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C1_ER_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C2_EV_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C2_ER_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SPI1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SPI2_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void USART1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void USART2_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void USART3_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void EXTI15_10_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void RTC_Alarm_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void OTG_FS_WKUP_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM8_BRK_TIM12_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM8_UP_TIM13_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM8_TRG_COM_TIM14_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM8_CC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA1_Stream7_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void FMC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SDMMC1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM5_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SPI3_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void UART4_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void UART5_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM6_DAC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void TIM7_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream0_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream2_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream3_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream4_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void ETH_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void ETH_WKUP_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN2_TX_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN2_RX0_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN2_RX1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CAN2_SCE_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void OTG_FS_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream5_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream6_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2_Stream7_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void USART6_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C3_EV_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C3_ER_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void OTG_HS_EP1_OUT_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void OTG_HS_EP1_IN_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void OTG_HS_WKUP_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void OTG_HS_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DCMI_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void RNG_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void FPU_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void UART7_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void UART8_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SPI4_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SPI5_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SPI6_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SAI1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void LTDC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void LTDC_ER_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void DMA2D_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SAI2_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void QUADSPI_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void LPTIM1_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void CEC_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C4_EV_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void I2C4_ER_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SPDIF_RX_IRQHandler(void) __attribute__((weak, alias("Default_Handler")));
void SDMMC2_IRQHandler(void) __attribute__((weak, alias("Default_Handler"))); // if present on package

// added to deal with --nostartup and bare metal // jdw
void _init(void)
{
}
void _fini(void)
{
}

// Helpers
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

// Vector table placed at the beginning of FLASH
__attribute__((section(".isr_vector"))) __attribute__((used)) void (*const g_pfnVectors[])(void) = {
    (void (*)(void))(&_estack), // Initial MSP
    Reset_Handler,              // Reset
    NMI_Handler,                // NMI
    HardFault_Handler,          // HardFault
    MemManage_Handler,          // MemManage
    BusFault_Handler,           // BusFault
    UsageFault_Handler,         // UsageFault
    0, 0, 0, 0,                 // Reserved
    SVC_Handler,                // SVCall
    DebugMon_Handler,           // DebugMonitor
    0,                          // Reserved
    PendSV_Handler,             // PendSV
    SysTick_Handler,            // SysTick

    // External interrupts start here (IRQ0..)
    WWDG_IRQHandler,               // 0
    PVD_IRQHandler,                // 1
    TAMP_STAMP_IRQHandler,         // 2
    RTC_WKUP_IRQHandler,           // 3
    FLASH_IRQHandler,              // 4
    RCC_IRQHandler,                // 5
    EXTI0_IRQHandler,              // 6
    EXTI1_IRQHandler,              // 7
    EXTI2_IRQHandler,              // 8
    EXTI3_IRQHandler,              // 9
    EXTI4_IRQHandler,              // 10
    DMA1_Stream0_IRQHandler,       // 11
    DMA1_Stream1_IRQHandler,       // 12
    DMA1_Stream2_IRQHandler,       // 13
    DMA1_Stream3_IRQHandler,       // 14
    DMA1_Stream4_IRQHandler,       // 15
    DMA1_Stream5_IRQHandler,       // 16
    DMA1_Stream6_IRQHandler,       // 17
    ADC_IRQHandler,                // 18
    CAN1_TX_IRQHandler,            // 19
    CAN1_RX0_IRQHandler,           // 20
    CAN1_RX1_IRQHandler,           // 21
    CAN1_SCE_IRQHandler,           // 22
    EXTI9_5_IRQHandler,            // 23
    TIM1_BRK_TIM9_IRQHandler,      // 24
    TIM1_UP_TIM10_IRQHandler,      // 25
    TIM1_TRG_COM_TIM11_IRQHandler, // 26
    TIM1_CC_IRQHandler,            // 27
    TIM2_IRQHandler,               // 28
    TIM3_IRQHandler,               // 29
    TIM4_IRQHandler,               // 30
    I2C1_EV_IRQHandler,            // 31
    I2C1_ER_IRQHandler,            // 32
    I2C2_EV_IRQHandler,            // 33
    I2C2_ER_IRQHandler,            // 34
    SPI1_IRQHandler,               // 35
    SPI2_IRQHandler,               // 36
    USART1_IRQHandler,             // 37
    USART2_IRQHandler,             // 38
    USART3_IRQHandler,             // 39
    EXTI15_10_IRQHandler,          // 40
    RTC_Alarm_IRQHandler,          // 41
    OTG_FS_WKUP_IRQHandler,        // 42
    TIM8_BRK_TIM12_IRQHandler,     // 43
    TIM8_UP_TIM13_IRQHandler,      // 44
    TIM8_TRG_COM_TIM14_IRQHandler, // 45
    TIM8_CC_IRQHandler,            // 46
    DMA1_Stream7_IRQHandler,       // 47
    FMC_IRQHandler,                // 48
    SDMMC1_IRQHandler,             // 49
    TIM5_IRQHandler,               // 50
    SPI3_IRQHandler,               // 51
    UART4_IRQHandler,              // 52
    UART5_IRQHandler,              // 53
    TIM6_DAC_IRQHandler,           // 54
    TIM7_IRQHandler,               // 55
    DMA2_Stream0_IRQHandler,       // 56
    DMA2_Stream1_IRQHandler,       // 57
    DMA2_Stream2_IRQHandler,       // 58
    DMA2_Stream3_IRQHandler,       // 59
    DMA2_Stream4_IRQHandler,       // 60
    ETH_IRQHandler,                // 61
    ETH_WKUP_IRQHandler,           // 62
    CAN2_TX_IRQHandler,            // 63
    CAN2_RX0_IRQHandler,           // 64
    CAN2_RX1_IRQHandler,           // 65
    CAN2_SCE_IRQHandler,           // 66
    OTG_FS_IRQHandler,             // 67
    DMA2_Stream5_IRQHandler,       // 68
    DMA2_Stream6_IRQHandler,       // 69
    DMA2_Stream7_IRQHandler,       // 70
    USART6_IRQHandler,             // 71
    I2C3_EV_IRQHandler,            // 72
    I2C3_ER_IRQHandler,            // 73
    OTG_HS_EP1_OUT_IRQHandler,     // 74
    OTG_HS_EP1_IN_IRQHandler,      // 75
    OTG_HS_WKUP_IRQHandler,        // 76
    OTG_HS_IRQHandler,             // 77
    DCMI_IRQHandler,               // 78
    0,                             // 79 (CRYP on some F7s; pad if not present)
    RNG_IRQHandler,                // 80
    FPU_IRQHandler,                // 81
    UART7_IRQHandler,              // 82
    UART8_IRQHandler,              // 83
    SPI4_IRQHandler,               // 84
    SPI5_IRQHandler,               // 85
    SPI6_IRQHandler,               // 86
    SAI1_IRQHandler,               // 87
    LTDC_IRQHandler,               // 88
    LTDC_ER_IRQHandler,            // 89
    DMA2D_IRQHandler,              // 90
    SAI2_IRQHandler,               // 91
    QUADSPI_IRQHandler,            // 92
    LPTIM1_IRQHandler,             // 93
    CEC_IRQHandler,                // 94
    I2C4_EV_IRQHandler,            // 95
    I2C4_ER_IRQHandler,            // 96
    SPDIF_RX_IRQHandler,           // 97
    SDMMC2_IRQHandler,             // 98

    // Pad the remainder out to 128 entries with Default_Handler to be safe
    [99 ... 127] = Default_Handler

};

// Weak SystemInit if CMSIS system file is not linked
__attribute__((weak)) void SystemInit(void)
{
    // Intentionally empty. Provide your RCC/clock init in system_stm32f7xx.c if
    // desired.
}

// Reset handler
void Reset_Handler(void)
{
    // Optionally set VTOR if you ever relocate the vector table
    // SCB->VTOR = (uint32_t)g_pfnVectors; // requires core_cm7.h

    if ((uintptr_t)&SystemInit != 0u)
    {
        SystemInit();
    }

    copy_section(&_sdata, &_sidata, &_edata);
    copy_section(&_sramfunc, &_siramfunc, &_eramfunc);
    zero_section(&bss_start, &bss_end);

    __libc_init_array();
    (void)main();

    while (1)
    {
        __asm__ volatile("bkpt 1");
    }
}

// Default handler for unimplemented IRQs
void Default_Handler(void)
{
    while (1)
    {
        asm volatile("bkpt 1");
    }
}
