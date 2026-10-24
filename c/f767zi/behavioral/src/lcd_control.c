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
#include "delay.h"
#include "lcd_NHD_0108HZ.h"


void lcd_clear(void)
{
    lcd_write_cmd(0x01); // Clear display
}

void lcd_home(void)
{
    lcd_write_cmd(0x02); // Return home
}

// For NHD-0108 (8x1), DDRAM column addresses are 0x00..0x07
void lcd_set_cursor(uint8_t col)
{
    col &= 0x07;
    // clamp to 7 

	// Set DDRAM address
    lcd_write_cmd(0x80 | col);
}

void lcd_write_char(char c)
{
    lcd_write_data((uint8_t)c);
}

void lcd_write_string(const char *s)
{
    while (*s)
    {
        lcd_write_char(*s++);
    }
}

// --- Initialization sequence for 4-bit HD44780-compatible LCD ---

void lcd_init(void)
{
    lcd_gpio_init();

    // Initial power-on delay: >15ms
    delay_ms(20);

    // 4-bit init sequence (HD44780 datasheet)
    // We are only using DB4..DB7, so send 0x3 (8-bit mode)
    // as nibble three times, then 0x2 to switch to 4-bit mode.

    lcd_write_nibble(0x03, 0);
    delay_ms(5);

    lcd_write_nibble(0x03, 0);
    delay_us(150);

    lcd_write_nibble(0x03, 0);
    delay_us(150);

    lcd_write_nibble(0x02, 0); // Set 4-bit mode
    delay_us(150);

    // Now we can send full commands in 4-bit mode

    // Function set: 4-bit, 1-line, 5x8 font
    // 0b0010NFxx: N=0 (1 line), F=0 (5x8) -> 0x20
    lcd_write_cmd(0x20);

    // Display OFF
    lcd_write_cmd(0x08);

    // Display clear
    lcd_clear();

    // Entry mode set: increment, no shift (0x06)
    lcd_write_cmd(0x06);

    // Display ON, cursor off, blink off (0x0C)
    lcd_write_cmd(0x0C);
}
