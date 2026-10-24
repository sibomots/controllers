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
#ifndef __BIFROST_GPIO_H__
#define __BIFROST_GPIO_H__

#define PERIPH_BASE 0x40000000UL
#define AHB1PERIPH_BASE (PERIPH_BASE + 0x00020000UL)
#define RCC_BASE (AHB1PERIPH_BASE + 0x3800UL)
#define GPIOB_BASE (AHB1PERIPH_BASE + 0x0400UL)
#define GPIOD_BASE (AHB1PERIPH_BASE + 0x0C00UL)

#define RCC_AHB1ENR ((volatile uint32_t *)(RCC_BASE + 0x30))
#define RCC_APB1ENR ((volatile uint32_t *)(RCC_BASE + 0x40))
#define GPIOB_MODER ((volatile uint32_t *)(GPIOB_BASE + 0x00))
#define GPIOB_ODR ((volatile uint32_t *)(GPIOB_BASE + 0x14))
#define GPIOD_MODER ((volatile uint32_t *)(GPIOD_BASE + 0x00))
#define GPIOD_AFRH ((volatile uint32_t *)(GPIOD_BASE + 0x24))

#define GPIODEN_BIT (3) // RCC_AHB1ENR bit 3
#define USART3EN_BIT (18) // RCC_APB1ENR bit 18

// USART3 ("new" IP: separate ISR/TDR, not legacy SR/DR -- RM0431)
#define USART3_BASE (PERIPH_BASE + 0x4800UL)
#define USART3_CR1 ((volatile uint32_t *)(USART3_BASE + 0x00))
#define USART3_BRR ((volatile uint32_t *)(USART3_BASE + 0x0C))
#define USART3_ISR ((volatile uint32_t *)(USART3_BASE + 0x1C))
#define USART3_RDR ((volatile uint32_t *)(USART3_BASE + 0x24))
#define USART3_TDR ((volatile uint32_t *)(USART3_BASE + 0x28))
#define USART3_IRQn (39) // RM0431 Table 36, cross-checked against the
                          // vendor vector table in config/src/startup_stm32f767.c

// NVIC (Nested Vectored Interrupt Controller) interrupt set-enable
// register covering IRQ32-63. Fixed by the ARMv7-M architecture itself,
// identical across every Cortex-M3/4/7 regardless of vendor -- not
// RM0431-sourced (RM0431 defers NVIC programming to the Cortex-M7
// Programming Manual, PM0253).
#define NVIC_ISER1 ((volatile uint32_t *)(0xE000E104UL))

// port B
#define PB1 (1)
#define PB2 (2)
#define PB15 (15)
#define PB14 (14)
#define PB13 (13)
#define PB6 (6)
#define PB10 (10)
#define PB4 (4)
#define PB5 (5)
#define PB3 (3)

// logical name, NUCLEO PIN GPIO, DISPLAY PIN number:
#define LCD_DB4 PB10 // display pin 6
#define LCD_DB5 PB4  // display pin 7
#define LCD_DB6 PB5  // display pin 8
#define LCD_DB7 PB3  // display pin 9
#define LCD_E PB2    // disiplay pin 5
#define LCD_RDWR PB1 // display read-write pin 4
#define LCD_DI PB15  // display register select (data or instruction) pin 3

// display pins 2, and 1 are used for power
// display pins 10 and 11 are used for backlight power.
//
#endif
