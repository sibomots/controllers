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
#include "gpio.h"

// --- GPIO helpers ---

void lcd_gpio_init(void)
{
    // Enable GPIOB clock (bit1 in RCC_AHB1ENR)
    *RCC_AHB1ENR |= (1U << 1);

    // Configure PB1,2,3,4,5,10,15 as general-purpose outputs
    uint32_t moder = *GPIOB_MODER;

    // Clear existing mode bits
    moder &= ~((3U << (LCD_DB4 * 2U)) | (3U << (LCD_DB5 * 2U)) | (3U << (LCD_DB6 * 2U)) | (3U << (LCD_DB7 * 2U)) |
               (3U << (LCD_E * 2U)) | (3U << (LCD_RDWR * 2U)) | (3U << (LCD_DI * 2U)));

    // Set to output mode (01)
    moder |= ((1U << (LCD_DB4 * 2U)) | (1U << (LCD_DB5 * 2U)) | (1U << (LCD_DB6 * 2U)) | (1U << (LCD_DB7 * 2U)) |
              (1U << (LCD_E * 2U)) | (1U << (LCD_RDWR * 2U)) | (1U << (LCD_DI * 2U)));

    *GPIOB_MODER = moder;

    // Default levels: E=0, RW=0, DI=0, data lines low
    *GPIOB_ODR &= ~((1U << LCD_E) | (1U << LCD_RDWR) | (1U << LCD_DI) | (1U << LCD_DB4) | (1U << LCD_DB5) |
                    (1U << LCD_DB6) | (1U << LCD_DB7));
}

// --- Low-level bit helpers ---

void lcd_set_bit(uint32_t bit)
{
    *GPIOB_ODR |= (1U << bit);
}

void lcd_clear_bit(uint32_t bit)
{
    *GPIOB_ODR &= ~(1U << bit);
}

// --- Write a 4-bit nibble on DB4..DB7 and strobe E ---

void lcd_write_nibble(uint8_t nibble, uint8_t is_data)
{
    // RS (DI) line: 1 = data, 0 = command
    if (is_data)
    {
        lcd_set_bit(LCD_DI);
    }
    else
    {
        lcd_clear_bit(LCD_DI);
    }

    // RW = 0 (write only; we do not read busy flag)
    lcd_clear_bit(LCD_RDWR);

    // Set data bits (DB4..DB7) according to nibble[3:0]
    // Clear current data bits first
    *GPIOB_ODR &= ~((1U << LCD_DB4) | (1U << LCD_DB5) | (1U << LCD_DB6) | (1U << LCD_DB7));

    if (nibble & 0x01)
        lcd_set_bit(LCD_DB4);
    if (nibble & 0x02)
        lcd_set_bit(LCD_DB5);
    if (nibble & 0x04)
        lcd_set_bit(LCD_DB6);
    if (nibble & 0x08)
        lcd_set_bit(LCD_DB7);

    // Pulse E to latch nibble
    lcd_set_bit(LCD_E);
    delay_us(1); // enable pulse width, t_pweh >= 230ns for HD44780
    lcd_clear_bit(LCD_E);
    delay_us(50); // allow command to settle
}

// --- Public low-level: write full 8-bit command or data ---

void lcd_write_byte(uint8_t value, uint8_t is_data)
{
    // Send high nibble first, then low nibble
    lcd_write_nibble((value >> 4) & 0x0F, is_data);
    lcd_write_nibble(value & 0x0F, is_data);
}

// Convenience wrappers
void lcd_write_cmd(uint8_t cmd)
{
    lcd_write_byte(cmd, 0);
    // Some commands need more time; be conservative /
    if (cmd == 0x01 || cmd == 0x02)
    {
        // Clear display or return home
        delay_ms(2);
    }
    else
    {
        delay_us(50);
    }
}

void lcd_write_data(uint8_t data)
{
    lcd_write_byte(data, 1);
    delay_us(50);
}
