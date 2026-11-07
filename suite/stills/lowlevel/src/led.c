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
#include "gpio.h"
#include "led.h"

void led_init(void)
{
    // Ungate GPIOB's clock before touching its registers.
    *RCC_AHB1ENR |= (1U << GPIOBEN_BIT);

    // PB0 to General Purpose Output mode: MODER bits[1:0] = "01".
    *GPIOB_MODER = (*GPIOB_MODER & ~0x00000003UL) | 0x00000001UL;
}

void led_on(void)
{
    // BSRR sets/resets a pin atomically, without a read-modify-write
    // on ODR.
    *GPIOB_BSRR = (1U << 0);
}

void led_off(void)
{
    // BSRR's upper 16 bits are the "reset" half (bit 16 resets pin 0).
    *GPIOB_BSRR = (1U << 16);
}
