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
#include <stdint.h>
#include "led.h"

// Blinks LD1 using a busy-wait counter. No timer, no RTOS, no
// interrupt. See DESIGN.md for the volatile counter and the blink
// rate's lack of calibration.
int main(void)
{
    led_init();

    static volatile uint32_t counter = 0;
    static const uint32_t loop_threshold = 2000000U; // not calibrated
    int state = 0;

    while (1)
    {
        counter++;

        if (counter >= loop_threshold)
        {
            counter = 0;

            if (state)
            {
                led_off();
            }
            else
            {
                led_on();
            }
            state = !state;
        }
    }
}
