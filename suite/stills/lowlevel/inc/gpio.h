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
#ifndef __STILLS_GPIO_H__
#define __STILLS_GPIO_H__

#include <stdint.h>

// Raw register addresses, hand-derived from the AHB1 peripheral base.
// No CMSIS header, no vendor device header.
#define PERIPH_BASE (0x40000000UL)
#define AHB1PERIPH_BASE (PERIPH_BASE + 0x00020000UL)
#define RCC_BASE (AHB1PERIPH_BASE + 0x3800UL)
#define GPIOB_BASE (AHB1PERIPH_BASE + 0x0400UL)

#define RCC_AHB1ENR ((volatile uint32_t *)(RCC_BASE + 0x30U))
#define GPIOB_MODER ((volatile uint32_t *)(GPIOB_BASE + 0x00U))
#define GPIOB_BSRR  ((volatile uint32_t *)(GPIOB_BASE + 0x18U))

#define GPIOBEN_BIT (1U) // RCC_AHB1ENR bit 1

#endif
